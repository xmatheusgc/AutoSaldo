import 'package:flutter/material.dart';

class AppTheme {
  // Paleta de cores corporativa e moderna
  static const Color primaryDark = Color(0xFF0F172A); // Slate 900
  static const Color primaryNavy = Color(0xFF1E293B); // Slate 800
  static const Color accentBlue = Color(0xFF2563EB); // Blue 600
  static const Color accentLight = Color(0xFF3B82F6); // Blue 500

  static const Color successGreen = Color(0xFF059669); // Emerald 600
  static const Color successLight = Color(0xFFD1FAE5); // Emerald 100
  static const Color warningOrange = Color(0xFFD97706); // Amber 600
  static const Color warningLight = Color(0xFFFEF3C7); // Amber 100
  static const Color dangerRed = Color(0xFFDC2626); // Red 600
  static const Color dangerLight = Color(0xFFFEE2E2); // Red 100

  static const Color bgSurface = Color(0xFFF8FAFC); // Slate 50
  static const Color cardSurface = Colors.white;
  static const Color textMain = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B); // Slate 500
  static const Color borderSubtle = Color(0xFFE2E8F0); // Slate 200

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryDark,
        primary: primaryDark,
        secondary: accentBlue,
        surface: bgSurface,
        onSurface: textMain,
        error: dangerRed,
      ),
      scaffoldBackgroundColor: bgSurface,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accentBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: dangerRed),
        ),
        labelStyle: const TextStyle(color: textMuted, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: accentBlue, fontWeight: FontWeight.w600),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textMain,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: borderSubtle),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
