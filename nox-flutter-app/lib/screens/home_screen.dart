import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../services/tracking_service.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../services/background_service.dart';
import '../services/monitor_service.dart';
import '../services/gallery_sync_service.dart';
import '../services/update_service.dart';
import '../services/native_bridge.dart';
import '../widgets/nox_banner.dart';
import 'permissions_setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _batteryLevel = 0;
  String _deviceModel = '';
  bool _trackingActive = false;
  bool _showPermissions = true;
  StreamSubscription? _commandSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Opportunistic re-check whenever the user brings the app back.
      // Cheap: the server returns a tiny JSON blob and we early-exit if the
      // installed versionCode already matches.
      try {
        context.read<UpdateService>().checkForUpdates();
      } catch (_) {}
    }
  }

  Future<void> _checkPermissions() async {
    try {
      final snap = await NativeBridge.getPermissionsSnapshot();
      if (snap.allEssentialGranted) {
        setState(() => _showPermissions = false);
        _initializeServices();
      }
    } catch (_) {
      // First launch may fail; show permissions screen anyway.
    }
  }

  void _onPermissionsDone() {
    setState(() => _showPermissions = false);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final auth = context.read<AuthService>();
    final socket = context.read<SocketService>();
    final tracking = context.read<TrackingService>();
    final location = context.read<LocationService>();
    final api = context.read<ApiService>();
    final monitor = context.read<MonitorService>();
    final gallery = context.read<GallerySyncService>();
    final update = context.read<UpdateService>();

    // Start foreground service first so Android keeps us alive.
    try { await NativeBridge.startForegroundService(); } catch (_) {}

    // Kick off the auto-update poller right away. Independent of auth, so
    // even an unenrolled device can self-heal to the current build.
    unawaited(update.start());

    // Get device info
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    setState(() {
      _deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
    });

    // Get battery
    final battery = Battery();
    _batteryLevel = await battery.batteryLevel;
    setState(() {});

    // Register device if needed
    String? deviceId = auth.deviceId;
    if (deviceId == null) {
      try {
        final result = await api.registerDevice(_deviceModel);
        deviceId = result['id'] as String;
        await auth.setDeviceId(deviceId);
        // Store the device JWT returned at registration — tracking uploads
        // are authenticated with THIS token, not the user token.
        final dt = result['deviceToken'];
        if (dt is String && dt.isNotEmpty) {
          await auth.setDeviceToken(dt);
        }
      } catch (e) {
        debugPrint('[NOX] Device registration failed: $e');
      }
    }

    // Ensure we hold a device token even if the device was registered earlier
    // (before device-tokens existed) or after a reinstall/clear-data.
    if (deviceId != null && !(await auth.hasDeviceToken())) {
      try {
        final dt = await api.issueDeviceToken(deviceId);
        if (dt != null) await auth.setDeviceToken(dt);
      } catch (e) {
        debugPrint('[NOX] Device token issue failed: $e');
      }
    }

    if (deviceId == null || auth.token == null) return;

    // Connect WebSocket
    socket.connect(token: auth.token!, deviceId: deviceId);

    // Start all tracking services
    tracking.startTracking(deviceId);
    location.startTracking(deviceId);
    await monitor.start();
    await gallery.start();
    setState(() => _trackingActive = true);

    // Register background tasks
    await BackgroundService.registerPeriodicSync();

    // Listen for admin commands
    _commandSub = socket.commandStream.listen(_handleCommand);

    // Battery updates
    battery.onBatteryStateChanged.listen((_) async {
      _batteryLevel = await battery.batteryLevel;
      if (mounted) setState(() {});
    });
  }

  void _handleCommand(Map<String, dynamic> command) {
    final cmd = command['command'] as String?;
    debugPrint('[NOX] Command received: $cmd');

    switch (cmd) {
      case 'LOCK':
        // Show lock screen overlay
        _showLockOverlay();
        break;
      case 'UNLOCK':
        // Dismiss lock overlay if shown
        Navigator.of(context).popUntil((route) => route.isFirst);
        break;
      case 'UNINSTALL':
        // Handled by device admin
        debugPrint('[NOX] Uninstall command received');
        break;
    }
  }

  void _showLockOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: NoxTheme.background,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, color: NoxTheme.danger, size: 64),
                const SizedBox(height: 24),
                Text(
                  'Device Locked',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'This device has been locked by your administrator.',
                  style: TextStyle(color: NoxTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _commandSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showPermissions) {
      return PermissionsSetupScreen(onDone: _onPermissionsDone);
    }

    final auth = context.watch<AuthService>();
    final socket = context.watch<SocketService>();
    final tracking = context.read<TrackingService>();

    return Scaffold(
      backgroundColor: NoxTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Managed device banner
            const NoxBanner(),

            // Auto-update banner (shows while an update is downloading or
            // ready to install; otherwise collapses to zero height).
            const _UpdateBanner(),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    // Logo
                    Center(
                      child: Text(
                        'NOX',
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(fontSize: 36, letterSpacing: 8),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Status cards
                    _StatusCard(
                      icon: Icons.wifi,
                      label: 'Connection',
                      value: socket.isConnected ? 'Connected' : 'Disconnected',
                      valueColor:
                          socket.isConnected ? NoxTheme.success : NoxTheme.danger,
                    ),
                    const SizedBox(height: 12),
                    _StatusCard(
                      icon: Icons.radar,
                      label: 'Tracking',
                      value: _trackingActive ? 'Active' : 'Inactive',
                      valueColor:
                          _trackingActive ? NoxTheme.success : NoxTheme.warning,
                    ),
                    const SizedBox(height: 12),
                    _StatusCard(
                      icon: Icons.battery_std,
                      label: 'Battery',
                      value: '$_batteryLevel%',
                      valueColor: _batteryLevel > 20
                          ? NoxTheme.success
                          : NoxTheme.danger,
                    ),
                    const SizedBox(height: 12),
                    _StatusCard(
                      icon: Icons.phone_android,
                      label: 'Device',
                      value: _deviceModel,
                      valueColor: NoxTheme.textPrimary,
                    ),
                    const SizedBox(height: 12),
                    _StatusCard(
                      icon: Icons.sync,
                      label: 'Last Sync',
                      value: _formatTime(tracking.lastSyncTime),
                      valueColor: NoxTheme.textSecondary,
                    ),

                    const Spacer(),

                    // User info
                    Text(
                      auth.currentUser?['email'] ?? '',
                      style: const TextStyle(
                        color: NoxTheme.textSecondary,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _StatusCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: NoxTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: NoxTheme.accent, size: 22),
          const SizedBox(width: 16),
          Text(
            label,
            style: const TextStyle(
              color: NoxTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}


/// Thin banner that appears while an update is being pulled, lets the user
/// tap once to launch the system installer, and collapses to zero height
/// when nothing's happening. Lives inside home_screen.dart because it has
/// no other callers.
class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner();

  @override
  Widget build(BuildContext context) {
    final update = context.watch<UpdateService>();
    final s = update.state;

    // Only render for the states the user actually cares about. "idle",
    // "checking" and "upToDate" are silent — surfacing them would be noise.
    final showingProgress = s.stage == UpdateStage.downloading;
    final readyToInstall = s.stage == UpdateStage.ready;
    final installing = s.stage == UpdateStage.installing;

    if (!showingProgress && !readyToInstall && !installing) {
      return const SizedBox.shrink();
    }

    final v = s.release?.versionName ?? '${s.release?.versionCode ?? ''}';
    final sizeTxt = s.release != null ? ' • ${formatBytes(s.release!.size)}' : '';

    final String title;
    final Widget trailing;

    if (showingProgress) {
      title = 'Downloading update${v.isNotEmpty ? ' $v' : ''}$sizeTxt';
      trailing = SizedBox(
        width: 60,
        child: LinearProgressIndicator(
          value: s.progress == 0 ? null : s.progress,
          minHeight: 4,
          backgroundColor: const Color(0xFF333333),
          valueColor: const AlwaysStoppedAnimation(Color(0xFF00E5FF)),
        ),
      );
    } else if (readyToInstall) {
      title = 'Update $v ready — tap Install';
      trailing = TextButton(
        onPressed: () =>
            context.read<UpdateService>().checkForUpdates(prompt: true),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF00E5FF),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: const Text('INSTALL',
            style: TextStyle(fontWeight: FontWeight.w700)),
      );
    } else {
      title = 'Installing update…';
      trailing = const SizedBox(
        width: 18, height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF0A1A1F),
      child: Row(
        children: [
          const Icon(Icons.system_update_alt, color: Color(0xFF00E5FF), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          trailing,
        ],
      ),
    );
  }
}
