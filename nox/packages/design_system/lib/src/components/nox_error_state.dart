import 'package:flutter/material.dart';
import '../theme/nox_colors.dart';
import '../theme/nox_typography.dart';
import '../theme/nox_spacing.dart';
import 'nox_button.dart';

/// Error state widget with icon, message, and retry button
class NoxErrorState extends StatelessWidget {
  final String message;
  final String? details;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;
  final double iconSize;

  const NoxErrorState({
    super.key,
    this.message = 'Something went wrong',
    this.details,
    this.onRetry,
    this.retryLabel = 'Retry',
    this.icon = Icons.error_outline_rounded,
    this.iconSize = 56,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NoxSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error icon with red glow
            Container(
              width: iconSize + 28,
              height: iconSize + 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: NoxColors.offlineRed.withValues(alpha: 0.08),
                border: Border.all(
                  color: NoxColors.offlineRed.withValues(alpha: 0.2),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: NoxColors.offlineRed.withValues(alpha: 0.15),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: iconSize,
                  color: NoxColors.offlineRed.withValues(alpha: 0.8),
                ),
              ),
            ),
            const SizedBox(height: NoxSpacing.xxl),
            Text(
              message,
              style: NoxTypography.h3.copyWith(color: NoxColors.softWhite),
              textAlign: TextAlign.center,
            ),
            if (details != null) ...[
              const SizedBox(height: NoxSpacing.sm),
              Text(
                details!,
                style: NoxTypography.body.copyWith(color: NoxColors.mistGray),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: NoxSpacing.xxl),
              NoxButton(
                label: retryLabel,
                onPressed: onRetry,
                variant: NoxButtonVariant.outlined,
                icon: Icons.refresh_rounded,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
