import 'package:flutter/material.dart';

abstract final class TavoPalette {
  static const ink = Color(0xFF050817);
  static const midnight = Color(0xFF081126);
  static const navy = Color(0xFF0D1B38);
  static const panel = Color(0xFF101D3A);
  static const panelSoft = Color(0xFF15264A);
  static const line = Color(0x334E79C7);
  static const moon = Color(0xFFF6F4FF);
  static const cyan = Color(0xFF88E9FF);
  static const blue = Color(0xFF6E8DFF);
  static const violet = Color(0xFFA886FF);
  static const sakura = Color(0xFFFFB7E6);
  static const gold = Color(0xFFFFD79B);
  static const jade = Color(0xFF7AF0C7);
  static const text = Color(0xFFF7F7FF);
  static const muted = Color(0xFFA9B4D0);
  static const danger = Color(0xFFFF7E96);
}

abstract final class TavoTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: TavoPalette.violet,
      brightness: Brightness.dark,
      surface: TavoPalette.panel,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: scheme.copyWith(
        primary: TavoPalette.blue,
        secondary: TavoPalette.violet,
        tertiary: TavoPalette.gold,
        surface: TavoPalette.panel,
        error: TavoPalette.danger,
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          color: TavoPalette.text,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.3,
        ),
        headlineSmall: TextStyle(
          color: TavoPalette.text,
          fontWeight: FontWeight.w800,
          letterSpacing: -.6,
        ),
        titleLarge: TextStyle(color: TavoPalette.text, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(color: TavoPalette.text, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: TavoPalette.text, height: 1.52),
        bodyMedium: TextStyle(color: TavoPalette.text, height: 1.48),
        bodySmall: TextStyle(color: TavoPalette.muted, height: 1.42),
      ),
      dividerColor: TavoPalette.line,
      navigationBarTheme: const NavigationBarThemeData(
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xAA0D1933),
        labelStyle: const TextStyle(color: TavoPalette.muted),
        hintStyle: TextStyle(color: TavoPalette.muted.withValues(alpha: .65)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: TavoPalette.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: TavoPalette.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: TavoPalette.cyan, width: 1.35),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          backgroundColor: TavoPalette.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: TavoPalette.panelSoft,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
