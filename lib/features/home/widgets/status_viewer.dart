import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/service_providers.dart';

class StatusViewer extends ConsumerStatefulWidget {
  final List<dynamic> entries;
  final int initialIndex;
  final String level;

  const StatusViewer({
    super.key,
    required this.entries,
    required this.initialIndex,
    required this.level,
  });

  @override
  ConsumerState<StatusViewer> createState() => _StatusViewerState();
}

class _StatusViewerState extends ConsumerState<StatusViewer> with TickerProviderStateMixin {
  late int _currentIndex;
  late List<dynamic> _localEntries;
  
  // Story animation controllers
  AnimationController? _progressController;
  bool _isPaused = false;
  
  // Real-time subscriptions
  StreamSubscription<Map<String, dynamic>>? _voteSub;
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    
    // Create a mutable copy of the entries so we can update vote/view counts in real-time
    _localEntries = List<dynamic>.from(widget.entries.map((e) => Map<String, dynamic>.from(e)));
    
    _initProgressController();
    _loadActiveEntryDetails();
    _subscribeToActiveEntry();
  }

  void _initProgressController() {
    _progressController?.dispose();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _progressController!.addListener(() {
      setState(() {});
    });

    _progressController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _goToNextStatus();
      }
    });

    _progressController!.forward();
  }

  @override
  void dispose() {
    _progressController?.dispose();
    _voteSub?.cancel();
    _unsubscribeFromActiveEntry();
    super.dispose();
  }

  void _subscribeToActiveEntry() {
    _voteSub?.cancel();
    final targetIndex = _currentIndex;
    if (targetIndex >= _localEntries.length) return;
    final entry = _localEntries[targetIndex];
    final int entryId = entry['id'];
    
    final realtime = ref.read(realtimeServiceProvider);
    realtime.subscribeToEntry(entryId);
    
    _voteSub = realtime.voteStream.listen((data) {
      if (!mounted) return;
      final incomingEntryId = data['entry_id'];
      if (incomingEntryId != null && incomingEntryId.toString() == entryId.toString()) {
        setState(() {
          _localEntries[targetIndex]['vote_count'] = data['new_vote_count'];
        });
      }
    });
  }

  void _unsubscribeFromActiveEntry() {
    if (_currentIndex < _localEntries.length) {
      final entry = _localEntries[_currentIndex];
      final int entryId = entry['id'];
      ref.read(realtimeServiceProvider).unsubscribeFromEntry(entryId);
    }
  }

  Future<void> _loadActiveEntryDetails() async {
    final targetIndex = _currentIndex;
    if (targetIndex >= _localEntries.length) return;
    final entry = _localEntries[targetIndex];
    final int entryId = entry['id'];
    
    try {
      // Fetch details from the API. The show endpoint automatically increments view_count!
      final response = await ref.read(apiServiceProvider).get('/entries/$entryId');
      if (response.data['success'] == true && mounted && _currentIndex == targetIndex) {
        final freshData = response.data['data'];
        setState(() {
          _localEntries[targetIndex]['view_count'] = freshData['view_count'];
          _localEntries[targetIndex]['vote_count'] = freshData['vote_count'];
        });
      }
    } catch (_) {}
  }

  void _goToNextStatus() {
    if (_currentIndex < _localEntries.length - 1) {
      _unsubscribeFromActiveEntry();
      setState(() {
        _currentIndex++;
        _isPaused = false;
      });
      _subscribeToActiveEntry();
      _loadActiveEntryDetails();
      _initProgressController();
    } else {
      // Completed all stories, close viewer
      Navigator.pop(context);
    }
  }

  void _goToPreviousStatus() {
    if (_currentIndex > 0) {
      _unsubscribeFromActiveEntry();
      setState(() {
        _currentIndex--;
        _isPaused = false;
      });
      _subscribeToActiveEntry();
      _loadActiveEntryDetails();
      _initProgressController();
    } else {
      // Restart current story if at start
      setState(() {
        _isPaused = false;
      });
      _progressController?.reset();
      _progressController?.forward();
    }
  }

  void _pauseStatus() {
    if (!_isPaused) {
      _progressController?.stop();
      setState(() {
        _isPaused = true;
      });
    }
  }

  void _resumeStatus() {
    if (_isPaused) {
      _progressController?.forward();
      setState(() {
        _isPaused = false;
      });
    }
  }

  Future<void> _castVoteLocal() async {
    _pauseStatus();
    final entry = _localEntries[_currentIndex];
    final int entryId = entry['id'];
    
    try {
      final response = await ref.read(apiServiceProvider).post('/votes/cast', data: {
        'entry_id': entryId,
        'level': widget.level,
      });
      
      if (response.data['success'] == true && mounted) {
        final newVoteCount = response.data['data']['new_vote_count'];
        setState(() {
          _localEntries[_currentIndex]['vote_count'] = newVoteCount;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vote cast successfully! 🗳️💖'),
            backgroundColor: AppColors.successGreen,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('Coins') || e.toString().contains('403') 
              ? 'Insufficient Sallah Coins! Please top up.' 
              : 'Failed to cast vote: $e'),
            backgroundColor: AppColors.errorRed,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      _resumeStatus();
    }
  }

  void _showAnalyticsDrawer(int entryId) {
    _pauseStatus();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _AnalyticsBottomSheet(entryId: entryId, formatTime: _formatRelativeTime);
      },
    ).then((_) {
      _resumeStatus();
    });
  }

  String _formatRelativeTime(String? dateTimeStr) {
    if (dateTimeStr == null) return '';
    try {
      final dateTime = DateTime.parse(dateTimeStr).toLocal();
      final difference = DateTime.now().difference(dateTime);
      
      if (difference.inSeconds < 60) {
        return 'just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = _localEntries[_currentIndex];
    final user = entry['user'] ?? {
      'name': 'My Sallah Status',
      'profile_photo_url': null,
    };
    final category = entry['category'];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Fullscreen story photo
            Positioned.fill(
              child: GestureDetector(
                onLongPressStart: (_) => _pauseStatus(),
                onLongPressEnd: (_) => _resumeStatus(),
                child: Center(
                  child: Image.network(
                    entry['photo_url'],
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentGold),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Tap navigation zones overlay
            Positioned.fill(
              child: Row(
                children: [
                  // Left 30% back zone
                  Expanded(
                    flex: 3,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _goToPreviousStatus,
                    ),
                  ),
                  // Middle 40% pause/resume handled by long press
                  const Expanded(
                    flex: 4,
                    child: SizedBox(),
                  ),
                  // Right 30% forward zone
                  Expanded(
                    flex: 3,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _goToNextStatus,
                    ),
                  ),
                ],
              ),
            ),

            // Top control header overlay
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // WhatsApp Segmented progress bars
                  Row(
                    children: List.generate(_localEntries.length, (index) {
                      double progressValue = 0.0;
                      if (index < _currentIndex) {
                        progressValue = 1.0;
                      } else if (index == _currentIndex) {
                        progressValue = _progressController?.value ?? 0.0;
                      }
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progressValue,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentGold),
                              minHeight: 3,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  
                  // Poster Profile Avatar details
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary,
                        backgroundImage: user['profile_photo_url'] != null
                            ? NetworkImage(user['profile_photo_url'])
                            : null,
                        child: user['profile_photo_url'] == null
                            ? const Icon(Icons.person, color: Colors.white, size: 20)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['name'],
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              category['name_en'] ?? 'Wankan Sallah',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Close button
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom glassmorphic dashboard panel
            if (!_isPaused)
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {}, // Block background tap-to-navigate gestures
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Caption if exists
                            if (entry['caption'] != null) ...[
                              Text(
                                entry['caption'],
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            
                            // Views and Votes Info Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Statistics chips
                                Row(
                                  children: [
                                    // Votes Chip
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        debugPrint('Votes Chip Tapped for Entry ID: ${entry['id']}');
                                        _showAnalyticsDrawer(entry['id']);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: AppColors.primary.withOpacity(0.4),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Text('🗳️', style: TextStyle(fontSize: 12)),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${entry['vote_count']} Votes',
                                              style: AppTextStyles.bodySmall.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    
                                    // Views Chip
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        debugPrint('Views Chip Tapped for Entry ID: ${entry['id']}');
                                        _showAnalyticsDrawer(entry['id']);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.15),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Text('👁️', style: TextStyle(fontSize: 12)),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${entry['view_count'] ?? 0} Views',
                                              style: AppTextStyles.bodySmall.copyWith(
                                                color: Colors.white70,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                // Glowing Interactive Vote action button
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    debugPrint('Glowing Vote Button Tapped for Entry ID: ${entry['id']}');
                                    _castVoteLocal();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: AppColors.goldGradient,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.accentGold.withOpacity(0.4),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        )
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.favorite, color: AppColors.richBrown, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Vote',
                                          style: AppTextStyles.bodySmall.copyWith(
                                            color: AppColors.richBrown,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsBottomSheet extends ConsumerStatefulWidget {
  final int entryId;
  final String Function(String?) formatTime;

  const _AnalyticsBottomSheet({
    required this.entryId,
    required this.formatTime,
  });

  @override
  ConsumerState<_AnalyticsBottomSheet> createState() => _AnalyticsBottomSheetState();
}

class _AnalyticsBottomSheetState extends ConsumerState<_AnalyticsBottomSheet> {
  bool _isLoading = true;
  List<dynamic> _votes = [];
  List<dynamic> _views = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    try {
      final response = await ref.read(apiServiceProvider).get('/entries/${widget.entryId}/analytics');
      if (response.data['success'] == true && mounted) {
        setState(() {
          _votes = response.data['data']['votes'];
          _views = response.data['data']['views'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Container(
        height: 400,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),
            
            // Tabs
            TabBar(
              indicatorColor: AppColors.accentGold,
              labelColor: AppColors.accentGold,
              unselectedLabelColor: Colors.white60,
              tabs: [
                Tab(text: 'Viewers (${_views.length})'),
                Tab(text: 'Voters (${_votes.length})'),
              ],
            ),
            
            // Tab contents
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentGold),
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Text(
                            'Failed to load analytics',
                            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
                          ),
                        )
                      : TabBarView(
                          children: [
                            // Viewers Tab List
                            _views.isEmpty
                                ? Center(
                                    child: Text(
                                      'No views yet 👁️',
                                      style: AppTextStyles.bodyMedium.copyWith(color: Colors.white60),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _views.length,
                                    itemBuilder: (context, index) {
                                      final view = _views[index];
                                      final viewer = view['user'] ?? {'name': 'Anonymous'};
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundImage: viewer['profile_photo_url'] != null
                                              ? NetworkImage(viewer['profile_photo_url'])
                                              : null,
                                          child: viewer['profile_photo_url'] == null
                                              ? const Icon(Icons.person)
                                              : null,
                                        ),
                                        title: Text(
                                          viewer['name'],
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text(
                                          'viewed ${widget.formatTime(view['viewed_at'])}',
                                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                                        ),
                                      );
                                    },
                                  ),
                            
                            // Voters Tab List
                            _votes.isEmpty
                                ? Center(
                                    child: Text(
                                      'No votes yet 🗳️',
                                      style: AppTextStyles.bodyMedium.copyWith(color: Colors.white60),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _votes.length,
                                    itemBuilder: (context, index) {
                                      final vote = _votes[index];
                                      final voter = vote['voter'] ?? {'name': 'Anonymous'};
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundImage: voter['profile_photo_url'] != null
                                              ? NetworkImage(voter['profile_photo_url'])
                                              : null,
                                          child: voter['profile_photo_url'] == null
                                              ? const Icon(Icons.person)
                                              : null,
                                        ),
                                        title: Text(
                                          voter['name'],
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text(
                                          'voted ${widget.formatTime(vote['voted_at'])}',
                                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                                        ),
                                      );
                                    },
                                  ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
