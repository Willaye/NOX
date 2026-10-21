import 'package:flutter/material.dart';
import '../theme/nox_colors.dart';
import '../theme/nox_typography.dart';
import 'nox_status_indicator.dart';

/// Avatar with image/initials, optional status dot, and gradient border
class NoxAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? initials;
  final double size;
  final NoxDeviceStatus? status;
  final bool showGradientBorder;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const NoxAvatar({
    super.key,
    this.imageUrl,
    this.initials,
    this.size = 44,
    this.status,
    this.showGradientBorder = false,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size + (showGradientBorder ? 6 : 0),
        height: size + (showGradientBorder ? 6 : 0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Gradient border wrapper
            if (showGradientBorder)
              Container(
                width: size + 6,
                height: size + 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: NoxColors.primaryGradient,
                ),
                padding: const EdgeInsets.all(2),
                child: _buildAvatarContent(),
              )
            else
              _buildAvatarContent(),

            // Status dot
            if (status != null)
              Positioned(
                right: showGradientBorder ? 2 : 0,
                bottom: showGradientBorder ? 2 : 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: NoxColors.voidBlack,
                    shape: BoxShape.circle,
                  ),
                  child: NoxStatusDot(
                    status: status!,
                    size: size * 0.2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarContent() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? NoxColors.elevatedSurface,
        border: showGradientBorder
            ? null
            : Border.all(color: NoxColors.glassBorder, width: 0.5),
        image: imageUrl != null
            ? DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: imageUrl == null
          ? Center(
              child: Text(
                _getInitials(),
                style: NoxTypography.button.copyWith(
                  fontSize: size * 0.35,
                  color: NoxColors.lavenderLight,
                ),
              ),
            )
          : null,
    );
  }

  String _getInitials() {
    if (initials != null && initials!.isNotEmpty) {
      return initials!.substring(0, initials!.length.clamp(0, 2)).toUpperCase();
    }
    return '?';
  }
}
