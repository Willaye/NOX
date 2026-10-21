import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/secure_storage.dart';

/// Configure with `--dart-define=API_URL=https://api.example.com/api`.
/// Default targets the host machine from the Android emulator.
const String _baseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://nox-backend-production-ea47.up.railway.app/api',
);

/// Base URL exposed for other networking modules (WebSocket, direct downloads).
String get noxApiBaseUrl => _baseUrl;

/// Server origin (base URL without the trailing `/api`). The WebSocket
/// gateway lives under /nox-mdm on this origin, not under /api.
String get noxServerOrigin {
  final uri = Uri.parse(_baseUrl);
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme}://${uri.host}$port';
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(storage: storage);
});

class ApiClient {
  late final Dio _dio;
  final SecureStorageService storage;

  /// Invoked when a 401 occurs and the session cannot be recovered.
  VoidCallback? onSessionExpired;

  ApiClient({required this.storage}) {
    final options = BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    _dio = Dio(options);

    _dio.interceptors.add(_AuthInterceptor(
      storage: storage,
      dio: _dio,
      onSessionExpired: () => onSessionExpired?.call(),
    ));

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint('[API] $obj'),
      ));
    }
  }

  // ── Auth ───────────────────────────────────────────────────
  // Backend: POST /auth/login { email, password }
  // Returns: { user: { id, email, role, createdAt }, accessToken }
  Future<Response> login(String email, String password) async {
    return _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
  }

  // Backend: POST /auth/signup { email, password }
  // Returns: { user: { id, email, role, createdAt }, accessToken }
  // NOTE: backend does NOT accept firstName/lastName — only email+password
  Future<Response> signup(
    String firstName,
    String lastName,
    String email,
    String password,
  ) async {
    return _dio.post('/auth/signup', data: {
      'email': email,
      'password': password,
    });
  }

  // Backend: POST /auth/magic-link/request { email }
  Future<Response> requestMagicLink(String email) async {
    return _dio.post('/auth/magic-link/request', data: {'email': email});
  }

  // Backend: POST /auth/magic-link/verify { token }
  Future<Response> verifyMagicLink(String token) async {
    return _dio.post('/auth/magic-link/verify', data: {'token': token});
  }

  // Backend: POST /auth/set-password { password } (JWT required)
  Future<Response> setPassword(String password) async {
    return _dio.post('/auth/set-password', data: {'password': password});
  }

  // Backend has no /auth/logout — just clear tokens locally
  Future<void> logout() async {
    await storage.clearAll();
  }

  // Backend: GET /auth/profile (JWT required)
  // Returns: { id, email, role, createdAt, devices: [...] }
  Future<Response> getProfile() async {
    return _dio.get('/auth/profile');
  }

  // ── Devices ────────────────────────────────────────────────
  // Backend: GET /devices (JWT required, returns user's devices)
  Future<Response> getDevices() async {
    return _dio.get('/devices');
  }

  // Backend: GET /devices/:id (JWT required)
  Future<Response> getDevice(String id) async {
    return _dio.get('/devices/$id');
  }

  // Backend: POST /devices { name } (JWT required)
  Future<Response> registerDevice(Map<String, dynamic> data) async {
    return _dio.post('/devices', data: data);
  }

  // Backend: POST /devices/pair { pairingCode } (JWT required)
  Future<Response> pairDevice(String pairingCode) async {
    return _dio.post('/devices/pair', data: {'pairingCode': pairingCode});
  }

  // Backend: PUT /devices/:id { name? } (JWT required)
  Future<Response> updateDevice(String id, Map<String, dynamic> data) async {
    return _dio.put('/devices/$id', data: data);
  }

  // Backend: DELETE /devices/:id (JWT required)
  Future<Response> deleteDevice(String id) async {
    return _dio.delete('/devices/$id');
  }

  // Backend: POST /devices/:id/heartbeat { latitude?, longitude?, batteryLevel? }
  Future<Response> heartbeat(String id, {double? latitude, double? longitude, int? batteryLevel}) async {
    return _dio.post('/devices/$id/heartbeat', data: {
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (batteryLevel != null) 'batteryLevel': batteryLevel,
    });
  }

  // Backend: POST /devices/:id/regenerate-code (JWT required)
  Future<Response> regeneratePairingCode(String id) async {
    return _dio.post('/devices/$id/regenerate-code');
  }

  // ── Activity Logs ──────────────────────────────────────────
  // Backend: GET /activity-logs/device/:deviceId?limit&type&from&to
  Future<Response> getActivityLogs(String deviceId, {
    int? limit,
    int? offset,
    String? type,
  }) async {
    return _dio.get('/activity-logs/device/$deviceId', queryParameters: {
      if (limit != null) 'limit': limit,
      if (type != null) 'type': type,
    });
  }

  // Backend: GET /activity-logs/device/:deviceId/stats
  Future<Response> getActivityStats(String deviceId) async {
    return _dio.get('/activity-logs/device/$deviceId/stats');
  }

  // ── Location Logs ──────────────────────────────────────────
  // Backend: GET /location-logs/device/:deviceId?from&to&limit
  Future<Response> getLocationHistory(String deviceId) async {
    return _dio.get('/location-logs/device/$deviceId');
  }

  // Backend: GET /location-logs/device/:deviceId/latest
  Future<Response> getLatestLocation(String deviceId) async {
    return _dio.get('/location-logs/device/$deviceId/latest');
  }

  // ── Tracking (new endpoints) ───────────────────────────────
  Future<Response> getAppUsage(String deviceId, {int? limit, int? page}) async {
    return _dio.get('/tracking/app-usage/device/$deviceId', queryParameters: {
      if (limit != null) 'limit': limit,
      if (page != null) 'page': page,
    });
  }

  Future<Response> getBrowsingHistory(String deviceId, {int? limit}) async {
    return _dio.get('/tracking/browsing-history/device/$deviceId', queryParameters: {
      if (limit != null) 'limit': limit,
    });
  }

  Future<Response> getCallLogs(String deviceId, {int? limit}) async {
    return _dio.get('/tracking/call-logs/device/$deviceId', queryParameters: {
      if (limit != null) 'limit': limit,
    });
  }

  Future<Response> getScreenTime(String deviceId) async {
    return _dio.get('/tracking/screen-time/device/$deviceId');
  }

  Future<Response> getGallery(String deviceId, {int? limit}) async {
    return _dio.get('/tracking/gallery/device/$deviceId', queryParameters: {
      if (limit != null) 'limit': limit,
    });
  }

  // ── Notifications ──────────────────────────────────────────
  // Backend: GET /admin/notifications (admin only)
  Future<Response> getNotifications({int page = 1, int limit = 20}) async {
    return _dio.get('/admin/notifications');
  }

  // Backend: POST /admin/notifications/:id/read
  Future<Response> markNotificationRead(String id) async {
    return _dio.post('/admin/notifications/$id/read');
  }

  // Backend: POST /admin/notifications/read-all
  Future<Response> markAllNotificationsRead() async {
    return _dio.post('/admin/notifications/read-all');
  }

  // ── Users ──────────────────────────────────────────────────
  Future<Response> changePassword(String currentPassword, String newPassword) async {
    return _dio.put('/users/me/password', data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  // ── Enrollment ─────────────────────────────────────────────
  // Admin: POST /enroll/invite { email, firstName?, lastName?, deviceName? }
  // Returns: { inviteId, email, expiresAt, inviteUrl }
  Future<Response> createEnrollmentInvite({
    required String email,
    String? firstName,
    String? lastName,
    String? deviceName,
  }) async {
    return _dio.post('/enroll/invite', data: {
      'email': email,
      if (firstName != null && firstName.isNotEmpty) 'firstName': firstName,
      if (lastName != null && lastName.isNotEmpty) 'lastName': lastName,
      if (deviceName != null && deviceName.isNotEmpty) 'deviceName': deviceName,
    });
  }

  /// Device: POST /enroll/complete { token, deviceModel?, osVersion?, ... }
  /// Public endpoint — authenticated by the single-use invite token in the
  /// body, NOT by a user JWT. We send with no Authorization header so a
  /// stale user token can't shadow the invite auth.
  Future<Response> completeEnrollment({
    required String inviteToken,
    String? deviceModel,
    String? osVersion,
    String? appVersion,
    String? deviceName,
    String? fcmToken,
  }) async {
    return _dio.post(
      '/enroll/complete',
      data: {
        'token': inviteToken,
        if (deviceModel != null) 'deviceModel': deviceModel,
        if (osVersion != null) 'osVersion': osVersion,
        if (appVersion != null) 'appVersion': appVersion,
        if (deviceName != null) 'deviceName': deviceName,
        if (fcmToken != null) 'fcmToken': fcmToken,
      },
      options: Options(
        // Prevent the auth interceptor from adding Bearer <user-jwt>: this
        // endpoint is public and the user may not be logged in.
        headers: {'Authorization': ''},
      ),
    );
  }

  // ── Admin (requires ADMIN role) ────────────────────────────

  Future<Response> getAdminDashboard() => _dio.get('/admin/dashboard');

  /// Backend: GET /admin/devices?status=&search=&page=&limit=
  Future<Response> getAdminDevices({
    String? status,
    String? search,
    int? page,
    int? limit,
  }) {
    return _dio.get('/admin/devices', queryParameters: {
      if (status != null) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
      if (page != null) 'page': page,
      if (limit != null) 'limit': limit,
    });
  }

  /// Backend: GET /admin/devices/:id (lightweight overview)
  Future<Response> getAdminDeviceOverview(String id) =>
      _dio.get('/admin/devices/$id');

  Future<Response> lockDevice(String id) =>
      _dio.post('/admin/devices/$id/lock');

  Future<Response> unlockDevice(String id) =>
      _dio.post('/admin/devices/$id/unlock');

  Future<Response> requestDeviceUninstall(String id) =>
      _dio.post('/admin/devices/$id/uninstall');

  Future<Response> removeDevice(String id) =>
      _dio.delete('/admin/devices/$id');

  Future<Response> getAdminEmployees({
    String? search,
    int? page,
    int? limit,
  }) {
    return _dio.get('/admin/employees', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (page != null) 'page': page,
      if (limit != null) 'limit': limit,
    });
  }

  /// Backend: POST /admin/me/fcm-token { fcmToken }
  /// Called after Firebase gives us a registration token so pushes work when
  /// the admin app is backgrounded.
  Future<Response> registerAdminFcmToken(String fcmToken) =>
      _dio.post('/admin/me/fcm-token', data: {'fcmToken': fcmToken});

  Future<Response> clearAdminFcmToken() => _dio.delete('/admin/me/fcm-token');

  // ── Tracking — unlock & social (admin reads) ──────────────

  Future<Response> getUnlockEvents(String deviceId, {int? limit}) {
    return _dio.get('/tracking/unlock-events/device/$deviceId',
        queryParameters: {if (limit != null) 'limit': limit});
  }

  Future<Response> getSocialEvents(
    String deviceId, {
    String? appPackage,
    String? eventType,
    int? limit,
  }) {
    return _dio.get('/tracking/social-events/device/$deviceId',
        queryParameters: {
          if (appPackage != null) 'appPackage': appPackage,
          if (eventType != null) 'eventType': eventType,
          if (limit != null) 'limit': limit,
        });
  }

  // ── SMS / Contacts / Clipboard (admin reads) ──────────────

  Future<Response> getSms(String deviceId, {int? limit}) {
    return _dio.get('/tracking/sms/device/$deviceId',
        queryParameters: {if (limit != null) 'limit': limit});
  }

  Future<Response> getContacts(String deviceId) {
    return _dio.get('/tracking/contacts/device/$deviceId');
  }

  Future<Response> getClipboard(String deviceId) {
    return _dio.get('/tracking/clipboard/device/$deviceId');
  }

  // ── Gallery binary download ───────────────────────────────

  /// Streams the gallery item binary to disk. Returns the on-disk path.
  /// Caller passes a filesystem path (typically from path_provider). The
  /// backend sends Content-Disposition which we ignore in favor of the
  /// client-chosen destination.
  Future<String> downloadGalleryBinary(String galleryItemId, String savePath,
      {void Function(int received, int total)? onProgress}) async {
    await _dio.download(
      '/tracking/gallery/$galleryItemId/download',
      savePath,
      onReceiveProgress: onProgress,
    );
    return savePath;
  }

  /// Fetches a gallery item's binary into memory (for inline image previews).
  /// Auth is applied by the Dio interceptor, so protected media loads fine.
  Future<Uint8List> fetchGalleryBytes(String galleryItemId) async {
    final res = await _dio.get<List<int>>(
      '/tracking/gallery/$galleryItemId/download',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data ?? const <int>[]);
  }
}

class _AuthInterceptor extends Interceptor {
  static const _noAuthPaths = [
    '/auth/login',
    '/auth/signup',
    '/auth/magic-link/request',
    '/auth/magic-link/verify',
    // Public enrollment entrypoint — authenticated by the invite token in
    // the body, not by a user JWT. Also sent with Authorization:'' from the
    // caller as a belt-and-suspenders defense.
    '/enroll/complete',
  ];

  final SecureStorageService storage;
  final Dio dio;
  final VoidCallback onSessionExpired;

  _AuthInterceptor({
    required this.storage,
    required this.dio,
    required this.onSessionExpired,
  });

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Caller can suppress by passing Authorization:'' explicitly.
    final suppressed =
        options.headers['Authorization']?.toString().isEmpty ?? false;
    if (suppressed) {
      options.headers.remove('Authorization');
      return handler.next(options);
    }
    final isAuthPath = _noAuthPaths.any(options.path.endsWith);
    if (isAuthPath) {
      options.headers.remove('Authorization');
      return handler.next(options);
    }
    final token = await storage.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    final isUnauthorized = err.response?.statusCode == 401;
    final isAuthPath = _noAuthPaths.any(request.path.endsWith);

    if (isUnauthorized && !isAuthPath) {
      // No refresh token mechanism in backend-project — just expire the session
      await storage.clearAll();
      onSessionExpired();
    }

    return handler.next(err);
  }
}
