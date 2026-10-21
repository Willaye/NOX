import 'package:flutter/material.dart';
import 'nox_colors.dart';
import 'nox_typography.dart';
import 'nox_spacing.dart';

class NoxTheme {
  NoxTheme._();

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    fontFamily: NoxTypography.fontFamily,
    scaffoldBackgroundColor: NoxColors.voidBlack,
    colorScheme: const ColorScheme.dark(
      primary: NoxColors.lavenderPrimary,
      onPrimary: NoxColors.pureWhite,
      secondary: NoxColors.icyBlue,
      onSecondary: NoxColors.voidBlack,
      surface: NoxColors.darkSurface,
      onSurface: NoxColors.softWhite,
      error: NoxColors.offlineRed,
      onError: NoxColors.pureWhite,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: NoxTypography.fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: NoxColors.pureWhite,
      ),
      iconTheme: IconThemeData(color: NoxColors.softWhite),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: NoxColors.deepAbyss,
      selectedItemColor: NoxColors.lavenderPrimary,
      unselectedItemColor: NoxColors.dimGray,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: NoxColors.cardSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NoxSpacing.radiusLg),
        side: const BorderSide(color: NoxColors.glassBorder, width: 0.5),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: NoxColors.darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NoxSpacing.radiusMd),
        borderSide: const BorderSide(color: NoxColors.glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NoxSpacing.radiusMd),
        borderSide: const BorderSide(color: NoxColors.glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NoxSpacing.radiusMd),
        borderSide: const BorderSide(color: NoxColors.lavenderPrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NoxSpacing.radiusMd),
        borderSide: const BorderSide(color: NoxColors.offlineRed),
      ),
      hintStyle: NoxTypography.body.copyWith(color: NoxColors.dimGray),
      labelStyle: NoxTypography.bodySmall.copyWith(color: NoxColors.mistGray),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    dividerTheme: const DividerThemeData(
      color: NoxColors.glassBorder,
      thickness: 0.5,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: NoxColors.elevatedSurface,
      contentTextStyle: NoxTypography.body,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NoxSpacing.radiusMd),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
