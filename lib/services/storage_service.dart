import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyToken = 'auth_token';
  static const String _keyPhone = 'user_phone';
  static const String _keyName = 'user_name';
  static const String _keyUserId = 'user_id';
  static const String _keyIsVerified = 'is_verified';
  static const String _keyHasSeenOnboarding = 'seen_onboarding';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  // Token
  Future<bool> setToken(String token) async {
    return await _prefs.setString(_keyToken, token);
  }

  String? getToken() {
    return _prefs.getString(_keyToken);
  }

  Future<bool> removeToken() async {
    return await _prefs.remove(_keyToken);
  }

  // Seen Onboarding
  Future<bool> setHasSeenOnboarding(bool seen) async {
    return await _prefs.setBool(_keyHasSeenOnboarding, seen);
  }

  bool getHasSeenOnboarding() {
    return _prefs.getBool(_keyHasSeenOnboarding) ?? false;
  }

  // Profile Data
  Future<void> saveUserSession({
    required String name,
    required String phone,
    required bool isVerified,
    int? userId,
  }) async {
    await _prefs.setString(_keyName, name);
    await _prefs.setString(_keyPhone, phone);
    await _prefs.setBool(_keyIsVerified, isVerified);
    if (userId != null) await _prefs.setInt(_keyUserId, userId);
  }

  int? getUserId() => _prefs.getInt(_keyUserId);

  String? getUserName() => _prefs.getString(_keyName);
  String? getUserPhone() => _prefs.getString(_keyPhone);
  bool isUserVerified() => _prefs.getBool(_keyIsVerified) ?? false;

  Future<void> clearAll() async {
    await _prefs.remove(_keyToken);
    await _prefs.remove(_keyName);
    await _prefs.remove(_keyPhone);
    await _prefs.remove(_keyIsVerified);
    await _prefs.remove(_keyUserId);
  }
}
