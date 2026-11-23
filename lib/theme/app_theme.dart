import 'package:flutter/material.dart';

/// Paleta de la app: blanco humo + rosado.
///
/// - [rose] es el color de acción (botones, pestaña activa). Tiene 5.0:1 con
///   texto blanco.
/// - [roseDeep] es para texto rosado pequeño (6.3:1 sobre [canvas]).
/// - [pinkStrong] es solo decorativo (iconos, ilustración): con texto blanco
///   no llega a 4.5:1.
abstract final class AppColors {
  static const canvas = Color(0xFFF7F4EF);
  static const surface = Color(0xFFFFFEFC);
  static const ink = Color(0xFF191816);
  static const muted = Color(0xFF6B665F);
  static const border = Color(0xFFE3DED6);
  static const pinkSoft = Color(0xFFF7E5EB);
  static const pinkStrong = Color(0xFFD76582);
  static const rose = Color(0xFFBE4467);
  static const roseDeep = Color(0xFF9E3355);
  static const whatsapp = Color(0xFF218A5B);
  static const error = Color(0xFFB42318);
}

/// Medidas compartidas para que todas las pantallas respiren igual.
abstract final class AppSpacing {
  /// Margen horizontal de las pantallas.
  static const gutter = 16.0;

  /// Ancho máximo del contenido: columna tipo móvil también en tablet/web.
  static const maxContentWidth = 640.0;

  static const radiusCard = 18.0;
  static const radiusControl = 16.0;
  static const radiusPill = 99.0;
}

abstract final class AppTheme {
  static const String displayFont = 'Lora';
  static const String bodyFont = 'Montserrat';

  static TextStyle priceStyle({
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.ink,
    double height = 1.2,
  }) {
    return TextStyle(
      fontFamily: displayFont,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      color: color,
    );
  }

  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.ink,
          brightness: Brightness.light,
          surface: AppColors.surface,
          error: AppColors.error,
        ).copyWith(
          primary: AppColors.rose,
          onPrimary: Colors.white,
          primaryContainer: AppColors.pinkSoft,
          onPrimaryContainer: AppColors.roseDeep,
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
      fontFamily: bodyFont,
      visualDensity: VisualDensity.standard,
      dividerColor: AppColors.border,
      focusColor: AppColors.pinkSoft,
      hoverColor: AppColors.pinkSoft.withValues(alpha: .35),
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: const TextStyle(
          fontFamily: displayFont,
          fontSize: 48,
          height: 1.08,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.6,
          color: AppColors.ink,
        ),
        displayMedium: const TextStyle(
          fontFamily: displayFont,
          fontSize: 40,
          height: 1.1,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.5,
          color: AppColors.ink,
        ),
        displaySmall: const TextStyle(
          fontFamily: displayFont,
          fontSize: 36,
          height: 1.12,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.4,
          color: AppColors.ink,
        ),
        headlineLarge: const TextStyle(
          fontFamily: displayFont,
          fontSize: 30,
          height: 1.16,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.3,
          color: AppColors.ink,
        ),
        headlineMedium: const TextStyle(
          fontFamily: displayFont,
          fontSize: 24,
          height: 1.2,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.2,
          color: AppColors.ink,
        ),
        headlineSmall: const TextStyle(
          fontFamily: displayFont,
          fontSize: 20,
          height: 1.24,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.15,
          color: AppColors.ink,
        ),
        titleLarge: const TextStyle(
          fontFamily: bodyFont,
          fontSize: 18.5,
          height: 1.26,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          color: AppColors.ink,
        ),
        titleMedium: const TextStyle(
          fontFamily: bodyFont,
          fontSize: 15,
          height: 1.32,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        titleSmall: const TextStyle(
          fontFamily: bodyFont,
          fontSize: 13.5,
          height: 1.32,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        bodyLarge: const TextStyle(
          fontFamily: bodyFont,
          fontSize: 15,
          height: 1.52,
          fontWeight: FontWeight.w400,
          color: AppColors.ink,
        ),
        bodyMedium: const TextStyle(
          fontFamily: bodyFont,
          fontSize: 13.5,
          height: 1.5,
          fontWeight: FontWeight.w400,
          color: AppColors.ink,
        ),
        bodySmall: const TextStyle(
          fontFamily: bodyFont,
          fontSize: 12,
          height: 1.45,
          fontWeight: FontWeight.w400,
          color: AppColors.muted,
        ),
        labelLarge: const TextStyle(
          fontFamily: bodyFont,
          fontSize: 13.5,
          height: 1.24,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        labelMedium: const TextStyle(
          fontFamily: bodyFont,
          fontSize: 11.5,
          height: 1.22,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.45,
          color: AppColors.ink,
        ),
        labelSmall: const TextStyle(
          fontFamily: bodyFont,
          fontSize: 10.5,
          height: 1.2,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.35,
          color: AppColors.muted,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: bodyFont,
          fontSize: 17,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
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
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
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
          borderSide: BorderSide(color: AppColors.rose, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.error),
        ),
        hintStyle: TextStyle(fontFamily: bodyFont, color: AppColors.muted),
        labelStyle: TextStyle(fontFamily: bodyFont, color: AppColors.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.rose,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.muted,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
          ),
          textStyle: const TextStyle(
            fontFamily: bodyFont,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.border, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
          ),
          textStyle: const TextStyle(
            fontFamily: bodyFont,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: AppColors.roseDeep,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: bodyFont,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.rose,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        labelStyle: const TextStyle(fontFamily: bodyFont, color: AppColors.ink),
        secondaryLabelStyle: const TextStyle(
          fontFamily: bodyFont,
          color: Colors.white,
        ),
        showCheckmark: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.ink,
        unselectedItemColor: AppColors.muted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontFamily: bodyFont,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: bodyFont,
          fontWeight: FontWeight.w500,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        indicatorColor: AppColors.pinkSoft,
        indicatorShape: const StadiumBorder(),
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.roseDeep
                : AppColors.muted,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontFamily: bodyFont,
            color: states.contains(WidgetState.selected)
                ? AppColors.roseDeep
                : AppColors.muted,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          );
        }),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.pinkSoft,
        selectedIconTheme: IconThemeData(color: AppColors.ink),
        unselectedIconTheme: IconThemeData(color: AppColors.muted),
        selectedLabelTextStyle: TextStyle(
          fontFamily: bodyFont,
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontFamily: bodyFont,
          color: AppColors.muted,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.rose,
        foregroundColor: Colors.white,
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(
          fontFamily: bodyFont,
          color: Colors.white,
          fontSize: 12,
        ),
        waitDuration: const Duration(milliseconds: 450),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(
          fontFamily: bodyFont,
          color: Colors.white,
        ),
        actionTextColor: AppColors.pinkSoft,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.border,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.rose,
        linearTrackColor: AppColors.pinkSoft,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.rose
              : AppColors.border,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? AppColors.rose : null,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.rose
              : AppColors.muted,
        ),
      ),
    );
  }
}
