import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nox_design_system/nox_design_system.dart';
import '../models/nox_models.dart';

/// "Just now", "5 min ago", "3 hours ago", "2 days ago", or a date.
String timeAgo(DateTime? time) {
  if (time == null) return 'Never';
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) {
    return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }
  return DateFormat.yMMMd().format(time);
}

String formatTime(DateTime? time) =>
    time == null ? '' : DateFormat.jm().format(time);

String formatDate(DateTime? time) =>
    time == null ? '—' : DateFormat.yMMMd().format(time);

String formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 100 || unit == 0 ? 0 : 1)} ${units[unit]}';
}

/// Best-effort human-readable error message from a Dio/Nest error.
String errorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final msg = data['message'];
      if (msg is List && msg.isNotEmpty) return msg.first.toString();
      if (msg is String && msg.isNotEmpty) return msg;
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'The server took too long to respond.';
      case DioExceptionType.connectionError:
        return 'Unable to connect to the server. Check your connection.';
      default:
        break;
    }
    final code = error.response?.statusCode;
    if (code != null) return 'Request failed ($code).';
  }
  return 'Something went wrong. Please try again.';
}

void showNoxSnackBar(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: NoxTypography.body.copyWith(color: NoxColors.pureWhite),
      ),
      backgroundColor: isError
          ? NoxColors.offlineRed.withValues(alpha: 0.9)
          : NoxColors.elevatedSurface,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

// ── Device presentation helpers ──────────────────────────────
NoxDeviceStatus deviceStatus(Device d) {
  if (!d.isOnline) return NoxDeviceStatus.offline;
  if (d.isLowBattery) return NoxDeviceStatus.warning;
  return NoxDeviceStatus.online;
}

IconData deviceIcon(Device d) {
  final apple = d.platform == 'IOS' || d.platform == 'MACOS';
  return switch (d.deviceType) {
    'PHONE' => apple ? Icons.phone_iphone_rounded : Icons.phone_android_rounded,
    'TABLET' => apple ? Icons.tablet_mac_rounded : Icons.tablet_android_rounded,
    'LAPTOP' => apple ? Icons.laptop_mac_rounded : Icons.laptop_rounded,
    'DESKTOP' => Icons.desktop_windows_rounded,
    _ => Icons.devices_other_rounded,
  };
}

// ── Notification presentation helpers ────────────────────────
IconData notificationIcon(String type) => switch (type) {
      'FILE_RECEIVED' || 'FILE_SENT' => Icons.insert_drive_file_rounded,
      'TRANSFER_COMPLETE' => Icons.cloud_done_rounded,
      'TRANSFER_FAILED' => Icons.cloud_off_rounded,
      'DEVICE_CONNECTED' => Icons.wifi_rounded,
      'DEVICE_DISCONNECTED' => Icons.wifi_off_rounded,
      'DEVICE_PAIRED' => Icons.link_rounded,
      'MESSAGE_RECEIVED' => Icons.chat_bubble_rounded,
      'PERMISSION_CHANGED' => Icons.admin_panel_settings_rounded,
      'SECURITY_ALERT' => Icons.security_rounded,
      'SESSION_STARTED' => Icons.play_circle_outline_rounded,
      'SESSION_ENDED' => Icons.stop_circle_outlined,
      _ => Icons.notifications_rounded,
    };

Color notificationColor(String type) => switch (type) {
      'DEVICE_CONNECTED' || 'DEVICE_PAIRED' || 'TRANSFER_COMPLETE' => NoxColors.onlineGreen,
      'DEVICE_DISCONNECTED' || 'TRANSFER_FAILED' => NoxColors.offlineRed,
      'SECURITY_ALERT' || 'PERMISSION_CHANGED' => NoxColors.warningAmber,
      'FILE_RECEIVED' || 'FILE_SENT' => NoxColors.peachAccent,
      'MESSAGE_RECEIVED' => NoxColors.pinkSoft,
      'SESSION_STARTED' || 'SESSION_ENDED' => NoxColors.icyBlue,
      _ => NoxColors.lavenderPrimary,
    };

String categoryLabel(String category) => switch (category) {
      'FILES' => 'Files',
      'MESSAGES' => 'Messages',
      'SECURITY' => 'Security',
      'DEVICES' => 'Devices',
      _ => 'System',
    };
