import 'package:flutter/material.dart';

abstract final class AppColors {
  static const forest = Color(0xFF075B43);
  static const cream = Color(0xFFF7F0E5);
  static const terracotta = Color(0xFFB34D30);
  static const charcoal = Color(0xFF292D2A);
  static const muted = Color(0xFF6E746F);
  static const line = Color(0xFFE4DCCE);
  static const paleGreen = Color(0xFFE3EEE8);
  static const paleTerracotta = Color(0xFFF5E5DE);
}

ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.forest,
        brightness: Brightness.light,
        surface: AppColors.cream,
      ).copyWith(
        primary: AppColors.forest,
        onPrimary: Colors.white,
        secondary: AppColors.terracotta,
        onSecondary: Colors.white,
        surface: AppColors.cream,
        onSurface: AppColors.charcoal,
        outline: AppColors.line,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.cream,
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: AppColors.charcoal,
      displayColor: AppColors.charcoal,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.cream,
      foregroundColor: AppColors.charcoal,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
    ),
  );
}
