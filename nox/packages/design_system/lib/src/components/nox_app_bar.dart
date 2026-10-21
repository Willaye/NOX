import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/nox_colors.dart';
import '../theme/nox_typography.dart';
import '../theme/nox_spacing.dart';

/// Glass-style app bar with transparent background and blur
class NoxAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final bool showBorder;
  final double height;
  final Color? backgroundColor;

  const NoxAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.showBackButton = false,
    this.onBackPressed,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.showBorder = true,
    this.height = 56,
    this.backgroundColor,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor ??
                NoxColors.voidBlack.withValues(alpha: 0.7),
            border: showBorder
                ? const Border(
                    bottom: BorderSide(
                      color: NoxColors.glassBorder,
                      width: 0.5,
                    ),
                  )
                : null,
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: NoxSpacing.sm,
                ),
                child: Row(
                  children: [
                    // Leading / Back button
                    if (leading != null)
                      leading!
                    else if (showBackButton)
                      _buildBackButton(context),

                    if (showBackButton || leading != null)
                      const SizedBox(width: NoxSpacing.sm),

                    // Title
                    Expanded(
                      child: centerTitle
                          ? Center(child: _buildTitle())
                          : _buildTitle(),
                    ),

                    // Actions
                    if (actions != null) ...actions!,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    if (titleWidget != null) return titleWidget!;
    if (title != null) {
      return Text(
        title!,
        style: NoxTypography.h3.copyWith(color: NoxColors.pureWhite),
        overflow: TextOverflow.ellipsis,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildBackButton(BuildContext context) {
    return GestureDetector(
      onTap: onBackPressed ?? () => Navigator.of(context).maybePop(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: NoxColors.glassWhite,
          shape: BoxShape.circle,
          border: Border.all(color: NoxColors.glassBorder, width: 0.5),
        ),
        child: const Center(
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: NoxColors.softWhite,
          ),
        ),
      ),
    );
  }
}
