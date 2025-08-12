import 'package:flutter/material.dart';

/// PUBLIC_INTERFACE
class AppTheme {
  /// Returns the light theme adhering to the provided palette.
  ///
  /// Palette:
  /// - primary: #1976D2
  /// - secondary: #424242
  /// - accent: #FFC107
  static ThemeData light() {
    const primary = Color(0xFF1976D2);
    const secondary = Color(0xFF424242);
    const accent = Color(0xFFFFC107);

    final base = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: Colors.white,
        onSurface: Colors.black87,
        tertiary: accent,
      ),
      scaffoldBackgroundColor: const Color(0xFFF7F9FC),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        centerTitle: true,
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 0.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE8EEF5),
        thickness: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
        ),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderSide: BorderSide(color: Colors.transparent)),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.transparent)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.transparent)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F5FA),
        selectedColor: accent.withValues(alpha: 0.15),
        labelStyle: const TextStyle(color: Colors.black87),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
