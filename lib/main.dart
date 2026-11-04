import 'dart:io';

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/i18n.dart';
import 'data/storage.dart';
import 'domain/profile.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final support = await getApplicationSupportDirectory();
  final storage = AppStorage(Directory('${support.path}${Platform.pathSeparator}dnd_tracker'));
  final profile =
      await storage.loadProfile() ??
      UserProfile(
        // Primera vez: castellano si el sistema está en español, si no inglés.
        language: PlatformDispatcher.instance.locale.languageCode == 'es' ? AppLanguage.es : AppLanguage.en,
      );
  runApp(
    ProviderScope(
      overrides: [storageProvider.overrideWithValue(storage), initialProfileProvider.overrideWithValue(profile)],
      child: const DndTrackerApp(),
    ),
  );
}
