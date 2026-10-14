import 'package:flutter/material.dart';

abstract final class AppColors {
  static const canvas = Color(0xFFF7F4EF);
  static const surface = Color(0xFFFFFEFC);
  static const ink = Color(0xFF191816);
  static const muted = Color(0xFF7B7771);
  static const border = Color(0xFFE3DED6);
  static const pinkSoft = Color(0xFFF7E5EB);
  static const pinkStrong = Color(0xFFD76582);
  static const whatsapp = Color(0xFF218A5B);
  static const error = Color(0xFFB42318);
}

abstract final class AppTheme {
  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.ink,
          brightness: Brightness.light,
          surface: AppColors.surface,
          error: AppColors.error,
        ).copyWith(
          primary: AppColors.ink,
          onPrimary: Colors.white,
          secondary: AppColors.pinkStrong,
          onSecondary: Colors.white,
          surface: AppColors.surface,
          onSurface: AppColors.ink,
          outline: AppColors.border,
          outlineVariant: AppColors.border,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      fontFamily: 'Arial',
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displaySmall: const TextStyle(
          fontFamily: 'serif',
          fontSize: 32,
          height: 1.08,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        headlineLarge: const TextStyle(
          fontFamily: 'serif',
          fontSize: 28,
          height: 1.12,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        headlineMedium: const TextStyle(
          fontFamily: 'serif',
          fontSize: 24,
          height: 1.18,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        bodyLarge: const TextStyle(
          fontSize: 16,
          height: 1.45,
          color: AppColors.ink,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          height: 1.42,
          color: AppColors.ink,
        ),
        bodySmall: const TextStyle(
          fontSize: 12,
          height: 1.4,
          color: AppColors.muted,
        ),
        labelLarge: const TextStyle(
          fontSize: 14,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        labelMedium: const TextStyle(
          fontSize: 12,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: .35,
          color: AppColors.ink,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.ink, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.error),
        ),
        hintStyle: TextStyle(color: AppColors.muted),
        labelStyle: TextStyle(color: AppColors.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.ink,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        labelStyle: const TextStyle(color: AppColors.ink),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        showCheckmark: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.ink,
        unselectedItemColor: AppColors.muted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
