import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/constants.dart';

class ApiService {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Tracking/location/heartbeat endpoints are protected by the backend's
        // DeviceJwtGuard and require the DEVICE token (not the user token).
        // Everything else (auth, device registration, profile) uses the user
        // access token.
        final path = options.path;
        final isDeviceScoped = path.contains('/tracking') ||
            path.contains('/location-logs') ||
            path.contains('/heartbeat');
        String? token;
        if (isDeviceScoped) {
          token = await _storage.read(key: 'device_token');
        }
        token ??= await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          _storage.delete(key: 'access_token');
        }
        return handler.next(error);
      },
    ));
  }

  // ─── Auth ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> requestMagicLink(String email) async {
    try {
      final response =
          await _dio.post('/auth/magic-link/request', data: {'email': email});
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_friendlyError(e,
          fallback: 'Could not send the code. Please try again.'));
    }
  }

  Future<Map<String, dynamic>> verifyMagicLink(String token) async {
    try {
      final response =
          await _dio.post('/auth/magic-link/verify', data: {'token': token});
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_friendlyError(e,
          fallback: 'Invalid or expired code. Please try again.'));
    }
  }

  /// Turns a Dio error into a user-readable message, preferring the backend's
  /// own error text (e.g. the 503 "could not send code" message) over generic
  /// network copy.
  String _friendlyError(DioException e, {required String fallback}) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final m = data['message'];
      if (m is String && m.trim().isNotEmpty) return m;
      if (m is List && m.isNotEmpty) return m.first.toString();
    }
    final code = e.response?.statusCode;
    if (code == 429) {
      return 'Too many attempts. Please wait a minute and try again.';
    }
    if (code == 503) {
      return "We couldn't send your code right now. Please tap Resend in a few seconds.";
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Unable to reach the server. Check your connection and try again.';
    }
    return fallback;
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _dio.get('/auth/profile');
    return Map<String, dynamic>.from(response.data);
  }

  // ─── Device ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> registerDevice(String name) async {
    final response = await _dio.post('/devices', data: {'name': name});
    return Map<String, dynamic>.from(response.data);
  }

  /// Obtain a device JWT for an already-registered device (used when the agent
  /// has a deviceId but no stored device token — e.g. after reinstall). Sent
  /// with the user token; backend verifies ownership.
  Future<String?> issueDeviceToken(String deviceId) async {
    final response = await _dio.post('/devices/$deviceId/token');
    final data = Map<String, dynamic>.from(response.data);
    final token = data['deviceToken'];
    return token is String && token.isNotEmpty ? token : null;
  }

  Future<void> heartbeat(String deviceId,
      {double? latitude, double? longitude, int? batteryLevel}) async {
    await _dio.post('/devices/$deviceId/heartbeat', data: {
      'latitude': ?latitude,
      'longitude': ?longitude,
      'batteryLevel': ?batteryLevel,
    });
  }

  // ─── Tracking Submission ──────────────────────────────────────────────

  Future<void> submitAppUsageBatch(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    await _dio.post('/tracking/app-usage/batch', data: {'items': items});
  }

  Future<void> submitBrowsingHistoryBatch(
      List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    await _dio
        .post('/tracking/browsing-history/batch', data: {'items': items});
  }

  Future<void> submitCallLogsBatch(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    await _dio.post('/tracking/call-logs/batch', data: {'items': items});
  }

  Future<void> submitScreenTime(Map<String, dynamic> data) async {
    await _dio.post('/tracking/screen-time', data: data);
  }

  Future<void> submitGalleryBatch(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    await _dio.post('/tracking/gallery/batch', data: {'items': items});
  }

  Future<void> submitGalleryUpload(String filePath, {String? takenAt}) async {
    final file = await MultipartFile.fromFile(filePath,
        filename: filePath.split('/').last);
    final formData = FormData.fromMap({
      'file': file,
      if (takenAt != null) 'takenAt': takenAt,
    });
    await _dio.post('/tracking/gallery/upload', data: formData);
  }

  Future<void> submitLocation(
      String deviceId, double latitude, double longitude,
      {double? accuracy, double? speed}) async {
    // deviceId is derived server-side from the device JWT, so it must NOT be
    // sent in the body (the DTO rejects unknown fields).
    await _dio.post('/location-logs', data: {
      'latitude': latitude,
      'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
      if (speed != null && speed >= 0) 'speed': speed,
    });
  }

  // ─── Unlock / Social / Browser (feed native buffers) ─────────────────

  Future<void> submitUnlockEventsBatch(List<int> timestamps) async {
    if (timestamps.isEmpty) return;
    final items = timestamps
        .map((ts) => {
              'occurredAt': DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true)
                  .toIso8601String(),
            })
        .toList();
    await _dio.post('/tracking/unlock-event/batch', data: {'items': items});
  }

  Future<void> submitSocialEventsBatch(
      List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    await _dio.post('/tracking/social-event/batch', data: {'items': items});
  }

  Future<void> submitBrowserVisitsBatch(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    await _dio.post('/tracking/browsing-history/batch', data: {'items': items});
  }

  Future<void> submitSmsBatch(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    await _dio.post('/tracking/sms/batch', data: {'items': items});
  }

  Future<void> submitContactsSync(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    await _dio.post('/tracking/contacts/sync', data: {'items': items});
  }
}
