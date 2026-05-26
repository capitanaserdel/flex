import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF1B5E20);      // Deep Islamic Green
  static const Color primaryLight = Color(0xFF2E7D32); // Success Green / Lighter Green
  static const Color accentGold = Color(0xFFFFD700);   // Accent Gold
  static const Color warmCream = Color(0xFFFFF8E7);   // Warm Cream Backgrounds
  static const Color richBrown = Color(0xFF4E342E);   // Rich Brown Accents
  static const Color softWhite = Color(0xFFFAFAFA);   // Main Canvas White
  static const Color darkText = Color(0xFF1A1A1A);    // Primary Body / Headings
  static const Color mutedGray = Color(0xFF9E9E9E);   // Secondary Text / Subheadings
  static const Color errorRed = Color(0xFFC62828);    // Validation / Error alerts
  static const Color successGreen = Color(0xFF2E7D32);

  // Gradient Colors
  static const LinearGradient heroGradient = LinearGradient(
    colors: [primary, Color(0xFF388E3C), accentGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient goldGradient = LinearGradient(
    colors: [accentGold, Color(0xFFFFB300)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
