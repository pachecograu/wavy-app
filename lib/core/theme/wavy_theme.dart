import 'package:flutter/material.dart';

class WavyTheme {
  // AudiShare color palette (from listen.css)
  static const Color primaryRed = Color(0xFFDC143C); // crimson
  static const Color accentRed = Color(0xFFA41935); // cta-btn bg
  static const Color ctaHover = Color(0xFFC51236); // cta-btn:hover
  static const Color darkBackground = Color(0xFF1E1F30); // player-wrap bg
  static const Color cardBackground = Color(0xFF222336); // sidebar bg
  static const Color surfaceDark = Color(0xFF2E2F49); // popover bg
  static const Color headerBg = Color(0x0F000000); // rgba(0,0,0,0.06)
  static const Color textPrimary = Color(0xFFF5F5F5); // whitesmoke
  static const Color textSecondary = Color(0xFF787BA2); // body color
  static const Color textFaded = Color(0x80787BA2);
  static const Color cornflowerBlue = Color(0xFF6495ED);
  static const Color borderColor = Color(0x14000000); // rgba(0,0,0,0.08)
  static const Color greenOnline = Color(0xFF008000); // .connected
  static const Color ctaPink = Color(0xFFFAC3CE); // cta-btn text
  static const Color itemBgEven = Color(0x1A000000); // rgba(0,0,0,0.1)
  static const Color itemBgOdd = Color(0x2E000000); // rgba(0,0,0,0.18)
  static const Color activeBg = Color(0xFF1A1B2A); // .active

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryRed,
      scaffoldBackgroundColor: darkBackground,
      cardColor: cardBackground,
      fontFamily: 'RobotoCondensed',
      colorScheme: const ColorScheme.dark(
        primary: primaryRed,
        secondary: accentRed,
        surface: cardBackground,
        surfaceContainerHighest: darkBackground,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onSurfaceVariant: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: primaryRed, fontSize: 20, fontWeight: FontWeight.w700),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: textPrimary, fontSize: 32, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w700),
        bodySmall: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w700),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentRed,
          foregroundColor: ctaPink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          elevation: 4,
          shadowColor: Colors.black54,
        ),
      ),
    );
  }
}
