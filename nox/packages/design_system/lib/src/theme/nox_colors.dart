import 'package:flutter/material.dart';

/// NOX ethereal color palette
/// Deep midnight backgrounds with lavender/purple accents and soft glows
class NoxColors {
  NoxColors._();

  // ── Backgrounds ────────────────────────────────────────────
  static const Color voidBlack = Color(0xFF060610);
  static const Color deepAbyss = Color(0xFF0C0C1E);
  static const Color midnightNavy = Color(0xFF111128);
  static const Color darkSurface = Color(0xFF161633);
  static const Color elevatedSurface = Color(0xFF1C1C40);
  static const Color cardSurface = Color(0xFF1E1E45);

  // ── Text ───────────────────────────────────────────────────
  static const Color pureWhite = Color(0xFFFAFAFF);
  static const Color softWhite = Color(0xFFE8E8F0);
  static const Color moonlightSilver = Color(0xFFB0B0C8);
  static const Color mistGray = Color(0xFF7070A0);
  static const Color dimGray = Color(0xFF4A4A78);

  // ── Primary Accent (Lavender/Purple) ───────────────────────
  static const Color lavenderPrimary = Color(0xFF7B68EE);
  static const Color lavenderLight = Color(0xFF9B8AFF);
  static const Color lavenderDark = Color(0xFF5B48CE);
  static const Color lavenderMuted = Color(0xFF3D3580);
  static const Color lavenderGlow = Color(0x407B68EE);

  // ── Secondary Accent (Soft Pink/Peach) ─────────────────────
  static const Color peachAccent = Color(0xFFFF9B9B);
  static const Color pinkSoft = Color(0xFFFF7EB3);
  static const Color roseGold = Color(0xFFE8A0BF);

  // ── Tertiary Accent (Icy Blue) ─────────────────────────────
  static const Color icyBlue = Color(0xFF00D4FF);
  static const Color cyanGlow = Color(0xFF00E5FF);
  static const Color frostedBlue = Color(0xFF80E8FF);

  // ── Status ─────────────────────────────────────────────────
  static const Color onlineGreen = Color(0xFF00E676);
  static const Color offlineRed = Color(0xFFFF5252);
  static const Color warningAmber = Color(0xFFFFD740);
  static const Color infoBlue = Color(0xFF448AFF);

  // ── Glassmorphism ──────────────────────────────────────────
  static const Color glassWhite = Color(0x14FFFFFF);
  static const Color glassBorder = Color(0x28FFFFFF);
  static const Color glassHighlight = Color(0x0AFFFFFF);

  // ── Gradients ──────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [lavenderPrimary, Color(0xFF9B6BFF), pinkSoft],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [darkSurface, midnightNavy],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [icyBlue, lavenderPrimary, pinkSoft],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1E1E48), Color(0xFF16163A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
