import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/providers.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/theme.dart';
import 'core/i18n.dart';

class DndTrackerApp extends ConsumerWidget {
  const DndTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    // El idioma es global para tr(); al cambiarlo se reconstruye toda la app.
    I18n.language = profile.language;
    // Igual con el tema: los colores se leen de AppColors al construir.
    AppColors.palette = AppPalettes.of(profile.theme);
    final theme = buildTheme();
    return MaterialApp(
      key: ValueKey('${profile.language.name}-${profile.theme.name}'),
      title: 'DnD Tracker',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: AppColors.palette.isDark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(profile.language.name),
      supportedLocales: [const Locale('es'), const Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: profile.isComplete ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}
