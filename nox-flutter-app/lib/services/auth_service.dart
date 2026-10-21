import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  final ApiService _api;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _token;
  Map<String, dynamic>? _currentUser;
  String? _deviceId;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get token => _token;
  Map<String, dynamic>? get currentUser => _currentUser;
  String? get deviceId => _deviceId;

  AuthService(this._api);

  Future<void> checkAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      _token = await _storage.read(key: 'access_token');
      _deviceId = await _storage.read(key: 'device_id');

      if (_token != null) {
        _currentUser = await _api.getProfile();
        _isAuthenticated = true;
      }
    } catch (e) {
      _isAuthenticated = false;
      _token = null;
      await _storage.delete(key: 'access_token');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<String> requestMagicLink(String email) async {
    final result = await _api.requestMagicLink(email);
    return result['message'] ?? 'Magic link sent';
  }

  Future<bool> verifyMagicLink(String magicToken) async {
    try {
      final result = await _api.verifyMagicLink(magicToken);
      _token = result['accessToken'];
      _currentUser = Map<String, dynamic>.from(result['user']);

      await _storage.write(key: 'access_token', value: _token!);
      _isAuthenticated = true;
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> setDeviceId(String id) async {
    _deviceId = id;
    await _storage.write(key: 'device_id', value: id);
    notifyListeners();
  }

  /// Persist the device JWT used to authenticate tracking uploads.
  Future<void> setDeviceToken(String token) async {
    await _storage.write(key: 'device_token', value: token);
  }

  Future<bool> hasDeviceToken() async {
    final t = await _storage.read(key: 'device_token');
    return t != null && t.isNotEmpty;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'device_token');
    _token = null;
    _currentUser = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}
