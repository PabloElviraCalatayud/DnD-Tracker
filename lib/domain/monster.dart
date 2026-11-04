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
    if (any(n, ['dragon', 'dragón', 'wyrm']) || any(t, ['dragon', 'dragón'])) return 'dragon';
    if (any(n, ['goblin', 'trasgo', 'bugbear', 'osgo'])) return 'goblin';
    if (any(n, ['orc', 'orco'])) return 'orc';
    if (any(n, ['troll', 'trol'])) return 'troll';
    if (any(n, ['wolf', 'worg', 'lobo'])) return 'wolf';
    if (any(n, ['spider', 'araña'])) return 'spider';
    if (any(n, ['hydra', 'hidra'])) return 'hydra';
    if (any(n, ['minotaur', 'minotauro'])) return 'minotaur';
    if (any(n, ['vampire', 'vampiro'])) return 'vampire';
    if (any(n, ['lich', 'liche'])) return 'crowned_skull';
    if (any(t, ['undead', 'muerto'])) return 'skull';
    if (any(t, ['aberration', 'aberración'])) return 'tentacle';
    if (any(t, ['fiend', 'infernal', 'demonio', 'diablo'])) return 'dragon_breath';
    if (t.contains('elemental')) return 'fire_spell';
    if (any(t, ['beast', 'bestia'])) return 'wolf';
    if (any(t, ['monstrosity', 'monstruosidad'])) return 'hydra';
    if (any(t, ['construct', 'constructo'])) return 'helm';
    if (any(t, ['fey', 'feéric', 'feeric', 'hada'])) return 'sparkles';
    if (t.contains('celestial')) return 'sun';
    if (any(t, ['giant', 'gigante'])) return 'troll';
    if (any(t, ['ooze', 'plant', 'cieno', 'planta', 'limo'])) return 'mushroom';
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
