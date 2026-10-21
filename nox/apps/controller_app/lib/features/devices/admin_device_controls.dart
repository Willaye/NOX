import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';

/// Admin-only data + actions for a specific device. The widget below is the
/// drop-in UI; the providers can be composed into the existing
/// device_detail_screen.dart without rewriting it.

final deviceOverviewProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.getAdminDeviceOverview(id);
  return Map<String, dynamic>.from(resp.data as Map);
});

final unlockEventsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.getUnlockEvents(id, limit: 20);
  final data = resp.data;
  if (data is List) return data.cast<Map<String, dynamic>>();
  return const [];
});

class AdminDeviceControls extends ConsumerStatefulWidget {
  final String deviceId;
  const AdminDeviceControls({super.key, required this.deviceId});

  @override
  ConsumerState<AdminDeviceControls> createState() =>
      _AdminDeviceControlsState();
}

class _AdminDeviceControlsState extends ConsumerState<AdminDeviceControls> {
  bool _busy = false;
  String? _error;

  Future<void> _call(Future<void> Function() op) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await op();
      // Refresh the overview so lockStatus reflects the new state.
      ref.invalidate(deviceOverviewProvider(widget.deviceId));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _niceError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _lock() async {
    final api = ref.read(apiClientProvider);
    await _call(() async {
      await api.lockDevice(widget.deviceId);
    });
  }

  Future<void> _unlock() async {
    final api = ref.read(apiClientProvider);
    await _call(() async {
      await api.unlockDevice(widget.deviceId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(deviceOverviewProvider(widget.deviceId));
    final unlockEvents = ref.watch(unlockEventsProvider(widget.deviceId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        overview.when(
          data: (data) => _Header(data: data),
          loading: () => const _Skeleton(height: 110),
          error: (e, _) => _ErrorCard(message: _niceError(e)),
        ),
        const SizedBox(height: 12),
        _ActionRow(
          busy: _busy,
          onLock: _lock,
          onUnlock: _unlock,
          lockStatus: overview.valueOrNull?['device']?['lockStatus']?.toString(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          _ErrorCard(message: _error!),
        ],
        const SizedBox(height: 16),
        const _SectionHeader(
          title: 'Unlock history',
          subtitle: 'Live events arrive at the top of the screen as alerts',
        ),
        const SizedBox(height: 8),
        unlockEvents.when(
          data: (rows) => _UnlockList(rows: rows),
          loading: () => const _Skeleton(height: 160),
          error: (e, _) => _ErrorCard(message: _niceError(e)),
        ),
      ],
    );
  }

  String _niceError(Object e) {
    final s = e.toString();
    if (s.contains('403')) return 'Only admins can control this device.';
    if (s.contains('404')) return 'Device not found.';
    if (s.contains('SocketException') || s.contains('Connection')) {
      return "Can't reach the server.";
    }
    return 'Something went wrong.';
  }
}

// ─── Pieces ─────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final Map<String, dynamic> data;
  const _Header({required this.data});

  @override
  Widget build(BuildContext context) {
    final device = (data['device'] as Map?) ?? const {};
    final name = device['name']?.toString() ?? 'Device';
    final employee = device['employeeEmail']?.toString() ?? '—';
    final online = device['isOnline'] == true;
    final battery = device['batteryLevel'];
    final lockStatus = device['lockStatus']?.toString() ?? '';
    final locked = lockStatus == 'LOCKED';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: online ? const Color(0xFF00E676) : const Color(0xFFFF5252),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
            ),
            if (battery is num)
              _Chip(
                icon: Icons.battery_full,
                label: '${battery.toInt()}%',
              ),
            const SizedBox(width: 8),
            _Chip(
              icon: locked ? Icons.lock : Icons.lock_open,
              label: locked ? 'Locked' : 'Unlocked',
              color: locked
                  ? const Color(0xFFFF9800)
                  : const Color(0xFF00E5FF),
            ),
          ]),
          const SizedBox(height: 8),
          Text('Employee: $employee',
              style: const TextStyle(color: Color(0xFFCCCCCC))),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final bool busy;
  final VoidCallback onLock;
  final VoidCallback onUnlock;
  final String? lockStatus;
  const _ActionRow({
    required this.busy,
    required this.onLock,
    required this.onUnlock,
    required this.lockStatus,
  });

  @override
  Widget build(BuildContext context) {
    final locked = lockStatus == 'LOCKED';
    return Row(children: [
      Expanded(
        child: FilledButton.icon(
          onPressed: busy || locked ? null : onLock,
          icon: const Icon(Icons.lock_outline),
          label: const Text('Lock'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: const Color(0xFFFF9800),
            foregroundColor: Colors.black,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: FilledButton.icon(
          onPressed: busy || !locked ? null : onUnlock,
          icon: const Icon(Icons.lock_open),
          label: const Text('Unlock'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: Colors.black,
          ),
        ),
      ),
    ]);
  }
}

class _UnlockList extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _UnlockList({required this.rows});
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyBlock(
        icon: Icons.lock_open_outlined,
        message: 'No unlock events recorded yet.',
      );
    }
    final fmt = DateFormat.yMMMd().add_jm();
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              const Icon(Icons.radio_button_checked,
                  size: 10, color: Color(0xFF00E5FF)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  fmt.format(DateTime.parse(
                          row['occurredAt']?.toString() ?? '')
                      .toLocal()),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ]),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionHeader({required this.title, this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!,
              style:
                  const TextStyle(color: Color(0xFF888888), fontSize: 12)),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _Chip({required this.icon, required this.label, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF888888);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: c, fontSize: 11)),
      ]),
    );
  }
}

class _Skeleton extends StatelessWidget {
  final double height;
  const _Skeleton({required this.height});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: SizedBox(
          width: 24, height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF553333)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: Color(0xFFFFBCBC)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: const TextStyle(color: Color(0xFFFFBCBC))),
        ),
      ]),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyBlock({required this.icon, required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 32, color: const Color(0xFF666666)),
        const SizedBox(height: 8),
        Text(message, style: const TextStyle(color: Color(0xFF888888))),
      ]),
    );
  }
}
