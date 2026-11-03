import 'package:flutter/material.dart';

/// Paleta: tinta y cuero oscuros, oro viejo, carmesí y un azul arcano.
class AppColors {
  static const background = Color(0xFF131011);
  static const surface = Color(0xFF1C1816);
  static const surfaceHigh = Color(0xFF26201C);
  static const surfaceHighest = Color(0xFF302823);
  static const outline = Color(0xFF4D4037);
  static const outlineSoft = Color(0xFF362D27);
  static const gold = Color(0xFFD4A64A);
  static const primaryContainer = Color(0xFF4A3912);
  static const goldSoft = Color(0xFF8C6D2F);
  static const crimson = Color(0xFFB8403B);
  static const secondaryDark = Color(0xFF5A1F1C);
  static const arcane = Color(0xFF63A9BD);
  static const parchment = Color(0xFFEDE3D0);
  static const muted = Color(0xFFA69C8C);
  static const success = Color(0xFF74B86C);
  static const warning = Color(0xFFE0A33E);
  static const danger = Color(0xFFE0655A);

  static Color hpColor(double ratio) {
    if (ratio > 0.5) return success;
    if (ratio > 0.25) return warning;
    return danger;
  }
}

const _headingFont = 'Cinzel';
const _bodyFont = 'AlegreyaSans';

TextStyle _heading(double size, {double weight = 600, double spacing = 0.4}) => TextStyle(
  fontFamily: _headingFont,
  fontSize: size,
  fontVariations: [FontVariation('wght', weight)],
  letterSpacing: spacing,
  color: AppColors.parchment,
);

ThemeData buildTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.gold,
    onPrimary: Color(0xFF1E1606),
    primaryContainer: Color(0xFF4A3912),
    onPrimaryContainer: Color(0xFFF6DFA6),
    secondary: AppColors.crimson,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFF4E1C1A),
    onSecondaryContainer: Color(0xFFFFD9D4),
    tertiary: AppColors.arcane,
    onTertiary: Color(0xFF06222A),
    tertiaryContainer: Color(0xFF1C4652),
    onTertiaryContainer: Color(0xFFCBEFFA),
    error: AppColors.danger,
    onError: Colors.black,
    surface: AppColors.surface,
    onSurface: AppColors.parchment,
    onSurfaceVariant: AppColors.muted,
    surfaceContainerLowest: Color(0xFF0E0B0B),
    surfaceContainerLow: Color(0xFF181412),
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.surfaceHigh,
    surfaceContainerHighest: AppColors.surfaceHighest,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineSoft,
    inverseSurface: AppColors.parchment,
    onInverseSurface: AppColors.background,
    inversePrimary: AppColors.goldSoft,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: _bodyFont);
  final text = base.textTheme
      .apply(bodyColor: AppColors.parchment, displayColor: AppColors.parchment)
      .copyWith(
        displaySmall: _heading(34, weight: 700),
        headlineLarge: _heading(30, weight: 700),
        headlineMedium: _heading(26, weight: 700),
        headlineSmall: _heading(22, weight: 650),
        titleLarge: _heading(19, weight: 650),
        titleMedium: const TextStyle(fontFamily: _bodyFont, fontSize: 17, fontWeight: FontWeight.w700),
        titleSmall: const TextStyle(fontFamily: _bodyFont, fontSize: 15, fontWeight: FontWeight.w700),
        bodyLarge: const TextStyle(fontFamily: _bodyFont, fontSize: 17, height: 1.35),
        bodyMedium: const TextStyle(fontFamily: _bodyFont, fontSize: 15.5, height: 1.35),
        bodySmall: const TextStyle(fontFamily: _bodyFont, fontSize: 13.5, color: AppColors.muted),
        labelLarge: const TextStyle(fontFamily: _bodyFont, fontSize: 15, fontWeight: FontWeight.w700),
        labelMedium: const TextStyle(fontFamily: _bodyFont, fontSize: 13.5, fontWeight: FontWeight.w500),
        labelSmall: const TextStyle(fontFamily: _bodyFont, fontSize: 12, letterSpacing: 0.4),
      );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface.withValues(alpha: 0.92),
      foregroundColor: AppColors.parchment,
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
      titleTextStyle: _heading(20, weight: 650).copyWith(color: AppColors.gold),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface.withValues(alpha: 0.94),
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.outlineSoft),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.outlineSoft, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceHigh.withValues(alpha: 0.7),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.outlineSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      isDense: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        textStyle: const TextStyle(fontFamily: _bodyFont, fontSize: 16, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        side: const BorderSide(color: AppColors.goldSoft),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surfaceHigh,
      side: const BorderSide(color: AppColors.outlineSoft),
      labelStyle: const TextStyle(fontFamily: _bodyFont, fontSize: 14, color: AppColors.parchment),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.surface.withValues(alpha: 0.96),
      indicatorColor: AppColors.primaryContainer,
      selectedLabelTextStyle: const TextStyle(
        fontFamily: _bodyFont,
        color: AppColors.gold,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: const TextStyle(fontFamily: _bodyFont, color: AppColors.muted),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primaryContainer,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontFamily: _bodyFont, fontSize: 12.5)),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.gold,
      unselectedLabelColor: AppColors.muted,
      indicatorColor: AppColors.gold,
      dividerColor: AppColors.outlineSoft,
      labelStyle: TextStyle(fontFamily: _bodyFont, fontSize: 15, fontWeight: FontWeight.w700),
    ),
    listTileTheme: const ListTileThemeData(iconColor: AppColors.gold),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outline),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: AppColors.surfaceHigh, showDragHandle: true),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHighest,
      contentTextStyle: TextStyle(fontFamily: _bodyFont, color: AppColors.parchment, fontSize: 15),
    ),
    tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 500)),
  );
}

/// Constantes de espaciado.
class Gap {
  static const xs = SizedBox(width: 4, height: 4);
  static const s = SizedBox(width: 8, height: 8);
  static const m = SizedBox(width: 12, height: 12);
  static const l = SizedBox(width: 20, height: 20);
}
