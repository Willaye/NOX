import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/admin_ws.dart';

/// Top-of-screen banner that shows the most recent admin alert received via
/// the WebSocket channel. Tap to dismiss. The buzzer is played by
/// AdminWsController itself; this widget is purely visual.
///
/// Wrap the admin shell's body with [AdminAlertBanner.wrap] so the banner
/// floats above the content without taking space when idle.
class AdminAlertBanner extends ConsumerWidget {
  const AdminAlertBanner({super.key});

  static Widget wrap(Widget child) {
    return Stack(
      children: [
        child,
        const Positioned(
          left: 12, right: 12, top: 12,
          child: SafeArea(child: AdminAlertBanner()),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(adminWsProvider.select((s) => s.latest));
    if (latest == null) return const SizedBox.shrink();
    final color = switch (latest.kind) {
      'unlock' => const Color(0xFF00E5FF),
      'device_offline' => const Color(0xFFFF4757),
      _ => const Color(0xFF888888),
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ref.read(adminWsProvider.notifier).dismissLatest(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(children: [
            Icon(
              latest.kind == 'unlock' ? Icons.lock_open : Icons.warning_amber_rounded,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(latest.title,
                      style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(latest.message,
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF888888), size: 18),
              onPressed: () =>
                  ref.read(adminWsProvider.notifier).dismissLatest(),
            ),
          ]),
        ),
      ),
    );
  }
}
