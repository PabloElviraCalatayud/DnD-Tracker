// Iconos de game-icons.net (assets/icons) para cosas del SRD. Se eligen por el
// nombre inglés (estable) y, si no lo hay, por el castellano.

/// Icono de un objeto según su nombre y su categoría del SRD.
String iconForItem(String name, String category) {
  final n = name.toLowerCase();
  bool has(List<String> words) => words.any(n.contains);
  if (has(['crossbow', 'ballesta'])) return 'crossbow';
  if (has(['arrow', 'bolt', 'needle', 'bullet', 'flecha', 'virote', 'dardos', 'munición', 'ammunition'])) {
    return 'arrows';
  }
  if (has(['bow', 'arco'])) return 'bow';
  if (has(['dagger', 'daga'])) return 'broad_dagger';
  if (has(['scimitar', 'cimitarra', 'katana'])) return 'katana';
  if (has(['sword', 'rapier', 'blade', 'espada', 'estoque', 'vorpal', 'defender', 'avenger', 'slayer'])) {
    return 'sword_brandish';
  }
  if (has(['axe', 'hacha'])) return 'axe';
  if (has(['war pick', 'pico de guerra'])) return 'war_pick';
  if (has(['flail', 'mangual'])) return 'flail';
  if (has(['mace', 'club', 'morningstar', 'maza', 'garrote', 'lucero'])) return 'flanged_mace';
  if (has(['hammer', 'martillo', 'maul'])) return 'hammer';
  if (has(['trident', 'tridente'])) return 'trident';
  if (has(['scythe', 'sickle', 'hoz', 'guadaña'])) return 'scythe';
  if (has([
    'spear',
    'javelin',
    'pike',
    'lance',
    'halberd',
    'glaive',
    'lanza',
    'jabalina',
    'pica',
    'alabarda',
    'guja',
  ])) {
    return 'spear';
  }
  if (has(['sling', 'honda'])) return 'sling';
  if (has(['whip', 'látigo'])) return 'whip';
  if (has(['shield', 'escudo'])) return 'round_shield';
  if (has(['chain', 'ring mail', 'cota de malla', 'camisa de malla', 'cota guarnecida', 'elven chain', 'malla'])) {
    return 'chain_mail';
  }
  if (has(['scale', 'escamas'])) return 'scale_mail';
  if (has(['plate', 'breastplate', 'splint', 'placas', 'coraza', 'bandas', 'half plate'])) return 'breastplate';
  if (has(['leather', 'padded', 'hide', 'cuero', 'acolchada', 'pieles'])) return 'leather_vest';
  if (has(['potion', 'philter', 'poción', 'filtro', 'elixir'])) return 'potion_ball';
  if (has([
    'oil',
    'vial',
    'flask',
    'acid',
    'antitoxin',
    'aceite',
    'frasco',
    'ácido',
    'antitoxina',
    'solvent',
    'glue',
  ])) {
    return 'corked_tube';
  }
  if (has(['scroll', 'pergamino'])) return 'tied_scroll';
  if (has(['ring', 'anillo'])) return 'ring';
  if (has(['holy symbol', 'símbolo sagrado', 'emblem', 'emblema', 'reliquary', 'relicario', 'amulet', 'amuleto'])) {
    return 'holy_symbol';
  }
  if (has(['necklace', 'periapt', 'medallion', 'talisman', 'collar', 'talismán', 'medallón', 'scarab'])) {
    return 'amulet';
  }
  if (has(['wand', 'varita'])) return 'crystal_wand';
  if (has(['rod', 'cetro', 'vara'])) return 'orb_wand';
  if (has(['staff', 'bastón', 'quarterstaff'])) return 'wizard_staff';
  if (has(['cloak', 'cape', 'mantle', 'capa', 'manto'])) return 'cape';
  if (has(['robe', 'túnica', 'vestments', 'clothes', 'ropas'])) return 'robe';
  if (has(['boots', 'slippers', 'horseshoe', 'botas', 'babuchas', 'herraduras'])) return 'boots';
  if (has(['gloves', 'gauntlets', 'bracers', 'guantes', 'guanteletes', 'brazales'])) return 'gloves';
  if (has(['hat', 'sombrero'])) return 'magic_hat';
  if (has(['helm', 'circlet', 'headband', 'yelmo', 'diadema', 'crown', 'corona'])) return 'helm';
  if (has(['backpack', 'mochila', 'haversack', 'morral'])) return 'backpack';
  if (has(['bag', 'sack', 'pouch', 'bolsa', 'saco', 'saquito', 'purse'])) return 'swap_bag';
  if (has(['spellbook', 'libro de conjuros'])) return 'spell_book';
  if (has(['tome', 'manual', 'book', 'tomo', 'libro'])) return category == 'magic' ? 'book_aura' : 'book';
  if (has(['ioun', 'gem', 'stone', 'pearl', 'gema', 'piedra', 'perla', 'diamond', 'diamante'])) return 'emerald';
  if (has(['crystal ball', 'bola de cristal', 'orb', 'orbe', 'crystal', 'cristal'])) return 'crystal_ball';
  if (has(['lamp', 'lámpara'])) return category == 'magic' ? 'magic_lamp' : 'lantern';
  if (has(['lantern', 'linterna'])) return 'lantern';
  if (has(['torch', 'antorcha'])) return 'torch';
  if (has(['candle', 'vela'])) return 'candle';
  if (has(['rope', 'cuerda', 'string', 'cordel', 'net', 'red'])) return 'rope';
  if (has(['manacles', 'esposas', 'shackles', 'grilletes', 'chain', 'cadena'])) return 'manacles';
  if (has(["healer's kit", 'útiles de sanador', 'herbalism', 'herborista'])) return 'first_aid';
  if (has(["thieves' tools", 'herramientas de ladrón', 'lockpick'])) return 'lockpicks';
  if (has(['key', 'llave'])) return 'key';
  if (has(['map', 'mapa'])) return 'treasure_map';
  if (has(['tools', 'supplies', 'kit', 'herramientas', 'suministros', 'útiles', 'utensilios'])) return 'hammer';
  if (has(['ration', 'ración', 'raciones', 'alimento'])) return 'campfire';
  if (has(['coin', 'moneda'])) return 'coins';
  return switch (category) {
    'weapon' => 'broadsword',
    'armor' => 'breastplate',
    'ammunition' => 'arrows',
    'tool' => 'hammer',
    'magic' => 'sparkles',
    _ => 'backpack',
  };
}

/// Icono de la escuela de magia (en inglés o en castellano).
String schoolIcon(String school) {
  final s = school.toLowerCase();
  if (s.startsWith('abju')) return 'school_abjuration';
  if (s.startsWith('conj')) return 'school_conjuration';
  if (s.startsWith('divin') || s.startsWith('adivin')) return 'school_divination';
  if (s.startsWith('ench') || s.startsWith('encan')) return 'school_enchantment';
  if (s.startsWith('evoc')) return 'school_evocation';
  if (s.startsWith('illu') || s.startsWith('ilus')) return 'school_illusion';
  if (s.startsWith('necro') || s.startsWith('nigro')) return 'school_necromancy';
  if (s.startsWith('trans')) return 'school_transmutation';
  return 'sparkles';
}

/// Icono de un estado (por su id del SRD).
String conditionIcon(String id) => switch (id) {
  'blinded' => 'cond_blinded',
  'charmed' => 'cond_charmed',
  'deafened' => 'cond_deafened',
  'frightened' => 'cond_frightened',
  'grappled' => 'cond_grappled',
  'incapacitated' => 'cond_incapacitated',
  'invisible' => 'invisible',
  'paralyzed' => 'cond_paralyzed',
  'petrified' => 'cond_petrified',
  'poisoned' => 'cond_poisoned',
  'prone' => 'cond_prone',
  'restrained' => 'cond_restrained',
  'stunned' => 'cond_stunned',
  'unconscious' => 'cond_unconscious',
  'exhaustion' => 'cond_exhaustion',
  _ => 'health',
};
