import 'package:flutter/material.dart';
import 'nox_colors.dart';

class NoxTypography {
  NoxTypography._();

  static const String fontFamily = 'Inter';

  static TextStyle heroTitle = const TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: NoxColors.pureWhite,
    height: 1.2,
  );

  static TextStyle h1 = const TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: NoxColors.pureWhite,
  );

  static TextStyle h2 = const TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: NoxColors.softWhite,
  );

  static TextStyle h3 = const TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: NoxColors.softWhite,
  );

  static TextStyle subtitle = const TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: NoxColors.moonlightSilver,
  );

  static TextStyle body = const TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: NoxColors.moonlightSilver,
    height: 1.5,
  );

  static TextStyle bodySmall = const TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: NoxColors.mistGray,
  );

  static TextStyle caption = const TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: NoxColors.dimGray,
    letterSpacing: 0.5,
  );

  static TextStyle button = const TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: NoxColors.pureWhite,
  );

  static TextStyle label = const TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.2,
    color: NoxColors.lavenderPrimary,
  );
}
