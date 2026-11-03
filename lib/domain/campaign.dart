import '../core/ids.dart';
import '../core/json.dart';
import 'character.dart';
import 'chat.dart';
import 'item.dart';
import 'monster.dart';
import 'recipe.dart';
import 'ruleset.dart';

enum EncumbranceRule {
  none('Sin carga'),
  standard('Capacidad de carga (FUE × 15)'),
  variant('Variante: cargado / muy cargado');

  const EncumbranceRule(this.label);
  final String label;
}

class CampaignSettings {
  CampaignSettings({
    this.hideItemWeights = false,
    this.hideItemValues = false,
    this.showPartyHp = true,
    this.showMonsterHp = false,
    this.encumbrance = EncumbranceRule.standard,
    this.countCoinWeight = true,
    this.allowMagicCrafting = true,
    this.playersCanCreateRecipes = false,
    this.allowNewPlayers = true,
    this.playersCanTrade = true,
  });

  /// Oculta a los jugadores el peso de todos los objetos.
  bool hideItemWeights;

  /// Oculta a los jugadores el valor de todos los objetos.
  bool hideItemValues;
  bool showPartyHp;
  bool showMonsterHp;
  EncumbranceRule encumbrance;
  bool countCoinWeight;
  bool allowMagicCrafting;
  bool playersCanCreateRecipes;
  bool allowNewPlayers;
  bool playersCanTrade;

  Map<String, dynamic> toJson() => {
    'hideItemWeights': hideItemWeights,
    'hideItemValues': hideItemValues,
    'showPartyHp': showPartyHp,
    'showMonsterHp': showMonsterHp,
    'encumbrance': encumbrance.name,
    'countCoinWeight': countCoinWeight,
    'allowMagicCrafting': allowMagicCrafting,
    'playersCanCreateRecipes': playersCanCreateRecipes,
    'allowNewPlayers': allowNewPlayers,
    'playersCanTrade': playersCanTrade,
  };

  factory CampaignSettings.fromJson(Map<String, dynamic> j) => CampaignSettings(
    hideItemWeights: asBool(j['hideItemWeights']),
    hideItemValues: asBool(j['hideItemValues']),
    showPartyHp: asBool(j['showPartyHp'], true),
    showMonsterHp: asBool(j['showMonsterHp']),
    encumbrance: enumByName(EncumbranceRule.values, j['encumbrance'], EncumbranceRule.standard),
    countCoinWeight: asBool(j['countCoinWeight'], true),
    allowMagicCrafting: asBool(j['allowMagicCrafting'], true),
    playersCanCreateRecipes: asBool(j['playersCanCreateRecipes']),
    allowNewPlayers: asBool(j['allowNewPlayers'], true),
    playersCanTrade: asBool(j['playersCanTrade'], true),
  );

  CampaignSettings copy() => CampaignSettings.fromJson(toJson());
}

enum Role { dm, player }

class Member {
  Member({
    required this.userId,
    required this.name,
    this.role = Role.player,
    this.deviceKey = '',
    int? joinedAt,
    this.lastSeenAt = 0,
    this.banned = false,
  }) : joinedAt = joinedAt ?? DateTime.now().millisecondsSinceEpoch;

  String userId;
  String name;
  Role role;

  /// Secreto del dispositivo del jugador; sólo lo guarda el anfitrión.
  String deviceKey;
  int joinedAt;
  int lastSeenAt;
  bool banned;

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'name': name,
    'role': role.name,
    if (deviceKey.isNotEmpty) 'deviceKey': deviceKey,
    'joinedAt': joinedAt,
    'lastSeenAt': lastSeenAt,
    if (banned) 'banned': true,
  };

  factory Member.fromJson(Map<String, dynamic> j) => Member(
    userId: asString(j['userId']),
    name: asString(j['name'], 'Jugador'),
    role: enumByName(Role.values, j['role'], Role.player),
    deviceKey: asString(j['deviceKey']),
    joinedAt: asIntOrNull(j['joinedAt']),
    lastSeenAt: asInt(j['lastSeenAt']),
    banned: asBool(j['banned']),
  );
}

enum CombatantKind { pc, monster, npc }

class Combatant {
  Combatant({
    String? id,
    required this.name,
    this.kind = CombatantKind.monster,
    this.initiative = 0,
    this.initiativeBonus = 0,
    this.characterId,
    this.monsterId,
    this.hp,
    this.hpMax,
    this.ac,
    List<String>? conditions,
    this.hidden = false,
    this.notes = '',
    this.xp = 0,
    this.status = '',
  }) : id = id ?? newId(),
       conditions = conditions ?? <String>[];

  String id;
  String name;
  CombatantKind kind;
  int initiative;
  int initiativeBonus;
  String? characterId;
  String? monsterId;
  int? hp;
  int? hpMax;
  int? ac;
  List<String> conditions;

  /// Oculto a los jugadores (emboscadas, criaturas invisibles...).
  bool hidden;
  String notes;
  int xp;

  /// Estado aproximado ("Ileso", "Herido"...) que ven los jugadores cuando
  /// el máster oculta los PG de los monstruos.
  String status;

  bool get isDown => hp != null && hp! <= 0;

  static String healthStatus(int hp, int max) {
    if (max <= 0) return '';
    if (hp <= 0) return 'Fuera de combate';
    final r = hp / max;
    if (r >= 1) return 'Ileso';
    if (r > 0.5) return 'Herido';
    if (r > 0.25) return 'Malherido';
    return 'Casi muerto';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'initiative': initiative,
    'initiativeBonus': initiativeBonus,
    if (characterId != null) 'characterId': characterId,
    if (monsterId != null) 'monsterId': monsterId,
    'hp': hp,
    'hpMax': hpMax,
    'ac': ac,
    'conditions': conditions,
    if (hidden) 'hidden': true,
    if (notes.isNotEmpty) 'notes': notes,
    if (xp != 0) 'xp': xp,
    if (status.isNotEmpty) 'status': status,
  };

  factory Combatant.fromJson(Map<String, dynamic> j) => Combatant(
    id: asString(j['id'], newId()),
    name: asString(j['name']),
    kind: enumByName(CombatantKind.values, j['kind'], CombatantKind.monster),
    initiative: asInt(j['initiative']),
    initiativeBonus: asInt(j['initiativeBonus']),
    characterId: asStringOrNull(j['characterId']),
    monsterId: asStringOrNull(j['monsterId']),
    hp: asIntOrNull(j['hp']),
    hpMax: asIntOrNull(j['hpMax']),
    ac: asIntOrNull(j['ac']),
    conditions: asStringList(j['conditions']),
    hidden: asBool(j['hidden']),
    notes: asString(j['notes']),
    xp: asInt(j['xp']),
    status: asString(j['status']),
  );
}

class Encounter {
  Encounter({
    this.active = false,
    this.round = 1,
    this.turn = 0,
    List<Combatant>? combatants,
    this.visibleToPlayers = true,
  }) : combatants = combatants ?? <Combatant>[];

  bool active;
  int round;
  int turn;
  List<Combatant> combatants;
  bool visibleToPlayers;

  Combatant? get current => combatants.isEmpty ? null : combatants[turn.clamp(0, combatants.length - 1)];

  void sort() {
    final currentId = current?.id;
    combatants.sort((a, b) {
      final c = b.initiative.compareTo(a.initiative);
      if (c != 0) return c;
      return b.initiativeBonus.compareTo(a.initiativeBonus);
    });
    if (currentId != null) {
      final i = combatants.indexWhere((c) => c.id == currentId);
      if (i >= 0) turn = i;
    }
  }

  void next() {
    if (combatants.isEmpty) return;
    turn++;
    if (turn >= combatants.length) {
      turn = 0;
      round++;
    }
  }

  void previous() {
    if (combatants.isEmpty) return;
    turn--;
    if (turn < 0) {
      if (round > 1) {
        round--;
        turn = combatants.length - 1;
      } else {
        turn = 0;
      }
    }
  }

  Encounter copy() => Encounter.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'active': active,
    'round': round,
    'turn': turn,
    'combatants': combatants.map((c) => c.toJson()).toList(),
    'visibleToPlayers': visibleToPlayers,
  };

  factory Encounter.fromJson(Map<String, dynamic> j) => Encounter(
    active: asBool(j['active']),
    round: asInt(j['round'], 1),
    turn: asInt(j['turn']),
    combatants: asList(j['combatants'], Combatant.fromJson),
    visibleToPlayers: asBool(j['visibleToPlayers'], true),
  );
}

/// Nota del máster. Si [shared] es true la ven todos los jugadores (diario
/// de la partida, pistas, documentos...).
class CampaignNote {
  CampaignNote({
    String? id,
    required this.title,
    this.body = '',
    this.shared = false,
    this.pinned = false,
    int? updatedAt,
  }) : id = id ?? newId(),
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  String id;
  String title;
  String body;
  bool shared;
  bool pinned;
  int updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'shared': shared,
    'pinned': pinned,
    'updatedAt': updatedAt,
  };

  factory CampaignNote.fromJson(Map<String, dynamic> j) => CampaignNote(
    id: asString(j['id'], newId()),
    title: asString(j['title']),
    body: asString(j['body']),
    shared: asBool(j['shared']),
    pinned: asBool(j['pinned']),
    updatedAt: asIntOrNull(j['updatedAt']),
  );
}

class LogEntry {
  LogEntry({required this.text, this.actor = '', this.characterId, int? ts})
    : ts = ts ?? DateTime.now().millisecondsSinceEpoch;

  String text;
  String actor;
  String? characterId;
  int ts;

  Map<String, dynamic> toJson() => {
    'text': text,
    'actor': actor,
    if (characterId != null) 'characterId': characterId,
    'ts': ts,
  };

  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(
    text: asString(j['text']),
    actor: asString(j['actor']),
    characterId: asStringOrNull(j['characterId']),
    ts: asIntOrNull(j['ts']),
  );
}

/// Estado completo de una partida. El anfitrión (máster) guarda la versión
/// completa; cada jugador recibe una versión filtrada (ver view_filter.dart).
class Campaign {
  Campaign({
    String? id,
    required this.name,
    this.description = '',
    this.ruleset = Ruleset.v2024,
    required this.dmUserId,
    required this.dmName,
    String? joinCode,
    CampaignSettings? settings,
    List<Member>? members,
    List<Character>? characters,
    List<InventoryItem>? itemLibrary,
    List<Recipe>? recipes,
    List<Monster>? monsters,
    Encounter? encounter,
    List<CampaignNote>? notes,
    List<LogEntry>? log,
    ChatState? chat,
    int? createdAt,
    int? updatedAt,
    this.revision = 0,
    List<String>? online,
    this.isView = false,
  }) : id = id ?? newId(),
       joinCode = joinCode ?? newJoinCode(),
       settings = settings ?? CampaignSettings(),
       members = members ?? <Member>[],
       characters = characters ?? <Character>[],
       itemLibrary = itemLibrary ?? <InventoryItem>[],
       recipes = recipes ?? <Recipe>[],
       monsters = monsters ?? <Monster>[],
       encounter = encounter ?? Encounter(),
       notes = notes ?? <CampaignNote>[],
       log = log ?? <LogEntry>[],
       chat = chat ?? ChatState(),
       online = online ?? <String>[],
       createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  static const maxLogEntries = 500;

  String id;
  String name;
  String description;
  Ruleset ruleset;
  String dmUserId;
  String dmName;
  String joinCode;
  CampaignSettings settings;
  List<Member> members;
  List<Character> characters;

  /// Objetos personalizados del máster (plantillas para repartir).
  List<InventoryItem> itemLibrary;
  List<Recipe> recipes;

  /// Monstruos personalizados (los del SRD se cargan de los assets).
  List<Monster> monsters;
  Encounter encounter;
  List<CampaignNote> notes;
  List<LogEntry> log;
  ChatState chat;
  int createdAt;
  int updatedAt;

  /// Se incrementa con cada cambio; sirve para detectar vistas obsoletas.
  int revision;

  /// Jugadores conectados ahora mismo (sólo en las vistas que envía el anfitrión).
  List<String> online;

  /// true si es una vista filtrada recibida del anfitrión.
  bool isView;

  Rules get rules => Rules(ruleset);

  Character? character(String id) {
    for (final c in characters) {
      if (c.id == id) return c;
    }
    return null;
  }

  Member? member(String userId) {
    for (final m in members) {
      if (m.userId == userId) return m;
    }
    return null;
  }

  String memberName(String userId) {
    if (userId == dmUserId) return dmName;
    return member(userId)?.name ?? 'Desconocido';
  }

  List<Character> charactersOf(String userId) => characters.where((c) => c.ownerId == userId).toList();

  Recipe? recipe(String id) {
    for (final r in recipes) {
      if (r.id == id) return r;
    }
    return null;
  }

  void addLog(String text, {String actor = '', String? characterId}) {
    log.add(LogEntry(text: text, actor: actor, characterId: characterId));
    if (log.length > maxLogEntries) log.removeRange(0, log.length - maxLogEntries);
  }

  Campaign copy() => Campaign.fromJson(toJson());

  Map<String, dynamic> toJson({bool includeChat = true}) => {
    'format': 1,
    'id': id,
    'name': name,
    'description': description,
    'ruleset': ruleset.name,
    'dmUserId': dmUserId,
    'dmName': dmName,
    'joinCode': joinCode,
    'settings': settings.toJson(),
    'members': members.map((m) => m.toJson()).toList(),
    'characters': characters.map((c) => c.toJson()).toList(),
    'itemLibrary': itemLibrary.map((i) => i.toJson()).toList(),
    'recipes': recipes.map((r) => r.toJson()).toList(),
    'monsters': monsters.map((m) => m.toJson()).toList(),
    'encounter': encounter.toJson(),
    'notes': notes.map((n) => n.toJson()).toList(),
    'log': log.map((l) => l.toJson()).toList(),
    if (includeChat) 'chat': chat.toJson(),
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'revision': revision,
    if (online.isNotEmpty) 'online': online,
    if (isView) 'isView': true,
  };

  factory Campaign.fromJson(Map<String, dynamic> j) => Campaign(
    id: asString(j['id'], newId()),
    name: asString(j['name'], 'Partida'),
    description: asString(j['description']),
    ruleset: Ruleset.parse(j['ruleset']),
    dmUserId: asString(j['dmUserId']),
    dmName: asString(j['dmName'], 'Máster'),
    joinCode: asString(j['joinCode']),
    settings: CampaignSettings.fromJson(asMap(j['settings'])),
    members: asList(j['members'], Member.fromJson),
    characters: asList(j['characters'], Character.fromJson),
    itemLibrary: asList(j['itemLibrary'], InventoryItem.fromJson),
    recipes: asList(j['recipes'], Recipe.fromJson),
    monsters: asList(j['monsters'], Monster.fromJson),
    encounter: Encounter.fromJson(asMap(j['encounter'])),
    notes: asList(j['notes'], CampaignNote.fromJson),
    log: asList(j['log'], LogEntry.fromJson),
    chat: j['chat'] is Map ? ChatState.fromJson(asMap(j['chat'])) : ChatState(),
    createdAt: asIntOrNull(j['createdAt']),
    updatedAt: asIntOrNull(j['updatedAt']),
    revision: asInt(j['revision']),
    online: asStringList(j['online']),
    isView: asBool(j['isView']),
  );
}
