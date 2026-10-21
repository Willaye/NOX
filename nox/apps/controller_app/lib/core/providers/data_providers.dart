import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/nox_models.dart';
import '../network/api_client.dart';
import 'auth_provider.dart';

/// Rebuild user-scoped data whenever the signed-in user changes
/// (login/logout), so cached data never leaks across accounts.
String? _watchUserId(Ref ref) =>
    ref.watch(authStateProvider.select((s) => s.user?.id));

// ── Devices ──────────────────────────────────────────────────
// An admin monitors ALL enrolled devices, which may be registered under the
// employees' own accounts (not the admin's). So we read the admin-scoped
// endpoint GET /admin/devices (returns every device) instead of GET /devices
// (which only returns the signed-in user's own devices and would therefore be
// empty for an admin whose employees self-registered). Falls back to /devices
// if the account isn't an admin (403).
final devicesProvider = FutureProvider<DevicesPage>((ref) async {
  _watchUserId(ref);
  final api = ref.watch(apiClientProvider);

  List<Map<String, dynamic>> items;
  try {
    // /admin/devices → { devices: [...], total, page, totalPages }
    final response = await api.getAdminDevices(limit: 100);
    final data = response.data;
    if (data is Map && data['devices'] is List) {
      items = (data['devices'] as List).cast<Map<String, dynamic>>();
    } else if (data is List) {
      items = data.cast<Map<String, dynamic>>();
    } else {
      items = extractList(data);
    }
  } on DioException catch (e) {
    // Non-admin account → fall back to the user's own devices.
    if (e.response?.statusCode == 403 || e.response?.statusCode == 404) {
      final response = await api.getDevices();
      final rawData = response.data;
      items = rawData is List
          ? rawData.cast<Map<String, dynamic>>()
          : extractList(rawData);
    } else {
      rethrow;
    }
  }

  final devices = items.map(Device.fromJson).toList();
  return DevicesPage(devices: devices, total: devices.length);
});

final deviceDetailProvider =
    FutureProvider.autoDispose.family<Device, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  try {
    // Admin overview (GET /admin/devices/:id) works for ANY device, not just
    // ones the signed-in user owns. Shape: { device: {...}, latest, stats }.
    final response = await api.getAdminDeviceOverview(id);
    final data = response.data;
    final deviceJson = (data is Map && data['device'] is Map)
        ? Map<String, dynamic>.from(data['device'] as Map)
        : Map<String, dynamic>.from(data as Map);
    return Device.fromJson(deviceJson);
  } on DioException catch (e) {
    // Non-admin → fall back to the owner-scoped GET /devices/:id.
    if (e.response?.statusCode == 403 || e.response?.statusCode == 404) {
      final response = await api.getDevice(id);
      return Device.fromJson(Map<String, dynamic>.from(response.data as Map));
    }
    rethrow;
  }
});

/// Device mutations. Invalidates the affected providers on success.
class DeviceActions {
  final Ref _ref;
  DeviceActions(this._ref);

  ApiClient get _api => _ref.read(apiClientProvider);

  Future<void> rename(String id, String name) async {
    await _api.updateDevice(id, {'name': name});
    _ref.invalidate(deviceDetailProvider(id));
    _ref.invalidate(devicesProvider);
  }

  Future<void> delete(String id) async {
    try {
      // Admin can remove any device (DELETE /admin/devices/:id).
      await _api.removeDevice(id);
    } on DioException catch (e) {
      // Non-admin → fall back to owner-scoped delete.
      if (e.response?.statusCode == 403 || e.response?.statusCode == 404) {
        await _api.deleteDevice(id);
      } else {
        rethrow;
      }
    }
    _ref.invalidate(devicesProvider);
  }
}

final deviceActionsProvider = Provider<DeviceActions>((ref) => DeviceActions(ref));

// ── Activity & location logs ─────────────────────────────────
Future<List<Map<String, dynamic>>> _listOrEmptyOn404(
  Future<Response> Function() request,
) async {
  try {
    final response = await request();
    final data = response.data;
    if (data is List) return data.cast<Map<String, dynamic>>();
    return extractList(data);
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return const [];
    rethrow;
  }
}

final activityLogsProvider =
    FutureProvider.autoDispose.family<List<ActivityLog>, String>((ref, deviceId) async {
  final api = ref.watch(apiClientProvider);
  final rows = await _listOrEmptyOn404(() => api.getActivityLogs(deviceId, limit: 50));
  return rows.map(ActivityLog.fromJson).toList();
});

final locationLogsProvider =
    FutureProvider.autoDispose.family<List<LocationLog>, String>((ref, deviceId) async {
  final api = ref.watch(apiClientProvider);
  final rows = await _listOrEmptyOn404(() => api.getLocationHistory(deviceId));
  final logs = rows.map(LocationLog.fromJson).toList()
    ..sort((a, b) => (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)));

  // Reverse geocode using free Nominatim HTTP API (no API key needed)
  final dio = Dio();
  // Only geocode first 5 unique locations to keep it fast
  final seen = <String>{};
  final cache = <String, String>{};
  for (final log in logs) {
    if (log.latitude == null || log.longitude == null) continue;
    // Round to 3 decimals (~100m) for caching
    final cacheKey = '${log.latitude!.toStringAsFixed(3)},${log.longitude!.toStringAsFixed(3)}';
    if (cache.containsKey(cacheKey)) {
      log.resolvedAddress = cache[cacheKey];
      continue;
    }
    if (seen.length >= 5) {
      // Use nearest cached location if available
      continue;
    }
    seen.add(cacheKey);
    try {
      final res = await dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': log.latitude, 'lon': log.longitude,
          'format': 'json', 'zoom': 10, 'addressdetails': 1,
        },
        options: Options(headers: {'User-Agent': 'NoxMDM/1.0'}),
      );
      if (res.statusCode == 200 && res.data is Map) {
        final addr = res.data['address'];
        if (addr is Map) {
          final city = addr['city'] ?? addr['town'] ?? addr['village'] ??
              addr['county'] ?? addr['state_district'] ?? '';
          final country = addr['country'] ?? '';
          final parts = <String>[
            if (city.toString().isNotEmpty) city.toString(),
            if (country.toString().isNotEmpty) country.toString(),
          ];
          if (parts.isNotEmpty) {
            log.resolvedAddress = parts.join(', ');
            cache[cacheKey] = log.resolvedAddress!;
          }
        }
      }
    } catch (_) {}
  }
  // Fill remaining logs from cache
  for (final log in logs) {
    if (log.resolvedAddress != null || log.latitude == null || log.longitude == null) continue;
    final cacheKey = '${log.latitude!.toStringAsFixed(3)},${log.longitude!.toStringAsFixed(3)}';
    if (cache.containsKey(cacheKey)) {
      log.resolvedAddress = cache[cacheKey];
    }
  }
  return logs;
});

// ── Files ────────────────────────────────────────────────────
// backend-project has no /files endpoint — return empty for now
final deviceFilesProvider =
    FutureProvider.autoDispose.family<List<NoxFile>, String>((ref, deviceId) async {
  return const [];
});

// ── Monitoring categories (admin reads) ──────────────────────
// Each returns the raw rows from the tracking endpoints (plain arrays). The
// detail screen renders them with best-effort field extraction so it stays
// resilient to minor backend shape changes.
final galleryItemsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, deviceId) async {
  final api = ref.watch(apiClientProvider);
  return _listOrEmptyOn404(() => api.getGallery(deviceId, limit: 100));
});

final browsingHistoryProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, deviceId) async {
  final api = ref.watch(apiClientProvider);
  return _listOrEmptyOn404(() => api.getBrowsingHistory(deviceId, limit: 100));
});

final socialEventsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, deviceId) async {
  final api = ref.watch(apiClientProvider);
  return _listOrEmptyOn404(() => api.getSocialEvents(deviceId, limit: 200));
});

/// Per-app social event providers — filter by appPackage so each tab only
/// shows its own app's data. Uses the backend's query parameter.
final whatsappEventsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, deviceId) async {
  final api = ref.watch(apiClientProvider);
  return _listOrEmptyOn404(() => api.getSocialEvents(deviceId, appPackage: 'com.whatsapp', limit: 200));
});

final instagramEventsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, deviceId) async {
  final api = ref.watch(apiClientProvider);
  return _listOrEmptyOn404(() => api.getSocialEvents(deviceId, appPackage: 'com.instagram.android', limit: 200));
});

final snapchatEventsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, deviceId) async {
  final api = ref.watch(apiClientProvider);
  return _listOrEmptyOn404(() => api.getSocialEvents(deviceId, appPackage: 'com.snapchat.android', limit: 200));
});

final facebookEventsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, deviceId) async {
  final api = ref.watch(apiClientProvider);
  // Facebook Messenger + Facebook main app
  final messenger = await _listOrEmptyOn404(() => api.getSocialEvents(deviceId, appPackage: 'com.facebook.orca', limit: 100));
  final fb = await _listOrEmptyOn404(() => api.getSocialEvents(deviceId, appPackage: 'com.facebook.katana', limit: 100));
  final all = [...messenger, ...fb];
  all.sort((a, b) {
    final aT = DateTime.tryParse((a['occurredAt'] ?? a['createdAt'] ?? '').toString()) ?? DateTime(0);
    final bT = DateTime.tryParse((b['occurredAt'] ?? b['createdAt'] ?? '').toString()) ?? DateTime(0);
    return bT.compareTo(aT);
  });
  return all;
});

final callLogsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, deviceId) async {
  final api = ref.watch(apiClientProvider);
  return _listOrEmptyOn404(() => api.getCallLogs(deviceId, limit: 100));
});

final appUsageProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, deviceId) async {
  final api = ref.watch(apiClientProvider);
  return _listOrEmptyOn404(() => api.getAppUsage(deviceId, limit: 100));
});

// ── SMS ──────────────────────────────────────────────────────
final smsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, deviceId) async {
  final api = ref.watch(apiClientProvider);
  return _listOrEmptyOn404(() => api.getSms(deviceId, limit: 200));
});

// ── Contacts ─────────────────────────────────────────────────
final contactsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, deviceId) async {
  final api = ref.watch(apiClientProvider);
  return _listOrEmptyOn404(() => api.getContacts(deviceId));
});

// ── Clipboard ────────────────────────────────────────────────
final clipboardProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, deviceId) async {
  final api = ref.watch(apiClientProvider);
  return _listOrEmptyOn404(() => api.getClipboard(deviceId));
});

/// Downloads a single gallery item's bytes for an inline preview. Keyed by the
/// gallery item id; autoDispose so off-screen images free memory.
final galleryBytesProvider =
    FutureProvider.autoDispose.family<Uint8List, String>((ref, itemId) async {
  final api = ref.watch(apiClientProvider);
  return api.fetchGalleryBytes(itemId);
});

// ── Auth sessions ────────────────────────────────────────────
// backend-project has no /auth/sessions endpoint — return empty
final sessionsProvider = FutureProvider.autoDispose<List<UserSession>>((ref) async {
  return const [];
});

// ── Notifications ────────────────────────────────────────────
class NotificationsNotifier extends StateNotifier<AsyncValue<List<AppNotification>>> {
  final ApiClient _api;

  NotificationsNotifier(this._api, {required bool enabled})
      : super(enabled ? const AsyncValue.loading() : const AsyncValue.data([])) {
    if (enabled) load();
  }

  int get unreadCount => state.valueOrNull?.where((n) => !n.isRead).length ?? 0;

  Future<void> load() async {
    if (!state.hasValue) state = const AsyncValue.loading();
    try {
      final response = await _api.getNotifications(limit: 50);
      // Backend returns a flat array of notifications
      final rawData = response.data;
      List<Map<String, dynamic>> items;
      if (rawData is List) {
        items = rawData.cast<Map<String, dynamic>>();
      } else {
        items = extractList(rawData);
      }
      final notifications = items.map(AppNotification.fromJson).toList();
      if (mounted) state = AsyncValue.data(notifications);
    } catch (e, st) {
      // If the user isn't admin, notifications endpoint returns 403 — show empty
      if (e is DioException && (e.response?.statusCode == 403 || e.response?.statusCode == 404)) {
        if (mounted) state = const AsyncValue.data([]);
        return;
      }
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> markAsRead(String id) async {
    final previous = state.valueOrNull;
    if (previous == null) return;
    final target = previous.where((n) => n.id == id).firstOrNull;
    if (target == null || target.isRead) return;

    state = AsyncValue.data([
      for (final n in previous) n.id == id ? n.copyWith(isRead: true) : n,
    ]);
    try {
      await _api.markNotificationRead(id);
    } catch (_) {
      if (mounted) state = AsyncValue.data(previous);
      rethrow;
    }
  }

  Future<void> markAllAsRead() async {
    final previous = state.valueOrNull;
    if (previous == null) return;
    state = AsyncValue.data([for (final n in previous) n.copyWith(isRead: true)]);
    try {
      await _api.markAllNotificationsRead();
    } catch (_) {
      if (mounted) state = AsyncValue.data(previous);
      rethrow;
    }
  }

  // backend-project has no DELETE /notifications/:id — just remove locally
  Future<void> dismiss(String id) async {
    final previous = state.valueOrNull;
    if (previous == null) return;
    state = AsyncValue.data(previous.where((n) => n.id != id).toList());
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, AsyncValue<List<AppNotification>>>((ref) {
  final userId = _watchUserId(ref);
  return NotificationsNotifier(ref.watch(apiClientProvider), enabled: userId != null);
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final items = ref.watch(notificationsProvider).valueOrNull ?? const [];
  return items.where((n) => !n.isRead).length;
});
