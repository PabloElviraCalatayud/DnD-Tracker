import '../core/json.dart';
import '../domain/board.dart';
import '../domain/campaign.dart';
import '../domain/character.dart';
import '../domain/currency.dart';
import '../domain/item.dart';
import '../domain/monster.dart';
import '../domain/recipe.dart';
import '../domain/ruleset.dart';

/// Quién ejecuta un comando.
class Actor {
  const Actor({required this.userId, required this.name, required this.isDm});
  final String userId;
  final String name;
  final bool isDm;
}

/// Comando que modifica la partida. Los jugadores los envían por la red y el
/// anfitrión los valida y aplica; el máster los aplica directamente.
class Command {
  const Command(this.type, [this.data = const {}]);

  final String type;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {'type': type, 'data': data};

  factory Command.fromJson(Map<String, dynamic> j) => Command(asString(j['type']), asMap(j['data']));

  // ------------------------------------------------------------ Personajes
  static Command putCharacter(Character c) => Command('character.put', {'character': c.toJson()});
  static Command deleteCharacter(String id) => Command('character.delete', {'characterId': id});
  static Command assignCharacter(String id, String ownerId) =>
      Command('character.assign', {'characterId': id, 'ownerId': ownerId});

  // ------------------------------------------------------------ Objetos
  static Command giveItem(String characterId, InventoryItem item) =>
      Command('item.give', {'characterId': characterId, 'item': item.toJson()});
  static Command transferItem(String from, String to, String itemId, int quantity) =>
      Command('item.transfer', {'fromCharacterId': from, 'toCharacterId': to, 'itemId': itemId, 'quantity': quantity});
  static Command transferCurrency(String from, String to, Currency c) =>
      Command('currency.transfer', {'fromCharacterId': from, 'toCharacterId': to, 'currency': c.toJson()});
  static Command putLibraryItem(InventoryItem item) => Command('library.put', {'item': item.toJson()});
  static Command deleteLibraryItem(String id) => Command('library.delete', {'id': id});

  // ------------------------------------------------------------ Artesanía
  static Command putRecipe(Recipe r) => Command('recipe.put', {'recipe': r.toJson()});
  static Command deleteRecipe(String id) => Command('recipe.delete', {'id': id});
  static Command craftRecipe(String characterId, String recipeId, int times) =>
      Command('craft.recipe', {'characterId': characterId, 'recipeId': recipeId, 'times': times});
  static Command craftStandard(String characterId, InventoryItem item, int costCp, int days) =>
      Command('craft.standard', {'characterId': characterId, 'item': item.toJson(), 'costCp': costCp, 'days': days});
  static Command craftProgress(String characterId, String projectId, int days) =>
      Command('craft.progress', {'characterId': characterId, 'projectId': projectId, 'days': days});
  static Command craftCancel(String characterId, String projectId) =>
      Command('craft.cancel', {'characterId': characterId, 'projectId': projectId});

  // ------------------------------------------------------------ Máster
  static Command putMonster(Monster m) => Command('monster.put', {'monster': m.toJson()});
  static Command deleteMonster(String id) => Command('monster.delete', {'id': id});
  static Command putEncounter(Encounter e) => Command('encounter.put', {'encounter': e.toJson()});
  static Command setInitiative(String characterId, int value) =>
      Command('encounter.initiative', {'characterId': characterId, 'value': value});
  static Command putNote(CampaignNote n) => Command('note.put', {'note': n.toJson()});
  static Command deleteNote(String id) => Command('note.delete', {'id': id});
  static Command putSettings(CampaignSettings s, {String? name, String? description, Ruleset? ruleset}) => Command(
    'settings.put',
    {'settings': s.toJson(), 'name': ?name, 'description': ?description, if (ruleset != null) 'ruleset': ruleset.name},
  );
  static Command kickMember(String userId, {bool ban = true}) => Command('member.kick', {'userId': userId, 'ban': ban});
  static Command unbanMember(String userId) => Command('member.unban', {'userId': userId});
  static Command regenerateJoinCode() => const Command('campaign.newJoinCode');

  // ------------------------------------------------------------ Tiradas y tablero
  static Command roll(String label, String expression, {String? characterId}) =>
      Command('roll.make', {'label': label, 'expression': expression, 'characterId': ?characterId});
  static Command putMap(BoardMap m) => Command('board.putMap', {'map': m.toJson()});
  static Command deleteMap(String id) => Command('board.deleteMap', {'id': id});
  static Command setActiveMap(String mapId) => Command('board.setActive', {'mapId': mapId});
  static Command putToken(BoardToken t) => Command('board.putToken', {'token': t.toJson()});
  static Command moveToken(String tokenId, int x, int y) =>
      Command('board.moveToken', {'tokenId': tokenId, 'x': x, 'y': y});
  static Command removeToken(String id) => Command('board.removeToken', {'id': id});

  // ------------------------------------------------------------ Chat
  static Command sendChat(String channelId, String text, {String kind = 'text'}) =>
      Command('chat.send', {'channelId': channelId, 'text': text, 'kind': kind});
  static Command createChannel(String name, List<String> memberIds, {bool direct = false}) =>
      Command('chat.createChannel', {'name': name, 'memberIds': memberIds, 'direct': direct});
}
