import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/constants.dart';

class SocketService extends ChangeNotifier {
  io.Socket? _socket;
  bool _isConnected = false;
  final _commandController = StreamController<Map<String, dynamic>>.broadcast();

  bool get isConnected => _isConnected;
  Stream<Map<String, dynamic>> get commandStream => _commandController.stream;

  void connect({required String token, String? deviceId}) {
    final queryParams = <String, dynamic>{'token': token};
    if (deviceId != null) queryParams['deviceId'] = deviceId;

    _socket = io.io(
      '${AppConstants.wsUrl}${AppConstants.wsNamespace}',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .setQuery(queryParams)
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[NOX Socket] Connected');
      _isConnected = true;
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      debugPrint('[NOX Socket] Disconnected');
      _isConnected = false;
      notifyListeners();
    });

    _socket!.onConnectError((data) {
      debugPrint('[NOX Socket] Connection error: $data');
      _isConnected = false;
      notifyListeners();
    });

    _socket!.on('connected', (data) {
      debugPrint('[NOX Socket] Server confirmed: $data');
    });

    _socket!.on('command', (data) {
      debugPrint('[NOX Socket] Command received: $data');
      if (data is Map<String, dynamic>) {
        _commandController.add(data);
      }
    });

    _socket!.on('error', (data) {
      debugPrint('[NOX Socket] Error: $data');
    });

    _socket!.connect();
  }

  void sendLocation(double latitude, double longitude,
      {double? accuracy, double? speed}) {
    _socket?.emit('device:location', {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': ?accuracy,
      'speed': ?speed,
    });
  }

  void sendHeartbeat({int? batteryLevel}) {
    _socket?.emit('device:heartbeat', {
      'batteryLevel': ?batteryLevel,
    });
  }

  void sendDeviceData(String type, Map<String, dynamic> payload) {
    _socket?.emit('device:data', {
      'type': type,
      'payload': payload,
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _commandController.close();
    super.dispose();
  }
}
