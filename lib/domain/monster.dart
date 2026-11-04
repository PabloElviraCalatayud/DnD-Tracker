import '../core/ids.dart';
import '../core/json.dart';
import 'abilities.dart';
import 'ruleset.dart';

class NamedText {
  NamedText(this.name, this.text);
  String name;
  String text;

  Map<String, dynamic> toJson() => {'n': name, 'd': text};
  factory NamedText.fromJson(Map<String, dynamic> j) => NamedText(asString(j['n']), asString(j['d']));
}

/// Bloque de estadísticas de una criatura. Se usa tanto para el SRD como
/// para los monstruos personalizados del máster (mismo formato JSON).
class Monster {
  Monster({
    String? id,
    required this.name,
    this.size = 'Medium',
    this.type = '',
    this.alignment = '',
    this.ac = 10,
    this.acNote = '',
    this.hp = 1,
    this.hitDice = '',
    this.speed = '30 ft.',
    List<int>? abilities,
    this.saves = '',
    this.skills = '',
    this.vulnerabilities = '',
    this.resistances = '',
    this.immunities = '',
    this.conditionImmunities = '',
    this.senses = '',
    this.languages = '',
    this.cr = 0,
    this.crText = '0',
    this.xp = 0,
    List<NamedText>? traits,
    List<NamedText>? actions,
    List<NamedText>? bonusActions,
    List<NamedText>? reactions,
    List<NamedText>? legendary,
    this.description = '',
    this.custom = false,
    this.icon = '',
  }) : id = id ?? newId(),
       abilities = abilities ?? List.filled(6, 10),
       traits = traits ?? [],
       actions = actions ?? [],
       bonusActions = bonusActions ?? [],
       reactions = reactions ?? [],
       legendary = legendary ?? [];

  String id;
  String name;
  String size;
  String type;
  String alignment;
  int ac;
  String acNote;
  int hp;
  String hitDice;
  String speed;
  List<int> abilities;
  String saves;
  String skills;
  String vulnerabilities;
  String resistances;
  String immunities;
  String conditionImmunities;
  String senses;
  String languages;
  double cr;
  String crText;
  int xp;
  List<NamedText> traits;
  List<NamedText> actions;
  List<NamedText> bonusActions;
  List<NamedText> reactions;
  List<NamedText> legendary;
  String description;
  bool custom;
  String icon;

  int score(Ability a) => abilities[Ability.values.indexOf(a)];
  int mod(Ability a) => Rules.abilityModifier(score(a));

  /// Icono aproximado según el tipo de criatura.
  String get iconName {
    if (icon.isNotEmpty) return icon;
    final t = type.toLowerCase();
    final n = name.toLowerCase();
    bool any(String text, List<String> words) => words.any(text.contains);
    // Primero por nombre (más concreto), luego por tipo.
    const byName = <String, List<String>>{
      'beholder': ['beholder', 'contemplador'],
      'wyvern': ['wyvern', 'guiverno'],
      'spiked_dragon': ['dracolich', 'ancient', 'anciano'],
      'dragon': ['dragon', 'dragón', 'wyrm'],
      'goblin': ['goblin', 'trasgo', 'bugbear', 'osgo', 'hobgoblin', 'kobold'],
      'orc': ['orc', 'orco'],
      'troll': ['troll', 'trol'],
      'ogre': ['ogre', 'ogro'],
      'cyclops': ['cyclops', 'cíclope'],
      'werewolf': [
        'werewolf',
        'hombre lobo',
        'weretiger',
        'hombre tigre',
        'wererat',
        'hombre rata',
        'werebear',
        'hombre oso',
        'wereboar',
        'hombre jabalí',
      ],
      'wolf': ['wolf', 'worg', 'lobo', 'jackal', 'chacal', 'dog', 'perro', 'mastiff', 'mastín', 'hyena', 'hiena'],
      'bear': ['bear', 'oso'],
      'rat': ['rat', 'rata'],
      'bat': ['bat', 'murciélago'],
      'spider': ['spider', 'araña', 'ettercap', 'phase spider'],
      'scorpion': ['scorpion', 'escorpión'],
      'centipede': ['centipede', 'ciempiés'],
      'wasp': ['wasp', 'avispa', 'bee', 'abeja'],
      'beetle': ['beetle', 'escarabajo'],
      'insect': ['insect', 'insecto', 'ankheg', 'stirge', 'estirge'],
      'crab': ['crab', 'cangrejo'],
      'shark': ['shark', 'tiburón', 'quipper', 'piraña'],
      'octopus': ['octopus', 'pulpo', 'kraken'],
      'cobra': ['cobra', 'naga'],
      'snake': ['snake', 'serpiente', 'constrictor'],
      'frog': ['frog', 'toad', 'rana', 'sapo'],
      'lizardman': ['lizardfolk', 'hombre lagarto', 'troglodyte', 'troglodita'],
      'horned_reptile': ['lizard', 'lagarto', 'crocodile', 'cocodrilo', 'basilisk', 'basilisco', 'behir'],
      'dinosaur': ['tyrannosaurus', 'tiranosaurio', 'triceratops', 'plesiosaurus', 'dinosaur'],
      'eagle': ['eagle', 'águila', 'hawk', 'halcón', 'owl', 'búho', 'raven', 'cuervo', 'vulture', 'buitre', 'roc'],
      'griffin': ['griffon', 'grifo', 'hippogriff', 'hipogrifo'],
      'harpy': ['harpy', 'arpía'],
      'horse': ['horse', 'caballo', 'pony', 'poni', 'mule', 'mula', 'nightmare', 'pesadilla', 'pegasus', 'pegaso'],
      'unicorn': ['unicorn', 'unicornio'],
      'centaur': ['centaur', 'centauro'],
      'minotaur': ['minotaur', 'minotauro'],
      'sphinx': ['sphinx', 'esfinge'],
      'medusa': ['medusa'],
      'mermaid': ['merfolk', 'sirena', 'tritón', 'sahuagin'],
      'hydra': ['hydra', 'hidra', 'chimera', 'quimera', 'manticore', 'mantícora'],
      'vampire': ['vampire', 'vampiro'],
      'crowned_skull': ['lich', 'liche', 'demilich', 'semiliche'],
      'mummy': ['mummy', 'momia'],
      'skeleton': ['skeleton', 'esqueleto'],
      'zombie': ['zombie', 'zombi', 'ghoul', 'necrófago', 'ghast'],
      'floating_ghost': ['ghost', 'fantasma', 'specter', 'espectro', 'wraith', 'wight', 'banshee', 'shadow', 'sombra'],
      'imp': ['imp', 'diablillo', 'quasit', 'kobold'],
      'golem': ['golem', 'gólem'],
      'slime': ['ooze', 'pudding', 'jelly', 'cube', 'cieno', 'pudin', 'cubo', 'gelatinoso'],
      'tree_face': ['treant', 'ent', 'blight', 'shrub', 'arbusto', 'árbol'],
      'fire_elemental': [
        'fire elemental',
        'elemental de fuego',
        'salamander',
        'salamandra',
        'azer',
        'efreeti',
        'ifrit',
      ],
      'water_elemental': ['water elemental', 'elemental de agua', 'water weird'],
      'air_elemental': ['air elemental', 'elemental de aire', 'djinni', 'djinn', 'invisible stalker'],
      'earth_elemental': ['earth elemental', 'elemental de tierra', 'xorn', 'gargoyle', 'gárgola'],
      'fairy': ['sprite', 'pixie', 'duende', 'pixi', 'dryad', 'dríade', 'satyr', 'sátiro', 'hag', 'saga'],
      'angel': ['deva', 'planetar', 'solar', 'couatl', 'ángel'],
      // Al final: «giant» aparece en muchos nombres de animales gigantes.
      'giant': ['giant', 'gigante', 'ettin'],
    };
    for (final e in byName.entries) {
      if (any(n, e.value)) return e.key;
    }
    if (any(t, ['undead', 'muerto'])) return 'skull';
    if (any(t, ['aberration', 'aberración'])) return 'tentacle';
    if (any(t, ['fiend', 'infernal', 'demon', 'devil', 'demonio', 'diablo'])) return 'devil_mask';
    if (t.contains('elemental')) return 'fire_elemental';
    if (any(t, ['beast', 'bestia'])) return 'wolf';
    if (any(t, ['monstrosity', 'monstruosidad'])) return 'hydra';
    if (any(t, ['construct', 'constructo'])) return 'golem';
    if (any(t, ['fey', 'feéric', 'feeric', 'hada'])) return 'fairy';
    if (t.contains('celestial')) return 'angel';
    if (any(t, ['giant', 'gigante'])) return 'giant';
    if (any(t, ['ooze', 'cieno', 'limo'])) return 'slime';
    if (any(t, ['plant', 'planta'])) return 'tree_face';
    if (any(t, ['dragon', 'dragón'])) return 'dragon';
    if (any(t, ['humanoid', 'humanoide'])) return 'hood';
    return 'crossed_swords';
  }

  /// Primer número de los dados de golpe ("18d10+36" -> "18d10+36").
  String get hitDiceExpression => hitDice.replaceAll(' ', '');

  Monster copy() => Monster.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'size': size,
    'type': type,
    'alignment': alignment,
    'ac': ac,
    'acNote': acNote,
    'hp': hp,
    'hitDice': hitDice,
    'speed': speed,
    'abilities': abilities,
    'saves': saves,
    'skills': skills,
    'vuln': vulnerabilities,
    'res': resistances,
    'imm': immunities,
    'condImm': conditionImmunities,
    'senses': senses,
    'languages': languages,
    'cr': cr,
    'crText': crText,
    'xp': xp,
    'traits': traits.map((t) => t.toJson()).toList(),
    'actions': actions.map((t) => t.toJson()).toList(),
    'bonus': bonusActions.map((t) => t.toJson()).toList(),
    'reactions': reactions.map((t) => t.toJson()).toList(),
    'legendary': legendary.map((t) => t.toJson()).toList(),
    if (description.isNotEmpty) 'desc': description,
    if (custom) 'custom': true,
    if (icon.isNotEmpty) 'icon': icon,
  };

  factory Monster.fromJson(Map<String, dynamic> j) {
    final ab = j['abilities'] is List ? (j['abilities'] as List).map((e) => asInt(e, 10)).toList() : null;
    return Monster(
      id: asString(j['id'], newId()),
      name: asString(j['name'], 'Criatura'),
      size: asString(j['size']),
      type: asString(j['type']),
      alignment: asString(j['alignment']),
      ac: asInt(j['ac'], 10),
      acNote: asString(j['acNote']),
      hp: asInt(j['hp'], 1),
      hitDice: asString(j['hitDice']),
      speed: asString(j['speed']),
      abilities: (ab != null && ab.length == 6) ? ab : null,
      saves: asString(j['saves']),
      skills: asString(j['skills']),
      vulnerabilities: asString(j['vuln']),
      resistances: asString(j['res']),
      immunities: asString(j['imm']),
      conditionImmunities: asString(j['condImm']),
      senses: asString(j['senses']),
      languages: asString(j['languages']),
      cr: asDouble(j['cr']),
      crText: asString(j['crText'], '0'),
      xp: asInt(j['xp']),
      traits: asList(j['traits'], NamedText.fromJson),
      actions: asList(j['actions'], NamedText.fromJson),
      bonusActions: asList(j['bonus'], NamedText.fromJson),
      reactions: asList(j['reactions'], NamedText.fromJson),
      legendary: asList(j['legendary'], NamedText.fromJson),
      description: asString(j['desc']),
      custom: asBool(j['custom']),
      icon: asString(j['icon']),
    );
  }
}

/// Convierte "1/4" o "2" a número.
double parseCr(String text) {
  final t = text.trim();
  if (t.contains('/')) {
    final parts = t.split('/');
    final a = double.tryParse(parts[0]) ?? 0;
    final b = double.tryParse(parts[1]) ?? 1;
    return b == 0 ? 0 : a / b;
  }
  return double.tryParse(t) ?? 0;
}
