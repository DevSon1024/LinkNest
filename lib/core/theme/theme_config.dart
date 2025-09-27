import 'package:flutter/material.dart';

class ThemeConfig {
  static final Color _primaryColor = const Color(0xFF6A5AE0);

  // Modern Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.light,
      primary: _primaryColor,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFE8DEFF),
      onPrimaryContainer: const Color(0xFF21005D),
      secondary: const Color(0xFF625B71),
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: const Color(0xFF1D1B20),
      surfaceContainer: const Color(0xFFF3EDF7),
      onSurfaceVariant: const Color(0xFF49454F),
      outline: const Color(0xFF79747E),
    ),
    scaffoldBackgroundColor: const Color(0xFFF8F8FA),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF8F8FA),
      surfaceTintColor: Colors.transparent,
      foregroundColor: Color(0xFF1D1B20),
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        side: BorderSide(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
    ),
    iconTheme: IconThemeData(
      color: _primaryColor,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
  );

  // Modern Dark Theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.dark,
      primary: const Color(0xFFB1A2F3),
      onPrimary: const Color(0xFF2A1C6A),
      primaryContainer: const Color(0xFF4A4088),
      onPrimaryContainer: const Color(0xFFE8DEFF),
      secondary: const Color(0xFFCCC2DC),
      onSecondary: const Color(0xFF332D41),
      surface: const Color(0xFF1C1B1F), // Main surface color (cards, dialogs)
      onSurface: const Color(0xFFE6E1E5), // Main text color
      surfaceContainer: const Color(0xFF211F26), // Slightly lighter containers
      onSurfaceVariant: const Color(0xFFCAC4D0), // Secondary text, icons
      outline: const Color(0xFF938F99), // Borders
    ),
    scaffoldBackgroundColor: const Color(0xFF100E14), // Darkest background
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF100E14),
      surfaceTintColor: Colors.transparent,
      foregroundColor: Color(0xFFE6E1E5),
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF1C1B1F),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        side: BorderSide(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
    ),
    iconTheme: const IconThemeData(
      color: Color(0xFFB1A2F3),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2A282E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: const Color(0xFF4A4088),
        foregroundColor: const Color(0xFFE8DEFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
  );
}