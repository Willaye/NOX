import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/nox_colors.dart';
import '../theme/nox_spacing.dart';

enum NoxCardVariant { glass, elevated, gradient }

class NoxCard extends StatelessWidget {
  final Widget child;
  final NoxCardVariant variant;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final double borderRadius;
  final Color? borderColor;

  const NoxCard({
    super.key,
    required this.child,
    this.variant = NoxCardVariant.glass,
    this.padding,
    this.margin,
    this.onTap,
    this.width,
    this.height,
    this.borderRadius = NoxSpacing.radiusLg,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: _buildCard(),
    );
  }

  Widget _buildCard() {
    switch (variant) {
      case NoxCardVariant.glass:
        return _buildGlassCard();
      case NoxCardVariant.elevated:
        return _buildElevatedCard();
      case NoxCardVariant.gradient:
        return _buildGradientCard();
    }
  }

  Widget _buildGlassCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: NoxColors.glassWhite,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? NoxColors.glassBorder,
              width: 0.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(borderRadius),
              splashColor: NoxColors.lavenderGlow,
              highlightColor: NoxColors.glassHighlight,
              child: Padding(
                padding: padding ??
                    const EdgeInsets.all(NoxSpacing.lg),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildElevatedCard() {
    return Container(
      decoration: BoxDecoration(
        color: NoxColors.cardSurface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? NoxColors.glassBorder,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: NoxColors.lavenderGlow.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: NoxColors.lavenderGlow,
          highlightColor: NoxColors.glassHighlight,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(NoxSpacing.lg),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildGradientCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: NoxColors.cardGradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? NoxColors.glassBorder,
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: NoxColors.lavenderGlow,
          highlightColor: NoxColors.glassHighlight,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(NoxSpacing.lg),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Convenience wrapper for a glass-morphism styled card
class NoxGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final double blurAmount;
  final Color? tintColor;
  final double borderRadius;

  const NoxGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.width,
    this.height,
    this.blurAmount = 16,
    this.tintColor,
    this.borderRadius = NoxSpacing.radiusLg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
          child: Container(
            decoration: BoxDecoration(
              color: tintColor ?? NoxColors.glassWhite,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: NoxColors.glassBorder, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(borderRadius),
                splashColor: NoxColors.lavenderGlow,
                child: Padding(
                  padding: padding ?? const EdgeInsets.all(NoxSpacing.lg),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
