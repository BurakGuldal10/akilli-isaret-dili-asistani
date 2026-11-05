import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color warmOrange = Color(0xFFFF6B35);
  static const Color warmRed = Color(0xFFE63946);
  static const Color warmYellow = Color(0xFFF4A261);
  static const Color warmGold = Color(0xFFFF9F1C);
  static const Color successGreen = Color(0xFF2ECC71);
  static const Color darkBg = Color(0xFF1A1A2E);
  static const Color midBg = Color(0xFF16213E);
  static const Color deepBg = Color(0xFF0F3460);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      textTheme: GoogleFonts.poppinsTextTheme(
        ThemeData.dark().textTheme,
      ),
    );
  }

  static List<Color> getCardGradient(int index, bool isLearned) {
    if (isLearned) {
      return const [Color(0xFF1B998B), Color(0xFF2ECC71)];
    }
    const warmColors = [
      [Color(0xFFFF6B35), Color(0xFFFF8E53)],
      [Color(0xFFE63946), Color(0xFFFF6B6B)],
      [Color(0xFFF4A261), Color(0xFFE9C46A)],
      [Color(0xFFD62828), Color(0xFFE85D04)],
      [Color(0xFFFF9F1C), Color(0xFFFFBF69)],
      [Color(0xFFCB4335), Color(0xFFEB6840)],
    ];
    return warmColors[index % warmColors.length];
  }
}
