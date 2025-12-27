import 'package:flutter/material.dart';

class SpotifyTheme {
  // Spotify Colors
  static const Color primary = Color(0xFF1DB954);
  static const Color primaryDark = Color(0xFF1AA34A);
  static const Color background = Color(0xFF121212);
  static const Color backgroundElevated = Color(0xFF1A1A1A);
  static const Color card = Color(0xFF181818);
  static const Color cardHover = Color(0xFF282828);
  static const Color surface = Color(0xFF242424);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textMuted = Color(0xFF727272);
  static const Color divider = Color(0xFF404040);
  static const Color error = Color(0xFFE91429);
  
  // Gradient colors
  static const List<Color> cardGradient = [
    Color(0xFF404040),
    Color(0xFF282828),
  ];

  // Text Styles
  static const TextStyle headingLarge = TextStyle(
    color: textPrimary,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static const TextStyle headingMedium = TextStyle(
    color: textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static const TextStyle headingSmall = TextStyle(
    color: textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle bodyLarge = TextStyle(
    color: textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle bodyMedium = TextStyle(
    color: textSecondary,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodySmall = TextStyle(
    color: textMuted,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle labelMedium = TextStyle(
    color: textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
  );

  // Decorations
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(8),
  );

  static BoxDecoration get elevatedCardDecoration => BoxDecoration(
    color: cardHover,
    borderRadius: BorderRadius.circular(8),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      fontFamily: 'Circular',
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: primary,
        background: background,
        surface: card,
        error: error,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onBackground: textPrimary,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: textPrimary,
        inactiveTrackColor: textMuted.withOpacity(0.3),
        thumbColor: textPrimary,
        overlayColor: textPrimary.withOpacity(0.2),
      ),
      iconTheme: const IconThemeData(color: textSecondary),
      dividerTheme: const DividerThemeData(color: divider, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardHover,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: headingSmall,
        contentTextStyle: bodyMedium,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: textMuted),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: textPrimary, width: 2),
        ),
      ),
    );
  }
}
