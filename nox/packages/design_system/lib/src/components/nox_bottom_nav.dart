import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/nox_colors.dart';
import '../theme/nox_typography.dart';
import '../theme/nox_spacing.dart';

/// Bottom navigation item data
class NoxNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  const NoxNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
  });
}

/// Glass-style bottom navigation bar with glow on selected item
class NoxBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NoxNavItem> items;

  const NoxBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.items = const [
      NoxNavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home',
      ),
      NoxNavItem(
        icon: Icons.devices_outlined,
        activeIcon: Icons.devices_rounded,
        label: 'Devices',
      ),
      NoxNavItem(
        icon: Icons.folder_outlined,
        activeIcon: Icons.folder_rounded,
        label: 'Files',
      ),
      NoxNavItem(
        icon: Icons.more_horiz_outlined,
        activeIcon: Icons.more_horiz_rounded,
        label: 'More',
      ),
    ],
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: NoxColors.deepAbyss.withValues(alpha: 0.85),
            border: const Border(
              top: BorderSide(color: NoxColors.glassBorder, width: 0.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: NoxSpacing.sm,
                vertical: NoxSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(
                  items.length,
                  (index) => _NoxNavItemWidget(
                    item: items[index],
                    isSelected: index == currentIndex,
                    onTap: () => onTap(index),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoxNavItemWidget extends StatelessWidget {
  final NoxNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NoxNavItemWidget({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color color =
        isSelected ? NoxColors.lavenderPrimary : NoxColors.dimGray;
    final IconData icon =
        isSelected ? (item.activeIcon ?? item.icon) : item.icon;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(
          horizontal: NoxSpacing.md,
          vertical: NoxSpacing.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(NoxSpacing.radiusMd),
          color: isSelected
              ? NoxColors.lavenderPrimary.withValues(alpha: 0.1)
              : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 24, color: color),
                  // Glow behind selected icon
                  if (isSelected)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: NoxColors.lavenderPrimary
                                  .withValues(alpha: 0.5),
                              blurRadius: 16,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: NoxSpacing.xs),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: NoxTypography.caption.copyWith(
                color: color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: isSelected ? 11 : 10,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}
