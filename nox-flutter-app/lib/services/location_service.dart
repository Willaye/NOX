import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../config/constants.dart';
import 'socket_service.dart';
import 'api_service.dart';

class LocationService {
  final SocketService _socketService;
  final ApiService _apiService;
  Timer? _locationTimer;
  String? _deviceId;
  Position? _lastPosition;

  Position? get lastPosition => _lastPosition;

  LocationService(this._socketService, this._apiService);

  Future<bool> requestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  Future<void> startTracking(String deviceId) async {
    _deviceId = deviceId;
    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      debugPrint('[NOX Location] Permission denied');
      return;
    }

    // Get initial position
    await _updateLocation();

    // Periodic location updates
    _locationTimer = Timer.periodic(
      AppConstants.locationInterval,
      (_) => _updateLocation(),
    );
  }

  Future<void> _updateLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      );

      _lastPosition = position;

      // Send via WebSocket for real-time
      _socketService.sendLocation(
        position.latitude,
        position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
      );

      // Also store via REST for persistence
      if (_deviceId != null) {
        await _apiService
            .submitLocation(
                _deviceId!, position.latitude, position.longitude,
                accuracy: position.accuracy, speed: position.speed)
            .catchError((e) =>
                debugPrint('[NOX Location] REST submit failed: $e'));
      }
    } catch (e) {
      debugPrint('[NOX Location] Error: $e');
    }
  }

  void stopTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }
}
