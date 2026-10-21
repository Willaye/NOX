import 'package:flutter/material.dart';
import '../theme/nox_colors.dart';
import '../theme/nox_typography.dart';
import '../theme/nox_spacing.dart';

enum NoxButtonVariant { primary, secondary, outlined, ghost }

class NoxButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final NoxButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool isExpanded;
  final double? width;
  final double height;
  final EdgeInsets? padding;

  const NoxButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = NoxButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isExpanded = false,
    this.width,
    this.height = 48,
    this.padding,
  });

  @override
  State<NoxButton> createState() => _NoxButtonState();
}

class _NoxButtonState extends State<NoxButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = widget.onPressed == null || widget.isLoading;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: widget.isExpanded ? double.infinity : widget.width,
          height: widget.height,
          decoration: _buildDecoration(isDisabled),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isDisabled ? null : widget.onPressed,
              borderRadius: BorderRadius.circular(NoxSpacing.radiusMd),
              splashColor: NoxColors.lavenderGlow,
              highlightColor: NoxColors.glassHighlight,
              child: Padding(
                padding: widget.padding ??
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Center(child: _buildContent(isDisabled)),
              ),
            ),
          ),
        );
      },
    );
  }

  BoxDecoration _buildDecoration(bool isDisabled) {
    final double glowValue = _glowAnimation.value;

    switch (widget.variant) {
      case NoxButtonVariant.primary:
        return BoxDecoration(
          gradient: isDisabled ? null : NoxColors.primaryGradient,
          color: isDisabled ? NoxColors.dimGray.withValues(alpha: 0.3) : null,
          borderRadius: BorderRadius.circular(NoxSpacing.radiusMd),
          boxShadow: isDisabled
              ? null
              : [
                  BoxShadow(
                    color: NoxColors.lavenderPrimary
                        .withValues(alpha: 0.3 + (glowValue * 0.2)),
                    blurRadius: 12 + (glowValue * 8),
                    offset: const Offset(0, 4),
                  ),
                ],
        );
      case NoxButtonVariant.secondary:
        return BoxDecoration(
          color: isDisabled
              ? NoxColors.dimGray.withValues(alpha: 0.2)
              : NoxColors.elevatedSurface,
          borderRadius: BorderRadius.circular(NoxSpacing.radiusMd),
          border: Border.all(color: NoxColors.glassBorder, width: 0.5),
        );
      case NoxButtonVariant.outlined:
        return BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(NoxSpacing.radiusMd),
          border: Border.all(
            color: isDisabled ? NoxColors.dimGray : NoxColors.lavenderPrimary,
            width: 1.5,
          ),
        );
      case NoxButtonVariant.ghost:
        return BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(NoxSpacing.radiusMd),
        );
    }
  }

  Widget _buildContent(bool isDisabled) {
    if (widget.isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(NoxColors.pureWhite),
        ),
      );
    }

    final Color textColor = _getTextColor(isDisabled);
    final List<Widget> children = [];

    if (widget.icon != null) {
      children.add(Icon(widget.icon, size: 18, color: textColor));
      children.add(const SizedBox(width: 8));
    }

    children.add(
      Text(
        widget.label,
        style: NoxTypography.button.copyWith(color: textColor),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }

  Color _getTextColor(bool isDisabled) {
    if (isDisabled) return NoxColors.dimGray;

    switch (widget.variant) {
      case NoxButtonVariant.primary:
        return NoxColors.pureWhite;
      case NoxButtonVariant.secondary:
        return NoxColors.softWhite;
      case NoxButtonVariant.outlined:
        return NoxColors.lavenderPrimary;
      case NoxButtonVariant.ghost:
        return NoxColors.lavenderLight;
    }
  }
}

/// Circular icon button with optional gradient background and glow
class NoxIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final Color? backgroundColor;
  final bool showGradient;
  final bool showGlow;
  final String? tooltip;

  const NoxIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 40,
    this.color,
    this.backgroundColor,
    this.showGradient = false,
    this.showGlow = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    Widget button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: showGradient ? NoxColors.primaryGradient : null,
        color: showGradient
            ? null
            : (backgroundColor ?? NoxColors.glassWhite),
        shape: BoxShape.circle,
        border: Border.all(color: NoxColors.glassBorder, width: 0.5),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: NoxColors.lavenderPrimary.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          splashColor: NoxColors.lavenderGlow,
          child: Center(
            child: Icon(
              icon,
              size: size * 0.5,
              color: color ?? NoxColors.softWhite,
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}
