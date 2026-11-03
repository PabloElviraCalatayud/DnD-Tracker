/// Características y habilidades (iguales en 2014 y 2024).
enum Ability {
  str('str', 'Fuerza', 'FUE'),
  dex('dex', 'Destreza', 'DES'),
  con('con', 'Constitución', 'CON'),
  intl('int', 'Inteligencia', 'INT'),
  wis('wis', 'Sabiduría', 'SAB'),
  cha('cha', 'Carisma', 'CAR');

  const Ability(this.key, this.label, this.abbr);
  final String key;
  final String label;
  final String abbr;

  static Ability? byKey(String? key) {
    if (key == null) return null;
    final k = key.toLowerCase();
    for (final a in values) {
      if (a.key == k || a.abbr.toLowerCase() == k) return a;
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

  const Skill(this.label, this.english, this.ability);
  final String label;
  final String english;
  final Ability ability;
}

/// Nivel de competencia en una habilidad o tirada.
enum Proficiency {
  none(0, ''),
  half(0.5, '½'),
  proficient(1, 'C'),
  expertise(2, 'P');

  const Proficiency(this.multiplier, this.badge);
  final double multiplier;
  final String badge;

  String get label => switch (this) {
    Proficiency.none => 'Sin competencia',
    Proficiency.half => 'Media competencia',
    Proficiency.proficient => 'Competente',
    Proficiency.expertise => 'Pericia',
  };

  Proficiency get next => Proficiency.values[(index + 1) % Proficiency.values.length];

  int bonus(int proficiencyBonus) => (proficiencyBonus * multiplier).floor();
}
