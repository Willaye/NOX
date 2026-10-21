import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nox_design_system/nox_design_system.dart';
import '../../../core/models/nox_models.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/utils/formatters.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<void> _refresh() async {
    try {
      await Future.wait<void>([
        ref.refresh(devicesProvider.future),
        ref.read(notificationsProvider.notifier).load(),
      ]);
    } catch (_) {}
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final firstName = authState.user?.firstName.trim() ?? '';
    final fullName = authState.user?.fullName ?? '';
    final userName = firstName.isNotEmpty ? firstName : (fullName.isNotEmpty ? fullName : 'there');
    final devicesAsync = ref.watch(devicesProvider);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [NoxColors.deepAbyss, NoxColors.voidBlack],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            color: NoxColors.lavenderPrimary,
            backgroundColor: NoxColors.darkSurface,
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Welcome Header ──────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(NoxSpacing.xxl, NoxSpacing.lg, NoxSpacing.xxl, 0),
                    child: Row(children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_getGreeting()},', style: NoxTypography.subtitle.copyWith(color: NoxColors.mistGray)),
                          const SizedBox(height: 2),
                          Text(userName, style: NoxTypography.h1),
                          const SizedBox(height: 4),
                          Text('Your world, in your control.',
                            style: NoxTypography.caption.copyWith(color: NoxColors.dimGray)),
                        ],
                      )),
                      NoxBadge.count(
                        count: ref.watch(unreadNotificationsCountProvider),
                        child: NoxIconButton(
                          icon: Icons.notifications_outlined,
                          onPressed: () => context.push('/notifications'),
                          size: 44,
                        ),
                      ),
                      const SizedBox(width: NoxSpacing.md),
                      NoxAvatar(
                        initials: authState.user?.initials ?? '?',
                        size: 44,
                        showGradientBorder: true,
                        status: NoxDeviceStatus.online,
                        onTap: () => context.push('/settings'),
                      ),
                    ]),
                  ),
                ),

                // ── Device Location + Add Device Row ─────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(NoxSpacing.xxl, NoxSpacing.xl, NoxSpacing.xxl, 0),
                    child: devicesAsync.when(
                      skipLoadingOnRefresh: true,
                      loading: () => const SizedBox(height: 120, child: Center(child: NoxLoadingSpinner())),
                      error: (e, _) => NoxCard(variant: NoxCardVariant.glass,
                        child: NoxErrorState(message: 'Couldn\'t load', details: errorMessage(e),
                          onRetry: () => ref.invalidate(devicesProvider))),
                      data: (page) => _buildTopRow(context, page),
                    ),
                  ),
                ),

                // ── Current Device Card ──────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(NoxSpacing.xxl, NoxSpacing.lg, NoxSpacing.xxl, 0),
                    child: devicesAsync.when(
                      skipLoadingOnRefresh: true,
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (page) => page.devices.isEmpty
                          ? const SizedBox.shrink()
                          : _buildCurrentDevice(context, page.devices.first),
                    ),
                  ),
                ),

                // ── Today's Activities ───────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(NoxSpacing.xxl, NoxSpacing.lg, NoxSpacing.xxl, 0),
                    child: devicesAsync.when(
                      skipLoadingOnRefresh: true,
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (page) => page.devices.isEmpty
                          ? const SizedBox.shrink()
                          : _TodaysActivities(deviceId: page.devices.first.id),
                    ),
                  ),
                ),

                // ── Recent Activity ──────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(NoxSpacing.xxl, NoxSpacing.lg, NoxSpacing.xxl, NoxSpacing.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Recent Activity', style: NoxTypography.h3),
                        GestureDetector(
                          onTap: () => context.push('/notifications'),
                          child: Text('View all', style: NoxTypography.bodySmall.copyWith(
                            color: NoxColors.lavenderLight, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Recent Activity List ─────────────────────────────
                ref.watch(notificationsProvider).when(
                  skipLoadingOnRefresh: true,
                  loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                  error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                  data: (items) => items.isEmpty
                      ? const SliverToBoxAdapter(
                          child: Padding(padding: EdgeInsets.symmetric(horizontal: NoxSpacing.xxl),
                            child: NoxEmptyState(icon: Icons.notifications_none_rounded,
                              title: 'No recent activity', subtitle: 'Events will show up here.')))
                      : SliverList(delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final n = items[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: NoxSpacing.xxl, vertical: NoxSpacing.xs),
                              child: NoxCard(
                                variant: NoxCardVariant.glass,
                                padding: const EdgeInsets.all(NoxSpacing.lg),
                                onTap: () => n.deviceId != null
                                    ? context.push('/devices/${n.deviceId}')
                                    : context.push('/notifications'),
                                child: Row(children: [
                                  Container(
                                    width: 40, height: 40,
                                    decoration: BoxDecoration(
                                      color: notificationColor(n.type).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(NoxSpacing.radiusMd)),
                                    child: Center(child: Icon(notificationIcon(n.type), size: 20,
                                      color: notificationColor(n.type))),
                                  ),
                                  const SizedBox(width: NoxSpacing.md),
                                  Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(n.title, style: NoxTypography.subtitle.copyWith(
                                        color: NoxColors.softWhite, fontSize: 13),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 2),
                                      Text(n.deviceName != null
                                          ? '${n.deviceName} • ${timeAgo(n.createdAt)}'
                                          : timeAgo(n.createdAt),
                                        style: NoxTypography.caption),
                                    ],
                                  )),
                                  const Icon(Icons.chevron_right_rounded, color: NoxColors.dimGray, size: 20),
                                ]),
                              ),
                            );
                          },
                          childCount: items.take(5).length,
                        )),
                ),

                // ── App Chats Quick Preview ──────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(NoxSpacing.xxl, NoxSpacing.lg, NoxSpacing.xxl, 0),
                    child: devicesAsync.when(
                      skipLoadingOnRefresh: true,
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (page) => page.devices.isEmpty
                          ? const SizedBox.shrink()
                          : _AppChatsPreview(deviceId: page.devices.first.id),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: NoxSpacing.xxxl)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopRow(BuildContext context, DevicesPage page) {
    final firstDevice = page.devices.isEmpty ? null : page.devices.first;
    return Row(children: [
      // Device Location
      Expanded(
        child: NoxCard(
          variant: NoxCardVariant.elevated,
          padding: const EdgeInsets.all(NoxSpacing.lg),
          height: 110,
          onTap: firstDevice != null ? () => context.push('/devices/${firstDevice.id}') : null,
          child: firstDevice == null
              ? const Center(child: Text('No device', style: TextStyle(color: NoxColors.dimGray)))
              : _LocationPreview(deviceId: firstDevice.id),
        ),
      ),
      const SizedBox(width: NoxSpacing.md),
      // Add Device
      SizedBox(
        width: 110, height: 110,
        child: NoxCard(
          variant: NoxCardVariant.gradient,
          padding: const EdgeInsets.all(NoxSpacing.md),
          onTap: () => context.push('/invite'),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: NoxColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.add_rounded, color: NoxColors.pureWhite, size: 26),
              ),
              const SizedBox(height: 8),
              Text('Add Device', style: NoxTypography.caption.copyWith(
                color: NoxColors.moonlightSilver, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _buildCurrentDevice(BuildContext context, Device device) {
    final battery = device.batteryLevel;
    final batteryColor = battery == null ? NoxColors.mistGray
        : battery > 60 ? NoxColors.onlineGreen
        : battery > 20 ? NoxColors.warningAmber : NoxColors.offlineRed;

    return NoxCard(
      variant: NoxCardVariant.glass,
      padding: const EdgeInsets.all(NoxSpacing.lg),
      onTap: () => context.push('/devices/${device.id}'),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            gradient: NoxColors.cardGradient, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: NoxColors.glassBorder, width: 0.5)),
          child: Center(child: Icon(deviceIcon(device), size: 24, color: NoxColors.lavenderLight)),
        ),
        const SizedBox(width: NoxSpacing.md),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Device', style: NoxTypography.caption.copyWith(color: NoxColors.dimGray)),
            Text(device.name, style: NoxTypography.subtitle.copyWith(color: NoxColors.pureWhite, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(children: [
              NoxStatusDot(status: deviceStatus(device), showLabel: true),
              const SizedBox(width: NoxSpacing.md),
              Text('Last seen: ${device.isOnline ? "Now" : timeAgo(device.lastSeenAt)}',
                style: NoxTypography.caption),
            ]),
          ],
        )),
        if (battery != null)
          Column(children: [
            Icon(Icons.battery_std_rounded, color: batteryColor, size: 20),
            Text('$battery%', style: NoxTypography.caption.copyWith(color: batteryColor, fontWeight: FontWeight.w600)),
          ]),
      ]),
    );
  }
}

/// Shows the latest location in the top row card
class _LocationPreview extends ConsumerWidget {
  final String deviceId;
  const _LocationPreview({required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(locationLogsProvider(deviceId));
    return logsAsync.when(
      loading: () => const Center(child: SizedBox(width: 20, height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: NoxColors.lavenderLight))),
      error: (_, __) => const Center(child: Icon(Icons.location_off_rounded, color: NoxColors.dimGray)),
      data: (logs) {
        final latest = logs.isEmpty ? null : logs.first;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.location_on_rounded, size: 16,
              color: latest != null ? NoxColors.offlineRed : NoxColors.dimGray),
            const SizedBox(width: 6),
            Text('Device Location', style: NoxTypography.caption.copyWith(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          if (latest == null)
            Text('No location data', style: NoxTypography.bodySmall.copyWith(color: NoxColors.dimGray))
          else ...[
            Text(latest.address ?? latest.coordinates,
              style: NoxTypography.subtitle.copyWith(color: NoxColors.pureWhite, fontSize: 13),
              maxLines: 2, overflow: TextOverflow.ellipsis),
            const Spacer(),
            Text('${timeAgo(latest.timestamp)}', style: NoxTypography.caption),
          ],
        ]);
      },
    );
  }
}

/// Today's app usage with progress bars
class _TodaysActivities extends ConsumerWidget {
  final String deviceId;
  const _TodaysActivities({required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync = ref.watch(appUsageProvider(deviceId));
    return usageAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (rows) {
        if (rows.isEmpty) return const SizedBox.shrink();

        // Aggregate by app, pick top 5
        final appMap = <String, int>{};
        for (final r in rows) {
          final name = (r['appName'] ?? r['packageName'] ?? '').toString();
          final ms = int.tryParse((r['durationMs'] ?? r['duration'] ?? '0').toString()) ?? 0;
          if (name.isNotEmpty && ms > 0) appMap[name] = (appMap[name] ?? 0) + ms;
        }
        if (appMap.isEmpty) return const SizedBox.shrink();

        final sorted = appMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final top = sorted.take(5).toList();
        final maxMs = top.first.value;

        final colors = [
          NoxColors.onlineGreen, const Color(0xFFE1306C), const Color(0xFFFFFC00),
          NoxColors.icyBlue, NoxColors.lavenderPrimary,
        ];

        return NoxCard(
          variant: NoxCardVariant.glass,
          padding: const EdgeInsets.all(NoxSpacing.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.bar_chart_rounded, size: 18, color: NoxColors.lavenderLight),
              const SizedBox(width: 8),
              Text("Today's Activities", style: NoxTypography.h3),
            ]),
            const SizedBox(height: NoxSpacing.lg),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: top.length,
                separatorBuilder: (_, __) => const SizedBox(width: NoxSpacing.lg),
                itemBuilder: (_, i) {
                  final name = top[i].key;
                  final ms = top[i].value;
                  final pct = maxMs > 0 ? ms / maxMs : 0.0;
                  final color = colors[i % colors.length];
                  return SizedBox(
                    width: 72,
                    child: Column(children: [
                      Text(_shortName(name), style: NoxTypography.caption.copyWith(fontSize: 10),
                        maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                      const SizedBox(height: 6),
                      Text(_fmtMs(ms), style: NoxTypography.subtitle.copyWith(
                        color: NoxColors.pureWhite, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 5,
                          backgroundColor: NoxColors.elevatedSurface,
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text('${(pct * 100).round()}%', style: NoxTypography.caption.copyWith(
                        fontSize: 9, color: color)),
                    ]),
                  );
                },
              ),
            ),
          ]),
        );
      },
    );
  }

  String _shortName(String name) {
    if (name.toLowerCase().contains('whatsapp')) return 'WhatsApp';
    if (name.toLowerCase().contains('instagram')) return 'Instagram';
    if (name.toLowerCase().contains('snapchat')) return 'Snapchat';
    if (name.toLowerCase().contains('chrome') || name.toLowerCase().contains('browser')) return 'Browser';
    if (name.toLowerCase().contains('gallery') || name.toLowerCase().contains('photos')) return 'Gallery';
    if (name.toLowerCase().contains('facebook')) return 'Facebook';
    if (name.toLowerCase().contains('tiktok')) return 'TikTok';
    if (name.toLowerCase().contains('youtube')) return 'YouTube';
    return name.length > 10 ? '${name.substring(0, 10)}…' : name;
  }

  String _fmtMs(int ms) {
    final totalMin = (ms / 60000).round();
    if (totalMin >= 60) return '${totalMin ~/ 60}h ${totalMin % 60}m';
    return '${totalMin}m';
  }
}

/// App Chats quick preview at bottom of dashboard
class _AppChatsPreview extends ConsumerWidget {
  final String deviceId;
  const _AppChatsPreview({required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final socialAsync = ref.watch(socialEventsProvider(deviceId));
    return socialAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (rows) {
        if (rows.isEmpty) return const SizedBox.shrink();

        // Count per app
        final apps = <String, int>{};
        for (final r in rows) {
          final pkg = (r['appPackage'] ?? '').toString().toLowerCase();
          String label = 'Other';
          if (pkg.contains('whatsapp')) label = 'WhatsApp';
          else if (pkg.contains('instagram')) label = 'Instagram';
          else if (pkg.contains('snapchat')) label = 'Snapchat';
          else if (pkg.contains('facebook') || pkg.contains('messenger')) label = 'Messenger';
          else if (pkg.contains('telegram')) label = 'Telegram';
          apps[label] = (apps[label] ?? 0) + 1;
        }

        return NoxCard(
          variant: NoxCardVariant.glass,
          padding: const EdgeInsets.all(NoxSpacing.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.chat_rounded, size: 18, color: NoxColors.lavenderLight),
              const SizedBox(width: 8),
              Text('App Chats & Activity', style: NoxTypography.h3),
            ]),
            const SizedBox(height: NoxSpacing.md),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in apps.entries)
                GestureDetector(
                  onTap: () {
                    final device = ref.read(devicesProvider).valueOrNull?.devices.firstOrNull;
                    if (device != null) context.push('/devices/${device.id}');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: NoxColors.elevatedSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: NoxColors.glassBorder, width: 0.5)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(e.key, style: NoxTypography.bodySmall.copyWith(color: NoxColors.softWhite)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: NoxColors.lavenderPrimary, borderRadius: BorderRadius.circular(10)),
                        child: Text('${e.value}', style: NoxTypography.caption.copyWith(
                          color: NoxColors.pureWhite, fontWeight: FontWeight.w700, fontSize: 10)),
                      ),
                    ]),
                  ),
                ),
            ]),
          ]),
        );
      },
    );
  }
}
