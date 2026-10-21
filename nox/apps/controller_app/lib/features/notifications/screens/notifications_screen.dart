import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nox_design_system/nox_design_system.dart';
import '../../../core/models/nox_models.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/utils/formatters.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _selectedCategory = 'All';

  // Labels map to backend NotificationCategory values via categoryLabel().
  final List<String> _categories = ['All', 'Devices', 'Security', 'Files', 'Messages', 'System'];

  @override
  void initState() {
    super.initState();
    // Always fetch fresh data when the screen opens.
    Future.microtask(() => ref.read(notificationsProvider.notifier).load());
  }

  List<_NotificationItem> _toItems(List<AppNotification> notifications) => [
        for (final n in notifications)
          _NotificationItem(
            id: n.id,
            icon: notificationIcon(n.type),
            title: n.title,
            body: n.body,
            time: timeAgo(n.createdAt),
            category: categoryLabel(n.category),
            color: notificationColor(n.type),
            isRead: n.isRead,
          ),
      ];

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) showNoxSnackBar(context, errorMessage(e), isError: true);
    }
  }

  void _markAllRead() =>
      _run(() => ref.read(notificationsProvider.notifier).markAllAsRead());

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final notifications = _toItems(notificationsAsync.valueOrNull ?? const []);
    final unreadCount = notifications.where((n) => !n.isRead).length;
    final filtered = _selectedCategory == 'All'
        ? notifications
        : notifications.where((n) => n.category == _selectedCategory).toList();

    return Scaffold(
      appBar: NoxAppBar(
        title: 'Notifications',
        showBackButton: true,
        onBackPressed: () => context.pop(),
        actions: [
          if (unreadCount > 0)
            GestureDetector(
              onTap: _markAllRead,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: NoxSpacing.lg),
                child: Center(
                  child: Text(
                    'Mark all read',
                    style: NoxTypography.bodySmall.copyWith(
                      color: NoxColors.lavenderLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
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
        child: Column(
          children: [
            // Unread count + category tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(
                NoxSpacing.xxl, NoxSpacing.lg, NoxSpacing.xxl, NoxSpacing.md,
              ),
              child: Row(
                children: [
                  Text(
                    '$unreadCount unread',
                    style: NoxTypography.bodySmall.copyWith(
                      color: unreadCount > 0
                          ? NoxColors.lavenderLight
                          : NoxColors.dimGray,
                    ),
                  ),
                ],
              ),
            ),

            // Category chips
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: NoxSpacing.xxl),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: NoxSpacing.sm),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = category == _selectedCategory;
                  final count = category == 'All'
                      ? notifications.length
                      : notifications.where((n) => n.category == category).length;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = category),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: NoxSpacing.lg,
                        vertical: NoxSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? NoxColors.lavenderPrimary.withValues(alpha: 0.15)
                            : NoxColors.glassWhite,
                        borderRadius: BorderRadius.circular(NoxSpacing.radiusRound),
                        border: Border.all(
                          color: isSelected
                              ? NoxColors.lavenderPrimary.withValues(alpha: 0.4)
                              : NoxColors.glassBorder,
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            category,
                            style: NoxTypography.bodySmall.copyWith(
                              color: isSelected
                                  ? NoxColors.lavenderLight
                                  : NoxColors.mistGray,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                          const SizedBox(width: NoxSpacing.xs),
                          Text(
                            '$count',
                            style: NoxTypography.caption.copyWith(
                              color: isSelected
                                  ? NoxColors.lavenderLight
                                  : NoxColors.dimGray,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: NoxSpacing.lg),

            // Notifications list
            Expanded(
              child: RefreshIndicator(
                color: NoxColors.lavenderPrimary,
                backgroundColor: NoxColors.darkSurface,
                onRefresh: () => ref.read(notificationsProvider.notifier).load(),
                child: notificationsAsync.when(
                  skipLoadingOnRefresh: true,
                  loading: () => const Center(
                    child: NoxLoadingSpinner(message: 'Loading notifications...'),
                  ),
                  error: (e, _) => _scrollable(
                    NoxErrorState(
                      message: 'Couldn\'t load notifications',
                      details: errorMessage(e),
                      onRetry: () => ref.read(notificationsProvider.notifier).load(),
                    ),
                  ),
                  data: (_) => filtered.isEmpty
                      ? _scrollable(
                          const NoxEmptyState(
                            icon: Icons.notifications_off_outlined,
                            title: 'No notifications',
                            subtitle: 'You\'re all caught up! Notifications will appear here.',
                          ),
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: NoxSpacing.xxl),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final notification = filtered[index];
                            return _NotificationTile(
                              key: ValueKey(notification.id),
                              notification: notification,
                              onTap: () => _run(() => ref
                                  .read(notificationsProvider.notifier)
                                  .markAsRead(notification.id)),
                              onDismiss: () => _run(() => ref
                                  .read(notificationsProvider.notifier)
                                  .dismiss(notification.id)),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
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
}

class _NotificationTile extends StatelessWidget {
  final _NotificationItem notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('dismiss-${notification.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: NoxSpacing.xxl),
        decoration: BoxDecoration(
          color: NoxColors.offlineRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(NoxSpacing.radiusLg),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: NoxColors.offlineRed,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: NoxSpacing.sm),
        child: NoxCard(
          variant: notification.isRead
              ? NoxCardVariant.glass
              : NoxCardVariant.elevated,
          padding: const EdgeInsets.all(NoxSpacing.lg),
          borderColor: notification.isRead
              ? null
              : notification.color.withValues(alpha: 0.2),
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: notification.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    notification.icon,
                    size: 22,
                    color: notification.color,
                  ),
                ),
              ),
              const SizedBox(width: NoxSpacing.md),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: NoxTypography.subtitle.copyWith(
                              color: notification.isRead
                                  ? NoxColors.moonlightSilver
                                  : NoxColors.pureWhite,
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: notification.color,
                              boxShadow: [
                                BoxShadow(
                                  color: notification.color.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: NoxSpacing.xs),
                    Text(
                      notification.body,
                      style: NoxTypography.bodySmall.copyWith(
                        color: notification.isRead
                            ? NoxColors.dimGray
                            : NoxColors.mistGray,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: NoxSpacing.sm),
                    Row(
                      children: [
                        NoxBadge.label(
                          text: notification.category,
                          color: notification.color,
                        ),
                        const Spacer(),
                        Text(
                          notification.time,
                          style: NoxTypography.caption.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationItem {
  final String id;
  final IconData icon;
  final String title;
  final String body;
  final String time;
  final String category;
  final Color color;
  final bool isRead;

  const _NotificationItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
    required this.time,
    required this.category,
    required this.color,
    required this.isRead,
  });
}
