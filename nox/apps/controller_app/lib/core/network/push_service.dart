import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import 'api_client.dart';

/// Thin FCM wrapper that:
///   1. Initializes Firebase lazily (silently no-ops if not configured).
///   2. Requests notification permission (iOS; Android 13+ via POST_NOTIFICATIONS).
///   3. Sends the device token to the backend for the signed-in admin.
///   4. Keeps the token up-to-date on refresh.
///
/// Degrades to a no-op when `Firebase.initializeApp` throws — e.g. if
/// `google-services.json` is missing in dev builds. This lets the app run
/// without a Firebase project while still being wired for prod.
class PushService {
  final Ref _ref;
  bool _initialized = false;
  bool _firebaseAvailable = false;
  String? _lastRegisteredToken;

  PushService(this._ref);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      // When google-services.json is missing, the plugin throws
      // "No Firebase App '[DEFAULT]' has been created".
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _firebaseAvailable = true;
    } catch (e) {
      debugPrint('[fcm] Firebase not initialized ($e) — push disabled');
      _firebaseAvailable = false;
      return;
    }

    try {
      // Ask for permission. On Android 13+ this maps to POST_NOTIFICATIONS.
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('[fcm] permission request failed: $e');
    }

    // Push token to backend now (if admin is already signed in).
    _syncToken();

    FirebaseMessaging.instance.onTokenRefresh
        .listen((_) => _syncToken(), onError: (e) => debugPrint('[fcm] token refresh error: $e'));
  }

  /// Pull the current token and register it with the backend for the
  /// signed-in admin. No-op for non-admins / anonymous.
  Future<void> _syncToken() async {
    if (!_firebaseAvailable) return;
    final auth = _ref.read(authStateProvider);
    if (!auth.isAuthenticated ||
        auth.user?.role?.toUpperCase() != 'ADMIN') {
      return;
    }
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      if (token == _lastRegisteredToken) return;
      await _ref.read(apiClientProvider).registerAdminFcmToken(token);
      _lastRegisteredToken = token;
      debugPrint('[fcm] admin token registered');
    } catch (e) {
      debugPrint('[fcm] token sync failed: $e');
    }
  }

  /// Call on logout.
  Future<void> clear() async {
    if (!_firebaseAvailable) return;
    try {
      await _ref.read(apiClientProvider).clearAdminFcmToken();
    } catch (_) {}
    _lastRegisteredToken = null;
  }
}

final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(ref);
  // Re-sync whenever auth transitions.
  ref.listen<AuthState>(authStateProvider, (prev, next) {
    if (next.isAuthenticated &&
        next.user?.role?.toUpperCase() == 'ADMIN') {
      service.init();
    } else if (prev != null &&
        prev.isAuthenticated &&
        !next.isAuthenticated) {
      service.clear();
    }
  });
  return service;
});
