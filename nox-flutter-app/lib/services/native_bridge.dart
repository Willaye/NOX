import 'dart:async';
import 'package:flutter/services.dart';

/// Dart-side wrapper around the Kotlin NativeBridge. Exposes:
///   • Permission state snapshot + openers.
///   • Buffer drains for unlocks / notifications / accessibility / browser.
///   • Foreground service control.
///   • A stream of "nudge" events signalling that new native data is ready
///     to drain (so Flutter can act immediately instead of waiting for the
///     next poll tick).
class NativeBridge {
  static const _method = MethodChannel('nox.mdm/native');
  static const _event = EventChannel('nox.mdm/native_events');

  static Stream<Map<String, dynamic>>? _nudges;

  static Stream<Map<String, dynamic>> get nudges {
    return _nudges ??= _event
        .receiveBroadcastStream()
        .map((e) => Map<String, dynamic>.from(e as Map))
        .asBroadcastStream();
  }

  // ─── Permission state ─────────────────────────────────────────────────

  static Future<PermissionsSnapshot> getPermissionsSnapshot() async {
    final result = await _method.invokeMapMethod<String, dynamic>(
          'getPermissionsSnapshot',
        ) ??
        <String, dynamic>{};
    return PermissionsSnapshot.fromMap(result);
  }

  static Future<void> openNotificationListenerSettings() =>
      _method.invokeMethod('openNotificationListenerSettings');

  static Future<void> openAccessibilitySettings() =>
      _method.invokeMethod('openAccessibilitySettings');

  static Future<void> openUsageAccessSettings() =>
      _method.invokeMethod('openUsageAccessSettings');

  static Future<void> requestIgnoreBatteryOptimizations() =>
      _method.invokeMethod('requestIgnoreBatteryOptimizations');

  static Future<void> openAppNotificationSettings() =>
      _method.invokeMethod('openAppNotificationSettings');

  // ─── In-app APK auto-update ───────────────────────────────────────────

  /// True if the user has granted this app permission to launch the system
  /// package installer. On API < 26 the per-app toggle doesn't exist and
  /// Android reports true automatically.
  static Future<bool> canRequestPackageInstalls() async {
    try {
      final r = await _method.invokeMethod<bool>('canRequestPackageInstalls');
      return r ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the per-app "Install unknown apps" settings page (API 26+).
  static Future<void> openManageInstallSources() async {
    try {
      await _method.invokeMethod('openManageInstallSources');
    } catch (_) {
      // Ignore — the UI will refresh its state on resume and show the
      // permission as still-missing so the user can try again.
    }
  }

  /// Hands [path] to the system package installer. Returns false if the
  /// file is missing / unreadable / the intent can't be started.
  static Future<bool> installApk(String path) async {
    try {
      final r = await _method
          .invokeMethod<bool>('installApk', <String, dynamic>{'path': path});
      return r ?? false;
    } catch (_) {
      return false;
    }
  }

  // ─── Foreground service ───────────────────────────────────────────────

  static Future<void> startForegroundService() async {
    await _method.invokeMethod('startForegroundService');
  }

  static Future<void> stopForegroundService() async {
    await _method.invokeMethod('stopForegroundService');
  }

  // ─── Buffer drains ────────────────────────────────────────────────────

  /// Returns a list of millisecond timestamps for each unlock since the
  /// last drain. May be empty.
  static Future<List<int>> drainUnlocks() async {
    final result = await _method.invokeListMethod<Object?>('drainUnlocks');
    if (result == null) return const [];
    return result.map((e) {
      if (e is int) return e;
      if (e is num) return e.toInt();
      return int.tryParse(e.toString()) ?? 0;
    }).where((e) => e > 0).toList();
  }

  static Future<List<Map<String, dynamic>>> drainNotifications() async {
    final result = await _method.invokeListMethod<Object?>('drainNotifications');
    return _coerceEventList(result);
  }

  static Future<List<Map<String, dynamic>>> drainAccessibility() async {
    final result = await _method.invokeListMethod<Object?>('drainAccessibility');
    return _coerceEventList(result);
  }

  static Future<List<Map<String, dynamic>>> drainBrowserHistory() async {
    final result = await _method.invokeListMethod<Object?>('drainBrowserHistory');
    return _coerceEventList(result);
  }

  static List<Map<String, dynamic>> _coerceEventList(List<Object?>? raw) {
    if (raw == null) return const [];
    return raw
        .whereType<Map>()
        .map((m) => _deepCoerceMap(m))
        .toList(growable: false);
  }

  static Map<String, dynamic> _deepCoerceMap(Map m) {
    final out = <String, dynamic>{};
    m.forEach((k, v) {
      out[k.toString()] = _deepCoerce(v);
    });
    return out;
  }

  static dynamic _deepCoerce(dynamic v) {
    if (v is Map) return _deepCoerceMap(v);
    if (v is List) return v.map(_deepCoerce).toList();
    return v;
  }
}

class PermissionsSnapshot {
  final bool notificationListener;
  final bool accessibility;
  final bool usageAccess;
  final bool batteryUnrestricted;
  final bool postNotifications;
  final bool mediaAccess;
  final bool installPackages;

  const PermissionsSnapshot({
    this.notificationListener = false,
    this.accessibility = false,
    this.usageAccess = false,
    this.batteryUnrestricted = false,
    this.postNotifications = false,
    this.mediaAccess = false,
    this.installPackages = false,
  });

  factory PermissionsSnapshot.fromMap(Map<String, dynamic> m) =>
      PermissionsSnapshot(
        notificationListener: m['notificationListener'] == true,
        accessibility: m['accessibility'] == true,
        usageAccess: m['usageAccess'] == true,
        batteryUnrestricted: m['batteryUnrestricted'] == true,
        postNotifications: m['postNotifications'] == true,
        mediaAccess: m['mediaAccess'] == true,
        installPackages: m['installPackages'] == true,
      );

  bool get allEssentialGranted =>
      notificationListener && accessibility && batteryUnrestricted;

  bool get allRecommendedGranted =>
      allEssentialGranted &&
      usageAccess &&
      postNotifications &&
      mediaAccess &&
      installPackages;
}
