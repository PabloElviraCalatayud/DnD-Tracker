import '../core/i18n.dart';

/// Características y habilidades (iguales en 2014 y 2024).
enum Ability {
  str('str', 'Fuerza', 'FUE'),
  dex('dex', 'Destreza', 'DES'),
  con('con', 'Constitución', 'CON'),
  intl('int', 'Inteligencia', 'INT'),
  wis('wis', 'Sabiduría', 'SAB'),
  cha('cha', 'Carisma', 'CAR');

  const Ability(this.key, this._label, this._abbr);
  final String key;
  final String _label;
  final String _abbr;

  String get label => tr(_label);
  String get abbr => I18n.isEnglish ? key.toUpperCase() : _abbr;

  static Ability? byKey(String? key) {
    if (key == null) return null;
    final k = key.toLowerCase();
    for (final a in values) {
      if (a.key == k || a._abbr.toLowerCase() == k) return a;
    }
    return null;
  }
}

enum Skill {
  acrobatics('Acrobacias', 'Acrobatics', Ability.dex),
  animalHandling('Trato con animales', 'Animal Handling', Ability.wis),
  arcana('Arcanos', 'Arcana', Ability.intl),
  athletics('Atletismo', 'Athletics', Ability.str),
  deception('Engaño', 'Deception', Ability.cha),
  history('Historia', 'History', Ability.intl),
  insight('Perspicacia', 'Insight', Ability.wis),
  intimidation('Intimidación', 'Intimidation', Ability.cha),
  investigation('Investigación', 'Investigation', Ability.intl),
  medicine('Medicina', 'Medicine', Ability.wis),
  nature('Naturaleza', 'Nature', Ability.intl),
  perception('Percepción', 'Perception', Ability.wis),
  performance('Interpretación', 'Performance', Ability.cha),
  persuasion('Persuasión', 'Persuasion', Ability.cha),
  religion('Religión', 'Religion', Ability.intl),
  sleightOfHand('Juego de manos', 'Sleight of Hand', Ability.dex),
  stealth('Sigilo', 'Stealth', Ability.dex),
  survival('Supervivencia', 'Survival', Ability.wis);

  const Skill(this._label, this.english, this.ability);
  final String _label;
  final String english;
  final Ability ability;

  String get label => I18n.isEnglish ? english : _label;
}

/// Nivel de competencia en una habilidad o tirada.
enum Proficiency {
  none(0, ''),
  half(0.5, '½'),
  proficient(1, 'C'),
  expertise(2, 'P');

  const Proficiency(this.multiplier, this._badge);
  final double multiplier;
  final String _badge;

  /// Letra que se muestra junto a la habilidad (C/P en castellano, P/E en inglés).
  String get badge => !I18n.isEnglish
      ? _badge
      : switch (this) {
          Proficiency.proficient => 'P',
          Proficiency.expertise => 'E',
          _ => _badge,
        };

  String get label => switch (this) {
    Proficiency.none => tr('Sin competencia'),
    Proficiency.half => tr('Media competencia'),
    Proficiency.proficient => tr('Competente'),
    Proficiency.expertise => tr('Pericia'),
  };

  Proficiency get next => Proficiency.values[(index + 1) % Proficiency.values.length];

  int bonus(int proficiencyBonus) => (proficiencyBonus * multiplier).floor();
}
