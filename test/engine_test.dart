import 'dart:math';

import 'package:dnd_tracker/core/dice.dart';
import 'package:dnd_tracker/data/demo.dart';
import 'package:dnd_tracker/domain/abilities.dart';
import 'package:dnd_tracker/domain/campaign.dart';
import 'package:dnd_tracker/domain/character.dart';
import 'package:dnd_tracker/domain/currency.dart';
import 'package:dnd_tracker/domain/item.dart';
import 'package:dnd_tracker/domain/recipe.dart';
import 'package:dnd_tracker/domain/ruleset.dart';
import 'package:dnd_tracker/engine/campaign_engine.dart';
import 'package:dnd_tracker/engine/commands.dart';
import 'package:dnd_tracker/engine/crafting.dart';
import 'package:dnd_tracker/engine/view_filter.dart';
import 'package:dnd_tracker/net/invite.dart';
import 'package:flutter_test/flutter_test.dart';

const dm = Actor(userId: 'dm', name: 'Máster', isDm: true);
const ana = Actor(userId: 'demo-ana', name: 'Ana', isDm: false);
const luis = Actor(userId: 'demo-luis', name: 'Luis', isDm: false);
const marta = Actor(userId: 'demo-marta', name: 'Marta', isDm: false);

void main() {
  late Campaign campaign;
  late CampaignEngine engine;

  Character byName(String n) => campaign.characters.firstWhere((c) => c.name.startsWith(n));

  setUp(() {
    campaign = buildDemoCampaign(dmUserId: 'dm', dmName: 'Máster');
    engine = CampaignEngine(campaign);
  });

  group('permisos', () {
    test('un jugador no puede editar el personaje de otro', () {
      final brom = byName('Brom').copy()..hpCurrent = 1;
      final r = engine.apply(Command.putCharacter(brom), luis);
      expect(r.ok, isFalse);
      expect(byName('Brom').hpCurrent, isNot(1));
    });

    test('sólo el máster gestiona monstruos, notas y ajustes', () {
      expect(engine.apply(Command.putSettings(CampaignSettings()), luis).ok, isFalse);
      expect(engine.apply(Command.deleteNote(campaign.notes.first.id), luis).ok, isFalse);
      expect(engine.apply(Command.putSettings(CampaignSettings(hideItemValues: true)), dm).ok, isTrue);
      expect(campaign.settings.hideItemValues, isTrue);
    });

    test('un jugador que crea un personaje queda como dueño aunque intente otra cosa', () {
      final pc = Character(ownerId: 'otro', name: 'Nuevo', dmNotes: 'trampa');
      expect(engine.apply(Command.putCharacter(pc), luis).ok, isTrue);
      final saved = campaign.character(pc.id)!;
      expect(saved.ownerId, 'demo-luis');
      expect(saved.dmNotes, isEmpty);
    });

    test('cada cambio aumenta la revisión', () {
      final before = campaign.revision;
      engine.apply(Command.putNote(CampaignNote(title: 'x')), dm);
      expect(campaign.revision, before + 1);
    });
  });

  group('datos ocultos', () {
    test('el jugador no ve peso/valor ocultos ni notas del máster', () {
      final view = ViewFilter.forPlayer(campaign, 'demo-luis');
      final ring = view.characters
          .firstWhere((c) => c.ownerId == 'demo-luis')
          .inventory
          .firstWhere((i) => i.rarity.isNotEmpty);
      expect(ring.weight, isNull);
      expect(ring.valueCp, isNull);
      expect(ring.dmNote, isEmpty);
      expect(view.monsters, isEmpty);
      expect(view.itemLibrary, isEmpty);
      expect(view.joinCode, isEmpty);
      expect(view.notes.every((n) => n.shared), isTrue);
    });

    test('al guardar su ficha el jugador no puede destapar ni borrar lo oculto', () {
      final view = ViewFilter.forPlayer(campaign, 'demo-luis');
      final mine = view.characters.firstWhere((c) => c.ownerId == 'demo-luis');
      final ring = mine.inventory.firstWhere((i) => i.rarity.isNotEmpty);
      ring
        ..visibility = ItemVisibility.some
        ..visibleTo = ['demo-ana']
        ..hideValue = false
        ..valueCp = 1;
      expect(engine.apply(Command.putCharacter(mine), luis).ok, isTrue);
      final stored = campaign.character(mine.id)!.inventory.firstWhere((i) => i.id == ring.id);
      expect(stored.shared, isTrue, reason: 'la visibilidad la decide el jugador');
      expect(stored.hideValue, isTrue);
      expect(stored.valueCp, 50000);
      expect(stored.dmNote, isNotEmpty);
    });

    test('los compañeros sólo ven los objetos compartidos y el dinero si lo comparten', () {
      final view = ViewFilter.forPlayer(campaign, 'demo-ana');
      final lyra = view.characters.firstWhere((c) => c.ownerId == 'demo-luis');
      final kesh = view.characters.firstWhere((c) => c.ownerId == 'demo-marta');
      expect(lyra.isSummary, isTrue);
      expect(lyra.inventory.every((i) => i.shared), isTrue);
      expect(lyra.currency.totalCp, greaterThan(0), reason: 'Lyra comparte su dinero');
      expect(kesh.currency.totalCp, 0);
      expect(kesh.toolProficiencies, isEmpty, reason: 'el resumen no incluye la ficha completa');
    });

    test('los monstruos ocultos no aparecen en el combate de los jugadores', () {
      final e = ViewFilter.encounterFor(campaign, 'demo-ana');
      expect(e.combatants.any((c) => c.hidden), isFalse);
      final knight = e.combatants.firstWhere((c) => c.name.startsWith('Caballero'));
      expect(knight.hp, isNull);
      expect(knight.ac, isNull);
    });
  });

  group('intercambios', () {
    test('dar parte de un montón de objetos', () {
      final kesh = byName('Kesh');
      final herb = kesh.inventory.firstWhere((i) => i.name == 'Hierba de sangre');
      final r = engine.apply(Command.transferItem(kesh.id, byName('Brom').id, herb.id, 2), marta);
      expect(r.ok, isTrue);
      expect(byName('Kesh').inventory.firstWhere((i) => i.name == 'Hierba de sangre').quantity, 3);
      expect(byName('Brom').inventory.firstWhere((i) => i.name == 'Hierba de sangre').quantity, 2);
    });

    test('no se puede dar dinero que no se tiene', () {
      final r = engine.apply(Command.transferCurrency(byName('Kesh').id, byName('Brom').id, Currency(pp: 5)), marta);
      expect(r.ok, isFalse);
    });

    test('el máster puede desactivar los intercambios', () {
      engine.apply(Command.putSettings(CampaignSettings(playersCanTrade: false)), dm);
      final kesh = byName('Kesh');
      final r = engine.apply(Command.transferCurrency(kesh.id, byName('Brom').id, Currency(gp: 1)), marta);
      expect(r.ok, isFalse);
    });
  });

  group('artesanía', () {
    Recipe potion() => campaign.recipes.firstWhere((r) => r.name.startsWith('Poción'));

    test('comprueba materiales por nombre y por etiqueta', () {
      final check = Crafting.check(byName('Kesh'), potion());
      expect(check.canCraft, isTrue);
      expect(check.maxTimes, 2, reason: '5 hierbas / 2 = 2, 3 viales, 88 po / 5 po');
      expect(check.toolOk, isTrue);
      final bomb = campaign.recipes.firstWhere((r) => r.name == 'Bomba de humo');
      final c2 = Crafting.check(byName('Kesh'), bomb);
      expect(c2.canCraft, isFalse);
      expect(c2.missing.single.ingredient.name, 'Azufre');
    });

    test('fabricar consume materiales y oro y añade el resultado', () {
      final kesh = byName('Kesh');
      final goldBefore = kesh.currency.totalCp;
      final r = engine.apply(Command.craftRecipe(kesh.id, potion().id, 2), marta);
      expect(r.ok, isTrue, reason: r.error);
      final after = byName('Kesh');
      expect(after.inventory.firstWhere((i) => i.name == 'Hierba de sangre').quantity, 1);
      expect(after.inventory.firstWhere((i) => i.name == 'Vial vacío').quantity, 1);
      expect(after.inventory.firstWhere((i) => i.name == 'Poción de curación menor').quantity, 2);
      expect(after.currency.totalCp, goldBefore - 1000);
    });

    test('quien no conoce la receta no puede usarla', () {
      final brom = byName('Brom');
      expect(engine.apply(Command.craftRecipe(brom.id, potion().id, 1), ana).ok, isFalse);
    });

    test('fabricación estándar con días crea un proyecto que se completa', () {
      final kesh = byName('Kesh');
      final item = InventoryItem(name: 'Antitoxina', weight: 0, valueCp: 5000);
      final days = campaign.rules.craftingDays(5000);
      expect(days, 5, reason: '2024: 50 po / 10 po por día');
      expect(engine.apply(Command.craftStandard(kesh.id, item, 2500, days), marta).ok, isTrue);
      final project = byName('Kesh').projects.single;
      engine.apply(Command.craftProgress(kesh.id, project.id, 3), marta);
      expect(byName('Kesh').projects.single.daysDone, 3);
      engine.apply(Command.craftProgress(kesh.id, project.id, 2), marta);
      expect(byName('Kesh').projects, isEmpty);
      expect(byName('Kesh').inventory.any((i) => i.name == 'Antitoxina'), isTrue);
    });
  });

  group('reglas por edición', () {
    test('descanso largo: 2014 recupera la mitad de los dados de golpe, 2024 todos', () {
      final c = Character(
        ownerId: 'x',
        name: 'x',
        classes: [ClassLevel(name: 'Fighter', level: 6, hitDie: 10)],
      );
      c.hitDiceUsed = {10: 6};
      c.copy().longRest(Ruleset.v2024);
      final c24 = c.copy()..longRest(Ruleset.v2024);
      final c14 = c.copy()..longRest(Ruleset.v2014);
      expect(c24.hitDiceAvailable(10), 6);
      expect(c14.hitDiceAvailable(10), 3);
    });

    test('cansancio 2024 resta 2 por nivel a las pruebas de d20', () {
      expect(const Rules(Ruleset.v2024).exhaustionD20Penalty(3), -6);
      expect(const Rules(Ruleset.v2014).exhaustionD20Penalty(3), 0);
    });

    test('espacios de conjuro multiclase', () {
      final c = Character(
        ownerId: 'x',
        name: 'x',
        classes: [
          ClassLevel(name: 'Wizard', level: 3),
          ClassLevel(name: 'Paladin', level: 3),
        ],
      );
      c.autoFillSlots(Ruleset.v2014);
      // Nivel de lanzador 3 + 1 = 4 → 4/3.
      expect(c.spellcasting.slots.take(2).map((s) => s.max), [4, 3]);
      c.autoFillSlots(Ruleset.v2024);
      // 2024 redondea hacia arriba la mitad del paladín: 3 + 2 = 5 → 4/3/2.
      expect(c.spellcasting.slots.take(3).map((s) => s.max), [4, 3, 2]);
    });

    test('brujo: espacios de pacto', () {
      expect(Rules.pactSlots(1), (1, 1));
      expect(Rules.pactSlots(5), (2, 3));
      expect(Rules.pactSlots(11), (3, 5));
    });

    test('dificultad de encuentro 2014 con multiplicador', () {
      const r = Rules(Ruleset.v2014);
      final thresholds = r.partyThresholds([3, 3, 3, 3]);
      expect(thresholds, [300, 600, 900, 1600]);
      expect(r.adjustedXp([50, 50, 50, 50], 4), 400);
      expect(r.difficultyFor(400, thresholds), 'Fácil');
    });

    test('derivados de la ficha', () {
      final c = Character(
        ownerId: 'x',
        name: 'x',
        classes: [ClassLevel(name: 'Rogue', level: 5)],
      );
      c.abilities[Ability.dex] = 18;
      c.skills[Skill.stealth] = Proficiency.expertise;
      expect(c.proficiencyBonus, 3);
      expect(c.skillBonus(Skill.stealth), 4 + 6);
      expect(c.passive(Skill.perception), 10);
    });

    test('el daño consume primero los PG temporales', () {
      final c = Character(ownerId: 'x', name: 'x', hpMax: 20, hpCurrent: 20, hpTemp: 5)..takeDamage(8);
      expect(c.hpTemp, 0);
      expect(c.hpCurrent, 17);
    });
  });

  group('utilidades', () {
    test('dados', () {
      final roller = DiceRoller(Random(1));
      for (var i = 0; i < 200; i++) {
        final r = roller.roll('2d6+3');
        expect(r.total, inInclusiveRange(5, 15));
      }
      final adv = roller.roll('2d20kh1');
      expect(adv.parts.single.kept.single, adv.parts.single.rolls.reduce(max));
      expect(() => roller.roll('2x6'), throwsFormatException);
      expect(averageOf('18d10+36'), 135);
    });

    test('monedas: pagar y dar cambio', () {
      final c = Currency(gp: 10);
      expect(c.pay(250), isTrue);
      expect(c.totalCp, 750);
      expect(c.gp, 7);
      expect(c.sp, 5);
      expect(Currency(sp: 2).pay(100), isFalse);
      expect(parseCost('15 po'), 1500);
      expect(parseCost('3 pp'), 30);
      expect(parseCost('2,5'), 250);
      expect(formatCp(1234), '12 po 3 pp 4 pc');
    });

    test('invitaciones dentro de un mensaje de WhatsApp', () {
      final inv = Invite(
        campaignId: 'abc123',
        campaignName: 'Mi partida',
        code: 'QWERTY',
        hosts: ['192.168.1.10', '100.64.0.7'],
        relayUrl: 'wss://relay.example.com',
      );
      final text = 'Hola!\n${inv.shareText()}\nNos vemos';
      final parsed = Invite.tryParse(text)!;
      expect(parsed.campaignId, 'abc123');
      expect(parsed.hosts, ['192.168.1.10', '100.64.0.7']);
      expect(parsed.candidates.length, 3);
      expect(parsed.candidates.last.toString(), 'wss://relay.example.com/join?room=abc123');
      expect(Invite.tryParse('nada por aquí'), isNull);
    });

    test('la partida sobrevive a guardar y cargar', () {
      final again = Campaign.fromJson(campaign.toJson());
      expect(again.toJson(), campaign.toJson());
    });
  });
}
