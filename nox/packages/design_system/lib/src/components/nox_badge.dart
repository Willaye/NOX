import 'package:flutter/material.dart';
import '../theme/nox_colors.dart';
import '../theme/nox_typography.dart';
import '../theme/nox_spacing.dart';

enum NoxBadgeVariant { notification, status, label }

/// Badge for notification counts, status indicators, and labels
class NoxBadge extends StatelessWidget {
  final String? text;
  final int? count;
  final NoxBadgeVariant variant;
  final Color? color;
  final Color? textColor;
  final double? size;
  final bool showBorder;
  final Widget? child;

  const NoxBadge({
    super.key,
    this.text,
    this.count,
    this.variant = NoxBadgeVariant.notification,
    this.color,
    this.textColor,
    this.size,
    this.showBorder = true,
    this.child,
  });

  /// Factory for notification count badge overlaid on a widget
  const NoxBadge.count({
    super.key,
    required this.count,
    required this.child,
    this.color,
  })  : text = null,
        variant = NoxBadgeVariant.notification,
        textColor = null,
        size = null,
        showBorder = true;

  /// Factory for status badge
  const NoxBadge.status({
    super.key,
    required this.text,
    this.color = NoxColors.onlineGreen,
  })  : count = null,
        variant = NoxBadgeVariant.status,
        textColor = null,
        size = null,
        showBorder = false,
        child = null;

  /// Factory for label badge
  const NoxBadge.label({
    super.key,
    required this.text,
    this.color = NoxColors.lavenderPrimary,
    this.textColor,
  })  : count = null,
        variant = NoxBadgeVariant.label,
        size = null,
        showBorder = false,
        child = null;

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case NoxBadgeVariant.notification:
        return _buildNotificationBadge();
      case NoxBadgeVariant.status:
        return _buildStatusBadge();
      case NoxBadgeVariant.label:
        return _buildLabelBadge();
    }
  }

  Widget _buildNotificationBadge() {
    final bool hasCount = count != null && count! > 0;
    final String displayText =
        count != null ? (count! > 99 ? '99+' : '$count') : '';

    if (child == null) {
      return _buildBadgeChip(displayText, hasCount);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child!,
        if (hasCount)
          Positioned(
            right: -6,
            top: -6,
            child: _buildBadgeChip(displayText, true),
          ),
      ],
    );
  }

  Widget _buildBadgeChip(String displayText, bool visible) {
    if (!visible) return const SizedBox.shrink();

    final double badgeSize = size ?? (displayText.length > 2 ? 22 : 18);

    return Container(
      constraints: BoxConstraints(
        minWidth: badgeSize,
        minHeight: badgeSize,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: displayText.length > 1 ? 5 : 0,
      ),
      decoration: BoxDecoration(
        color: color ?? NoxColors.offlineRed,
        borderRadius: BorderRadius.circular(NoxSpacing.radiusRound),
        border: showBorder
            ? Border.all(color: NoxColors.voidBlack, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: (color ?? NoxColors.offlineRed).withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          displayText,
          style: NoxTypography.caption.copyWith(
            color: textColor ?? NoxColors.pureWhite,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final badgeColor = color ?? NoxColors.onlineGreen;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: NoxSpacing.sm,
        vertical: NoxSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(NoxSpacing.radiusRound),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: badgeColor,
              boxShadow: [
                BoxShadow(
                  color: badgeColor.withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: NoxSpacing.xs),
          Text(
            text ?? '',
            style: NoxTypography.caption.copyWith(
              color: badgeColor,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelBadge() {
    final badgeColor = color ?? NoxColors.lavenderPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: NoxSpacing.md,
        vertical: NoxSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(NoxSpacing.radiusRound),
      ),
      child: Text(
        text?.toUpperCase() ?? '',
        style: NoxTypography.label.copyWith(
          color: textColor ?? badgeColor,
          fontSize: 10,
        ),
      ),
    );
  }
}
