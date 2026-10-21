import 'package:flutter/material.dart';
import '../theme/nox_colors.dart';
import '../theme/nox_typography.dart';
import '../theme/nox_spacing.dart';
import 'nox_button.dart';

/// Empty state placeholder with icon, title, subtitle, and optional action
class NoxEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double iconSize;
  final Color? iconColor;

  const NoxEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconSize = 64,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NoxSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glowing icon container
            Container(
              width: iconSize + 32,
              height: iconSize + 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: NoxColors.elevatedSurface.withValues(alpha: 0.5),
                border: Border.all(
                  color: NoxColors.glassBorder,
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (iconColor ?? NoxColors.lavenderPrimary)
                        .withValues(alpha: 0.1),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: iconSize,
                  color: iconColor ?? NoxColors.dimGray,
                ),
              ),
            ),
            const SizedBox(height: NoxSpacing.xxl),
            Text(
              title,
              style: NoxTypography.h3.copyWith(color: NoxColors.softWhite),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: NoxSpacing.sm),
              Text(
                subtitle!,
                style: NoxTypography.body.copyWith(color: NoxColors.mistGray),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: NoxSpacing.xxl),
              NoxButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: NoxButtonVariant.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
