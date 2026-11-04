import 'dart:math';

import '../core/i18n.dart';

/// Edición de reglas de la partida.
enum Ruleset {
  v2014,
  v2024;

  String get label => this == v2014 ? 'D&D 5e (2014)' : 'D&D 5.5e (2024)';
  String get short => this == v2014 ? '5e' : '5.5e';

  /// Carpeta de assets/srd con los datos de esta edición.
  String get srdFolder => this == v2014 ? '2014' : '2024';
  String get srdName => this == v2014 ? 'SRD 5.1' : 'SRD 5.2';

  /// En 2024 "raza" pasa a llamarse "especie".
  String get speciesLabel => this == v2014 ? tr('Raza') : tr('Especie');
  String get subspeciesLabel => this == v2014 ? tr('Subraza') : tr('Linaje');
  String get inspirationLabel => this == v2014 ? tr('Inspiración') : tr('Inspiración heroica');

  static Ruleset parse(Object? v) => v == 'v2014' ? Ruleset.v2014 : Ruleset.v2024;
}

/// Reglas que cambian entre ediciones. Todo lo que dependa de la edición
/// debería pasar por aquí para que añadir variantes sea sencillo.
class Rules {
  const Rules(this.ruleset);
  final Ruleset ruleset;

  bool get is2024 => ruleset == Ruleset.v2024;

  static int abilityModifier(int score) => ((score - 10) / 2).floor();

  static int proficiencyBonus(int totalLevel) => 2 + (max(1, min(20, totalLevel)) - 1) ~/ 4;

  // ---------------------------------------------------------------- Descansos

  /// Dados de golpe recuperados al terminar un descanso largo.
  int hitDiceRecoveredOnLongRest(int totalHitDice) => is2024 ? totalHitDice : max(1, totalHitDice ~/ 2);

  String get longRestSummary => is2024
      ? tr(
          'Recuperas todos los PG, todos los dados de golpe gastados y todos los espacios de conjuro. El cansancio baja 1 nivel.',
        )
      : tr(
          'Recuperas todos los PG, la mitad de tus dados de golpe (mínimo 1) y todos los espacios de conjuro. El cansancio baja 1 nivel si has comido y bebido.',
        );

  // ---------------------------------------------------------------- Cansancio

  static const int maxExhaustion = 6;

  String exhaustionEffect(int level) {
    if (level <= 0) return tr('Sin cansancio.');
    if (level >= 6) return tr('Muerte.');
    if (is2024) {
      return tr('−{0} a todas las pruebas de d20 (ataques, características y salvaciones) y −{1} pies de velocidad.', [
        2 * level,
        5 * level,
      ]);
    }
    final effects = [
      tr('Desventaja en las pruebas de característica.'),
      tr('Velocidad reducida a la mitad.'),
      tr('Desventaja en tiradas de ataque y de salvación.'),
      tr('Puntos de golpe máximos reducidos a la mitad.'),
      tr('Velocidad reducida a 0.'),
    ];
    return effects.take(level).join(' ');
  }

  /// Penalizador a las pruebas de d20 por cansancio (sólo 2024).
  int exhaustionD20Penalty(int level) => is2024 ? -2 * level.clamp(0, 5) : 0;

  // ---------------------------------------------------------------- Conjuros

  /// Tabla de espacios de conjuro por nivel de lanzador (multiclase).
  static const List<List<int>> multiclassSlots = [
    [2],
    [3],
    [4, 2],
    [4, 3],
    [4, 3, 2],
    [4, 3, 3],
    [4, 3, 3, 1],
    [4, 3, 3, 2],
    [4, 3, 3, 3, 1],
    [4, 3, 3, 3, 2],
    [4, 3, 3, 3, 2, 1],
    [4, 3, 3, 3, 2, 1],
    [4, 3, 3, 3, 2, 1, 1],
    [4, 3, 3, 3, 2, 1, 1],
    [4, 3, 3, 3, 2, 1, 1, 1],
    [4, 3, 3, 3, 2, 1, 1, 1],
    [4, 3, 3, 3, 2, 1, 1, 1, 1],
    [4, 3, 3, 3, 3, 1, 1, 1, 1],
    [4, 3, 3, 3, 3, 2, 1, 1, 1],
    [4, 3, 3, 3, 3, 2, 2, 1, 1],
  ];

  static List<int> slotsForCasterLevel(int casterLevel) {
    if (casterLevel <= 0) return List.filled(9, 0);
    final row = multiclassSlots[min(20, casterLevel) - 1];
    return [for (var i = 0; i < 9; i++) i < row.length ? row[i] : 0];
  }

  /// Tipo de lanzador según el nombre (o id SRD) de la clase/subclase.
  static CasterType casterType(String className, String subclass) {
    final c = className.toLowerCase();
    final s = subclass.toLowerCase();
    const full = [
      'bard',
      'bardo',
      'cleric',
      'clérigo',
      'clerigo',
      'druid',
      'druida',
      'sorcerer',
      'hechicero',
      'wizard',
      'mago',
    ];
    const half = ['paladin', 'paladín', 'ranger', 'explorador', 'artificer', 'artífice', 'artifice'];
    if (full.any(c.contains)) return CasterType.full;
    if (half.any(c.contains)) return CasterType.half;
    if (c.contains('warlock') || c.contains('brujo')) return CasterType.pact;
    if (s.contains('eldritch knight') ||
        s.contains('caballero arcano') ||
        s.contains('arcane trickster') ||
        s.contains('embaucador arcano')) {
      return CasterType.third;
    }
    return CasterType.none;
  }

  /// Nivel de lanzador para la tabla multiclase.
  int casterLevelContribution(CasterType type, int level, String className) {
    final artificer = className.toLowerCase().contains('artif');
    switch (type) {
      case CasterType.full:
        return level;
      case CasterType.half:
        return (is2024 || artificer) ? (level / 2).ceil() : level ~/ 2;
      case CasterType.third:
        return level ~/ 3;
      case CasterType.pact:
      case CasterType.none:
        return 0;
    }
  }

  /// Espacios de pacto del brujo: (cantidad, nivel de espacio).
  static (int, int) pactSlots(int warlockLevel) {
    if (warlockLevel <= 0) return (0, 0);
    final count = warlockLevel == 1 ? 1 : (warlockLevel >= 17 ? 4 : (warlockLevel >= 11 ? 3 : 2));
    final level = min(5, (warlockLevel + 1) ~/ 2);
    return (count, level);
  }

  /// Hechizos preparables en 2014 para las clases que preparan con fórmula.
  /// Devuelve null si la clase usa "conjuros conocidos" (tabla).
  int? preparedFormula2014(String className, int level, int abilityMod) {
    final c = className.toLowerCase();
    if (c.contains('cleric') ||
        c.contains('clérigo') ||
        c.contains('clerigo') ||
        c.contains('druid') ||
        c.contains('wizard') ||
        c.contains('mago')) {
      return max(1, abilityMod + level);
    }
    if (c.contains('paladin') || c.contains('paladín')) return max(1, abilityMod + level ~/ 2);
    if (c.contains('artif')) return max(1, abilityMod + (level / 2).ceil());
    return null;
  }

  // ---------------------------------------------------------------- Artesanía

  /// Días de trabajo (8 h) necesarios para fabricar un objeto mundano.
  int craftingDays(int costCp) {
    final gp = costCp / 100;
    if (gp <= 0) return 0;
    return max(1, (gp / (is2024 ? 10 : 5)).ceil());
  }

  /// Coste de materias primas de un objeto mundano (la mitad del precio).
  int craftingMaterialsCp(int costCp) => (costCp / 2).ceil();

  String get craftingRulesSummary => is2024
      ? tr(
          'Necesitas competencia con la herramienta indicada y materias primas por valor de la mitad del precio del objeto. Cada día de trabajo (8 h) avanza 10 po del precio; varios personajes competentes pueden colaborar para reducir el tiempo.',
        )
      : tr(
          'Necesitas competencia con las herramientas adecuadas y materias primas por valor de la mitad del precio. Cada día de tiempo libre (8 h) avanza 5 po del precio del objeto; varios personajes pueden colaborar para reducir el tiempo.',
        );

  // ---------------------------------------------------------------- Cuadrícula

  /// Lado de una casilla del tablero: 5 pies en 2014 y en 2024.
  static const int gridFeet = 5;

  /// Coste y días orientativos para fabricar objetos mágicos según rareza.
  (int costGp, int days)? magicItemCrafting(String rarity, {bool consumable = false}) {
    final r = rarity.toLowerCase();
    (int, int)? base;
    if (is2024) {
      if (r.startsWith('common') || r.startsWith('común')) base = (50, 5);
      if (r.startsWith('uncommon') || r.startsWith('poco')) base = (200, 10);
      if (r.startsWith('rare') || r.startsWith('raro')) base = (2000, 50);
      if (r.startsWith('very') || r.startsWith('muy')) base = (20000, 125);
      if (r.startsWith('legendary') || r.startsWith('legend')) base = (100000, 250);
      if (base != null && consumable) base = ((base.$1 / 2).ceil(), (base.$2 / 2).ceil());
    } else {
      int? gp;
      if (r.startsWith('common') || r.startsWith('común')) gp = 100;
      if (r.startsWith('uncommon') || r.startsWith('poco')) gp = 500;
      if (r.startsWith('rare') || r.startsWith('raro')) gp = 5000;
      if (r.startsWith('very') || r.startsWith('muy')) gp = 50000;
      if (r.startsWith('legendary') || r.startsWith('legend')) gp = 500000;
      if (gp != null) base = (gp, max(1, gp ~/ 25));
    }
    return base;
  }

  // ---------------------------------------------------------------- Encuentros

  static const Map<String, int> xpByCr = {
    '0': 10,
    '1/8': 25,
    '1/4': 50,
    '1/2': 100,
    '1': 200,
    '2': 450,
    '3': 700,
    '4': 1100,
    '5': 1800,
    '6': 2300,
    '7': 2900,
    '8': 3900,
    '9': 5000,
    '10': 5900,
    '11': 7200,
    '12': 8400,
    '13': 10000,
    '14': 11500,
    '15': 13000,
    '16': 15000,
    '17': 18000,
    '18': 20000,
    '19': 22000,
    '20': 25000,
    '21': 33000,
    '22': 41000,
    '23': 50000,
    '24': 62000,
    '25': 75000,
    '26': 90000,
    '27': 105000,
    '28': 120000,
    '29': 135000,
    '30': 155000,
  };

  // 2014: umbrales fácil / medio / difícil / mortal por personaje.
  static const List<List<int>> _thresholds2014 = [
    [25, 50, 75, 100],
    [50, 100, 150, 200],
    [75, 150, 225, 400],
    [125, 250, 375, 500],
    [250, 500, 750, 1100],
    [300, 600, 900, 1400],
    [350, 750, 1100, 1700],
    [450, 900, 1400, 2100],
    [550, 1100, 1600, 2400],
    [600, 1200, 1900, 2800],
    [800, 1600, 2400, 3600],
    [1000, 2000, 3000, 4500],
    [1100, 2200, 3400, 5100],
    [1250, 2500, 3800, 5700],
    [1400, 2800, 4300, 6400],
    [1600, 3200, 4800, 7200],
    [2000, 3900, 5900, 8800],
    [2100, 4200, 6300, 9500],
    [2400, 4900, 7300, 10900],
    [2800, 5700, 8500, 12700],
  ];

  // 2024: presupuesto de PX bajo / moderado / alto por personaje.
  static const List<List<int>> _budget2024 = [
    [50, 75, 100],
    [100, 150, 200],
    [150, 225, 400],
    [250, 375, 500],
    [500, 750, 1100],
    [600, 1000, 1400],
    [750, 1300, 1700],
    [1000, 1700, 2100],
    [1300, 2000, 2600],
    [1600, 2300, 3100],
    [1900, 2900, 4100],
    [2200, 3700, 4700],
    [2600, 4200, 5400],
    [2900, 4900, 6200],
    [3300, 5400, 7800],
    [3800, 6100, 9800],
    [4500, 7200, 11700],
    [5000, 8700, 14200],
    [5500, 10700, 17200],
    [6400, 13200, 22000],
  ];

  List<String> get difficultyLabels =>
      is2024 ? [tr('Baja'), tr('Moderada'), tr('Alta')] : [tr('Fácil'), tr('Media'), tr('Difícil'), tr('Mortal')];

  /// Umbrales de PX del grupo para cada dificultad.
  List<int> partyThresholds(List<int> characterLevels) {
    final table = is2024 ? _budget2024 : _thresholds2014;
    final out = List<int>.filled(table.first.length, 0);
    for (final lvl in characterLevels) {
      final row = table[lvl.clamp(1, 20) - 1];
      for (var i = 0; i < out.length; i++) {
        out[i] += row[i];
      }
    }
    return out;
  }

  /// PX "ajustados" de un grupo de monstruos. En 2024 no hay multiplicador.
  int adjustedXp(List<int> monsterXp, int partySize) {
    final total = monsterXp.fold<int>(0, (a, b) => a + b);
    if (is2024) return total;
    const mults = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0];
    final n = monsterXp.length;
    var idx = n <= 0
        ? 1
        : n == 1
        ? 1
        : n == 2
        ? 2
        : n <= 6
        ? 3
        : n <= 10
        ? 4
        : n <= 14
        ? 5
        : 6;
    if (partySize > 0 && partySize < 3) idx++;
    if (partySize >= 6) idx--;
    return (total * mults[idx.clamp(0, mults.length - 1)]).round();
  }

  /// Nombre de la dificultad alcanzada (o "Trivial").
  String difficultyFor(int adjustedXp, List<int> thresholds) {
    var label = tr('Trivial');
    for (var i = 0; i < thresholds.length; i++) {
      if (adjustedXp >= thresholds[i]) label = difficultyLabels[i];
    }
    if (is2024 && thresholds.isNotEmpty && adjustedXp > thresholds.last * 1.5) {
      label = tr('Extrema');
    }
    return label;
  }
}

enum CasterType { none, full, half, third, pact }

/// Nombres en castellano de los estados del SRD (las descripciones son del SRD en inglés).
const Map<String, String> conditionNamesEs = {
  'blinded': 'Cegado',
  'charmed': 'Hechizado',
  'deafened': 'Ensordecido',
  'exhaustion': 'Cansancio',
  'frightened': 'Asustado',
  'grappled': 'Agarrado',
  'incapacitated': 'Incapacitado',
  'invisible': 'Invisible',
  'paralyzed': 'Paralizado',
  'petrified': 'Petrificado',
  'poisoned': 'Envenenado',
  'prone': 'Derribado',
  'restrained': 'Apresado',
  'stunned': 'Aturdido',
  'unconscious': 'Inconsciente',
};

String conditionLabel(String id) {
  if (I18n.isEnglish) return id.isEmpty ? id : id[0].toUpperCase() + id.substring(1);
  return conditionNamesEs[id] ?? id;
}
