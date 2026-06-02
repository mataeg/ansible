import 'package:flutter/material.dart';

class AppTheme {
  static const Color bg      = Color(0xFF060D1A);
  static const Color surface = Color(0xFF0D1423);
  static const Color card    = Color(0xFF111827);
  static const Color border  = Color(0xFF1E2D45);
  static const Color accent  = Color(0xFF3B82F6);
  static const Color green   = Color(0xFF22C55E);
  static const Color red     = Color(0xFFEF4444);
  static const Color yellow  = Color(0xFFFBBF24);
  static const Color purple  = Color(0xFFA855F7);
  static const Color text1   = Color(0xFFE2E8F0);
  static const Color text2   = Color(0xFF64748B);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary:   accent,
      secondary: green,
      surface:   surface,
      error:     red,
      onPrimary: Colors.white,
      onSurface: text1,
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: border, width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: text1,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: text1),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accent, width: 2),
      ),
      labelStyle: const TextStyle(color: text2),
      hintStyle: const TextStyle(color: text2),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: text1, fontWeight: FontWeight.w800),
      headlineMedium: TextStyle(color: text1, fontWeight: FontWeight.w700),
      bodyLarge:  TextStyle(color: text1),
      bodyMedium: TextStyle(color: text2),
      labelLarge: TextStyle(color: text1, fontWeight: FontWeight.w600),
    ),
    dividerTheme: const DividerThemeData(color: border, thickness: 1),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: accent,
      unselectedItemColor: text2,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: card,
      labelStyle: const TextStyle(color: text1, fontSize: 11),
      side: const BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: card,
      contentTextStyle: const TextStyle(color: text1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
