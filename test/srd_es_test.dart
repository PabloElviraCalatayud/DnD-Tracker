import 'dart:io';

import 'package:dnd_tracker/core/i18n.dart';
import 'package:dnd_tracker/data/srd.dart';
import 'package:dnd_tracker/domain/character.dart';
import 'package:dnd_tracker/domain/ruleset.dart';
import 'package:dnd_tracker/domain/srd_terms.dart';
import 'package:flutter_test/flutter_test.dart';

SrdData load(Ruleset rs, {required bool spanish}) {
  final files = <String, String>{};
  for (final name in SrdData.fileNames) {
    final f = File('assets/srd/${rs.srdFolder}/$name.json');
    files[name] = f.existsSync() ? f.readAsStringSync() : '[]';
  }
  return SrdData.parse(rs, files, spanish: spanish);
}

void main() {
  tearDown(() => I18n.language = AppLanguage.es);

  for (final rs in Ruleset.values) {
    test('SRD ${rs.srdFolder} en castellano: todo traducido', () {
      final es = load(rs, spanish: true);
      final en = load(rs, spanish: false);
      expect(es.spanish, isTrue);
      expect(en.spanish, isFalse);
      // Cada conjuro, criatura y objeto tiene nombre en castellano.
      final untranslatedSpells = es.spells.where((s) => s.nameEs.isEmpty).map((s) => s.nameEn).toList();
      expect(untranslatedSpells, isEmpty);
      final untranslatedItems = es.items.where((i) => i.nameEs.isEmpty).map((i) => i.nameEn).toList();
      expect(untranslatedItems, isEmpty);
      final enMon = {for (final m in en.monsters) m.id: m.name};
      final sameName = es.monsters.where((m) => m.name == enMon[m.id] && m.name.contains(' ')).toList();
      expect(sameName.length, lessThan(5), reason: sameName.map((m) => m.name).join(', '));
      // Estados, clases y reglas.
      expect(es.condition('blinded')!.name, 'Cegado');
      expect(es.classByName('wizard')!.name, 'Mago');
      expect(es.classByName('Mago')!.id, 'wizard');
      expect(es.rules, isNotEmpty);
      // Los iconos se eligen con el nombre inglés.
      final dragonEs = es.monsters.firstWhere((m) => m.id.contains('red-dragon'));
      expect(dragonEs.icon, 'dragon');
    });
  }

  test('las fichas guardadas en inglés se muestran en castellano y viceversa', () {
    final es = load(Ruleset.v2024, spanish: true);
    final en = load(Ruleset.v2024, spanish: false);
    final sp = CharacterSpell(name: 'Magic Missile', srdId: 'magic-missile', level: 1);
    expect(es.localizeSpell(sp).name, 'Proyectil mágico');
    expect(es.localizeSpell(sp).id, sp.id);
    final spEs = CharacterSpell(name: 'Proyectil mágico', srdId: 'magic-missile', level: 1);
    expect(en.localizeSpell(spEs).name, 'Magic Missile');
    final renamed = CharacterSpell(name: 'Mi proyectil', srdId: 'magic-missile', level: 1);
    expect(es.localizeSpell(renamed).name, 'Mi proyectil');
    expect(srdTerm('Wizard'), 'Mago');
    I18n.language = AppLanguage.en;
    expect(srdTerm('Mago'), 'Wizard');
    expect(srdTerm('Mi clase'), 'Mi clase');
  });
}
