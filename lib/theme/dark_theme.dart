// File: lib/theme/dark_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF121212),
  primaryColor: const Color(0xFF6366F1),
  // secondary: const Color(0xFF818CF8),
  // tertiary: const Color(0xFFC4B5FD),
  // surface: const Color(0xFF1E1E1E),
  colorScheme: ColorScheme.dark(
    primary: const Color(0xFF6366F1),
    onPrimary: Colors.white,
    secondary: const Color(0xFF818CF8),
    onSecondary: Colors.white,
    tertiary: const Color(0xFFC4B5FD),
    surface: const Color(0xFF1E1E1E),
    onSurface: Colors.white,
    background: const Color(0xFF121212),
    onBackground: Colors.white,
    error: const Color(0xFFEF5350),
  ),
  textTheme: TextTheme(
    displayLarge: GoogleFonts.roboto(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    displayMedium: GoogleFonts.roboto(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    displaySmall: GoogleFonts.roboto(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    headlineMedium: GoogleFonts.roboto(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    headlineSmall: GoogleFonts.roboto(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
    titleLarge: GoogleFonts.roboto(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
    bodyLarge: GoogleFonts.roboto(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: Colors.white70,
    ),
    bodyMedium: GoogleFonts.roboto(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: Colors.white70,
    ),
    bodySmall: GoogleFonts.roboto(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: Colors.white54,
    ),
    labelLarge: GoogleFonts.roboto(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF6366F1),
    ),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: const Color(0xFF1E1E1E),
    elevation: 0,
    centerTitle: true,
    titleTextStyle: GoogleFonts.roboto(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: const Color(0xFF6366F1),
    foregroundColor: Colors.white,
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF6366F1),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF6366F1),
      side: const BorderSide(color: Color(0xFF6366F1)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF2A2A2A),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF404040)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF404040)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
    ),
    labelStyle: GoogleFonts.roboto(
      color: Colors.white54,
      fontSize: 14,
    ),
    hintStyle: GoogleFonts.roboto(
      color: Colors.white38,
      fontSize: 14,
    ),
  ),
  cardTheme: CardTheme(
    color: const Color(0xFF1E1E1E),
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  ),
);