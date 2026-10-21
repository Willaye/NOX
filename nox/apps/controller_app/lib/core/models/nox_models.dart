// Lightweight client-side models for backend API responses.
// Parsing is defensive: every field is optional on the wire.

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
int? _int(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');
double? _double(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
String? _str(dynamic v) {
  final s = v?.toString();
  return (s == null || s.isEmpty) ? null : s;
}

/// Extracts a list from either a bare JSON array or a `{data: [...]}` envelope.
List<Map<String, dynamic>> extractList(dynamic body) {
  final raw = body is Map ? (body['data'] ?? body['items'] ?? body['logs']) : body;
  if (raw is! List) return const [];
  return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

// ── Device ───────────────────────────────────────────────────
class Device {
  final String id;
  final String name;
  final String deviceType; // PHONE | TABLET | LAPTOP | DESKTOP | OTHER
  final String platform; // ANDROID | IOS | WINDOWS | MACOS | LINUX | WEB
  final String? osVersion;
  final String? appVersion;
  final String? model;
  final String? manufacturer;
  final bool isOnline;
  final bool isPaired;
  final DateTime? lastSeenAt;
  final int? batteryLevel;
  final String? networkType;
  final int? storageUsed;
  final int? storageTotal;
  final DateTime? createdAt;

  const Device({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.platform,
    this.osVersion,
    this.appVersion,
    this.model,
    this.manufacturer,
    this.isOnline = false,
    this.isPaired = false,
    this.lastSeenAt,
    this.batteryLevel,
    this.networkType,
    this.storageUsed,
    this.storageTotal,
    this.createdAt,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString().toUpperCase();
    return Device(
      id: json['id']?.toString() ?? '',
      name: _str(json['name']) ?? 'Unnamed device',
      deviceType: json['deviceType']?.toString().toUpperCase() ?? 'OTHER',
      platform: json['platform']?.toString().toUpperCase() ?? '',
      osVersion: _str(json['osVersion']),
      appVersion: _str(json['appVersion']),
      model: _str(json['model']),
      manufacturer: _str(json['manufacturer']),
      isOnline: json['isOnline'] == true || status == 'ONLINE',
      isPaired: json['isPaired'] == true,
      lastSeenAt: _date(json['lastSeenAt']),
      batteryLevel: _int(json['batteryLevel']),
      networkType: _str(json['networkType']),
      storageUsed: _int(json['storageUsed']),
      storageTotal: _int(json['storageTotal']),
      createdAt: _date(json['createdAt']),
    );
  }

  bool get isLowBattery => batteryLevel != null && batteryLevel! <= 20;

  String get platformLabel => switch (platform) {
        'ANDROID' => 'Android',
        'IOS' => 'iOS',
        'WINDOWS' => 'Windows',
        'MACOS' => 'macOS',
        'LINUX' => 'Linux',
        'WEB' => 'Web',
        _ => '',
      };

  String get typeLabel => switch (deviceType) {
        'PHONE' => 'Phone',
        'TABLET' => 'Tablet',
        'LAPTOP' => 'Laptop',
        'DESKTOP' => 'Desktop',
        _ => 'Device',
      };

  /// e.g. "Android Phone"
  String get typeDescription => '$platformLabel $typeLabel'.trim();
}

class DevicesPage {
  final List<Device> devices;
  final int total;

  const DevicesPage({required this.devices, required this.total});

  int get onlineCount => devices.where((d) => d.isOnline).length;
  int get lowBatteryCount => devices.where((d) => d.isLowBattery).length;
}

// ── Notification ─────────────────────────────────────────────
class AppNotification {
  final String id;
  final String type; // NotificationType enum from backend
  final String category; // ALL | FILES | MESSAGES | SYSTEM | SECURITY | DEVICES
  final String title;
  final String body;
  final bool isRead;
  final DateTime? createdAt;
  final String? deviceId;
  final String? deviceName;

  const AppNotification({
    required this.id,
    required this.type,
    required this.category,
    required this.title,
    required this.body,
    required this.isRead,
    this.createdAt,
    this.deviceId,
    this.deviceName,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final device = json['device'];
    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString().toUpperCase() ?? 'SYSTEM',
      category: json['category']?.toString().toUpperCase() ?? 'SYSTEM',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      isRead: json['isRead'] == true,
      createdAt: _date(json['createdAt']),
      deviceId: _str(json['deviceId']),
      deviceName: device is Map ? _str(device['name']) : null,
    );
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        category: category,
        title: title,
        body: body,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        deviceId: deviceId,
        deviceName: deviceName,
      );
}

// ── Activity log ─────────────────────────────────────────────
class ActivityLog {
  final String id;
  final String type;
  final String title;
  final String? description;
  final DateTime? timestamp;

  const ActivityLog({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    this.timestamp,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? json['action'] ?? json['category'] ?? 'event').toString();
    return ActivityLog(
      id: json['id']?.toString() ?? '',
      type: type,
      title: _str(json['title']) ??
          _str(json['description']) ??
          _str(json['message']) ??
          type.replaceAll(RegExp(r'[._]'), ' '),
      description: _str(json['title']) != null ? _str(json['description']) : null,
      timestamp: _date(json['timestamp'] ?? json['occurredAt'] ?? json['createdAt']),
    );
  }
}

// ── Location log ─────────────────────────────────────────────
class LocationLog {
  final String id;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String? address;
  final DateTime? timestamp;
  /// Set by client-side reverse geocoding (city, country)
  String? resolvedAddress;

  LocationLog({
    required this.id,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.address,
    this.timestamp,
    this.resolvedAddress,
  });

  factory LocationLog.fromJson(Map<String, dynamic> json) => LocationLog(
        id: json['id']?.toString() ?? '',
        latitude: _double(json['latitude'] ?? json['lat']),
        longitude: _double(json['longitude'] ?? json['lng'] ?? json['lon']),
        accuracy: _double(json['accuracy']),
        address: _str(json['address']) ?? _str(json['placeName']),
        timestamp: _date(json['timestamp'] ?? json['recordedAt'] ?? json['createdAt']),
      );

  /// Returns the best available display name: resolved city/country, backend address, or raw coords.
  String get displayAddress => resolvedAddress ?? address ?? coordinates;

  String get coordinates => (latitude != null && longitude != null)
      ? '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'
      : 'Unknown position';
}

// ── File ─────────────────────────────────────────────────────
class NoxFile {
  final String id;
  final String name;
  final String mimeType;
  final int size;
  final DateTime? createdAt;

  const NoxFile({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.size,
    this.createdAt,
  });

  factory NoxFile.fromJson(Map<String, dynamic> json) => NoxFile(
        id: json['id']?.toString() ?? '',
        name: _str(json['originalName']) ?? _str(json['name']) ?? 'file',
        mimeType: json['mimeType']?.toString().toLowerCase() ?? '',
        size: _int(json['size']) ?? 0,
        createdAt: _date(json['createdAt']),
      );
}

// ── Auth session ─────────────────────────────────────────────
class UserSession {
  final String id;
  final String? deviceInfo;
  final String? ipAddress;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  const UserSession({
    required this.id,
    this.deviceInfo,
    this.ipAddress,
    this.createdAt,
    this.expiresAt,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
        id: json['id']?.toString() ?? '',
        deviceInfo: _str(json['deviceInfo']),
        ipAddress: _str(json['ipAddress']),
        createdAt: _date(json['createdAt']),
        expiresAt: _date(json['expiresAt']),
      );
}
