import 'dart:math';

import '../core/i18n.dart';
import '../core/ids.dart';
import '../core/json.dart';
import 'abilities.dart';
import 'currency.dart';
import 'item.dart';
import 'ruleset.dart';
import 'srd_terms.dart';

class ClassLevel {
  ClassLevel({required this.name, this.subclass = '', this.level = 1, this.hitDie = 8, this.srdId});

  String name;
  String subclass;
  int level;
  int hitDie;
  String? srdId;

  Map<String, dynamic> toJson() => {
    'name': name,
    if (subclass.isNotEmpty) 'subclass': subclass,
    'level': level,
    'hitDie': hitDie,
    if (srdId != null) 'srdId': srdId,
  };

  factory ClassLevel.fromJson(Map<String, dynamic> j) => ClassLevel(
    name: asString(j['name'], 'Clase'),
    subclass: asString(j['subclass']),
    level: asInt(j['level'], 1),
    hitDie: asInt(j['hitDie'], 8),
    srdId: asStringOrNull(j['srdId']),
  );

  @override
  String toString() => subclass.isEmpty ? '${srdTerm(name)} $level' : '${srdTerm(name)} (${srdTerm(subclass)}) $level';
}

enum Recharge {
  none('Sin recarga'),
  shortRest('Descanso corto'),
  longRest('Descanso largo'),
  dawn('Al amanecer');

  const Recharge(this._label);
  final String _label;
  String get label => tr(_label);
}

/// Rasgo, dote o recurso con usos (Furia, Canalizar divinidad...).
class Feature {
  Feature({
    String? id,
    required this.name,
    this.description = '',
    this.maxUses,
    this.used = 0,
    this.recharge = Recharge.longRest,
    this.source = '',
  }) : id = id ?? newId();

  String id;
  String name;
  String description;
  int? maxUses;
  int used;
  Recharge recharge;
  String source;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (description.isNotEmpty) 'description': description,
    if (maxUses != null) 'maxUses': maxUses,
    if (used != 0) 'used': used,
    'recharge': recharge.name,
    if (source.isNotEmpty) 'source': source,
  };

  factory Feature.fromJson(Map<String, dynamic> j) => Feature(
    id: asString(j['id'], newId()),
    name: asString(j['name']),
    description: asString(j['description']),
    maxUses: asIntOrNull(j['maxUses']),
    used: asInt(j['used']),
    recharge: enumByName(Recharge.values, j['recharge'], Recharge.longRest),
    source: asString(j['source']),
  );
}

class Attack {
  Attack({String? id, required this.name, this.bonus = '', this.damage = '', this.notes = ''}) : id = id ?? newId();

  String id;
  String name;
  String bonus;
  String damage;
  String notes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'bonus': bonus,
    'damage': damage,
    if (notes.isNotEmpty) 'notes': notes,
  };

  factory Attack.fromJson(Map<String, dynamic> j) => Attack(
    id: asString(j['id'], newId()),
    name: asString(j['name']),
    bonus: asString(j['bonus']),
    damage: asString(j['damage']),
    notes: asString(j['notes']),
  );
}

class CharacterSpell {
  CharacterSpell({
    String? id,
    required this.name,
    this.level = 0,
    this.srdId,
    this.prepared = false,
    this.alwaysPrepared = false,
    this.school = '',
    this.castingTime = '',
    this.range = '',
    this.components = '',
    this.duration = '',
    this.concentration = false,
    this.ritual = false,
    this.description = '',
    this.higherLevels = '',
    this.sourceClass = '',
    this.notes = '',
  }) : id = id ?? newId();

  String id;
  String name;
  int level;
  String? srdId;
  bool prepared;
  bool alwaysPrepared;
  String school;
  String castingTime;
  String range;
  String components;
  String duration;
  bool concentration;
  bool ritual;
  String description;
  String higherLevels;
  String sourceClass;
  String notes;

  bool get isCantrip => level == 0;
  bool get isReady => isCantrip || prepared || alwaysPrepared;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'level': level,
    if (srdId != null) 'srdId': srdId,
    if (prepared) 'prepared': true,
    if (alwaysPrepared) 'alwaysPrepared': true,
    if (school.isNotEmpty) 'school': school,
    if (castingTime.isNotEmpty) 'castingTime': castingTime,
    if (range.isNotEmpty) 'range': range,
    if (components.isNotEmpty) 'components': components,
    if (duration.isNotEmpty) 'duration': duration,
    if (concentration) 'concentration': true,
    if (ritual) 'ritual': true,
    if (description.isNotEmpty) 'description': description,
    if (higherLevels.isNotEmpty) 'higherLevels': higherLevels,
    if (sourceClass.isNotEmpty) 'sourceClass': sourceClass,
    if (notes.isNotEmpty) 'notes': notes,
  };

  factory CharacterSpell.fromJson(Map<String, dynamic> j) => CharacterSpell(
    id: asString(j['id'], newId()),
    name: asString(j['name']),
    level: asInt(j['level']),
    srdId: asStringOrNull(j['srdId']),
    prepared: asBool(j['prepared']),
    alwaysPrepared: asBool(j['alwaysPrepared']),
    school: asString(j['school']),
    castingTime: asString(j['castingTime']),
    range: asString(j['range']),
    components: asString(j['components']),
    duration: asString(j['duration']),
    concentration: asBool(j['concentration']),
    ritual: asBool(j['ritual']),
    description: asString(j['description']),
    higherLevels: asString(j['higherLevels']),
    sourceClass: asString(j['sourceClass']),
    notes: asString(j['notes']),
  );
}

class SlotLevel {
  SlotLevel({this.max = 0, this.used = 0});
  int max;
  int used;

  int get available => (max - used).clamp(0, max);

  Map<String, dynamic> toJson() => {'max': max, 'used': used};
  factory SlotLevel.fromJson(Map<String, dynamic> j) => SlotLevel(max: asInt(j['max']), used: asInt(j['used']));
}

class Spellcasting {
  Spellcasting({
    this.ability,
    List<SlotLevel>? slots,
    this.pactSlotsMax = 0,
    this.pactSlotsUsed = 0,
    this.pactSlotLevel = 0,
    List<CharacterSpell>? spells,
    this.preparedLimit,
    this.saveDcBonus = 0,
    this.attackBonus = 0,
    this.concentratingOn = '',
  }) : slots = slots ?? List.generate(9, (_) => SlotLevel()),
       spells = spells ?? <CharacterSpell>[];

  Ability? ability;
  List<SlotLevel> slots;
  int pactSlotsMax;
  int pactSlotsUsed;
  int pactSlotLevel;
  List<CharacterSpell> spells;

  /// Límite de conjuros preparados escrito a mano (si es null se sugiere uno).
  int? preparedLimit;
  int saveDcBonus;
  int attackBonus;
  String concentratingOn;

  bool get hasSlots => slots.any((s) => s.max > 0) || pactSlotsMax > 0;

  int get preparedCount => spells.where((s) => !s.isCantrip && s.prepared && !s.alwaysPrepared).length;

  Map<String, dynamic> toJson() => {
    if (ability != null) 'ability': ability!.key,
    'slots': slots.map((s) => s.toJson()).toList(),
    if (pactSlotsMax > 0) 'pactSlotsMax': pactSlotsMax,
    if (pactSlotsUsed > 0) 'pactSlotsUsed': pactSlotsUsed,
    if (pactSlotLevel > 0) 'pactSlotLevel': pactSlotLevel,
    'spells': spells.map((s) => s.toJson()).toList(),
    if (preparedLimit != null) 'preparedLimit': preparedLimit,
    if (saveDcBonus != 0) 'saveDcBonus': saveDcBonus,
    if (attackBonus != 0) 'attackBonus': attackBonus,
    if (concentratingOn.isNotEmpty) 'concentratingOn': concentratingOn,
  };

  factory Spellcasting.fromJson(Map<String, dynamic> j) {
    final slots = asList(j['slots'], SlotLevel.fromJson);
    while (slots.length < 9) {
      slots.add(SlotLevel());
    }
    return Spellcasting(
      ability: Ability.byKey(asStringOrNull(j['ability'])),
      slots: slots.take(9).toList(),
      pactSlotsMax: asInt(j['pactSlotsMax']),
      pactSlotsUsed: asInt(j['pactSlotsUsed']),
      pactSlotLevel: asInt(j['pactSlotLevel']),
      spells: asList(j['spells'], CharacterSpell.fromJson),
      preparedLimit: asIntOrNull(j['preparedLimit']),
      saveDcBonus: asInt(j['saveDcBonus']),
      attackBonus: asInt(j['attackBonus']),
      concentratingOn: asString(j['concentratingOn']),
    );
  }
}

/// Fabricación en curso: los materiales ya se gastaron y faltan días de trabajo.
class CraftingProject {
  CraftingProject({
    String? id,
    required this.result,
    this.recipeId,
    this.daysRequired = 1,
    this.daysDone = 0,
    this.note = '',
    int? startedAt,
  }) : id = id ?? newId(),
       startedAt = startedAt ?? DateTime.now().millisecondsSinceEpoch;

  String id;
  InventoryItem result;
  String? recipeId;
  int daysRequired;
  int daysDone;
  String note;
  int startedAt;

  bool get done => daysDone >= daysRequired;
  double get progress => daysRequired <= 0 ? 1 : (daysDone / daysRequired).clamp(0, 1);

  Map<String, dynamic> toJson() => {
    'id': id,
    'result': result.toJson(),
    if (recipeId != null) 'recipeId': recipeId,
    'daysRequired': daysRequired,
    'daysDone': daysDone,
    if (note.isNotEmpty) 'note': note,
    'startedAt': startedAt,
  };

  factory CraftingProject.fromJson(Map<String, dynamic> j) => CraftingProject(
    id: asString(j['id'], newId()),
    result: InventoryItem.fromJson(asMap(j['result'])),
    recipeId: asStringOrNull(j['recipeId']),
    daysRequired: asInt(j['daysRequired'], 1),
    daysDone: asInt(j['daysDone']),
    note: asString(j['note']),
    startedAt: asIntOrNull(j['startedAt']),
  );
}

enum Encumbrance { none, encumbered, heavilyEncumbered, overCapacity }

/// Ficha de personaje. Los valores derivados (modificadores, bonificadores,
/// CD de conjuros, carga...) se calculan siempre a partir de los base.
class Character {
  Character({
    String? id,
    required this.ownerId,
    required this.name,
    List<ClassLevel>? classes,
    this.species = '',
    this.subspecies = '',
    this.background = '',
    this.alignment = '',
    this.xp = 0,
    Map<Ability, int>? abilities,
    Set<Ability>? saveProficiencies,
    Map<Skill, Proficiency>? skills,
    this.armorProficiencies = '',
    this.weaponProficiencies = '',
    List<String>? toolProficiencies,
    this.languages = '',
    this.hpMax = 10,
    this.hpCurrent = 10,
    this.hpTemp = 0,
    Map<int, int>? hitDiceUsed,
    this.deathSuccesses = 0,
    this.deathFailures = 0,
    this.armorClass = 10,
    this.initiativeBonus = 0,
    this.speed = 30,
    List<String>? conditions,
    this.exhaustion = 0,
    this.inspiration = false,
    Currency? currency,
    List<InventoryItem>? inventory,
    Spellcasting? spellcasting,
    List<Feature>? features,
    List<Attack>? attacks,
    List<CraftingProject>? projects,
    this.weaponMasteries = '',
    this.personality = '',
    this.ideals = '',
    this.bonds = '',
    this.flaws = '',
    this.appearance = '',
    this.backstory = '',
    this.portrait = 'hood',
    this.dmNotes = '',
    this.shareCurrency = false,
    this.isSummary = false,
    this.hpHidden = false,
    this.carryCapacityOverride,
    this.passivePerceptionBonus = 0,
    this.initiativeRoll,
  }) : id = id ?? newId(),
       classes = classes ?? <ClassLevel>[],
       abilities = abilities ?? {for (final a in Ability.values) a: 10},
       saveProficiencies = saveProficiencies ?? <Ability>{},
       skills = skills ?? <Skill, Proficiency>{},
       toolProficiencies = toolProficiencies ?? <String>[],
       hitDiceUsed = hitDiceUsed ?? <int, int>{},
       conditions = conditions ?? <String>[],
       currency = currency ?? Currency(),
       inventory = inventory ?? <InventoryItem>[],
       spellcasting = spellcasting ?? Spellcasting(),
       features = features ?? <Feature>[],
       attacks = attacks ?? <Attack>[],
       projects = projects ?? <CraftingProject>[];

  String id;
  String ownerId;
  String name;
  List<ClassLevel> classes;
  String species;
  String subspecies;
  String background;
  String alignment;
  int xp;
  Map<Ability, int> abilities;
  Set<Ability> saveProficiencies;
  Map<Skill, Proficiency> skills;
  String armorProficiencies;
  String weaponProficiencies;
  List<String> toolProficiencies;
  String languages;
  int hpMax;
  int hpCurrent;
  int hpTemp;

  /// Dados de golpe gastados por tamaño de dado (8 -> 2 significa 2d8 gastados).
  Map<int, int> hitDiceUsed;
  int deathSuccesses;
  int deathFailures;
  int armorClass;
  int initiativeBonus;
  int speed;
  List<String> conditions;
  int exhaustion;
  bool inspiration;
  Currency currency;
  List<InventoryItem> inventory;
  Spellcasting spellcasting;
  List<Feature> features;
  List<Attack> attacks;
  List<CraftingProject> projects;
  String weaponMasteries;
  String personality;
  String ideals;
  String bonds;
  String flaws;
  String appearance;
  String backstory;
  String portrait;

  /// Notas privadas del máster sobre el personaje (nunca se envían al jugador).
  String dmNotes;

  /// El jugador decide si el grupo ve su dinero.
  bool shareCurrency;

  /// true cuando es la versión resumida que ven los demás jugadores.
  bool isSummary;

  /// true si el máster no deja ver los PG de este personaje a los demás.
  bool hpHidden;
  double? carryCapacityOverride;
  int passivePerceptionBonus;

  /// Última tirada de iniciativa enviada por el jugador (para el rastreador).
  int? initiativeRoll;

  // ------------------------------------------------------------- Derivados

  int get level => classes.fold(0, (a, c) => a + c.level);
  int get proficiencyBonus => Rules.proficiencyBonus(max(1, level));

  String get classSummary => classes.isEmpty ? tr('Sin clase') : classes.map((c) => c.toString()).join(' / ');

  int score(Ability a) => abilities[a] ?? 10;
  int mod(Ability a) => Rules.abilityModifier(score(a));

  int saveBonus(Ability a) => mod(a) + (saveProficiencies.contains(a) ? proficiencyBonus : 0);

  Proficiency skillProficiency(Skill s) => skills[s] ?? Proficiency.none;

  int skillBonus(Skill s) => mod(s.ability) + skillProficiency(s).bonus(proficiencyBonus);

  int passive(Skill s) => 10 + skillBonus(s) + (s == Skill.perception ? passivePerceptionBonus : 0);

  int get initiative => mod(Ability.dex) + initiativeBonus;

  int get spellSaveDc {
    final a = spellcasting.ability;
    if (a == null) return 0;
    return 8 + proficiencyBonus + mod(a) + spellcasting.saveDcBonus;
  }

  int get spellAttackBonus {
    final a = spellcasting.ability;
    if (a == null) return 0;
    return proficiencyBonus + mod(a) + spellcasting.attackBonus;
  }

  /// Dados de golpe totales por tamaño de dado.
  Map<int, int> get hitDiceTotal {
    final out = <int, int>{};
    for (final c in classes) {
      out[c.hitDie] = (out[c.hitDie] ?? 0) + c.level;
    }
    return out;
  }

  int hitDiceAvailable(int die) => max(0, (hitDiceTotal[die] ?? 0) - (hitDiceUsed[die] ?? 0));

  bool get isDying => hpCurrent <= 0 && !isSummary;

  double get inventoryWeight => inventory.fold(0.0, (a, i) => a + (i.totalWeight ?? 0));

  double totalWeight({bool includeCoins = true}) => inventoryWeight + (includeCoins ? currency.weightLb : 0);

  /// Capacidad de carga (criatura mediana): FUE × 15 libras.
  double get carryCapacity => carryCapacityOverride ?? score(Ability.str) * 15.0;

  Encumbrance encumbrance({required bool variant, bool includeCoins = true}) {
    final w = totalWeight(includeCoins: includeCoins);
    final str = score(Ability.str);
    if (w > carryCapacity) return Encumbrance.overCapacity;
    if (variant) {
      if (w > str * 10) return Encumbrance.heavilyEncumbered;
      if (w > str * 5) return Encumbrance.encumbered;
    }
    return Encumbrance.none;
  }

  int get attunedCount => inventory.where((i) => i.attuned).length;

  // ------------------------------------------------------------- Acciones

  /// Aplica daño: primero a los PG temporales.
  void takeDamage(int amount) {
    if (amount <= 0) return;
    var rest = amount;
    if (hpTemp > 0) {
      final absorbed = min(hpTemp, rest);
      hpTemp -= absorbed;
      rest -= absorbed;
    }
    hpCurrent = max(0, hpCurrent - rest);
  }

  void heal(int amount, [Ruleset ruleset = Ruleset.v2024]) {
    if (amount <= 0) return;
    if (hpCurrent <= 0) {
      deathSuccesses = 0;
      deathFailures = 0;
    }
    hpCurrent = min(effectiveHpMax(ruleset), hpCurrent + amount);
  }

  /// En 2014 el cansancio 4 reduce a la mitad los PG máximos.
  int effectiveHpMax(Ruleset ruleset) => ruleset == Ruleset.v2014 && exhaustion >= 4 ? (hpMax / 2).floor() : hpMax;

  void shortRest() {
    for (final f in features) {
      if (f.recharge == Recharge.shortRest) f.used = 0;
    }
    spellcasting.pactSlotsUsed = 0;
  }

  void longRest(Ruleset ruleset) {
    final rules = Rules(ruleset);
    hpCurrent = effectiveHpMax(ruleset);
    hpTemp = 0;
    deathSuccesses = 0;
    deathFailures = 0;
    for (final s in spellcasting.slots) {
      s.used = 0;
    }
    spellcasting.pactSlotsUsed = 0;
    spellcasting.concentratingOn = '';
    for (final f in features) {
      if (f.recharge != Recharge.none) f.used = 0;
    }
    // Recupera dados de golpe empezando por los más grandes.
    final totals = hitDiceTotal;
    var toRecover = rules.hitDiceRecoveredOnLongRest(totals.values.fold(0, (a, b) => a + b));
    final dice = hitDiceUsed.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final d in dice) {
      final used = hitDiceUsed[d] ?? 0;
      final back = min(used, toRecover);
      hitDiceUsed[d] = used - back;
      toRecover -= back;
    }
    hitDiceUsed.removeWhere((_, v) => v <= 0);
    if (exhaustion > 0) exhaustion--;
    if (hpCurrent > effectiveHpMax(ruleset)) hpCurrent = effectiveHpMax(ruleset);
  }

  InventoryItem? itemById(String id) {
    for (final i in inventory) {
      if (i.id == id) return i;
    }
    return null;
  }

  /// Rellena los espacios de conjuro según las clases (tabla SRD para una
  /// sola clase, tabla multiclase si hay varias).
  void autoFillSlots(Ruleset ruleset, {List<int>? singleClassSlots}) {
    final rules = Rules(ruleset);
    var casterLevel = 0;
    var warlockLevel = 0;
    final casters = <ClassLevel>[];
    for (final c in classes) {
      final type = Rules.casterType(c.srdId ?? c.name, c.subclass);
      if (type == CasterType.pact) {
        warlockLevel += c.level;
      } else if (type != CasterType.none) {
        casters.add(c);
        casterLevel += rules.casterLevelContribution(type, c.level, c.srdId ?? c.name);
      }
    }
    final slots = (casters.length == 1 && singleClassSlots != null)
        ? singleClassSlots
        : Rules.slotsForCasterLevel(casterLevel);
    for (var i = 0; i < 9; i++) {
      final s = spellcasting.slots[i];
      s.max = i < slots.length ? slots[i] : 0;
      if (s.used > s.max) s.used = s.max;
    }
    final (count, lvl) = Rules.pactSlots(warlockLevel);
    spellcasting.pactSlotsMax = count;
    spellcasting.pactSlotLevel = lvl;
    if (spellcasting.pactSlotsUsed > count) spellcasting.pactSlotsUsed = count;
  }

  Character copy() => Character.fromJson(toJson());

  // ------------------------------------------------------------- JSON

  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'name': name,
    'classes': classes.map((c) => c.toJson()).toList(),
    'species': species,
    'subspecies': subspecies,
    'background': background,
    'alignment': alignment,
    'xp': xp,
    'abilities': {for (final e in abilities.entries) e.key.key: e.value},
    'saves': saveProficiencies.map((a) => a.key).toList(),
    'skills': {
      for (final e in skills.entries)
        if (e.value != Proficiency.none) e.key.name: e.value.name,
    },
    'armorProficiencies': armorProficiencies,
    'weaponProficiencies': weaponProficiencies,
    'toolProficiencies': toolProficiencies,
    'languages': languages,
    'hpMax': hpMax,
    'hpCurrent': hpCurrent,
    'hpTemp': hpTemp,
    'hitDiceUsed': {for (final e in hitDiceUsed.entries) '${e.key}': e.value},
    'deathSuccesses': deathSuccesses,
    'deathFailures': deathFailures,
    'armorClass': armorClass,
    'initiativeBonus': initiativeBonus,
    'speed': speed,
    'conditions': conditions,
    'exhaustion': exhaustion,
    'inspiration': inspiration,
    'currency': currency.toJson(),
    'inventory': inventory.map((i) => i.toJson()).toList(),
    'spellcasting': spellcasting.toJson(),
    'features': features.map((f) => f.toJson()).toList(),
    'attacks': attacks.map((a) => a.toJson()).toList(),
    'projects': projects.map((p) => p.toJson()).toList(),
    'weaponMasteries': weaponMasteries,
    'personality': personality,
    'ideals': ideals,
    'bonds': bonds,
    'flaws': flaws,
    'appearance': appearance,
    'backstory': backstory,
    'portrait': portrait,
    if (dmNotes.isNotEmpty) 'dmNotes': dmNotes,
    'shareCurrency': shareCurrency,
    if (isSummary) 'isSummary': true,
    if (hpHidden) 'hpHidden': true,
    if (carryCapacityOverride != null) 'carryCapacityOverride': carryCapacityOverride,
    if (passivePerceptionBonus != 0) 'passivePerceptionBonus': passivePerceptionBonus,
    if (initiativeRoll != null) 'initiativeRoll': initiativeRoll,
  };

  factory Character.fromJson(Map<String, dynamic> j) {
    final ab = asMap(j['abilities']);
    final skillsJson = asMap(j['skills']);
    final hd = asMap(j['hitDiceUsed']);
    return Character(
      id: asString(j['id'], newId()),
      ownerId: asString(j['ownerId']),
      name: asString(j['name'], 'Sin nombre'),
      classes: asList(j['classes'], ClassLevel.fromJson),
      species: asString(j['species']),
      subspecies: asString(j['subspecies']),
      background: asString(j['background']),
      alignment: asString(j['alignment']),
      xp: asInt(j['xp']),
      abilities: {for (final a in Ability.values) a: asInt(ab[a.key], 10)},
      saveProficiencies: asStringList(j['saves']).map(Ability.byKey).whereType<Ability>().toSet(),
      skills: {
        for (final s in Skill.values)
          if (skillsJson[s.name] != null) s: enumByName(Proficiency.values, skillsJson[s.name], Proficiency.none),
      },
      armorProficiencies: asString(j['armorProficiencies']),
      weaponProficiencies: asString(j['weaponProficiencies']),
      toolProficiencies: asStringList(j['toolProficiencies']),
      languages: asString(j['languages']),
      hpMax: asInt(j['hpMax'], 10),
      hpCurrent: asInt(j['hpCurrent'], 10),
      hpTemp: asInt(j['hpTemp']),
      hitDiceUsed: {for (final e in hd.entries) asInt(e.key): asInt(e.value)},
      deathSuccesses: asInt(j['deathSuccesses']),
      deathFailures: asInt(j['deathFailures']),
      armorClass: asInt(j['armorClass'], 10),
      initiativeBonus: asInt(j['initiativeBonus']),
      speed: asInt(j['speed'], 30),
      conditions: asStringList(j['conditions']),
      exhaustion: asInt(j['exhaustion']),
      inspiration: asBool(j['inspiration']),
      currency: Currency.fromJson(asMap(j['currency'])),
      inventory: asList(j['inventory'], InventoryItem.fromJson),
      spellcasting: Spellcasting.fromJson(asMap(j['spellcasting'])),
      features: asList(j['features'], Feature.fromJson),
      attacks: asList(j['attacks'], Attack.fromJson),
      projects: asList(j['projects'], CraftingProject.fromJson),
      weaponMasteries: asString(j['weaponMasteries']),
      personality: asString(j['personality']),
      ideals: asString(j['ideals']),
      bonds: asString(j['bonds']),
      flaws: asString(j['flaws']),
      appearance: asString(j['appearance']),
      backstory: asString(j['backstory']),
      portrait: asString(j['portrait'], 'hood'),
      dmNotes: asString(j['dmNotes']),
      shareCurrency: asBool(j['shareCurrency']),
      isSummary: asBool(j['isSummary']),
      hpHidden: asBool(j['hpHidden']),
      carryCapacityOverride: asDoubleOrNull(j['carryCapacityOverride']),
      passivePerceptionBonus: asInt(j['passivePerceptionBonus']),
      initiativeRoll: asIntOrNull(j['initiativeRoll']),
    );
  }
}
