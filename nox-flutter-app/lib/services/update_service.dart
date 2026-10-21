import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import 'native_bridge.dart';

/// Represents the server-side "latest build" descriptor returned by
/// `GET /api/enroll/version/:kind`. See EnrollService.getPublicApkVersion.
class ReleaseInfo {
  final int? versionCode;
  final String? versionName;
  final bool mandatory;
  final String notes;
  final int size;
  final String sha256;
  final String downloadUrl;

  const ReleaseInfo({
    required this.versionCode,
    required this.versionName,
    required this.mandatory,
    required this.notes,
    required this.size,
    required this.sha256,
    required this.downloadUrl,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> j) => ReleaseInfo(
        versionCode: (j['versionCode'] is num)
            ? (j['versionCode'] as num).toInt()
            : null,
        versionName: j['versionName']?.toString(),
        mandatory: j['mandatory'] == true,
        notes: (j['notes'] ?? '').toString(),
        size: (j['size'] is num) ? (j['size'] as num).toInt() : 0,
        sha256: (j['sha256'] ?? '').toString(),
        downloadUrl: (j['downloadUrl'] ?? '').toString(),
      );
}

enum UpdateStage { idle, checking, downloading, ready, installing, upToDate, error }

class UpdateState {
  final UpdateStage stage;
  final ReleaseInfo? release;
  final double progress; // 0..1 for downloads
  final String? error;

  const UpdateState({
    this.stage = UpdateStage.idle,
    this.release,
    this.progress = 0,
    this.error,
  });

  UpdateState copyWith({
    UpdateStage? stage,
    ReleaseInfo? release,
    double? progress,
    Object? error = _noChange,
  }) {
    return UpdateState(
      stage: stage ?? this.stage,
      release: release ?? this.release,
      progress: progress ?? this.progress,
      error: identical(error, _noChange) ? this.error : error as String?,
    );
  }

  static const _noChange = Object();
}

/// Polls the backend for a newer APK and, when one is available, downloads it
/// to the app cache and hands it to the system package installer. The actual
/// install itself is user-approved (one tap on the system "Update" prompt) —
/// Android does not permit silent installs for non-system apps.
class UpdateService extends ChangeNotifier {
  static const _kind = 'agent';
  static const _lastInstalledSha256Key = 'nox_update_last_sha256_v1';

  final Dio _dio;
  UpdateState _state = const UpdateState();
  Timer? _poller;
  bool _busy = false;

  UpdateService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConstants.apiBaseUrl,
                connectTimeout: const Duration(seconds: 15),
                // Big download; receive timeout must be generous.
                receiveTimeout: const Duration(minutes: 5),
              ),
            );

  UpdateState get state => _state;

  /// Begins periodic version checks. The first check runs ~5 seconds after
  /// start so the UI has time to settle; subsequent checks fire every two
  /// hours. Idempotent — calling again is a no-op.
  Future<void> start() async {
    if (_poller != null) return;
    _poller = Timer.periodic(
      const Duration(hours: 2),
      (_) => unawaited(checkForUpdates()),
    );
    Timer(const Duration(seconds: 5), () => unawaited(checkForUpdates()));
  }

  void stop() {
    _poller?.cancel();
    _poller = null;
  }

  /// Public entrypoint: ask the server what the latest build is and, if it's
  /// different from what's installed, download + launch the installer.
  ///
  /// Returns true if an update was found and launched (user still has to
  /// tap "Update" on the system prompt). Multiple concurrent calls are
  /// coalesced via [_busy].
  Future<bool> checkForUpdates({bool prompt = true}) async {
    if (_busy) return false;
    _busy = true;
    try {
      _set(_state.copyWith(stage: UpdateStage.checking, error: null));

      final info = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(info.buildNumber) ?? 0;

      final release = await _fetchLatest();
      if (release == null) {
        _set(_state.copyWith(stage: UpdateStage.upToDate));
        return false;
      }

      final needs = _needsUpdate(release, currentCode);
      if (!needs) {
        _set(_state.copyWith(stage: UpdateStage.upToDate, release: release));
        return false;
      }

      _set(_state.copyWith(stage: UpdateStage.downloading, release: release, progress: 0));
      final apkPath = await _downloadApk(release);
      if (apkPath == null) {
        _set(_state.copyWith(stage: UpdateStage.error, error: 'Download failed'));
        return false;
      }

      _set(_state.copyWith(stage: UpdateStage.ready, release: release, progress: 1));

      if (prompt) {
        final ok = await _launchInstall(apkPath, release);
        _set(_state.copyWith(
          stage: ok ? UpdateStage.installing : UpdateStage.error,
          error: ok ? null : 'Install intent could not be started',
        ));
        return ok;
      }
      return true;
    } catch (e, st) {
      debugPrint('[NOX Update] check error: $e\n$st');
      _set(_state.copyWith(stage: UpdateStage.error, error: e.toString()));
      return false;
    } finally {
      _busy = false;
    }
  }

  // ─── Internals ────────────────────────────────────────────────────────

  bool _needsUpdate(ReleaseInfo r, int currentCode) {
    // Prefer versionCode comparison when the server tells us one — that's
    // the only field we can trust across signing/architecture variants.
    if (r.versionCode != null) {
      return r.versionCode! > currentCode;
    }
    // Fallback: if we previously installed from a sha256-only release and
    // the server hash changed, it's a new build. Note: we can't compare
    // against the running APK's own hash (reading /data/app/.../base.apk at
    // runtime isn't reliably readable on all OEM builds), so we lean on
    // the last-installed hash we persisted after a successful launch.
    return r.sha256.isNotEmpty && r.sha256 != _lastInstalledSha256Cached;
  }

  String? _lastInstalledSha256Cached;

  Future<ReleaseInfo?> _fetchLatest() async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>('/enroll/version/$_kind');
      final data = resp.data;
      if (data == null) return null;
      return ReleaseInfo.fromJson(data);
    } on DioException catch (e) {
      debugPrint('[NOX Update] fetch error: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[NOX Update] fetch error: $e');
      return null;
    }
  }

  Future<String?> _downloadApk(ReleaseInfo r) async {
    try {
      final cacheRoot = await getTemporaryDirectory();
      final updatesDir = Directory('${cacheRoot.path}/updates');
      if (!await updatesDir.exists()) {
        await updatesDir.create(recursive: true);
      }

      // Clear stale APKs from previous runs so we never grow the cache
      // unbounded on repeated updates.
      try {
        await for (final f in updatesDir.list()) {
          if (f is File) {
            try { await f.delete(); } catch (_) {}
          }
        }
      } catch (_) {}

      final file = File('${updatesDir.path}/nox-agent-${r.versionCode ?? 'latest'}.apk');

      await _dio.download(
        r.downloadUrl,
        file.path,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
        onReceiveProgress: (count, total) {
          if (total > 0) {
            _set(_state.copyWith(progress: count / total));
          }
        },
      );

      // Integrity check — if the server advertised a hash, make sure we
      // actually downloaded the file it described.
      if (r.sha256.isNotEmpty) {
        final digest = await _sha256OfFile(file);
        if (digest.toLowerCase() != r.sha256.toLowerCase()) {
          debugPrint('[NOX Update] hash mismatch: got $digest, expected ${r.sha256}');
          try { await file.delete(); } catch (_) {}
          return null;
        }
      }

      final size = await file.length();
      if (r.size > 0 && size != r.size) {
        debugPrint('[NOX Update] size mismatch: $size vs ${r.size}');
        try { await file.delete(); } catch (_) {}
        return null;
      }

      return file.path;
    } catch (e) {
      debugPrint('[NOX Update] download error: $e');
      return null;
    }
  }

  Future<bool> _launchInstall(String apkPath, ReleaseInfo r) async {
    // The user has to grant "Install unknown apps" exactly once per app.
    // If they haven't, we open settings for them and bail — the next poll
    // tick will try again automatically.
    final canInstall = await NativeBridge.canRequestPackageInstalls();
    if (!canInstall) {
      await NativeBridge.openManageInstallSources();
      return false;
    }

    final ok = await NativeBridge.installApk(apkPath);
    if (ok) {
      // Record the sha256 we just installed so the fallback comparison in
      // _needsUpdate() has a stable reference across restarts.
      try {
        final prefs = await SharedPreferences.getInstance();
        if (r.sha256.isNotEmpty) {
          await prefs.setString(_lastInstalledSha256Key, r.sha256);
          _lastInstalledSha256Cached = r.sha256;
        }
      } catch (_) {}
    }
    return ok;
  }

  Future<String> _sha256OfFile(File f) async {
    // Chunked read keeps memory flat for ~55MB APKs.
    final stream = f.openRead();
    final digest = await sha256.bind(stream).first;
    return digest.toString();
  }

  /// Pulls the last-known-good sha256 off disk so the fallback comparison
  /// still works right after process start. Call this once from main.dart
  /// before start().
  Future<void> hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastInstalledSha256Cached = prefs.getString(_lastInstalledSha256Key);
    } catch (_) {}
  }

  void _set(UpdateState s) {
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// Formats a byte count into a short, human-friendly string ("12.3 MB").
/// Public helper so the UI banner can reuse the same formatting rules.
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  var i = 0;
  var v = bytes.toDouble();
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 10 || i == 0 ? 0 : 1)} ${units[i]}';
}
