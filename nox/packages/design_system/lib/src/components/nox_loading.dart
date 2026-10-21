import 'package:flutter/material.dart';
import '../theme/nox_colors.dart';
import '../theme/nox_spacing.dart';
import '../theme/nox_typography.dart';

/// Animated loading spinner with lavender gradient arc
class NoxLoadingSpinner extends StatefulWidget {
  final double size;
  final double strokeWidth;
  final Color? color;
  final String? message;

  const NoxLoadingSpinner({
    super.key,
    this.size = 40,
    this.strokeWidth = 3,
    this.color,
    this.message,
  });

  @override
  State<NoxLoadingSpinner> createState() => _NoxLoadingSpinnerState();
}

class _NoxLoadingSpinnerState extends State<NoxLoadingSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.rotate(
              angle: _controller.value * 6.2832, // 2π
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      (widget.color ?? NoxColors.lavenderPrimary)
                          .withValues(alpha: 0.0),
                      widget.color ?? NoxColors.lavenderPrimary,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: widget.size - (widget.strokeWidth * 2),
                    height: widget.size - (widget.strokeWidth * 2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: NoxColors.voidBlack,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (widget.message != null) ...[
          const SizedBox(height: NoxSpacing.md),
          Text(
            widget.message!,
            style: NoxTypography.bodySmall.copyWith(
              color: NoxColors.mistGray,
            ),
          ),
        ],
      ],
    );
  }
}

/// Skeleton loader placeholder with shimmer animation
class NoxSkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final bool isCircle;

  const NoxSkeletonLoader({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = NoxSpacing.radiusSm,
    this.isCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    return NoxShimmer(
      child: Container(
        width: width,
        height: isCircle ? width : height,
        decoration: BoxDecoration(
          color: NoxColors.elevatedSurface,
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius:
              isCircle ? null : BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Shimmer animation effect wrapper
class NoxShimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Color baseColor;
  final Color highlightColor;

  const NoxShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.baseColor = NoxColors.elevatedSurface,
    this.highlightColor = const Color(0xFF2A2A55),
  });

  @override
  State<NoxShimmer> createState() => _NoxShimmerState();
}

class _NoxShimmerState extends State<NoxShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: [
                0.0,
                (_animation.value + 2) / 4, // Normalize to 0..1
                1.0,
              ],
              transform: _SlidingGradientTransform(
                slidePercent: _animation.value,
              ),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}
