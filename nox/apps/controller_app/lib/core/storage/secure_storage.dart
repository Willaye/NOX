import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

class SecureStorageService {
  static const _tokenKey = 'nox_auth_token';
  static const _userKey = 'nox_user_data';
  static const _refreshTokenKey = 'nox_refresh_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Token ──────────────────────────────────────────────────
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // ── Refresh Token ──────────────────────────────────────────
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  // ── User Data ──────────────────────────────────────────────
  Future<void> saveUserData(String userData) async {
    await _storage.write(key: _userKey, value: userData);
  }

  Future<String?> getUserData() async {
    return await _storage.read(key: _userKey);
  }

  // ── Device Token (separate from user JWT; set after /enroll/complete) ──
  static const _deviceTokenKey = 'nox_device_token';
  static const _deviceIdKey = 'nox_device_id';

  Future<void> saveDeviceToken(String token, String deviceId) async {
    await _storage.write(key: _deviceTokenKey, value: token);
    await _storage.write(key: _deviceIdKey, value: deviceId);
  }

  Future<String?> getDeviceToken() => _storage.read(key: _deviceTokenKey);
  Future<String?> getDeviceId() => _storage.read(key: _deviceIdKey);

  Future<bool> hasDeviceToken() async {
    final t = await getDeviceToken();
    return t != null && t.isNotEmpty;
  }

  // ── Clear All ──────────────────────────────────────────────
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // ── Has Token ──────────────────────────────────────────────
  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
