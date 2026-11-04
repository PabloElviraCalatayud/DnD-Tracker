import 'package:flutter/material.dart';

import '../domain/profile.dart';

/// Colores de un tema. Los nombres siguen el tema original (oro, carmesí,
/// arcano…) aunque cada tema los reinterprete.
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.background,
    required this.surfaceLowest,
    required this.surfaceLow,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.outline,
    required this.outlineSoft,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.primarySoft,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.text,
    required this.muted,
    required this.success,
    required this.warning,
    required this.danger,
    required this.mapFloor,
    required this.textureTint,
    required this.glow,
  });

  final Brightness brightness;
  final Color background;
  final Color surfaceLowest;
  final Color surfaceLow;
  final Color surface;
  final Color surfaceHigh;
  final Color surfaceHighest;
  final Color outline;
  final Color outlineSoft;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color primarySoft;
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color text;
  final Color muted;
  final Color success;
  final Color warning;
  final Color danger;

  /// Color del suelo de los mapas en blanco.
  final Color mapFloor;

  /// Color con el que se multiplica la textura del fondo.
  final Color textureTint;

  /// Resplandor de los elementos seleccionados.
  final Color glow;

  bool get isDark => brightness == Brightness.dark;
}

class AppPalettes {
  static const dungeon = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF131011),
    surfaceLowest: Color(0xFF0E0B0B),
    surfaceLow: Color(0xFF181412),
    surface: Color(0xFF1C1816),
    surfaceHigh: Color(0xFF26201C),
    surfaceHighest: Color(0xFF302823),
    outline: Color(0xFF4D4037),
    outlineSoft: Color(0xFF362D27),
    primary: Color(0xFFD4A64A),
    onPrimary: Color(0xFF1E1606),
    primaryContainer: Color(0xFF4A3912),
    onPrimaryContainer: Color(0xFFF6DFA6),
    primarySoft: Color(0xFF8C6D2F),
    secondary: Color(0xFFB8403B),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFF5A1F1C),
    onSecondaryContainer: Color(0xFFFFD9D4),
    tertiary: Color(0xFF63A9BD),
    onTertiary: Color(0xFF06222A),
    tertiaryContainer: Color(0xFF1C4652),
    onTertiaryContainer: Color(0xFFCBEFFA),
    text: Color(0xFFEDE3D0),
    muted: Color(0xFFA69C8C),
    success: Color(0xFF74B86C),
    warning: Color(0xFFE0A33E),
    danger: Color(0xFFE0655A),
    mapFloor: Color(0xFF2A2420),
    textureTint: Color(0xFF1A1616),
    glow: Color(0xFFFFC857),
  );

  static const parchment = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFEFE4CC),
    surfaceLowest: Color(0xFFFFFBF2),
    surfaceLow: Color(0xFFF7EFDD),
    surface: Color(0xFFFAF3E3),
    surfaceHigh: Color(0xFFF1E6CD),
    surfaceHighest: Color(0xFFE7D8B8),
    outline: Color(0xFFA48B66),
    outlineSoft: Color(0xFFD5C3A0),
    primary: Color(0xFF8A2C1D),
    onPrimary: Color(0xFFFFF4E8),
    primaryContainer: Color(0xFFF2CDB8),
    onPrimaryContainer: Color(0xFF3C0E06),
    primarySoft: Color(0xFFB0705C),
    secondary: Color(0xFF7A5414),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFEBD3A0),
    onSecondaryContainer: Color(0xFF2E1E00),
    tertiary: Color(0xFF2D5F73),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFC5E1EC),
    onTertiaryContainer: Color(0xFF062430),
    text: Color(0xFF2A1F16),
    muted: Color(0xFF6E5D4A),
    success: Color(0xFF3F7D38),
    warning: Color(0xFFA86A0C),
    danger: Color(0xFFB3261E),
    mapFloor: Color(0xFFD9C7A2),
    textureTint: Color(0xFFF6ECD6),
    glow: Color(0xFFC2410C),
  );

  static const inferno = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF140B0A),
    surfaceLowest: Color(0xFF0D0706),
    surfaceLow: Color(0xFF1A0F0D),
    surface: Color(0xFF201310),
    surfaceHigh: Color(0xFF2B1A15),
    surfaceHighest: Color(0xFF38221B),
    outline: Color(0xFF5E3A2E),
    outlineSoft: Color(0xFF40271F),
    primary: Color(0xFFF08A3C),
    onPrimary: Color(0xFF2A0F00),
    primaryContainer: Color(0xFF5C2A0C),
    onPrimaryContainer: Color(0xFFFFDCC2),
    primarySoft: Color(0xFFA35A26),
    secondary: Color(0xFFD7392B),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFF65170F),
    onSecondaryContainer: Color(0xFFFFDAD3),
    tertiary: Color(0xFFF2C14E),
    onTertiary: Color(0xFF2B1F00),
    tertiaryContainer: Color(0xFF5A4410),
    onTertiaryContainer: Color(0xFFFFE9AE),
    text: Color(0xFFF4E3D6),
    muted: Color(0xFFB29484),
    success: Color(0xFF8BC34A),
    warning: Color(0xFFF2B33D),
    danger: Color(0xFFFF6B57),
    mapFloor: Color(0xFF2E1A14),
    textureTint: Color(0xFF1F110E),
    glow: Color(0xFFFF8A3D),
  );

  static const feywild = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF0C1410),
    surfaceLowest: Color(0xFF070D0A),
    surfaceLow: Color(0xFF101A15),
    surface: Color(0xFF13201A),
    surfaceHigh: Color(0xFF1B2B23),
    surfaceHighest: Color(0xFF24372D),
    outline: Color(0xFF3C5A49),
    outlineSoft: Color(0xFF2A3F33),
    primary: Color(0xFF7FD69A),
    onPrimary: Color(0xFF00210E),
    primaryContainer: Color(0xFF1D4B2E),
    onPrimaryContainer: Color(0xFFC4F2D1),
    primarySoft: Color(0xFF4E8F64),
    secondary: Color(0xFFC08BE0),
    onSecondary: Color(0xFF2A0B3D),
    secondaryContainer: Color(0xFF452A5A),
    onSecondaryContainer: Color(0xFFF1DAFF),
    tertiary: Color(0xFFE8CB6A),
    onTertiary: Color(0xFF261C00),
    tertiaryContainer: Color(0xFF4F4110),
    onTertiaryContainer: Color(0xFFFFEEB0),
    text: Color(0xFFE3F0E6),
    muted: Color(0xFF94AB9C),
    success: Color(0xFF7FD69A),
    warning: Color(0xFFE8CB6A),
    danger: Color(0xFFF07A7A),
    mapFloor: Color(0xFF1C2A21),
    textureTint: Color(0xFF121D17),
    glow: Color(0xFFB8F5C8),
  );

  static const abyss = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF0B0E19),
    surfaceLowest: Color(0xFF070912),
    surfaceLow: Color(0xFF0F1322),
    surface: Color(0xFF131829),
    surfaceHigh: Color(0xFF1B2236),
    surfaceHighest: Color(0xFF252D45),
    outline: Color(0xFF3F4A6E),
    outlineSoft: Color(0xFF2A3350),
    primary: Color(0xFF8FB2FF),
    onPrimary: Color(0xFF071A44),
    primaryContainer: Color(0xFF233A73),
    onPrimaryContainer: Color(0xFFD9E3FF),
    primarySoft: Color(0xFF5570B0),
    secondary: Color(0xFFC77DFF),
    onSecondary: Color(0xFF2B0050),
    secondaryContainer: Color(0xFF4A2370),
    onSecondaryContainer: Color(0xFFF1DBFF),
    tertiary: Color(0xFF5EE0C9),
    onTertiary: Color(0xFF00201B),
    tertiaryContainer: Color(0xFF124A42),
    onTertiaryContainer: Color(0xFFB8FFF1),
    text: Color(0xFFE2E6F5),
    muted: Color(0xFF8E97B5),
    success: Color(0xFF6FD39A),
    warning: Color(0xFFF3C969),
    danger: Color(0xFFFF7A90),
    mapFloor: Color(0xFF1A2033),
    textureTint: Color(0xFF111628),
    glow: Color(0xFF9EC1FF),
  );

  static const frost = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF0E1417),
    surfaceLowest: Color(0xFF090D0F),
    surfaceLow: Color(0xFF121A1E),
    surface: Color(0xFF152024),
    surfaceHigh: Color(0xFF1D2B31),
    surfaceHighest: Color(0xFF27373E),
    outline: Color(0xFF46606B),
    outlineSoft: Color(0xFF2F434B),
    primary: Color(0xFFBFE3F2),
    onPrimary: Color(0xFF00222E),
    primaryContainer: Color(0xFF2B4B57),
    onPrimaryContainer: Color(0xFFDDF4FF),
    primarySoft: Color(0xFF6F98A8),
    secondary: Color(0xFF7FB7D6),
    onSecondary: Color(0xFF002233),
    secondaryContainer: Color(0xFF1E4558),
    onSecondaryContainer: Color(0xFFCDEBFA),
    tertiary: Color(0xFFD9C6F2),
    onTertiary: Color(0xFF261540),
    tertiaryContainer: Color(0xFF433461),
    onTertiaryContainer: Color(0xFFF0E5FF),
    text: Color(0xFFE6F1F5),
    muted: Color(0xFF93A9B2),
    success: Color(0xFF7BD3A7),
    warning: Color(0xFFF2CF7A),
    danger: Color(0xFFF48A8A),
    mapFloor: Color(0xFF1F2B30),
    textureTint: Color(0xFF141D21),
    glow: Color(0xFFD6F3FF),
  );

  static const ash = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF111214),
    surfaceLowest: Color(0xFF0A0B0C),
    surfaceLow: Color(0xFF16171A),
    surface: Color(0xFF1A1C1F),
    surfaceHigh: Color(0xFF24272B),
    surfaceHighest: Color(0xFF2F3237),
    outline: Color(0xFF55595F),
    outlineSoft: Color(0xFF383B40),
    primary: Color(0xFFF2F2F2),
    onPrimary: Color(0xFF111111),
    primaryContainer: Color(0xFF45484D),
    onPrimaryContainer: Color(0xFFFFFFFF),
    primarySoft: Color(0xFF9EA2A8),
    secondary: Color(0xFFFF6B6B),
    onSecondary: Color(0xFF2B0000),
    secondaryContainer: Color(0xFF5C1E1E),
    onSecondaryContainer: Color(0xFFFFDADA),
    tertiary: Color(0xFF7CC4FF),
    onTertiary: Color(0xFF001E33),
    tertiaryContainer: Color(0xFF1C4466),
    onTertiaryContainer: Color(0xFFD6ECFF),
    text: Color(0xFFF5F5F5),
    muted: Color(0xFFA9ADB3),
    success: Color(0xFF6EE08F),
    warning: Color(0xFFFFC857),
    danger: Color(0xFFFF6B6B),
    mapFloor: Color(0xFF26282C),
    textureTint: Color(0xFF17181B),
    glow: Color(0xFFFFFFFF),
  );

  static AppPalette of(ThemeChoice t) => switch (t) {
    ThemeChoice.dungeon => dungeon,
    ThemeChoice.parchment => parchment,
    ThemeChoice.inferno => inferno,
    ThemeChoice.feywild => feywild,
    ThemeChoice.abyss => abyss,
    ThemeChoice.frost => frost,
    ThemeChoice.ash => ash,
  };
}

/// Colores del tema activo. Al cambiar de tema se reconstruye toda la app.
class AppColors {
  static AppPalette palette = AppPalettes.dungeon;

  static Color get background => palette.background;
  static Color get surface => palette.surface;
  static Color get surfaceHigh => palette.surfaceHigh;
  static Color get surfaceHighest => palette.surfaceHighest;
  static Color get outline => palette.outline;
  static Color get outlineSoft => palette.outlineSoft;
  static Color get gold => palette.primary;
  static Color get onGold => palette.onPrimary;
  static Color get primaryContainer => palette.primaryContainer;
  static Color get goldSoft => palette.primarySoft;
  static Color get crimson => palette.secondary;
  static Color get secondaryDark => palette.secondaryContainer;
  static Color get arcane => palette.tertiary;
  static Color get parchment => palette.text;
  static Color get muted => palette.muted;
  static Color get success => palette.success;
  static Color get warning => palette.warning;
  static Color get danger => palette.danger;
  static Color get glow => palette.glow;
  static Color get mapFloor => palette.mapFloor;

  /// Texto que va sobre colores fuertes (fichas, dados, etiquetas).
  static Color get onStrong => palette.isDark ? Colors.white : palette.onPrimary;

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

ThemeData buildTheme([AppPalette? p]) {
  final c = p ?? AppColors.palette;
  final scheme = ColorScheme(
    brightness: c.brightness,
    primary: c.primary,
    onPrimary: c.onPrimary,
    primaryContainer: c.primaryContainer,
    onPrimaryContainer: c.onPrimaryContainer,
    secondary: c.secondary,
    onSecondary: c.onSecondary,
    secondaryContainer: c.secondaryContainer,
    onSecondaryContainer: c.onSecondaryContainer,
    tertiary: c.tertiary,
    onTertiary: c.onTertiary,
    tertiaryContainer: c.tertiaryContainer,
    onTertiaryContainer: c.onTertiaryContainer,
    error: c.danger,
    onError: c.isDark ? Colors.black : Colors.white,
    surface: c.surface,
    onSurface: c.text,
    onSurfaceVariant: c.muted,
    surfaceContainerLowest: c.surfaceLowest,
    surfaceContainerLow: c.surfaceLow,
    surfaceContainer: c.surface,
    surfaceContainerHigh: c.surfaceHigh,
    surfaceContainerHighest: c.surfaceHighest,
    outline: c.outline,
    outlineVariant: c.outlineSoft,
    inverseSurface: c.text,
    onInverseSurface: c.background,
    inversePrimary: c.primarySoft,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: _bodyFont);
  final text = base.textTheme
      .apply(bodyColor: c.text, displayColor: c.text)
      .copyWith(
        displaySmall: _heading(34, weight: 700),
        headlineLarge: _heading(30, weight: 700),
        headlineMedium: _heading(26, weight: 700),
        headlineSmall: _heading(22, weight: 650),
        titleLarge: _heading(19, weight: 650),
        titleMedium: TextStyle(fontFamily: _bodyFont, fontSize: 17, fontWeight: FontWeight.w700, color: c.text),
        titleSmall: TextStyle(fontFamily: _bodyFont, fontSize: 15, fontWeight: FontWeight.w700, color: c.text),
        bodyLarge: TextStyle(fontFamily: _bodyFont, fontSize: 17, height: 1.35, color: c.text),
        bodyMedium: TextStyle(fontFamily: _bodyFont, fontSize: 15.5, height: 1.35, color: c.text),
        bodySmall: TextStyle(fontFamily: _bodyFont, fontSize: 13.5, color: c.muted),
        labelLarge: TextStyle(fontFamily: _bodyFont, fontSize: 15, fontWeight: FontWeight.w700, color: c.text),
        labelMedium: TextStyle(fontFamily: _bodyFont, fontSize: 13.5, fontWeight: FontWeight.w500, color: c.text),
        labelSmall: TextStyle(fontFamily: _bodyFont, fontSize: 12, letterSpacing: 0.4, color: c.text),
      );

  return base.copyWith(
    scaffoldBackgroundColor: c.background,
    textTheme: text,
    iconTheme: IconThemeData(color: c.text),
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface.withValues(alpha: 0.92),
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
      titleTextStyle: _heading(20, weight: 650).copyWith(color: c.primary),
    ),
    cardTheme: CardThemeData(
      color: c.surface.withValues(alpha: 0.94),
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.outlineSoft),
      ),
    ),
    dividerTheme: DividerThemeData(color: c.outlineSoft, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceHigh.withValues(alpha: 0.7),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.outlineSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.primary, width: 1.5),
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
        foregroundColor: c.primary,
        side: BorderSide(color: c.primarySoft),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: c.surfaceHigh,
      side: BorderSide(color: c.outlineSoft),
      labelStyle: TextStyle(fontFamily: _bodyFont, fontSize: 14, color: c.text),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: c.surface.withValues(alpha: 0.96),
      indicatorColor: c.primaryContainer,
      selectedLabelTextStyle: TextStyle(fontFamily: _bodyFont, color: c.primary, fontWeight: FontWeight.w700),
      unselectedLabelTextStyle: TextStyle(fontFamily: _bodyFont, color: c.muted),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.primaryContainer,
      labelTextStyle: WidgetStateProperty.all(TextStyle(fontFamily: _bodyFont, fontSize: 12.5, color: c.text)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: c.primary,
      unselectedLabelColor: c.muted,
      indicatorColor: c.primary,
      dividerColor: c.outlineSoft,
      labelStyle: const TextStyle(fontFamily: _bodyFont, fontSize: 15, fontWeight: FontWeight.w700),
    ),
    listTileTheme: ListTileThemeData(iconColor: c.primary, textColor: c.text),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.outline),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.surfaceHigh, showDragHandle: true),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.surfaceHighest,
      contentTextStyle: TextStyle(fontFamily: _bodyFont, color: c.text, fontSize: 15),
    ),
    tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 500)),
    popupMenuTheme: PopupMenuThemeData(color: c.surfaceHigh),
    menuTheme: MenuThemeData(style: MenuStyle(backgroundColor: WidgetStatePropertyAll(c.surfaceHigh))),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(c.outline.withValues(alpha: 0.8)),
      radius: const Radius.circular(8),
    ),
  );
}

/// Constantes de espaciado.
class Gap {
  static const xs = SizedBox(width: 4, height: 4);
  static const s = SizedBox(width: 8, height: 8);
  static const m = SizedBox(width: 12, height: 12);
  static const l = SizedBox(width: 20, height: 20);
}
