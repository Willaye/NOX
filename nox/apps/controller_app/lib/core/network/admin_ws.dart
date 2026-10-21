import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../providers/auth_provider.dart';
import 'api_client.dart';

/// A single real-time alert received by an admin over the WebSocket channel.
/// Payload is the raw map so the UI can show additional fields if it wants.
class AdminAlert {
  final String kind; // 'unlock' | 'device_offline' | 'device_online' | 'other'
  final String title;
  final String message;
  final Map<String, dynamic> payload;
  final DateTime at;
  const AdminAlert({
    required this.kind,
    required this.title,
    required this.message,
    required this.payload,
    required this.at,
  });
}

/// Keeps the most recent N admin alerts for banner/history display and plays
/// the buzzer on urgent events.
class AdminAlertState {
  final List<AdminAlert> alerts;
  final AdminAlert? latest;
  final bool connected;
  const AdminAlertState({
    this.alerts = const [],
    this.latest,
    this.connected = false,
  });

  AdminAlertState copyWith({
    List<AdminAlert>? alerts,
    AdminAlert? latest,
    bool? connected,
    bool clearLatest = false,
  }) =>
      AdminAlertState(
        alerts: alerts ?? this.alerts,
        latest: clearLatest ? null : (latest ?? this.latest),
        connected: connected ?? this.connected,
      );
}

class AdminWsController extends StateNotifier<AdminAlertState> {
  final AudioPlayer _player = AudioPlayer(playerId: 'nox_alert');
  io.Socket? _socket;
  String? _lastToken;

  AdminWsController() : super(const AdminAlertState());

  /// Opens/refreshes the socket for the current signed-in admin. Safe to
  /// call on login and after reconnects.
  void start(String userJwt) {
    if (_socket != null && _lastToken == userJwt) return;
    _lastToken = userJwt;
    stop();
    final url = '$noxServerOrigin/nox-mdm';
    final socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': userJwt})
          .setExtraHeaders({'Authorization': 'Bearer $userJwt'})
          .enableReconnection()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(2000)
          .build(),
    );

    socket
      ..onConnect((_) {
        debugPrint('[ws] connected $url');
        state = state.copyWith(connected: true);
      })
      ..onDisconnect((_) {
        debugPrint('[ws] disconnected');
        state = state.copyWith(connected: false);
      })
      ..onConnectError((e) => debugPrint('[ws] connect_error: $e'))
      ..onError((e) => debugPrint('[ws] error: $e'))
      // ─── Admin-targeted events ───
      ..on('admin:unlock-alert', (data) => _onUnlockAlert(data))
      ..on('admin:device-offline', (data) => _onDeviceOffline(data))
      ..on('admin:device-online', (data) => _onDeviceOnline(data));

    socket.connect();
    _socket = socket;
  }

  void stop() {
    _socket?.dispose();
    _socket = null;
  }

  /// Dismiss the current banner. The alert stays in history.
  void dismissLatest() {
    state = state.copyWith(clearLatest: true);
  }

  // ─── Event handlers ───────────────────────────────────────

  void _onUnlockAlert(dynamic data) {
    final map = _asMap(data);
    final employee = map['employeeEmail']?.toString();
    final deviceName = map['deviceName']?.toString() ?? 'A device';
    final message = map['message']?.toString() ??
        (employee != null
            ? "$employee's phone was just unlocked"
            : '$deviceName was just unlocked');
    final alert = AdminAlert(
      kind: 'unlock',
      title: 'Device unlocked',
      message: message,
      payload: map,
      at: DateTime.now(),
    );
    _pushAlert(alert);
    _playBuzzer();
  }

  void _onDeviceOffline(dynamic data) {
    final map = _asMap(data);
    _pushAlert(AdminAlert(
      kind: 'device_offline',
      title: 'Device offline',
      message: map['message']?.toString() ?? 'A device stopped reporting',
      payload: map,
      at: DateTime.now(),
    ));
    _playBuzzer();
  }

  void _onDeviceOnline(dynamic data) {
    final map = _asMap(data);
    _pushAlert(AdminAlert(
      kind: 'device_online',
      title: 'Device online',
      message: 'A device came online',
      payload: map,
      at: DateTime.now(),
    ));
    // No buzzer for "online" — too noisy on daily reconnects.
  }

  // ─── Internals ────────────────────────────────────────────

  void _pushAlert(AdminAlert alert) {
    final next = [alert, ...state.alerts].take(50).toList(growable: false);
    state = state.copyWith(alerts: next, latest: alert);
  }

  Future<void> _playBuzzer() async {
    try {
      // Stop any previous play so rapid-fire alerts don't layer.
      await _player.stop();
      await _player.play(AssetSource('sounds/alert.wav'));
    } catch (e) {
      // Asset might be invalid in dev builds; log and move on.
      debugPrint('[ws] buzzer play failed: $e');
    }
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return const {};
  }

  @override
  void dispose() {
    stop();
    _player.dispose();
    super.dispose();
  }
}

final adminWsProvider =
    StateNotifierProvider<AdminWsController, AdminAlertState>((ref) {
  final controller = AdminWsController();
  // Hook: start the socket whenever we have an authenticated admin.
  ref.listen<AuthState>(authStateProvider, (prev, next) {
    final token = next.token;
    if (next.isAuthenticated &&
        token != null &&
        next.user?.role?.toUpperCase() == 'ADMIN') {
      controller.start(token);
    } else {
      controller.stop();
    }
  }, fireImmediately: true);
  return controller;
});
