import '../core/i18n.dart';

/// Nombres oficiales de clases, subclases, especies y trasfondos del SRD en
/// inglés y en castellano. Las fichas guardan el nombre tal cual se escribió;
/// [srdTerm] lo muestra en el idioma de quien mira si es un término del SRD.
const Map<String, String> _enToEs = {
  // Clases
  'Barbarian': 'Bárbaro', 'Bard': 'Bardo', 'Cleric': 'Clérigo', 'Druid': 'Druida', 'Fighter': 'Guerrero',
  'Monk': 'Monje', 'Paladin': 'Paladín', 'Ranger': 'Explorador', 'Rogue': 'Pícaro', 'Sorcerer': 'Hechicero',
  'Warlock': 'Brujo', 'Wizard': 'Mago', 'Artificer': 'Artífice',
  // Subclases del SRD (2014 y 2024)
  'Berserker': 'Berserker', 'Path of the Berserker': 'Senda del berserker', 'Lore': 'Conocimiento',
  'College of Lore': 'Colegio del conocimiento', 'Life': 'Vida', 'Life Domain': 'Dominio de la vida',
  'Land': 'Tierra', 'Circle of the Land': 'Círculo de la tierra', 'Champion': 'Campeón',
  'Open Hand': 'Mano abierta', 'Way of the Open Hand': 'Camino de la mano abierta',
  'Warrior of the Open Hand': 'Guerrero de la mano abierta', 'Devotion': 'Devoción',
  'Oath of Devotion': 'Juramento de devoción', 'Hunter': 'Cazador', 'Thief': 'Ladrón',
  'Draconic': 'Dracónico', 'Draconic Bloodline': 'Linaje dracónico', 'Draconic Sorcery': 'Hechicería dracónica',
  'Fiend': 'Infernal', 'The Fiend': 'El Infernal', 'Fiend Patron': 'Patrón infernal', 'Evoker': 'Evocador',
  'Evocation': 'Evocación', 'School of Evocation': 'Escuela de evocación',
  // Especies y razas
  'Dragonborn': 'Dracónido', 'Dwarf': 'Enano', 'Elf': 'Elfo', 'Gnome': 'Gnomo', 'Half-Elf': 'Semielfo',
  'Half-Orc': 'Semiorco', 'Halfling': 'Mediano', 'Human': 'Humano', 'Tiefling': 'Tiefling', 'Goliath': 'Goliat',
  'Orc': 'Orco', 'Aasimar': 'Aasimar', 'Hill Dwarf': 'Enano de las colinas', 'High Elf': 'Alto elfo',
  'Wood Elf': 'Elfo de los bosques', 'Drow': 'Drow', 'Lightfoot Halfling': 'Mediano piesligeros',
  'Lightfoot': 'Piesligeros', 'Rock Gnome': 'Gnomo de las rocas', 'Forest Gnome': 'Gnomo de los bosques',
  // Trasfondos
  'Acolyte': 'Acólito', 'Criminal': 'Criminal', 'Sage': 'Erudito', 'Soldier': 'Soldado',
};

final Map<String, String> _esToEn = {for (final e in _enToEs.entries) e.value.toLowerCase(): e.key};
final Map<String, String> _enLower = {for (final e in _enToEs.entries) e.key.toLowerCase(): e.value};

/// Devuelve [name] en el idioma actual si es un término del SRD; si no, igual.
String srdTerm(String name) {
  final k = name.trim().toLowerCase();
  if (k.isEmpty) return name;
  if (I18n.isEnglish) return _esToEn[k] ?? name;
  return _enLower[k] ?? name;
}
