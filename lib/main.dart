import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/storage.dart';
import 'domain/profile.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final support = await getApplicationSupportDirectory();
  final storage = AppStorage(Directory('${support.path}${Platform.pathSeparator}dnd_tracker'));
  final profile = await storage.loadProfile() ?? UserProfile();
  runApp(
    ProviderScope(
      overrides: [storageProvider.overrideWithValue(storage), initialProfileProvider.overrideWithValue(profile)],
      child: const DndTrackerApp(),
    ),
  );
}
