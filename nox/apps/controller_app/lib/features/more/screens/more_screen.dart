import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nox_design_system/nox_design_system.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/data_providers.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final devicesPage = ref.watch(devicesProvider).valueOrNull;
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

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
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: NoxSpacing.xxl),
            children: [
              const SizedBox(height: NoxSpacing.lg),

              // Header
              Text('More', style: NoxTypography.h1),

              const SizedBox(height: NoxSpacing.xxl),

              // Profile card
              NoxCard(
                variant: NoxCardVariant.gradient,
                padding: const EdgeInsets.all(NoxSpacing.xl),
                onTap: () => context.push('/settings'),
                child: Row(
                  children: [
                    NoxAvatar(
                      initials: user?.initials ?? '?',
                      size: 56,
                      showGradientBorder: true,
                      status: NoxDeviceStatus.online,
                    ),
                    const SizedBox(width: NoxSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (user?.fullName.isNotEmpty ?? false) ? user!.fullName : 'User',
                            style: NoxTypography.h3.copyWith(
                              color: NoxColors.pureWhite,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email ?? '',
                            style: NoxTypography.bodySmall.copyWith(
                              color: NoxColors.moonlightSilver,
                            ),
                          ),
                          const SizedBox(height: NoxSpacing.xs),
                          const NoxBadge.label(text: 'Premium'),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: NoxColors.mistGray,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: NoxSpacing.xxl),

              // Quick stats
              Row(
                children: [
                  Expanded(
                    child: _QuickStatCard(
                      icon: Icons.devices_rounded,
                      value: devicesPage == null ? '—' : '${devicesPage.total}',
                      label: 'Devices',
                      color: NoxColors.lavenderPrimary,
                    ),
                  ),
                  const SizedBox(width: NoxSpacing.md),
                  Expanded(
                    child: _QuickStatCard(
                      icon: Icons.wifi_tethering_rounded,
                      value: devicesPage == null ? '—' : '${devicesPage.onlineCount}',
                      label: 'Online',
                      color: NoxColors.onlineGreen,
                    ),
                  ),
                  const SizedBox(width: NoxSpacing.md),
                  Expanded(
                    child: _QuickStatCard(
                      icon: Icons.notifications_active_rounded,
                      value: '$unreadCount',
                      label: 'Unread',
                      color: NoxColors.icyBlue,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: NoxSpacing.xxxl),

              // Menu sections
              _buildSection('General', [
                _MenuItem(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  subtitle: 'Account, security, appearance',
                  onTap: () => context.push('/settings'),
                ),
                _MenuItem(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: 'Alerts and push preferences',
                  badge: unreadCount > 0 ? '$unreadCount' : null,
                  onTap: () => context.push('/notifications'),
                ),
                _MenuItem(
                  icon: Icons.lock_outline_rounded,
                  title: 'Privacy & Security',
                  subtitle: 'Data protection, permissions',
                  onTap: () {},
                ),
              ]),

              const SizedBox(height: NoxSpacing.xxl),

              _buildSection('Devices', [
                _MenuItem(
                  icon: Icons.add_circle_outline_rounded,
                  title: 'Add New Device',
                  subtitle: 'Pair a new device to monitor',
                  onTap: () => context.push('/add-device'),
                ),
                _MenuItem(
                  icon: Icons.sync_rounded,
                  title: 'Sync Settings',
                  subtitle: 'Auto-sync, frequency, data usage',
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.storage_outlined,
                  title: 'Storage Management',
                  subtitle: 'Manage synced data and cache',
                  onTap: () {},
                ),
              ]),

              const SizedBox(height: NoxSpacing.xxl),

              _buildSection('Support', [
                _MenuItem(
                  icon: Icons.help_outline_rounded,
                  title: 'Help Center',
                  subtitle: 'FAQs, guides, troubleshooting',
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Contact Support',
                  subtitle: 'Get help from our team',
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.bug_report_outlined,
                  title: 'Report a Bug',
                  subtitle: 'Help us improve NOX',
                  onTap: () {},
                ),
              ]),

              const SizedBox(height: NoxSpacing.xxl),

              _buildSection('About', [
                _MenuItem(
                  icon: Icons.info_outline_rounded,
                  title: 'About NOX',
                  subtitle: 'Version 1.0.0',
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  onTap: () {},
                ),
              ]),

              const SizedBox(height: NoxSpacing.xxxl),

              // Logout
              NoxButton(
                label: 'Sign Out',
                variant: NoxButtonVariant.outlined,
                isExpanded: true,
                icon: Icons.logout_rounded,
                onPressed: () async {
                  final confirmed = await NoxConfirmDialog.show(
                    context: context,
                    title: 'Sign Out',
                    message: 'Are you sure you want to sign out? You\'ll need to sign in again to access your devices.',
                    confirmLabel: 'Sign Out',
                    isDangerous: true,
                  );
                  if (confirmed) {
                    await ref.read(authStateProvider.notifier).logout();
                    if (context.mounted) context.go('/welcome');
                  }
                },
              ),

              const SizedBox(height: NoxSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<_MenuItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: NoxSpacing.md),
          child: Text(
            title.toUpperCase(),
            style: NoxTypography.label.copyWith(
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
        ),
        NoxCard(
          variant: NoxCardVariant.elevated,
          padding: EdgeInsets.zero,
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: item.onTap,
                      borderRadius: index == 0
                          ? const BorderRadius.vertical(top: Radius.circular(16))
                          : index == items.length - 1
                              ? const BorderRadius.vertical(bottom: Radius.circular(16))
                              : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: NoxSpacing.lg,
                          vertical: NoxSpacing.md,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: NoxColors.lavenderPrimary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Icon(
                                  item.icon,
                                  size: 20,
                                  color: NoxColors.lavenderLight,
                                ),
                              ),
                            ),
                            const SizedBox(width: NoxSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: NoxTypography.subtitle.copyWith(
                                      color: NoxColors.softWhite,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (item.subtitle != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      item.subtitle!,
                                      style: NoxTypography.caption,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (item.badge != null) ...[
                              NoxBadge(
                                count: int.tryParse(item.badge!) ?? 0,
                                variant: NoxBadgeVariant.notification,
                              ),
                              const SizedBox(width: NoxSpacing.sm),
                            ],
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: NoxColors.dimGray,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (index < items.length - 1)
                    const Padding(
                      padding: EdgeInsets.only(left: 68),
                      child: Divider(
                        height: 0.5,
                        color: NoxColors.glassBorder,
                      ),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _QuickStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return NoxCard(
      variant: NoxCardVariant.glass,
      padding: const EdgeInsets.all(NoxSpacing.md),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: NoxSpacing.xs),
          Text(
            value,
            style: NoxTypography.subtitle.copyWith(
              color: NoxColors.pureWhite,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: NoxTypography.caption.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.badge,
    required this.onTap,
  });
}
