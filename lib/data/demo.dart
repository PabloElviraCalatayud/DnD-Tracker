import '../domain/abilities.dart';
import '../domain/board.dart';
import '../domain/campaign.dart';
import '../domain/character.dart';
import '../domain/chat.dart';
import '../domain/currency.dart';
import '../domain/item.dart';
import '../domain/monster.dart';
import '../domain/recipe.dart';
import '../domain/roll.dart';
import '../domain/ruleset.dart';

/// Partida de ejemplo para explorar la app sin jugadores conectados.
/// Los jugadores son ficticios; el máster puede borrarla cuando quiera.
Campaign buildDemoCampaign({required String dmUserId, required String dmName, Ruleset ruleset = Ruleset.v2024}) {
  const ana = 'demo-ana';
  const luis = 'demo-luis';
  const marta = 'demo-marta';

  final brom = Character(
    ownerId: ana,
    name: 'Brom Yunquehondo',
    portrait: 'helm',
    classes: [ClassLevel(name: 'Cleric', srdId: 'cleric', subclass: 'Life', level: 3, hitDie: 8)],
    species: 'Dwarf',
    background: 'Acolyte',
    alignment: 'Legal bueno',
    abilities: {Ability.str: 14, Ability.dex: 10, Ability.con: 16, Ability.intl: 10, Ability.wis: 16, Ability.cha: 12},
    saveProficiencies: {Ability.wis, Ability.cha},
    skills: {
      Skill.insight: Proficiency.proficient,
      Skill.religion: Proficiency.proficient,
      Skill.medicine: Proficiency.proficient,
    },
    armorProficiencies: 'Ligeras, medias, escudos',
    weaponProficiencies: 'Sencillas',
    toolProficiencies: ['Herramientas de herrero'],
    languages: 'Común, enano',
    hpMax: 27,
    hpCurrent: 19,
    armorClass: 18,
    speed: 30,
    currency: Currency(gp: 42, sp: 15, cp: 30),
    inventory: [
      InventoryItem(
        name: 'Maza',
        category: ItemCategory.weapon,
        weight: 4,
        valueCp: 500,
        damage: '1d6 Bludgeoning',
        equipped: true,
        visibility: ItemVisibility.party,
      ),
      InventoryItem(
        name: 'Cota de escamas',
        category: ItemCategory.armor,
        weight: 45,
        valueCp: 5000,
        armorClass: '14 + DES (máx. 2)',
        equipped: true,
        visibility: ItemVisibility.party,
      ),
      InventoryItem(
        name: 'Escudo',
        category: ItemCategory.armor,
        weight: 6,
        valueCp: 1000,
        armorClass: '+2',
        equipped: true,
        visibility: ItemVisibility.party,
      ),
      InventoryItem(name: 'Símbolo sagrado', category: ItemCategory.gear, weight: 1, valueCp: 500, icon: 'amulet'),
      InventoryItem(name: 'Raciones (1 día)', category: ItemCategory.consumable, quantity: 5, weight: 2, valueCp: 50),
      InventoryItem(
        name: 'Cuerda de cáñamo (50 pies)',
        category: ItemCategory.gear,
        weight: 10,
        valueCp: 100,
        icon: 'rope',
      ),
    ],
    spellcasting: Spellcasting(
      ability: Ability.wis,
      spells: [
        CharacterSpell(name: 'Guidance', level: 0, school: 'Divination', castingTime: 'Action', range: 'Touch'),
        CharacterSpell(name: 'Sacred Flame', level: 0, school: 'Evocation', castingTime: 'Action', range: '60 feet'),
        CharacterSpell(
          name: 'Cure Wounds',
          level: 1,
          prepared: true,
          school: 'Abjuration',
          castingTime: 'Action',
          range: 'Touch',
          description:
              'A creature you touch regains a number of Hit Points equal to 2d8 plus your spellcasting ability modifier.',
        ),
        CharacterSpell(
          name: 'Bless',
          level: 1,
          prepared: true,
          concentration: true,
          school: 'Enchantment',
          castingTime: 'Action',
          range: '30 feet',
        ),
        CharacterSpell(
          name: 'Spiritual Weapon',
          level: 2,
          prepared: true,
          school: 'Evocation',
          castingTime: 'Bonus Action',
          range: '60 feet',
        ),
      ],
    ),
    features: [
      Feature(name: 'Canalizar divinidad', maxUses: 2, used: 1, recharge: Recharge.shortRest, source: 'Clérigo'),
    ],
    personality: 'Habla poco y bebe mucho; nunca olvida una deuda.',
  );
  brom.autoFillSlots(ruleset, singleClassSlots: [4, 2, 0, 0, 0, 0, 0, 0, 0]);
  brom.spellcasting.slots[0].used = 1;

  final lyra = Character(
    ownerId: luis,
    name: 'Lyra Vientoalba',
    portrait: 'wizard_face',
    classes: [ClassLevel(name: 'Wizard', srdId: 'wizard', subclass: 'Evoker', level: 3, hitDie: 6)],
    species: 'Elf',
    subspecies: 'High Elf',
    background: 'Sage',
    alignment: 'Caótico bueno',
    abilities: {Ability.str: 8, Ability.dex: 14, Ability.con: 13, Ability.intl: 17, Ability.wis: 12, Ability.cha: 10},
    saveProficiencies: {Ability.intl, Ability.wis},
    skills: {
      Skill.arcana: Proficiency.expertise,
      Skill.history: Proficiency.proficient,
      Skill.perception: Proficiency.proficient,
    },
    languages: 'Común, élfico, dracónico',
    hpMax: 17,
    hpCurrent: 9,
    armorClass: 12,
    currency: Currency(gp: 15, sp: 4, pp: 1),
    shareCurrency: true,
    inventory: [
      InventoryItem(
        name: 'Bastón arcano',
        category: ItemCategory.gear,
        weight: 4,
        valueCp: 1000,
        icon: 'wizard_staff',
        equipped: true,
        visibility: ItemVisibility.party,
      ),
      InventoryItem(
        name: 'Libro de conjuros',
        category: ItemCategory.gear,
        weight: 3,
        valueCp: 5000,
        icon: 'spell_book',
      ),
      InventoryItem(
        name: 'Anillo de plata con runas',
        category: ItemCategory.magic,
        weight: 0,
        valueCp: 50000,
        rarity: 'Uncommon',
        requiresAttunement: true,
        hideValue: true,
        hideWeight: true,
        dmNote: 'Anillo de protección: +1 a CA y salvaciones al vincularse.',
        description: 'Un anillo frío al tacto. Las runas brillan débilmente a la luz de la luna.',
        icon: 'ring',
      ),
      InventoryItem(
        name: 'Poción de curación',
        category: ItemCategory.consumable,
        quantity: 2,
        weight: 0.5,
        valueCp: 5000,
        icon: 'potion',
        visibility: ItemVisibility.party,
      ),
    ],
    spellcasting: Spellcasting(
      ability: Ability.intl,
      spells: [
        CharacterSpell(name: 'Fire Bolt', level: 0, school: 'Evocation', castingTime: 'Action', range: '120 feet'),
        CharacterSpell(name: 'Mage Hand', level: 0, school: 'Conjuration', castingTime: 'Action', range: '30 feet'),
        CharacterSpell(
          name: 'Magic Missile',
          level: 1,
          prepared: true,
          school: 'Evocation',
          castingTime: 'Action',
          range: '120 feet',
        ),
        CharacterSpell(
          name: 'Shield',
          level: 1,
          prepared: true,
          school: 'Abjuration',
          castingTime: 'Reaction',
          range: 'Self',
        ),
        CharacterSpell(
          name: 'Detect Magic',
          level: 1,
          ritual: true,
          concentration: true,
          school: 'Divination',
          castingTime: 'Action',
          range: 'Self',
        ),
        CharacterSpell(
          name: 'Misty Step',
          level: 2,
          prepared: true,
          school: 'Conjuration',
          castingTime: 'Bonus Action',
          range: 'Self',
        ),
        CharacterSpell(
          name: 'Web',
          level: 2,
          concentration: true,
          school: 'Conjuration',
          castingTime: 'Action',
          range: '60 feet',
        ),
      ],
    ),
    conditions: ['poisoned'],
  );
  lyra.autoFillSlots(ruleset, singleClassSlots: [4, 2, 0, 0, 0, 0, 0, 0, 0]);

  final kesh = Character(
    ownerId: marta,
    name: 'Kesh',
    portrait: 'hood',
    classes: [ClassLevel(name: 'Rogue', srdId: 'rogue', subclass: 'Thief', level: 3, hitDie: 8)],
    species: 'Human',
    background: 'Criminal',
    alignment: 'Neutral',
    abilities: {Ability.str: 10, Ability.dex: 17, Ability.con: 12, Ability.intl: 14, Ability.wis: 11, Ability.cha: 13},
    saveProficiencies: {Ability.dex, Ability.intl},
    skills: {
      Skill.stealth: Proficiency.expertise,
      Skill.sleightOfHand: Proficiency.expertise,
      Skill.perception: Proficiency.proficient,
      Skill.deception: Proficiency.proficient,
    },
    toolProficiencies: ['Útiles de alquimista', 'Herramientas de ladrón'],
    hpMax: 21,
    hpCurrent: 21,
    armorClass: 14,
    currency: Currency(gp: 88, sp: 20),
    inventory: [
      InventoryItem(
        name: 'Estoque',
        category: ItemCategory.weapon,
        weight: 2,
        valueCp: 2500,
        damage: '1d8 Piercing',
        equipped: true,
        visibility: ItemVisibility.party,
      ),
      InventoryItem(name: 'Útiles de alquimista', category: ItemCategory.tool, weight: 8, valueCp: 5000),
      InventoryItem(
        name: 'Hierba de sangre',
        category: ItemCategory.material,
        quantity: 5,
        weight: 0.1,
        valueCp: 200,
        tags: ['hierba'],
        icon: 'herbs',
      ),
      InventoryItem(
        name: 'Vial vacío',
        category: ItemCategory.material,
        quantity: 3,
        weight: 0.1,
        valueCp: 100,
        icon: 'flask',
      ),
      InventoryItem(
        name: 'Polvo de hueso',
        category: ItemCategory.material,
        quantity: 1,
        weight: 0.1,
        valueCp: 300,
        tags: ['componente'],
        // Kesh sólo se lo enseña a Luis (el jugador de Lyra).
        visibility: ItemVisibility.some,
        visibleTo: [luis],
      ),
    ],
  );

  final healingRecipe = Recipe(
    name: 'Poción de curación menor',
    description: 'Destila la hierba de sangre a fuego lento. El máster puede pedir una prueba.',
    result: InventoryItem(
      name: 'Poción de curación menor',
      category: ItemCategory.consumable,
      weight: 0.5,
      valueCp: 2500,
      icon: 'potion',
      description: 'Recuperas 1d4+2 PG al beberla.',
    ),
    ingredients: [
      Ingredient(name: 'hierba', quantity: 2),
      Ingredient(name: 'Vial vacío', quantity: 1),
    ],
    goldCostCp: 500,
    tool: 'Útiles de alquimista',
    characterIds: [kesh.id],
  );
  final smokeRecipe = Recipe(
    name: 'Bomba de humo',
    result: InventoryItem(
      name: 'Bomba de humo',
      category: ItemCategory.consumable,
      weight: 1,
      valueCp: 1000,
      icon: 'bubbling_flask',
    ),
    ingredients: [
      Ingredient(name: 'Polvo de hueso', quantity: 1),
      Ingredient(name: 'Vial vacío', quantity: 1),
      Ingredient(name: 'Azufre', quantity: 1),
    ],
    tool: 'Útiles de alquimista',
    days: 1,
    characterIds: [kesh.id],
  );

  final ashKnight = Monster(
    name: 'Caballero de ceniza',
    size: 'Medium',
    type: 'undead',
    alignment: 'lawful evil',
    ac: 17,
    acNote: 'armadura de placas quemada',
    hp: 52,
    hitDice: '8d8+16',
    speed: '30 ft.',
    abilities: [17, 10, 15, 8, 12, 14],
    saves: 'CON +4, WIS +3',
    immunities: 'Poison, Fire',
    conditionImmunities: 'Exhaustion, Poisoned',
    senses: 'darkvision 60 ft., passive perception 11',
    languages: 'las que conocía en vida',
    cr: 3,
    crText: '3',
    xp: 700,
    traits: [NamedText('Rescoldos', 'Cuando cae a 0 PG, cada criatura a 5 pies recibe 5 (2d4) de daño de fuego.')],
    actions: [
      NamedText('Multiataque', 'El caballero hace dos ataques con su espada.'),
      NamedText(
        'Espada ardiente',
        'Melee Attack Roll: +5, reach 5 ft. Hit: 7 (1d8 + 3) Slashing damage plus 3 (1d6) Fire damage.',
      ),
    ],
    custom: true,
  );

  final c = Campaign(
    name: 'La Cripta del Rey Ceniza (demo)',
    description: 'Partida de ejemplo para probar la app. Los jugadores son ficticios.',
    ruleset: ruleset,
    dmUserId: dmUserId,
    dmName: dmName,
    members: [
      Member(userId: ana, name: 'Ana'),
      Member(userId: luis, name: 'Luis'),
      Member(userId: marta, name: 'Marta'),
    ],
    characters: [brom, lyra, kesh],
    itemLibrary: [
      InventoryItem(
        name: 'Llave de hueso negro',
        category: ItemCategory.treasure,
        weight: 0.1,
        valueCp: 0,
        hideValue: true,
        icon: 'key',
        description: 'Una llave tallada en un hueso ennegrecido. Huele a humo.',
        dmNote: 'Abre el sarcófago del Rey Ceniza.',
        custom: true,
      ),
    ],
    recipes: [healingRecipe, smokeRecipe],
    monsters: [ashKnight],
    notes: [
      CampaignNote(
        title: 'Trama',
        body: 'El Rey Ceniza despierta con cada luna nueva. Los PJ tienen 3 noches.',
        pinned: true,
      ),
      CampaignNote(
        title: 'Carta encontrada en la cripta',
        body: '*«Quien porte la llave de hueso no debe cruzar el umbral antes del alba…»*',
        shared: true,
      ),
    ],
    chat: ChatState(
      messages: [
        ChatMessage(
          channelId: ChatChannel.generalId,
          authorId: luis,
          authorName: 'Luis',
          text: '¿Alguien tiene antídoto? Lyra sigue envenenada 🤢',
        ),
        ChatMessage(
          channelId: ChatChannel.generalId,
          authorId: marta,
          authorName: 'Marta',
          text: 'Puedo fabricar una poción si me dais un vial.',
        ),
        ChatMessage(
          channelId: ChatChannel.generalId,
          authorId: ana,
          authorName: 'Ana',
          text: '🎲 Perspicacia: **17**  (1d20+5 [12])',
          kind: MessageKind.roll,
        ),
      ],
    ),
  );
  final knightCombatant = Combatant(
    name: 'Caballero de ceniza',
    kind: CombatantKind.monster,
    monsterId: ashKnight.id,
    initiative: 15,
    hp: 31,
    hpMax: 52,
    ac: 17,
    xp: 700,
    tags: ['Herido', 'Se le ve cansado'],
  );
  final skeleton = Combatant(
    name: 'Esqueleto emboscado',
    kind: CombatantKind.monster,
    initiative: 5,
    hp: 13,
    hpMax: 13,
    ac: 13,
    hidden: true,
    xp: 50,
  );
  c.encounter = Encounter(
    active: true,
    round: 2,
    turn: 1,
    combatants: [
      Combatant(
        name: 'Lyra Vientoalba',
        kind: CombatantKind.pc,
        characterId: lyra.id,
        initiative: 18,
        initiativeBonus: 2,
      ),
      knightCombatant,
      Combatant(name: 'Kesh', kind: CombatantKind.pc, characterId: kesh.id, initiative: 12, initiativeBonus: 3),
      Combatant(name: 'Brom Yunquehondo', kind: CombatantKind.pc, characterId: brom.id, initiative: 7),
      skeleton,
    ],
  );
  // Tablero: un mapa liso con el grupo frente al caballero.
  final map = BoardMap(name: 'Cripta (en blanco)', cols: 18, rows: 12);
  c.board = Board(
    maps: [map],
    activeMapId: map.id,
    tokens: [
      BoardToken(mapId: map.id, kind: TokenKind.pc, characterId: brom.id, x: 4, y: 6),
      BoardToken(mapId: map.id, kind: TokenKind.pc, characterId: lyra.id, x: 2, y: 8),
      BoardToken(mapId: map.id, kind: TokenKind.pc, characterId: kesh.id, x: 6, y: 4),
      BoardToken(
        mapId: map.id,
        kind: TokenKind.monster,
        combatantId: knightCombatant.id,
        monsterId: ashKnight.id,
        icon: ashKnight.iconName,
        x: 10,
        y: 5,
      ),
      BoardToken(
        mapId: map.id,
        kind: TokenKind.monster,
        combatantId: skeleton.id,
        icon: 'skull',
        x: 14,
        y: 2,
        hidden: true,
      ),
      BoardToken(mapId: map.id, kind: TokenKind.object, label: 'Sarcófago', icon: 'chest', x: 15, y: 8, size: 2),
    ],
  );
  // Algunas tiradas para que el tablero no empiece vacío.
  final now = DateTime.now().millisecondsSinceEpoch;
  c.rolls = [
    RollEntry(
      userId: ana,
      authorName: 'Ana',
      characterId: brom.id,
      characterName: brom.name,
      portrait: brom.portrait,
      label: 'Perspicacia',
      expression: '1d20+5',
      total: 17,
      dice: const [RollDie(sides: 20, value: 12)],
      modifier: 5,
      breakdown: '1d20 [12] +5',
      ts: now - 120000,
    ),
    RollEntry(
      userId: luis,
      authorName: 'Luis',
      characterId: lyra.id,
      characterName: lyra.name,
      portrait: lyra.portrait,
      label: 'Magic Missile',
      expression: '3d4+3',
      total: 11,
      dice: const [RollDie(sides: 4, value: 3), RollDie(sides: 4, value: 1), RollDie(sides: 4, value: 4)],
      modifier: 3,
      breakdown: '3d4 [3, 1, 4] +3',
      ts: now - 60000,
    ),
    RollEntry(
      userId: marta,
      authorName: 'Marta',
      characterId: kesh.id,
      characterName: kesh.name,
      portrait: kesh.portrait,
      label: 'Sigilo (ventaja)',
      expression: '2d20kh1+7',
      total: 27,
      dice: const [RollDie(sides: 20, value: 20), RollDie(sides: 20, value: 6, kept: false)],
      modifier: 7,
      breakdown: '2d20kh1 [20, 6 → 20] +7',
      ts: now - 30000,
    ),
  ];
  c.addLog('Partida de demostración creada', actor: dmName);
  c.addLog('Lyra Vientoalba: PG 17 → 9', actor: 'Luis', characterId: lyra.id);
  c.addLog('Máster entregó 1× Anillo de plata con runas a Lyra Vientoalba', actor: dmName, characterId: lyra.id);
  return c;
}
