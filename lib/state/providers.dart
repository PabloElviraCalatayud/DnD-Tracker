import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/srd.dart';
import '../data/storage.dart';
import '../domain/campaign.dart';
import '../domain/profile.dart';
import '../domain/ruleset.dart';

/// Se sobrescriben en main() con los valores ya cargados.
final storageProvider = Provider<AppStorage>((ref) => throw UnimplementedError('storageProvider'));
final initialProfileProvider = Provider<UserProfile>((ref) => throw UnimplementedError('initialProfileProvider'));

class ProfileNotifier extends Notifier<UserProfile> {
  @override
  UserProfile build() => ref.read(initialProfileProvider);

  Future<void> save(UserProfile profile) async {
    state = profile;
    await ref.read(storageProvider).saveProfile(profile);
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, UserProfile>(ProfileNotifier.new);

final unitsProvider = Provider<Units>((ref) => Units(ref.watch(profileProvider).units));

/// Contenido SRD de cada edición, cargado de los assets en segundo plano.
final srdProvider = FutureProvider.family<SrdData, Ruleset>((ref, ruleset) async {
  final files = <String, String>{};
  for (final name in SrdData.fileNames) {
    try {
      files[name] = await rootBundle.loadString('assets/srd/${ruleset.srdFolder}/$name.json');
    } on Object {
      files[name] = '[]';
    }
  }
  return compute(_parseSrd, (ruleset, files));
});

SrdData _parseSrd((Ruleset, Map<String, String>) args) => SrdData.parse(args.$1, args.$2);

final hostedCampaignsProvider = FutureProvider<List<Campaign>>((ref) => ref.read(storageProvider).listHosted());

final joinedCampaignsProvider = FutureProvider<List<JoinedCampaign>>((ref) => ref.read(storageProvider).listJoined());
