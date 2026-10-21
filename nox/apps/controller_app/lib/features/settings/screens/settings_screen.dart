import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nox_design_system/nox_design_system.dart';
import '../../../core/models/nox_models.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/utils/formatters.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _deviceAlerts = true;
  bool _batteryAlerts = true;
  bool _locationTracking = true;
  bool _biometricLock = false;
  bool _autoSync = true;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final sessionsAsync = ref.watch(sessionsProvider);
    final sessionsSubtitle = sessionsAsync.when(
      data: (s) => s.length == 1
          ? '1 active session'
          : '${s.length} active sessions',
      loading: () => 'Loading sessions...',
      error: (_, __) => 'Couldn\'t load sessions',
    );

    return Scaffold(
      appBar: NoxAppBar(
        title: 'Settings',
        showBackButton: true,
        onBackPressed: () => context.pop(),
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
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: NoxSpacing.xxl,
            vertical: NoxSpacing.lg,
          ),
          children: [
            // Account section
            _buildSectionHeader('Account'),
            NoxCard(
              variant: NoxCardVariant.elevated,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // Profile row
                  Padding(
                    padding: const EdgeInsets.all(NoxSpacing.lg),
                    child: Row(
                      children: [
                        NoxAvatar(
                          initials: user?.initials ?? '?',
                          size: 56,
                          showGradientBorder: true,
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
                                user?.email ?? 'user@example.com',
                                style: NoxTypography.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        NoxButton(
                          label: 'Edit',
                          variant: NoxButtonVariant.outlined,
                          onPressed: () {},
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: NoxColors.glassBorder, height: 0.5),
                  _buildSettingsTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Edit Profile',
                    subtitle: 'Name, avatar, bio',
                    onTap: () {},
                  ),
                  _buildSettingsTile(
                    icon: Icons.email_outlined,
                    title: 'Change Email',
                    subtitle: user?.email ?? 'user@example.com',
                    onTap: () {},
                  ),
                  _buildSettingsTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Change Password',
                    subtitle: 'Update your account password',
                    onTap: () => _showChangePasswordDialog(context),
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: NoxSpacing.xxl),

            // Security section
            _buildSectionHeader('Security'),
            NoxCard(
              variant: NoxCardVariant.elevated,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildSwitchTile(
                    icon: Icons.fingerprint_rounded,
                    title: 'Biometric Lock',
                    subtitle: 'Require fingerprint or face to open app',
                    value: _biometricLock,
                    onChanged: (val) => setState(() => _biometricLock = val),
                  ),
                  _buildSwitchTile(
                    icon: Icons.location_on_outlined,
                    title: 'Location Tracking',
                    subtitle: 'Track device locations in real-time',
                    value: _locationTracking,
                    onChanged: (val) => setState(() => _locationTracking = val),
                  ),
                  _buildSettingsTile(
                    icon: Icons.devices_rounded,
                    title: 'Active Sessions',
                    subtitle: sessionsSubtitle,
                    onTap: () => _showSessionsSheet(context),
                  ),
                  _buildSettingsTile(
                    icon: Icons.key_rounded,
                    title: 'Two-Factor Authentication',
                    subtitle: 'Not enabled',
                    trailing: const NoxBadge.label(
                      text: 'Recommended',
                      color: NoxColors.warningAmber,
                    ),
                    onTap: () {},
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: NoxSpacing.xxl),

            // Notifications section
            _buildSectionHeader('Notifications'),
            NoxCard(
              variant: NoxCardVariant.elevated,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildSwitchTile(
                    icon: Icons.notifications_outlined,
                    title: 'Push Notifications',
                    subtitle: 'Receive push notifications',
                    value: _pushNotifications,
                    onChanged: (val) => setState(() => _pushNotifications = val),
                  ),
                  _buildSwitchTile(
                    icon: Icons.email_outlined,
                    title: 'Email Notifications',
                    subtitle: 'Receive email alerts',
                    value: _emailNotifications,
                    onChanged: (val) => setState(() => _emailNotifications = val),
                  ),
                  _buildSwitchTile(
                    icon: Icons.phone_android_rounded,
                    title: 'Device Status Alerts',
                    subtitle: 'Notify when devices go online/offline',
                    value: _deviceAlerts,
                    onChanged: (val) => setState(() => _deviceAlerts = val),
                  ),
                  _buildSwitchTile(
                    icon: Icons.battery_alert_rounded,
                    title: 'Battery Alerts',
                    subtitle: 'Notify when battery drops below 20%',
                    value: _batteryAlerts,
                    onChanged: (val) => setState(() => _batteryAlerts = val),
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: NoxSpacing.xxl),

            // Appearance section
            _buildSectionHeader('Appearance'),
            NoxCard(
              variant: NoxCardVariant.elevated,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildSettingsTile(
                    icon: Icons.palette_outlined,
                    title: 'Theme',
                    subtitle: 'Dark (Ethereal)',
                    trailing: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: NoxColors.primaryGradient,
                      ),
                    ),
                    onTap: () {},
                  ),
                  _buildSettingsTile(
                    icon: Icons.text_fields_rounded,
                    title: 'Text Size',
                    subtitle: 'Medium',
                    onTap: () {},
                  ),
                  _buildSettingsTile(
                    icon: Icons.language_rounded,
                    title: 'Language',
                    subtitle: 'English',
                    onTap: () {},
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: NoxSpacing.xxl),

            // Data & Sync section
            _buildSectionHeader('Data & Sync'),
            NoxCard(
              variant: NoxCardVariant.elevated,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildSwitchTile(
                    icon: Icons.sync_rounded,
                    title: 'Auto Sync',
                    subtitle: 'Automatically sync device data',
                    value: _autoSync,
                    onChanged: (val) => setState(() => _autoSync = val),
                  ),
                  _buildSettingsTile(
                    icon: Icons.cloud_outlined,
                    title: 'Data Usage',
                    subtitle: '14.6 GB synced this month',
                    onTap: () {},
                  ),
                  _buildSettingsTile(
                    icon: Icons.delete_sweep_outlined,
                    title: 'Clear Cache',
                    subtitle: '256 MB cached data',
                    onTap: () async {
                      final confirmed = await NoxConfirmDialog.show(
                        context: context,
                        title: 'Clear Cache',
                        message: 'This will remove all cached data. Your account and device data will not be affected.',
                        confirmLabel: 'Clear',
                      );
                      if (confirmed && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Cache cleared successfully',
                              style: NoxTypography.body.copyWith(
                                color: NoxColors.pureWhite,
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: NoxSpacing.xxl),

            // Support section
            _buildSectionHeader('Support'),
            NoxCard(
              variant: NoxCardVariant.elevated,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildSettingsTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Help Center',
                    onTap: () {},
                  ),
                  _buildSettingsTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Contact Support',
                    onTap: () {},
                  ),
                  _buildSettingsTile(
                    icon: Icons.star_outline_rounded,
                    title: 'Rate NOX',
                    onTap: () {},
                  ),
                  _buildSettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'About',
                    subtitle: 'Version 1.0.0 (Build 1)',
                    onTap: () {},
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: NoxSpacing.xxxl),

            // Danger zone
            _buildSectionHeader('Danger Zone'),
            NoxCard(
              variant: NoxCardVariant.elevated,
              borderColor: NoxColors.offlineRed.withValues(alpha: 0.2),
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildSettingsTile(
                    icon: Icons.logout_rounded,
                    title: 'Sign Out',
                    titleColor: NoxColors.offlineRed,
                    iconColor: NoxColors.offlineRed,
                    onTap: () async {
                      final confirmed = await NoxConfirmDialog.show(
                        context: context,
                        title: 'Sign Out',
                        message: 'Are you sure you want to sign out?',
                        confirmLabel: 'Sign Out',
                        isDangerous: true,
                      );
                      if (confirmed) {
                        await ref.read(authStateProvider.notifier).logout();
                        if (context.mounted) context.go('/welcome');
                      }
                    },
                  ),
                  _buildSettingsTile(
                    icon: Icons.delete_forever_rounded,
                    title: 'Delete Account',
                    subtitle: 'Permanently delete your account and all data',
                    titleColor: NoxColors.offlineRed,
                    iconColor: NoxColors.offlineRed,
                    onTap: () async {
                      await NoxConfirmDialog.show(
                        context: context,
                        title: 'Delete Account',
                        message: 'This action is permanent and cannot be undone. All your data, devices, and logs will be permanently deleted.',
                        confirmLabel: 'Delete Forever',
                        isDangerous: true,
                      );
                    },
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: NoxSpacing.huge),

            // App info footer
            Center(
              child: Column(
                children: [
                  Text(
                    'NOX',
                    style: NoxTypography.label.copyWith(
                      letterSpacing: 4,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: NoxSpacing.xs),
                  Text(
                    'Version 1.0.0 • Build 1',
                    style: NoxTypography.caption.copyWith(
                      color: NoxColors.dimGray,
                    ),
                  ),
                  const SizedBox(height: NoxSpacing.sm),
                  Text(
                    'Developed by Willaye Haider',
                    style: NoxTypography.caption.copyWith(
                      color: NoxColors.moonlightSilver,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Developer Lobby',
                    style: NoxTypography.caption.copyWith(
                      color: NoxColors.lavenderLight,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: NoxSpacing.xxxl),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    NoxDialog.show(
      context: context,
      dialog: _ChangePasswordDialog(
        onSubmit: (current, next) =>
            ref.read(apiClientProvider).changePassword(current, next),
        onSuccess: () => showNoxSnackBar(context, 'Password changed successfully'),
      ),
    );
  }

  void _showSessionsSheet(BuildContext context) {
    ref.invalidate(sessionsProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: NoxColors.darkSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(NoxSpacing.radiusXl)),
      ),
      builder: (_) => const _SessionsSheet(),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NoxSpacing.md),
      child: Text(
        title.toUpperCase(),
        style: NoxTypography.label.copyWith(
          fontSize: 11,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
    bool isLast = false,
    Color? titleColor,
    Color? iconColor,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
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
                      color: (iconColor ?? NoxColors.lavenderPrimary)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        size: 20,
                        color: iconColor ?? NoxColors.lavenderLight,
                      ),
                    ),
                  ),
                  const SizedBox(width: NoxSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: NoxTypography.subtitle.copyWith(
                            color: titleColor ?? NoxColors.softWhite,
                            fontSize: 14,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle, style: NoxTypography.caption),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    trailing,
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
        if (!isLast)
          const Padding(
            padding: EdgeInsets.only(left: 68),
            child: Divider(height: 0.5, color: NoxColors.glassBorder),
          ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
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
                  child: Icon(icon, size: 20, color: NoxColors.lavenderLight),
                ),
              ),
              const SizedBox(width: NoxSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: NoxTypography.subtitle.copyWith(
                        color: NoxColors.softWhite,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: NoxTypography.caption),
                  ],
                ),
              ),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeThumbColor: NoxColors.lavenderPrimary,
                activeTrackColor: NoxColors.lavenderPrimary.withValues(alpha: 0.3),
                inactiveTrackColor: NoxColors.elevatedSurface,
                inactiveThumbColor: NoxColors.mistGray,
              ),
            ],
          ),
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.only(left: 68),
            child: Divider(height: 0.5, color: NoxColors.glassBorder),
          ),
      ],
    );
  }
}


/// Change-password form: PUT /users/me/password { currentPassword, newPassword }.
class _ChangePasswordDialog extends StatefulWidget {
  final Future<void> Function(String currentPassword, String newPassword) onSubmit;
  final VoidCallback onSuccess;

  const _ChangePasswordDialog({required this.onSubmit, required this.onSuccess});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentController.text;
    final next = _newController.text;

    String? error;
    if (current.isEmpty) {
      error = 'Enter your current password';
    } else if (next.length < 8) {
      error = 'New password must be at least 8 characters';
    } else if (next != _confirmController.text) {
      error = 'New passwords do not match';
    } else if (next == current) {
      error = 'New password must be different from the current one';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(current, next);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = errorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NoxDialog(
      title: 'Change Password',
      showCloseButton: false,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NoxTextField(
            hint: 'Current password',
            controller: _currentController,
            obscureText: true,
            showPasswordToggle: true,
            leadingIcon: Icons.lock_outline_rounded,
            enabled: !_saving,
            autofocus: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: NoxSpacing.md),
          NoxTextField(
            hint: 'New password (min. 8 characters)',
            controller: _newController,
            obscureText: true,
            showPasswordToggle: true,
            leadingIcon: Icons.lock_reset_rounded,
            enabled: !_saving,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: NoxSpacing.md),
          NoxTextField(
            hint: 'Confirm new password',
            controller: _confirmController,
            obscureText: true,
            showPasswordToggle: true,
            leadingIcon: Icons.lock_reset_rounded,
            enabled: !_saving,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: NoxSpacing.md),
            Text(
              _error!,
              style: NoxTypography.bodySmall.copyWith(color: NoxColors.offlineRed),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: NoxSpacing.xxl),
          Row(
            children: [
              Expanded(
                child: NoxButton(
                  label: 'Cancel',
                  variant: NoxButtonVariant.ghost,
                  onPressed: _saving ? null : () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: NoxSpacing.md),
              Expanded(
                child: NoxButton(
                  label: 'Update',
                  isLoading: _saving,
                  onPressed: _saving ? null : _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lists active sessions (GET /auth/sessions) with per-session revoke.
class _SessionsSheet extends ConsumerStatefulWidget {
  const _SessionsSheet();

  @override
  ConsumerState<_SessionsSheet> createState() => _SessionsSheetState();
}

class _SessionsSheetState extends ConsumerState<_SessionsSheet> {
  final Set<String> _revoking = {};

  Future<void> _revoke(UserSession session) async {
    final confirmed = await NoxConfirmDialog.show(
      context: context,
      title: 'Revoke Session',
      message: 'This will sign out ${session.deviceInfo ?? 'this session'}. '
          'If it is this device, you will be signed out once your current access token expires.',
      confirmLabel: 'Revoke',
      isDangerous: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _revoking.add(session.id));
    try {
      // Session revocation not available in backend-project
      showNoxSnackBar(context, 'Session revocation not available');
      ref.invalidate(sessionsProvider);
    } catch (e) {
      if (mounted) showNoxSnackBar(context, errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _revoking.remove(session.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sessionsProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Padding(
          padding: const EdgeInsets.all(NoxSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Active Sessions', style: NoxTypography.h2),
              const SizedBox(height: NoxSpacing.lg),
              Flexible(
                child: sessionsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(NoxSpacing.xxl),
                    child: Center(child: NoxLoadingSpinner()),
                  ),
                  error: (e, _) => NoxErrorState(
                    message: 'Couldn\'t load sessions',
                    details: errorMessage(e),
                    onRetry: () => ref.invalidate(sessionsProvider),
                  ),
                  data: (sessions) => sessions.isEmpty
                      ? Text('No active sessions.', style: NoxTypography.bodySmall)
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: sessions.length,
                          separatorBuilder: (_, __) =>
                              const Divider(color: NoxColors.glassBorder, height: NoxSpacing.xl),
                          itemBuilder: (context, index) {
                            final session = sessions[index];
                            final busy = _revoking.contains(session.id);
                            return Row(
                              children: [
                                const Icon(Icons.devices_rounded,
                                    size: 22, color: NoxColors.lavenderLight),
                                const SizedBox(width: NoxSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        session.deviceInfo ?? 'Unknown device',
                                        style: NoxTypography.subtitle.copyWith(
                                          color: NoxColors.softWhite,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        [
                                          if (session.ipAddress != null) session.ipAddress!,
                                          'Signed in ${timeAgo(session.createdAt)}',
                                        ].join(' • '),
                                        style: NoxTypography.caption,
                                      ),
                                    ],
                                  ),
                                ),
                                busy
                                    ? const NoxLoadingSpinner(size: 20)
                                    : NoxButton(
                                        label: 'Revoke',
                                        variant: NoxButtonVariant.outlined,
                                        height: 32,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        onPressed: () => _revoke(session),
                                      ),
                              ],
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
