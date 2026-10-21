import 'package:flutter/material.dart';
import '../theme/nox_colors.dart';
import '../theme/nox_typography.dart';
import '../theme/nox_spacing.dart';

enum NoxDeviceStatus { online, offline, warning, idle }

/// Animated status dot with pulse effect for online state
class NoxStatusDot extends StatefulWidget {
  final NoxDeviceStatus status;
  final double size;
  final bool showLabel;
  final bool animate;

  const NoxStatusDot({
    super.key,
    required this.status,
    this.size = 10,
    this.showLabel = false,
    this.animate = true,
  });

  @override
  State<NoxStatusDot> createState() => _NoxStatusDotState();
}

class _NoxStatusDotState extends State<NoxStatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.animate && widget.status == NoxDeviceStatus.online) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(NoxStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == NoxDeviceStatus.online && widget.animate) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color get _statusColor {
    switch (widget.status) {
      case NoxDeviceStatus.online:
        return NoxColors.onlineGreen;
      case NoxDeviceStatus.offline:
        return NoxColors.offlineRed;
      case NoxDeviceStatus.warning:
        return NoxColors.warningAmber;
      case NoxDeviceStatus.idle:
        return NoxColors.mistGray;
    }
  }

  String get _statusLabel {
    switch (widget.status) {
      case NoxDeviceStatus.online:
        return 'Online';
      case NoxDeviceStatus.offline:
        return 'Offline';
      case NoxDeviceStatus.warning:
        return 'Warning';
      case NoxDeviceStatus.idle:
        return 'Idle';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dot = AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final double pulse = _pulseAnimation.value;
        return Container(
          width: widget.size + (pulse * 6),
          height: widget.size + (pulse * 6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _statusColor,
            boxShadow: [
              BoxShadow(
                color: _statusColor.withValues(alpha: 0.4 + (pulse * 0.3)),
                blurRadius: 6 + (pulse * 8),
                spreadRadius: pulse * 2,
              ),
            ],
          ),
        );
      },
    );

    if (!widget.showLabel) {
      return SizedBox(
        width: widget.size + 6,
        height: widget.size + 6,
        child: Center(child: dot),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size + 6,
          height: widget.size + 6,
          child: Center(child: dot),
        ),
        const SizedBox(width: NoxSpacing.sm),
        Text(
          _statusLabel,
          style: NoxTypography.bodySmall.copyWith(color: _statusColor),
        ),
      ],
    );
  }
}

/// Battery level indicator with colored fill and optional percentage
class NoxBatteryIndicator extends StatelessWidget {
  final int level; // 0–100
  final double width;
  final double height;
  final bool showPercentage;

  const NoxBatteryIndicator({
    super.key,
    required this.level,
    this.width = 28,
    this.height = 14,
    this.showPercentage = true,
  });

  Color get _fillColor {
    if (level > 60) return NoxColors.onlineGreen;
    if (level > 20) return NoxColors.warningAmber;
    return NoxColors.offlineRed;
  }

  @override
  Widget build(BuildContext context) {
    final clampedLevel = level.clamp(0, 100);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Battery body
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: NoxColors.mistGray, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(1.5),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: clampedLevel / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: _fillColor,
                  borderRadius: BorderRadius.circular(1.5),
                  boxShadow: [
                    BoxShadow(
                      color: _fillColor.withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Battery tip
        Container(
          width: 2,
          height: height * 0.5,
          margin: const EdgeInsets.only(left: 1),
          decoration: BoxDecoration(
            color: NoxColors.mistGray,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(1),
            ),
          ),
        ),
        if (showPercentage) ...[
          const SizedBox(width: NoxSpacing.xs),
          Text(
            '$clampedLevel%',
            style: NoxTypography.caption.copyWith(
              color: _fillColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
