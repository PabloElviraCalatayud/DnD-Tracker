import 'dart:convert';

import '../core/json.dart';
import '../core/text.dart';
import '../domain/character.dart';
import '../domain/icons.dart';
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
      save = asString(j['save']),
      nameEn = asString(j['name']);

  final String id;
  String name;
  final int level;
  String school;
  String time;
  String range;
  String components;
  String material;
  String duration;
  final bool concentration;
  final bool ritual;

  /// Clases en inglés (sirven para filtrar); [classLabels] es lo que se muestra.
  final List<String> classes;
  List<String> classLabels = const [];
  String description;
  String higher;
  final String damageType;
  final String save;

  /// Nombre en inglés y en castellano (para reconocer conjuros ya guardados).
  final String nameEn;
  String nameEs = '';

  void applyEs(Map<String, dynamic> o) {
    nameEs = asString(o['name'], name);
    name = nameEs;
    school = asString(o['school'], school);
    time = asString(o['time'], time);
    range = asString(o['range'], range);
    components = asString(o['components'], components);
    material = asString(o['material']);
    duration = asString(o['duration'], duration);
    description = asString(o['desc'], description);
    higher = asString(o['higher']);
    final cl = asStringList(o['classes']);
    if (cl.isNotEmpty) classLabels = cl;
  }

  List<String> get classesShown => classLabels.isEmpty ? classes : classLabels;

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
      quantity = asInt(j['qty'], 1),
      nameEn = asString(j['name']);

  final String id;
  String name;
  final String category;
  String subcategory;
  final int costCp;
  final double weight;
  String description;
  String damage;
  String damage2h;
  final String range;
  List<String> properties;
  final String armorClass;
  String mastery;
  final String nameEn;
  String nameEs = '';

  void applyEs(Map<String, dynamic> o) {
    nameEs = asString(o['name'], name);
    name = nameEs;
    description = asString(o['desc'], description);
    damage = asString(o['damage'], damage);
    damage2h = asString(o['damage2h'], damage2h);
    final p = asStringList(o['props']);
    if (p.isNotEmpty) properties = p;
    mastery = asString(o['mastery'], mastery);
    subcategory = asString(o['sub'], subcategory);
  }

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

  /// Icono según el tipo de objeto (se elige con el nombre inglés).
  String get icon => iconForItem(nameEn, category);

  InventoryItem toInventoryItem({int quantity = 1}) => InventoryItem(
    name: name,
    icon: icon,
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
  String name;
  String description;

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
  List<String> features;
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
      levels = asList(j['levels'], SrdClassLevel.fromJson),
      nameEn = asString(j['name']);

  final String id;
  String name;
  final String nameEn;
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
      items = asStringList(j['items']),
      label = asString(j['tool']);

  /// Nombre en inglés (para reconocer la competencia) y nombre a mostrar.
  final String tool;
  String label;
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
    this.spanish = false,
    this.names = const {},
  });

  /// ¿El contenido está en castellano (traducción oficial del SRD)?
  final bool spanish;

  /// Nombres de clases, especies, trasfondos… en ambos idiomas -> idioma actual.
  final Map<String, Map<String, String>> names;

  String _local(String kind, String name) {
    if (name.isEmpty) return name;
    return names[kind]?[name.trim().toLowerCase()] ?? name;
  }

  /// Traduce al idioma actual un nombre guardado del SRD (si no lo es, lo deja igual).
  String className(String name) => _local('class', name);
  String speciesName(String name) => _local('species', name);
  String backgroundName(String name) => _local('background', name);
  String languageNames(String text) =>
      text.split(',').map((x) => _local('language', x.trim())).where((x) => x.isNotEmpty).join(', ');

  SrdSpell? spellById(String? id) {
    if (id == null) return null;
    for (final s in spells) {
      if (s.id == id) return s;
    }
    return null;
  }

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
  factory SrdData.parse(Ruleset ruleset, Map<String, String> files, {bool spanish = false}) {
    List<dynamic> list(String name) {
      final raw = files[name];
      if (raw == null || raw.isEmpty) return const [];
      final v = jsonDecode(raw);
      return v is List ? v : const [];
    }

    final listsRaw = files['lists'];
    final lists = listsRaw == null ? <String, dynamic>{} : asMap(jsonDecode(listsRaw));
    final esRaw = files['es'];
    final es = esRaw == null || esRaw.isEmpty ? <String, dynamic>{} : asMap(jsonDecode(esRaw));
    Map<String, dynamic> esPart(String k) => es[k] is Map ? asMap(es[k]) : const {};
    final useEs = spanish && es.isNotEmpty;

    final monsters = list('monsters').map((e) => Monster.fromJson(asMap(e))).toList();
    final spells = list('spells').map((e) => SrdSpell.fromJson(asMap(e))).toList();
    final items = list('items').map((e) => SrdItem.fromJson(asMap(e))).toList();
    final conditions = list('conditions').map((e) => SrdCondition.fromJson(asMap(e))).toList();
    final classes = list('classes').map((e) => SrdClass.fromJson(asMap(e))).toList();
    final craft = list('craft').map((e) => CraftTool.fromJson(asMap(e))).toList();
    var rules = list('rules').map((e) => RulesChapter.fromJson(asMap(e))).toList();
    var feats = (lists['feats'] is List ? lists['feats'] as List : const [])
        .map((f) => Feat(asString(asMap(f)['name']), asString(asMap(f)['desc'])))
        .toList();
    final enLists = {
      for (final k in ['species', 'subspecies', 'backgrounds', 'languages']) k: asStringList(lists[k]),
    };
    final esListsRaw = esPart('lists');
    final esLists = {for (final k in enLists.keys) k: asStringList(esListsRaw[k])};

    // El icono se elige con el nombre inglés, antes de traducir.
    for (final m in monsters) {
      if (m.icon.isEmpty) m.icon = m.iconName;
    }
    // Ambos nombres de cada conjuro y objeto, para reconocer los ya guardados.
    final esSpells = esPart('spells');
    for (final s in spells) {
      final o = esSpells[s.id];
      if (o is Map) {
        if (useEs) {
          s.applyEs(asMap(o));
        } else {
          s.nameEs = asString(o['name']);
        }
      }
    }
    final esItems = esPart('items');
    for (final i in items) {
      final o = esItems[i.id];
      if (o is Map) {
        if (useEs) {
          i.applyEs(asMap(o));
        } else {
          i.nameEs = asString(o['name']);
        }
      }
    }
    final names = <String, Map<String, String>>{};
    void addNames(String kind, List<String> en, List<String> esl) {
      final m = names.putIfAbsent(kind, () => {});
      for (var i = 0; i < en.length && i < esl.length; i++) {
        final target = useEs ? esl[i] : en[i];
        m[en[i].toLowerCase()] = target;
        m[esl[i].toLowerCase()] = target;
      }
    }

    addNames(
      'species',
      [...enLists['species']!, ...enLists['subspecies']!],
      [...esLists['species']!, ...esLists['subspecies']!],
    );
    addNames('background', enLists['backgrounds']!, esLists['backgrounds']!);
    addNames('language', enLists['languages']!, esLists['languages']!);
    final esClasses = esPart('classes');
    addNames(
      'class',
      [for (final c in classes) c.nameEn],
      [for (final c in classes) asString(asMap(esClasses[c.id] ?? const {})['name'], c.nameEn)],
    );

    if (useEs) {
      final esMon = esPart('monsters');
      for (final m in monsters) {
        final o = esMon[m.id];
        if (o is! Map) continue;
        final j = asMap(o);
        List<NamedText>? nt(String k) => j[k] is List ? asList(j[k], NamedText.fromJson) : null;
        m
          ..name = asString(j['name'], m.name)
          ..size = asString(j['size'], m.size)
          ..type = asString(j['type'], m.type)
          ..alignment = asString(j['alignment'], m.alignment)
          ..acNote = asString(j['acNote'], m.acNote)
          ..speed = asString(j['speed'], m.speed)
          ..saves = asString(j['saves'], m.saves)
          ..skills = asString(j['skills'], m.skills)
          ..vulnerabilities = asString(j['vuln'], m.vulnerabilities)
          ..resistances = asString(j['res'], m.resistances)
          ..immunities = asString(j['imm'], m.immunities)
          ..conditionImmunities = asString(j['condImm'], m.conditionImmunities)
          ..senses = asString(j['senses'], m.senses)
          ..languages = asString(j['languages'], m.languages)
          ..traits = nt('traits') ?? m.traits
          ..actions = nt('actions') ?? m.actions
          ..bonusActions = nt('bonus') ?? m.bonusActions
          ..reactions = nt('reactions') ?? m.reactions
          ..legendary = nt('legendary') ?? m.legendary
          ..description = asString(j['desc'], m.description);
      }
      final esCond = esPart('conditions');
      for (final c in conditions) {
        final o = esCond[c.id];
        if (o is Map) {
          c
            ..name = asString(o['name'], c.name)
            ..description = asString(o['desc'], c.description);
        }
      }
      for (final c in classes) {
        final o = esClasses[c.id];
        if (o is! Map) continue;
        c.name = asString(o['name'], c.name);
        final feats = o['features'] is Map ? asMap(o['features']) : const <String, dynamic>{};
        for (final l in c.levels) {
          final f = asStringList(feats['${l.level}']);
          if (feats.isNotEmpty) l.features = f;
        }
      }
      final byEn = {for (final i in items) i.nameEn.toLowerCase(): i.name};
      for (final t in craft) {
        t.label = byEn[t.tool.toLowerCase()] ?? t.label;
      }
      final esRules = es['rules'];
      if (esRules is List && esRules.isNotEmpty) {
        rules = esRules.map((e) => RulesChapter.fromJson(asMap(e))).toList();
      }
      final esFeats = esListsRaw['feats'];
      if (esFeats is List && esFeats.length == feats.length) {
        feats = esFeats.map((f) => Feat(asString(asMap(f)['name']), asString(asMap(f)['desc']))).toList();
      }
    }
    monsters.sort((a, b) => _cmp(a.name, b.name));
    spells.sort((a, b) => a.level != b.level ? a.level.compareTo(b.level) : _cmp(a.name, b.name));
    items.sort((a, b) => _cmp(a.name, b.name));
    return SrdData(
      ruleset: ruleset,
      monsters: monsters,
      spells: spells,
      items: items,
      conditions: conditions,
      classes: classes,
      species: useEs ? esLists['species']! : enLists['species']!,
      subspecies: useEs ? esLists['subspecies']! : enLists['subspecies']!,
      backgrounds: useEs ? esLists['backgrounds']! : enLists['backgrounds']!,
      languages: useEs ? esLists['languages']! : enLists['languages']!,
      feats: feats,
      craftTools: craft,
      rules: rules,
      spanish: useEs,
      names: names,
    );
  }

  static const fileNames = ['monsters', 'spells', 'items', 'conditions', 'classes', 'lists', 'craft', 'rules', 'es'];

  SrdClass? classByName(String name) {
    final n = name.trim().toLowerCase();
    for (final c in classes) {
      if (c.name.toLowerCase() == n || c.nameEn.toLowerCase() == n || c.id == n) return c;
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

/// Orden alfabético sin tener en cuenta tildes ni mayúsculas.
int _cmp(String a, String b) => foldText(a).compareTo(foldText(b));

/// Muestra en el idioma actual los conjuros y objetos del SRD ya guardados en
/// una ficha (se copiaron en el idioma de quien los añadió). Si el jugador los
/// renombró, se respetan tal cual.
extension SrdLocalize on SrdData {
  CharacterSpell localizeSpell(CharacterSpell sp) {
    final src = spellById(sp.srdId);
    if (src == null || src.name == sp.name && sp.description == src.description) return sp;
    if (sp.name != src.nameEn && sp.name != src.nameEs) return sp;
    return CharacterSpell.fromJson(sp.toJson())
      ..name = src.name
      ..school = src.school
      ..castingTime = src.time
      ..range = src.range
      ..components = src.componentsFull
      ..duration = src.duration
      ..description = src.description
      ..higherLevels = src.higher;
  }

  InventoryItem localizeItem(InventoryItem it) {
    final src = itemById(it.srdId ?? '');
    if (src == null || src.name == it.name) return it;
    if (it.name != src.nameEn && it.name != src.nameEs) return it;
    final c = it.copy()..name = src.name;
    if (src.description.isNotEmpty) c.description = src.description;
    if (src.damage.isNotEmpty) c.damage = src.damage;
    if (src.propertiesText.isNotEmpty) c.properties = src.propertiesText;
    return c;
  }
}
