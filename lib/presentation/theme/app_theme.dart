import 'package:flutter/material.dart';

class AppTheme {
  // Paleta moderna com contraste WCAG AA (>= 4.5:1) em texto e >= 3:1 em bordas interativas
  static const Color primaryDark = Color(0xFF0F172A); // Slate 900
  static const Color primaryNavy = Color(0xFF1E293B); // Slate 800
  static const Color accentBlue = Color(0xFF2563EB); // Blue 600
  static const Color accentLight = Color(0xFF3B82F6); // Blue 500
  static const Color accentSoft = Color(0xFFEFF6FF); // Blue 50

  static const Color successGreen = Color(0xFF047857); // Emerald 700
  static const Color successLight = Color(0xFFECFDF5); // Emerald 50
  static const Color successBorder = Color(0xFFA7F3D0); // Emerald 200

  static const Color warningOrange = Color(0xFFB45309); // Amber 700
  static const Color warningLight = Color(0xFFFFFBEB); // Amber 50
  static const Color warningBorder = Color(0xFFFDE68A); // Amber 200

  static const Color dangerRed = Color(0xFFB91C1C); // Red 700
  static const Color dangerLight = Color(0xFFFEF2F2); // Red 50
  static const Color dangerBorder = Color(0xFFFECACA); // Red 200

  static const Color bgSurface = Colors.white;
  static const Color desktopBg = Color(0xFFF8FAFC);
  static const Color sectionDivider = Color(0xFFF1F5F9);
  static const Color cardSurface = Colors.white;
  static const Color textMain = Color(0xFF0F172A); // Slate 900
  static const Color textMuted = Color(0xFF475569); // Slate 600 (>= 6.3:1 em bgSurface)
  static const Color textLight = Color(0xFF475569); // Elevado de Slate 500 p/ AA em superfícies claras
  static const Color borderSubtle = Color(0xFFE2E8F0); // Slate 200 (cards e divisores)
  static const Color borderInteractive = Color(0xFF7B8CA3); // Contraste >= 3.0:1 para inputs/botões

  static const List<FontFeature> tabularNumbers = [FontFeature.tabularFigures()];

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentBlue,
        primary: primaryDark,
        secondary: accentBlue,
        surface: bgSurface,
        onSurface: textMain,
        error: dangerRed,
      ),
      scaffoldBackgroundColor: bgSurface,
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: primaryDark,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: primaryDark),
      ),
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderInteractive),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderInteractive),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dangerRed),
        ),
        labelStyle: const TextStyle(color: textMuted, fontSize: 14),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
          if (states.contains(WidgetState.error)) {
            return const TextStyle(color: dangerRed, fontWeight: FontWeight.w700);
          }
          if (states.contains(WidgetState.focused)) {
            return const TextStyle(color: accentBlue, fontWeight: FontWeight.w700);
          }
          return const TextStyle(color: textMuted, fontWeight: FontWeight.w600);
        }),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderSubtle),
        ),
        textStyle: const TextStyle(
          color: textMain,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          minimumSize: const Size(88, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textMain,
          minimumSize: const Size(88, 48),
          side: const BorderSide(color: borderInteractive, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 60,
        indicatorColor: sectionDivider,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textMain,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: textMain, size: 22);
          }
          return const IconThemeData(color: textMuted, size: 22);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
