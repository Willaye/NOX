import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/deep_link_handler.dart';
import '../../../core/storage/secure_storage.dart';

/// One-shot employee enrollment screen.
///
/// Flow:
///   1. Pick up the invite token (from the ?token= query param or the
///      pending deep-link state).
///   2. Show the single "Grant permissions" button.
///   3. Request the batch of runtime permissions in one call.
///   4. Call POST /enroll/complete and store the device JWT.
///   5. Navigate to the "running" screen.
///
/// Accessibility, Usage Access, and Device Admin are NOT requested via
/// permission_handler — those are system settings that must be opened by
/// the native agent in Phase 4. Phase 3 wires the subset Flutter can request
/// directly so the main part of the flow is testable end-to-end.
class EnrollmentScreen extends ConsumerStatefulWidget {
  final String? inviteToken;
  const EnrollmentScreen({super.key, this.inviteToken});

  @override
  ConsumerState<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends ConsumerState<EnrollmentScreen> {
  String? _token;
  _Status _status = _Status.idle;
  String? _error;

  @override
  void initState() {
    super.initState();
    _token = widget.inviteToken ??
        ref.read(enrollmentLinkProvider).pendingInviteToken;
    // If the token arrived via deep-link after mount, pick it up.
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(enrollmentLinkProvider, (prev, next) {
      if (_token == null && next.pendingInviteToken != null) {
        setState(() => _token = next.pendingInviteToken);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Enroll device', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_token == null || _token!.isEmpty) {
      return const _Empty(
        title: 'No invite link detected',
        body:
            'Open the "Enroll your device" link your admin emailed you on this phone. The link looks like noxapp://enroll?token=…',
      );
    }
    if (_status == _Status.done) {
      return const _Done();
    }
    return _Prompt(
      busy: _status == _Status.busy,
      error: _error,
      onContinue: _run,
    );
  }

  Future<void> _run() async {
    setState(() {
      _status = _Status.busy;
      _error = null;
    });
    try {
      await _requestPermissions();
      await _complete();
      ref.read(enrollmentLinkProvider.notifier).consume();
      if (!mounted) return;
      setState(() => _status = _Status.done);
      // Brief pause so the user sees the success state.
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      context.go('/employee/running');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _Status.idle;
        _error = _niceError(e);
      });
    }
  }

  Future<void> _requestPermissions() async {
    // Request the batch Flutter can handle. Settings-intent permissions
    // (Accessibility, Usage Access, Device Admin) come in Phase 4.
    final targets = <Permission>[
      Permission.locationAlways,
      Permission.locationWhenInUse,
      Permission.camera,
      Permission.notification,
      if (Platform.isAndroid) ...[
        Permission.phone, // READ_PHONE_STATE
        Permission.contacts,
        Permission.sms,
        Permission.photos, // Android 13+ READ_MEDIA_IMAGES
        Permission.videos,
        Permission.storage, // older Android
        Permission.ignoreBatteryOptimizations,
      ],
    ];
    // The platform returns a result per permission; we don't block on any
    // single denial — the admin can see from the agent-side status which
    // signals are available. Hard-blocking only on the backend call failing.
    await targets.request();
  }

  Future<void> _complete() async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(secureStorageProvider);

    final resp = await api.completeEnrollment(
      inviteToken: _token!,
      deviceModel: _deviceModelGuess(),
      osVersion: _osGuess(),
      appVersion: '0.1.0',
    );
    final data = resp.data as Map<String, dynamic>;
    final deviceToken = data['deviceToken']?.toString() ?? '';
    final deviceId = data['deviceId']?.toString() ?? '';
    if (deviceToken.isEmpty || deviceId.isEmpty) {
      throw StateError('Enrollment response missing deviceToken/deviceId');
    }
    await storage.saveDeviceToken(deviceToken, deviceId);
  }

  String _deviceModelGuess() {
    if (Platform.isAndroid) return 'Android device';
    if (Platform.isIOS) return 'iOS device';
    return Platform.operatingSystem;
  }

  String _osGuess() => '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';

  String _niceError(Object e) {
    final s = e.toString();
    if (s.contains('400') && s.contains('already')) {
      return 'This invite has already been used. Ask your admin for a new one.';
    }
    if (s.contains('400') && s.contains('expired')) {
      return 'This invite has expired. Ask your admin for a new one.';
    }
    if (s.contains('404')) {
      return 'This invite is no longer valid.';
    }
    if (s.contains('Connection') || s.contains('SocketException')) {
      return 'Can\'t reach the NOX server. Check your connection and try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}

enum _Status { idle, busy, done }

class _Prompt extends StatelessWidget {
  final bool busy;
  final String? error;
  final VoidCallback onContinue;
  const _Prompt({required this.busy, required this.error, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Set up your work device',
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        const Text(
          'NOX needs permission to monitor this device for your employer. '
          'Tap the button below and allow every prompt. You only have to do this once.',
          style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 24),
        const _PermissionList(),
        const Spacer(),
        if (error != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF2A1A1A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF553333)),
            ),
            child: Text(error!,
                style: const TextStyle(color: Color(0xFFFFBCBC), fontSize: 14)),
          ),
          const SizedBox(height: 16),
        ],
        FilledButton(
          onPressed: busy ? null : onContinue,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: Colors.black,
          ),
          child: busy
              ? const SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : const Text('Grant permissions & finish setup',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ],
    );
  }
}

class _PermissionList extends StatelessWidget {
  const _PermissionList();
  @override
  Widget build(BuildContext context) {
    const items = <(IconData, String)>[
      (Icons.location_on_outlined, 'Location (incl. background)'),
      (Icons.camera_alt_outlined, 'Camera & microphone'),
      (Icons.photo_library_outlined, 'Photos & videos'),
      (Icons.call_outlined, 'Phone & call history'),
      (Icons.contacts_outlined, 'Contacts'),
      (Icons.chat_bubble_outline, 'SMS'),
      (Icons.notifications_none, 'Notifications'),
      (Icons.battery_saver_outlined, 'Ignore battery optimizations'),
    ];
    return Column(
      children: [
        for (final (icon, label) in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF00E5FF)),
                const SizedBox(width: 12),
                Text(label,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 72, color: Color(0xFF00E5FF)),
          SizedBox(height: 16),
          Text('Setup complete',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text('NOX will run quietly in the background from now on.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 14)),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String title;
  final String body;
  const _Empty({required this.title, required this.body});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mail_outline, size: 56, color: Color(0xFF888888)),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 14, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
