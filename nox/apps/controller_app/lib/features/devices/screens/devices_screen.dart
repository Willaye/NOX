import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nox_design_system/nox_design_system.dart';
import '../../../core/models/nox_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/utils/formatters.dart';

enum _DeviceFilter { all, online, offline }

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  final _searchController = TextEditingController();
  _DeviceFilter _currentFilter = _DeviceFilter.all;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      ref.invalidate(devicesProvider);
      await ref.read(devicesProvider.future);
    } catch (_) {
      // Shown by the error state.
    }
  }

  List<_DeviceData> _toViewData(List<Device> devices) => [
        for (final d in devices)
          _DeviceData(
            id: d.id,
            name: d.name,
            type: d.typeDescription,
            status: deviceStatus(d),
            battery: d.batteryLevel,
            lastSeen: d.isOnline ? 'Online now' : timeAgo(d.lastSeenAt),
            icon: deviceIcon(d),
          ),
      ];

  List<_DeviceData> _filter(List<_DeviceData> all) {
    var devices = all;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      devices = devices.where((d) =>
        d.name.toLowerCase().contains(q) ||
        d.type.toLowerCase().contains(q)
      ).toList();
    }

    // Apply status filter
    switch (_currentFilter) {
      case _DeviceFilter.all:
        break;
      case _DeviceFilter.online:
        devices = devices.where((d) => d.isOnline).toList();
      case _DeviceFilter.offline:
        devices = devices.where((d) => !d.isOnline).toList();
    }

    return devices;
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesProvider);
    final allDevices = _toViewData(devicesAsync.valueOrNull?.devices ?? const []);
    final filtered = _filter(allDevices);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [NoxColors.deepAbyss, NoxColors.voidBlack],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  NoxSpacing.xxl, NoxSpacing.lg, NoxSpacing.xxl, 0,
                ),
                child: _buildHeader(context, allDevices),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.all(NoxSpacing.xxl),
                child: NoxTextField(
                  hint: 'Search devices...',
                  controller: _searchController,
                  leadingIcon: Icons.search_rounded,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  trailing: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: const Icon(
                            Icons.clear_rounded,
                            size: 18,
                            color: NoxColors.mistGray,
                          ),
                        )
                      : null,
                ),
              ),

              // Filter chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: NoxSpacing.xxl),
                child: _buildFilterChips(allDevices),
              ),

              const SizedBox(height: NoxSpacing.lg),

              // Device list
              Expanded(
                child: RefreshIndicator(
                  color: NoxColors.lavenderPrimary,
                  backgroundColor: NoxColors.darkSurface,
                  onRefresh: _refresh,
                  child: devicesAsync.when(
                    skipLoadingOnRefresh: true,
                    loading: _buildLoadingState,
                    error: (e, _) => _scrollable(
                      NoxErrorState(
                        message: 'Couldn\'t load devices',
                        details: errorMessage(e),
                        onRetry: () => ref.invalidate(devicesProvider),
                      ),
                    ),
                    data: (_) => filtered.isEmpty
                        ? _scrollable(_buildEmptyState())
                        : _buildDeviceList(filtered),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Makes non-list states pull-to-refreshable.
  Widget _scrollable(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, List<_DeviceData> allDevices) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Devices', style: NoxTypography.h1),
            const SizedBox(height: 2),
            Text(
              '${allDevices.where((d) => d.isOnline).length} of ${allDevices.length} online',
              style: NoxTypography.bodySmall.copyWith(
                color: NoxColors.onlineGreen,
              ),
            ),
          ],
        ),
        NoxIconButton(
          icon: Icons.add_rounded,
          onPressed: () => context.push('/add-device'),
          size: 44,
          showGradient: true,
          showGlow: true,
          tooltip: 'Add device',
        ),
      ],
    );
  }

  Widget _buildFilterChips(List<_DeviceData> allDevices) {
    final onlineCount = allDevices.where((d) => d.isOnline).length;
    return Row(
      children: [
        _FilterChip(
          label: 'All',
          count: allDevices.length,
          isSelected: _currentFilter == _DeviceFilter.all,
          onTap: () => setState(() => _currentFilter = _DeviceFilter.all),
        ),
        const SizedBox(width: NoxSpacing.sm),
        _FilterChip(
          label: 'Online',
          count: onlineCount,
          isSelected: _currentFilter == _DeviceFilter.online,
          onTap: () => setState(() => _currentFilter = _DeviceFilter.online),
          activeColor: NoxColors.onlineGreen,
        ),
        const SizedBox(width: NoxSpacing.sm),
        _FilterChip(
          label: 'Offline',
          count: allDevices.length - onlineCount,
          isSelected: _currentFilter == _DeviceFilter.offline,
          onTap: () => setState(() => _currentFilter = _DeviceFilter.offline),
          activeColor: NoxColors.offlineRed,
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: NoxSpacing.xxl),
      itemCount: 4,
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: NoxSpacing.md),
          child: NoxCard(
            variant: NoxCardVariant.elevated,
            child: Row(
              children: [
                NoxSkeletonLoader(width: 52, height: 52, borderRadius: 14),
                SizedBox(width: NoxSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NoxSkeletonLoader(width: 140, height: 16),
                      SizedBox(height: NoxSpacing.sm),
                      NoxSkeletonLoader(width: 100, height: 12),
                      SizedBox(height: NoxSpacing.sm),
                      NoxSkeletonLoader(width: 80, height: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    if (_searchQuery.isNotEmpty) {
      return NoxEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results found',
        subtitle: 'No devices match "$_searchQuery". Try a different search.',
        actionLabel: 'Clear search',
        onAction: () {
          _searchController.clear();
          setState(() => _searchQuery = '');
        },
      );
    }

    return NoxEmptyState(
      icon: Icons.devices_rounded,
      title: 'No devices yet',
      subtitle: 'Add your first device to start monitoring it remotely.',
      actionLabel: 'Add Device',
      onAction: () => context.push('/add-device'),
    );
  }

  Widget _buildDeviceList(List<_DeviceData> devices) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: NoxSpacing.xxl),
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: NoxSpacing.md),
          child: _DeviceListTile(
            device: device,
            onTap: () => context.push('/devices/${device.id}'),
          ),
        );
      },
    );
  }
}

class _DeviceListTile extends StatelessWidget {
  final _DeviceData device;
  final VoidCallback onTap;

  const _DeviceListTile({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return NoxCard(
      variant: NoxCardVariant.elevated,
      padding: const EdgeInsets.all(NoxSpacing.lg),
      onTap: onTap,
      child: Row(
        children: [
          // Device icon
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: NoxColors.cardGradient,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: NoxColors.glassBorder, width: 0.5),
            ),
            child: Center(
              child: Icon(
                device.icon,
                size: 26,
                color: NoxColors.lavenderLight,
              ),
            ),
          ),

          const SizedBox(width: NoxSpacing.lg),

          // Device info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        device.name,
                        style: NoxTypography.subtitle.copyWith(
                          color: NoxColors.pureWhite,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    NoxStatusDot(status: device.status, showLabel: true),
                  ],
                ),
                const SizedBox(height: NoxSpacing.xs),
                Text(device.type, style: NoxTypography.bodySmall),
                const SizedBox(height: NoxSpacing.sm),
                Row(
                  children: [
                    if (device.battery != null) ...[
                      NoxBatteryIndicator(
                        level: device.battery!,
                        showPercentage: true,
                      ),
                      const SizedBox(width: NoxSpacing.lg),
                    ],
                    const Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: NoxColors.dimGray,
                    ),
                    const SizedBox(width: NoxSpacing.xs),
                    Text(
                      device.lastSeen,
                      style: NoxTypography.caption,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: NoxSpacing.sm),

          const Icon(
            Icons.chevron_right_rounded,
            color: NoxColors.dimGray,
            size: 22,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? activeColor;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? NoxColors.lavenderPrimary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: NoxSpacing.lg,
          vertical: NoxSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : NoxColors.glassWhite,
          borderRadius: BorderRadius.circular(NoxSpacing.radiusRound),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.4) : NoxColors.glassBorder,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: NoxTypography.bodySmall.copyWith(
                color: isSelected ? color : NoxColors.mistGray,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(width: NoxSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.2)
                    : NoxColors.elevatedSurface,
                borderRadius: BorderRadius.circular(NoxSpacing.radiusRound),
              ),
              child: Text(
                '$count',
                style: NoxTypography.caption.copyWith(
                  color: isSelected ? color : NoxColors.dimGray,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceData {
  final String id;
  final String name;
  final String type;
  final NoxDeviceStatus status;
  final int? battery;
  final String lastSeen;
  final IconData icon;

  bool get isOnline =>
      status == NoxDeviceStatus.online || status == NoxDeviceStatus.warning;

  const _DeviceData({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    this.battery,
    required this.lastSeen,
    required this.icon,
  });
}
