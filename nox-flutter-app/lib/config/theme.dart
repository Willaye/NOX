import 'package:flutter/material.dart';

class NoxTheme {
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color surfaceLight = Color(0xFF252525);
  static const Color accent = Color(0xFF00E5FF);
  static const Color accentDark = Color(0xFF00B8D4);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF888888);
  static const Color success = Color(0xFF00C853);
  static const Color danger = Color(0xFFFF1744);
  static const Color warning = Color(0xFFFFC107);

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        primaryColor: accent,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          secondary: accentDark,
          surface: surface,
          error: danger,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: surface,
          foregroundColor: textPrimary,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: surface,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: background,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: accent, width: 2),
          ),
          hintStyle: const TextStyle(color: textSecondary),
          labelStyle: const TextStyle(color: textSecondary),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: textPrimary,
            letterSpacing: 8,
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
          bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
          bodyMedium: TextStyle(fontSize: 14, color: textSecondary),
          labelLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
      );
}
