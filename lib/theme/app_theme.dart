import 'package:flutter/material.dart';

class AppTheme {
  // Brand colors
  static const Color _primaryGreen = Color(0xFF00C9A7);
  static const Color _primaryBlue = Color(0xFF00B4D8);
  static const Color _amber = Color(0xFFFFB830);

  static const Color _darkBg = Color(0xFF0D0D0F);
  static const Color _darkSurface = Color(0xFF1A1A1E);
  static const Color _darkSurface2 = Color(0xFF252529);

  static const Color _lightBg = Color(0xFFF0F4F8);
  static const Color _lightSurface = Color(0xFFFFFFFF);

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _darkBg,
        colorScheme: const ColorScheme.dark(
          primary: _primaryGreen,
          secondary: _primaryBlue,
          tertiary: _amber,
          surface: _darkSurface,
          onSurface: Colors.white,
          onPrimary: Colors.white,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          color: _darkSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: EdgeInsets.zero,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _darkBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        dividerTheme: const DividerThemeData(
          color: _darkSurface2,
          thickness: 1,
          space: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: _darkSurface2,
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
      );

  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: _lightBg,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF009880),
          secondary: Color(0xFF0096B4),
          tertiary: Color(0xFFE09000),
          surface: _lightSurface,
          onSurface: Color(0xFF111111),
          onPrimary: Colors.white,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          color: _lightSurface,
          elevation: 0,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE8E8EE), width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _lightBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF111111)),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFEEEEF4),
          thickness: 1,
          space: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF1A1A1E),
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
      );
}
