import 'dart:convert';

import '../core/json.dart';
import '../domain/character.dart';
import '../domain/item.dart';
import '../domain/monster.dart';
import '../domain/ruleset.dart';
import '../core/i18n.dart';

class SrdSpell {
  SrdSpell.fromJson(Map<String, dynamic> j)
    : id = asString(j['id']),
      name = asString(j['name']),
      level = asInt(j['level']),
      school = asString(j['school']),
      time = asString(j['time']),
      range = asString(j['range']),
      components = asString(j['components']),
      material = asString(j['material']),
      duration = asString(j['duration']),
      concentration = asBool(j['conc']),
      ritual = asBool(j['ritual']),
      classes = asStringList(j['classes']),
      description = asString(j['desc']),
      higher = asString(j['higher']),
      damageType = asString(j['damageType']),
      save = asString(j['save']);

  final String id;
  final String name;
  final int level;
  final String school;
  final String time;
  final String range;
  final String components;
  final String material;
  final String duration;
  final bool concentration;
  final bool ritual;
  final List<String> classes;
  final String description;
  final String higher;
  final String damageType;
  final String save;

  String get componentsFull => material.isEmpty ? components : '$components ($material)';

  CharacterSpell toCharacterSpell({String sourceClass = ''}) => CharacterSpell(
    name: name,
    level: level,
    srdId: id,
    school: school,
    castingTime: time,
    range: range,
    components: componentsFull,
    duration: duration,
    concentration: concentration,
    ritual: ritual,
    description: description,
    higherLevels: higher,
    sourceClass: sourceClass,
  );
}

class SrdItem {
  SrdItem.fromJson(Map<String, dynamic> j)
    : id = asString(j['id']),
      name = asString(j['name']),
      category = asString(j['cat']),
      subcategory = asString(j['sub']),
      costCp = asInt(j['cost']),
      weight = asDouble(j['weight']),
      description = asString(j['desc']),
      damage = asString(j['damage']),
      damage2h = asString(j['damage2h']),
      range = asString(j['range']),
      properties = asStringList(j['props']),
      armorClass = asString(j['ac']),
      mastery = asString(j['mastery']),
      rarity = asString(j['rarity']),
      attunement = asBool(j['attune']),
      stealthDisadvantage = asBool(j['stealthDis']),
      strMinimum = asInt(j['strMin']),
      quantity = asInt(j['qty'], 1);

  final String id;
  final String name;
  final String category;
  final String subcategory;
  final int costCp;
  final double weight;
  final String description;
  final String damage;
  final String damage2h;
  final String range;
  final List<String> properties;
  final String armorClass;
  final String mastery;
  final String rarity;
  final bool attunement;
  final bool stealthDisadvantage;
  final int strMinimum;
  final int quantity;

  bool get isMagic => category == 'magic';

  String get propertiesText {
    final parts = <String>[
      ...properties,
      if (damage2h.isNotEmpty) tr('a dos manos {0}', [damage2h]),
      if (range.isNotEmpty) tr('alcance {0}', [range]),
      if (mastery.isNotEmpty) tr('maestría: {0}', [mastery]),
      if (stealthDisadvantage) tr('desventaja en Sigilo'),
      if (strMinimum > 0) tr('FUE {0}', [strMinimum]),
    ];
    return parts.join(', ');
  }

  InventoryItem toInventoryItem({int quantity = 1}) => InventoryItem(
    name: name,
    description: description,
    category: ItemCategory.fromSrd(category),
    quantity: quantity,
    weight: weight,
    valueCp: costCp,
    rarity: rarity,
    requiresAttunement: attunement,
    srdId: id,
    damage: damage,
    armorClass: armorClass,
    properties: propertiesText,
  );
}

class SrdCondition {
  SrdCondition.fromJson(Map<String, dynamic> j)
    : id = asString(j['id']),
      name = asString(j['name']),
      description = asString(j['desc']);

  final String id;
  final String name;
  final String description;

  String get label => conditionLabel(id);
}

class SrdClassLevel {
  SrdClassLevel.fromJson(Map<String, dynamic> j)
    : level = asInt(j['l']),
      proficiencyBonus = asInt(j['pb'], 2),
      features = asStringList(j['features']),
      cantrips = asIntOrNull(j['cantrips']),
      prepared = asIntOrNull(j['prepared']),
      known = asIntOrNull(j['known']),
      slots = j['slots'] is List ? (j['slots'] as List).map((e) => asInt(e)).toList() : null;

  final int level;
  final int proficiencyBonus;
  final List<String> features;
  final int? cantrips;
  final int? prepared;
  final int? known;
  final List<int>? slots;
}

class SrdClass {
  SrdClass.fromJson(Map<String, dynamic> j)
    : id = asString(j['id']),
      name = asString(j['name']),
      hitDie = asInt(j['hitDie'], 8),
      saves = asStringList(j['saves']),
      spellAbility = asStringOrNull(j['spellAbility']),
      levels = asList(j['levels'], SrdClassLevel.fromJson);

  final String id;
  final String name;
  final int hitDie;
  final List<String> saves;
  final String? spellAbility;
  final List<SrdClassLevel> levels;

  SrdClassLevel? level(int l) {
    for (final x in levels) {
      if (x.level == l) return x;
    }
    return null;
  }
}

class CraftTool {
  CraftTool.fromJson(Map<String, dynamic> j)
    : tool = asString(j['tool']),
      toolId = asString(j['toolId']),
      ability = asString(j['ability']),
      items = asStringList(j['items']);

  final String tool;
  final String toolId;
  final String ability;
  final List<String> items;
}

class RulesSection {
  RulesSection.fromJson(Map<String, dynamic> j)
    : id = asString(j['id']),
      name = asString(j['name']),
      description = asString(j['desc']);
  final String id;
  final String name;
  final String description;
}

class RulesChapter {
  RulesChapter.fromJson(Map<String, dynamic> j)
    : id = asString(j['id']),
      name = asString(j['name']),
      sections = asList(j['sections'], RulesSection.fromJson);
  final String id;
  final String name;
  final List<RulesSection> sections;
}

class Feat {
  Feat(this.name, this.description);
  final String name;
  final String description;
}

/// Todo el contenido SRD de una edición.
class SrdData {
  SrdData({
    required this.ruleset,
    required this.monsters,
    required this.spells,
    required this.items,
    required this.conditions,
    required this.classes,
    required this.species,
    required this.subspecies,
    required this.backgrounds,
    required this.languages,
    required this.feats,
    required this.craftTools,
    required this.rules,
  });

  final Ruleset ruleset;
  final List<Monster> monsters;
  final List<SrdSpell> spells;
  final List<SrdItem> items;
  final List<SrdCondition> conditions;
  final List<SrdClass> classes;
  final List<String> species;
  final List<String> subspecies;
  final List<String> backgrounds;
  final List<String> languages;
  final List<Feat> feats;
  final List<CraftTool> craftTools;
  final List<RulesChapter> rules;

  /// Lee los JSON generados por tool/build_srd.dart. [files] mapea el nombre
  /// del fichero (sin extensión) a su contenido.
  factory SrdData.parse(Ruleset ruleset, Map<String, String> files) {
    List<dynamic> list(String name) {
      final raw = files[name];
      if (raw == null || raw.isEmpty) return const [];
      final v = jsonDecode(raw);
      return v is List ? v : const [];
    }

    final listsRaw = files['lists'];
    final lists = listsRaw == null ? <String, dynamic>{} : asMap(jsonDecode(listsRaw));
    final monsters = list('monsters').map((e) => Monster.fromJson(asMap(e))).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final spells = list('spells').map((e) => SrdSpell.fromJson(asMap(e))).toList()
      ..sort((a, b) => a.level != b.level ? a.level.compareTo(b.level) : a.name.compareTo(b.name));
    final items = list('items').map((e) => SrdItem.fromJson(asMap(e))).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return SrdData(
      ruleset: ruleset,
      monsters: monsters,
      spells: spells,
      items: items,
      conditions: list('conditions').map((e) => SrdCondition.fromJson(asMap(e))).toList(),
      classes: list('classes').map((e) => SrdClass.fromJson(asMap(e))).toList(),
      species: asStringList(lists['species']),
      subspecies: asStringList(lists['subspecies']),
      backgrounds: asStringList(lists['backgrounds']),
      languages: asStringList(lists['languages']),
      feats: (lists['feats'] is List ? lists['feats'] as List : const [])
          .map((f) => Feat(asString(asMap(f)['name']), asString(asMap(f)['desc'])))
          .toList(),
      craftTools: list('craft').map((e) => CraftTool.fromJson(asMap(e))).toList(),
      rules: list('rules').map((e) => RulesChapter.fromJson(asMap(e))).toList(),
    );
  }

  static const fileNames = ['monsters', 'spells', 'items', 'conditions', 'classes', 'lists', 'craft', 'rules'];

  SrdClass? classByName(String name) {
    final n = name.trim().toLowerCase();
    for (final c in classes) {
      if (c.name.toLowerCase() == n || c.id == n) return c;
    }
    const es = {
      'bárbaro': 'barbarian',
      'barbaro': 'barbarian',
      'bardo': 'bard',
      'clérigo': 'cleric',
      'clerigo': 'cleric',
      'druida': 'druid',
      'guerrero': 'fighter',
      'monje': 'monk',
      'paladín': 'paladin',
      'paladin': 'paladin',
      'explorador': 'ranger',
      'pícaro': 'rogue',
      'picaro': 'rogue',
      'hechicero': 'sorcerer',
      'brujo': 'warlock',
      'mago': 'wizard',
    };
    final id = es[n];
    if (id == null) return null;
    for (final c in classes) {
      if (c.id == id) return c;
    }
    return null;
  }

  SrdItem? itemById(String id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  SrdCondition? condition(String id) {
    for (final c in conditions) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Herramientas de artesano (2024) que sirven para fabricar [itemId].
  List<CraftTool> toolsFor(String itemId) => craftTools.where((t) => t.items.contains(itemId)).toList();
}
