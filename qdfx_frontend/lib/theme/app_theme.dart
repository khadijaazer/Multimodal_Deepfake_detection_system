import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- NEW COLOR PALETTE ---
  static const Color primaryBlue = Color(0xFF3B82F6); 
  static const Color accentCyan = Color(0xFF06B6D4);
  
  static const Color darkBg = Color(0xFF0B1121);
  static const Color darkCard = Color(0xFF151E32);
  static const Color darkBorder = Color(0xFF2D3B55);
  
  static const Color lightBg = Color(0xFFF1F5F9);
  static const Color lightCard = Colors.white;
  static const Color lightBorder = Color(0xFFE2E8F0);

  // --- COMPATIBILITY FIXES (For Dashboard) ---
  static const Color cardDark = darkCard; 
  static const Color bgDark = darkBg;     

  // --- THEMES ---

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBg,
    primaryColor: primaryBlue,
    fontFamily: GoogleFonts.inter().fontFamily,
    // FIX 1: Use CardThemeData instead of CardTheme
    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: darkBorder),
      ),
    ),
    // FIX 2: Use 'extensions' (plural)
    extensions: const [
      ShadowTheme(
        glow: BoxShadow(color: Color(0x403B82F6), blurRadius: 20, spreadRadius: 0),
        soft: BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
      ),
    ],
    useMaterial3: true,
  );

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBg,
    primaryColor: primaryBlue,
    fontFamily: GoogleFonts.inter().fontFamily,
    // FIX 1: Use CardThemeData instead of CardTheme
    cardTheme: CardThemeData(
      color: lightCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: lightBorder),
      ),
    ),
    // FIX 2: Use 'extensions' (plural)
    extensions: const [
      ShadowTheme(
        glow: BoxShadow(color: Colors.transparent, blurRadius: 0), 
        soft: BoxShadow(color: Color(0x10000000), blurRadius: 10, offset: Offset(0, 4)),
      ),
    ],
    useMaterial3: true,
  );
}

// Custom Extension for Shadows
class ShadowTheme extends ThemeExtension<ShadowTheme> {
  final BoxShadow glow;
  final BoxShadow soft;
  const ShadowTheme({required this.glow, required this.soft});
  
  @override
  ThemeExtension<ShadowTheme> copyWith() => this;
  
  @override
  ThemeExtension<ShadowTheme> lerp(ThemeExtension<ShadowTheme>? other, double t) => this;
}