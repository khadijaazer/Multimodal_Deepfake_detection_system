import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // QDFX Brand Colors
  static const Color primaryBlue = Color(0xFF2E86DE);
  static const Color bgDark = Color(0xFF0F172A); // Deep Navy
  static const Color cardDark = Color(0xFF1E293B); // Lighter Navy
  static const Color textWhite = Colors.white;

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgDark,
    primaryColor: primaryBlue,
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    // FIX: Changed 'CardTheme' to 'CardThemeData'
    cardTheme: CardThemeData(
      color: cardDark,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    useMaterial3: true,
  );
}