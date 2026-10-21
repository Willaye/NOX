import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/nox_colors.dart';
import '../theme/nox_typography.dart';
import '../theme/nox_spacing.dart';
import 'nox_button.dart';

/// Glass-styled dialog with title, content, and actions
class NoxDialog extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget content;
  final List<Widget>? actions;
  final EdgeInsets? contentPadding;
  final double maxWidth;
  final bool showCloseButton;

  const NoxDialog({
    super.key,
    this.title,
    this.titleWidget,
    required this.content,
    this.actions,
    this.contentPadding,
    this.maxWidth = 340,
    this.showCloseButton = true,
  });

  /// Show the dialog using the Flutter dialog API
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget dialog,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => dialog,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(NoxSpacing.radiusXl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: NoxColors.darkSurface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(NoxSpacing.radiusXl),
                border: Border.all(
                  color: NoxColors.glassBorder,
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 32,
                    offset: const Offset(0, 16),
                  ),
                  BoxShadow(
                    color: NoxColors.lavenderGlow.withValues(alpha: 0.1),
                    blurRadius: 48,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: contentPadding ??
                      const EdgeInsets.all(NoxSpacing.xxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      if (title != null ||
                          titleWidget != null ||
                          showCloseButton)
                        _buildHeader(context),

                      // Content
                      content,

                      // Actions
                      if (actions != null && actions!.isNotEmpty) ...[
                        const SizedBox(height: NoxSpacing.xxl),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: actions!
                              .map((action) => Padding(
                                    padding: const EdgeInsets.only(
                                        left: NoxSpacing.sm),
                                    child: action,
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NoxSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: titleWidget ??
                (title != null
                    ? Text(title!, style: NoxTypography.h3)
                    : const SizedBox.shrink()),
          ),
          if (showCloseButton)
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: NoxColors.glassWhite,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: NoxColors.glassBorder, width: 0.5),
                ),
                child: const Center(
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: NoxColors.mistGray,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Confirmation dialog with title, message, confirm/cancel buttons
class NoxConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final Color? confirmColor;
  final bool isDangerous;

  const NoxConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.onConfirm,
    this.onCancel,
    this.confirmColor,
    this.isDangerous = false,
  });

  /// Convenience method to show and await confirmation result
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDangerous = false,
  }) async {
    final result = await NoxDialog.show<bool>(
      context: context,
      dialog: NoxConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDangerous: isDangerous,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final Color actionColor = isDangerous
        ? NoxColors.offlineRed
        : (confirmColor ?? NoxColors.lavenderPrimary);

    return NoxDialog(
      title: title,
      showCloseButton: false,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: NoxTypography.body.copyWith(color: NoxColors.moonlightSilver),
          ),
          const SizedBox(height: NoxSpacing.xxl),
          Row(
            children: [
              Expanded(
                child: NoxButton(
                  label: cancelLabel,
                  variant: NoxButtonVariant.ghost,
                  onPressed: onCancel ?? () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: NoxSpacing.md),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: isDangerous
                        ? null
                        : NoxColors.primaryGradient,
                    color: isDangerous ? actionColor : null,
                    borderRadius:
                        BorderRadius.circular(NoxSpacing.radiusMd),
                    boxShadow: [
                      BoxShadow(
                        color: actionColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onConfirm ??
                          () => Navigator.of(context).pop(true),
                      borderRadius:
                          BorderRadius.circular(NoxSpacing.radiusMd),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        child: Center(
                          child: Text(
                            confirmLabel,
                            style: NoxTypography.button,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
