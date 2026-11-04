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
    return MaterialApp(
      title: tr('DnD Tracker'),
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      darkTheme: buildTheme(),
      themeMode: ThemeMode.dark,
      locale: const Locale('es'),
      supportedLocales: [const Locale('es'), const Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: profile.isComplete ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}
