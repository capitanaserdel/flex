import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ── Reverb / Pusher connection constants ────────────────────────────────────

/// LAN IP of the backend for real devices on the same WiFi.
/// Web testing uses 'localhost'.
const String _reverbHost = kIsWeb ? 'localhost' : '192.168.1.166';
const int    _reverbPort = 8080;

/// Reverb app key (from .env REVERB_APP_KEY)
const String _reverbAppKey = 'ewjawizvolbqa70ldyjy';

/// Laravel API base URL for private channel auth
const String _apiBase = kIsWeb
    ? 'http://localhost:8000/api'
    : 'http://192.168.1.166:8000/api';

/// WebSocket handshake URL — Pusher protocol path
String get _wsUrl =>
    'ws://$_reverbHost:$_reverbPort/app/$_reverbAppKey'
    '?protocol=7&client=flutter&version=1.0&flash=false';

// ── Pusher message types ─────────────────────────────────────────────────────
const _eventSubscribe    = 'pusher:subscribe';
const _eventUnsubscribe  = 'pusher:unsubscribe';
const _eventPong         = 'pusher:pong';

/// ---------------------------------------------------------------------------
/// RealtimeService
///
/// Pure-Dart Pusher-protocol WebSocket client for Laravel Reverb.
/// Uses [web_socket_channel] — works on iOS, Android, and Web.
///
/// Usage:
///   1. [connect] once after login (pass the JWT token).
///   2. [subscribeToCoins] to track balance changes.
///   3. [subscribeToEntry] before entering an entry detail screen.
///   4. [unsubscribeFromEntry] in dispose.
///   5. [disconnect] at logout.
///
/// Streams (broadcast — multiple listeners OK):
///   [coinStream]  → {user_id, new_balance, reason}
///   [voteStream]  → {entry_id, new_vote_count, level}
/// ---------------------------------------------------------------------------
class RealtimeService {
  WebSocketChannel? _channel;
  String? _socketId;
  String? _jwtToken;
  bool _connected = false;
  Timer? _pingTimer;

  /// Set of channels we are currently subscribed to
  final Set<String> _subscribed = {};

  final _coinController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _voteController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get coinStream => _coinController.stream;
  Stream<Map<String, dynamic>> get voteStream => _voteController.stream;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> connect({required String jwtToken}) async {
    if (_connected) return;
    _jwtToken = jwtToken;

    try {
      final uri = Uri.parse(_wsUrl);
      _channel = WebSocketChannel.connect(uri);
      _connected = true;
      debugPrint('[Reverb] ✅ WS connected to $uri');

      _channel!.stream.listen(
        _onMessage,
        onError: (e) => debugPrint('[Reverb] ❌ WS error: $e'),
        onDone: () {
          debugPrint('[Reverb] WS closed');
          _connected = false;
          _socketId = null;
          _pingTimer?.cancel();
          // Auto-reconnect after 3s
          Future.delayed(const Duration(seconds: 3), () {
            if (_jwtToken != null) connect(jwtToken: _jwtToken!);
          });
        },
      );
    } catch (e) {
      debugPrint('[Reverb] ❌ connect error: $e');
      _connected = false;
    }
  }

  void disconnect() {
    _pingTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _connected = false;
    _socketId = null;
    _subscribed.clear();
    _jwtToken = null;
  }

  void dispose() {
    disconnect();
    _coinController.close();
    _voteController.close();
  }

  // ── Message handling ───────────────────────────────────────────────────────

  void _onMessage(dynamic rawMessage) {
    try {
      final msg = jsonDecode(rawMessage as String) as Map<String, dynamic>;
      final event = msg['event'] as String?;
      final channel = msg['channel'] as String?;
      final rawData = msg['data'];

      // Parse nested data (Pusher wraps it as a JSON string sometimes)
      Map<String, dynamic> data = {};
      if (rawData is String && rawData.isNotEmpty) {
        try { data = jsonDecode(rawData) as Map<String, dynamic>; } catch (_) {}
      } else if (rawData is Map) {
        data = Map<String, dynamic>.from(rawData);
      }

      switch (event) {
        case 'pusher:connection_established':
          _socketId = data['socket_id'] as String?;
          debugPrint('[Reverb] socket_id: $_socketId');
          // Start ping/pong keepalive every 30s
          _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
            _send({'event': 'pusher:ping', 'data': {}});
          });
          // Re-subscribe to pending channels
          for (final ch in List.from(_subscribed)) {
            _sendSubscribe(ch);
          }
          break;

        case 'pusher:error':
          debugPrint('[Reverb] pusher error: ${data['message']}');
          break;

        case 'pusher:ping':
          _send({'event': _eventPong, 'data': {}});
          break;

        case 'coins.updated':
          if (!_coinController.isClosed) _coinController.add(data);
          debugPrint('[Reverb] 🪙 coins.updated: $data');
          break;

        case 'vote.cast':
          if (!_voteController.isClosed) _voteController.add(data);
          debugPrint('[Reverb] 🗳 vote.cast ch=$channel data=$data');
          break;

        default:
          // Ignore pusher internal events
          if (event != null && !event.startsWith('pusher')) {
            debugPrint('[Reverb] unhandled event: $event ch=$channel');
          }
      }
    } catch (e) {
      debugPrint('[Reverb] parse error: $e  raw=$rawMessage');
    }
  }

  // ── Channel subscriptions ──────────────────────────────────────────────────

  /// Subscribe to the **private** coin balance channel for [userId].
  /// Requires a private channel auth handshake against Laravel.
  Future<void> subscribeToCoins(int userId) async {
    final name = 'private-coins.$userId';
    if (_subscribed.contains(name)) return;
    _subscribed.add(name);

    if (!_connected || _socketId == null) return; // will subscribe after connection_established

    final auth = await _privateChannelAuth(name);
    if (auth != null) {
      _sendSubscribe(name, auth: auth);
    } else {
      debugPrint('[Reverb] ⚠️ could not auth private channel $name');
    }
  }

  /// Subscribe to the **public** vote-count channel for [entryId].
  void subscribeToEntry(int entryId) {
    final name = 'entry.$entryId';
    if (_subscribed.contains(name)) return;
    _subscribed.add(name);
    if (_connected && _socketId != null) _sendSubscribe(name);
  }

  /// Unsubscribe from an entry channel when leaving the screen.
  void unsubscribeFromEntry(int entryId) {
    final name = 'entry.$entryId';
    _subscribed.remove(name);
    if (_connected) {
      _send({'event': _eventUnsubscribe, 'data': {'channel': name}});
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _sendSubscribe(String channelName, {String? auth}) {
    final data = <String, dynamic>{'channel': channelName};
    if (auth != null) data['auth'] = auth;
    _send({'event': _eventSubscribe, 'data': data});
    debugPrint('[Reverb] subscribing to $channelName');
  }

  void _send(Map<String, dynamic> payload) {
    if (_channel == null) return;
    try {
      _channel!.sink.add(jsonEncode(payload));
    } catch (e) {
      debugPrint('[Reverb] send error: $e');
    }
  }

  /// Call Laravel's /broadcasting/auth to get a private channel auth signature.
  Future<String?> _privateChannelAuth(String channelName) async {
    if (_socketId == null || _jwtToken == null) return null;
    if (kIsWeb) return null; // skip private auth on web in debug

    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final uri = Uri.parse('$_apiBase/broadcasting/auth');
      final req = await client.postUrl(uri);
      req.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $_jwtToken')
        ..set(HttpHeaders.contentTypeHeader,
            'application/x-www-form-urlencoded');
      final body =
          'channel_name=${Uri.encodeQueryComponent(channelName)}'
          '&socket_id=${Uri.encodeQueryComponent(_socketId!)}';
      req.contentLength = utf8.encode(body).length;
      req.write(body);
      final resp = await req.close();
      final respBody = await resp.transform(utf8.decoder).join();
      client.close();

      // Response is JSON: {"auth":"key:signature"}
      final json = jsonDecode(respBody) as Map<String, dynamic>;
      return json['auth'] as String?;
    } catch (e) {
      debugPrint('[Reverb] auth error: $e');
      return null;
    }
  }
}
