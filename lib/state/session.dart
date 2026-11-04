import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../domain/campaign.dart';
import '../domain/character.dart';
import '../domain/chat.dart';
import '../domain/roll.dart';
import '../engine/commands.dart';
import '../core/i18n.dart';

enum ConnectionStatus {
  hosting('Anfitrión activo'),
  connecting('Conectando…'),
  online('Conectado'),
  offline('Sin conexión (datos guardados)'),
  denied('Acceso denegado'),
  kicked('Expulsado de la partida');

  const ConnectionStatus(this._label);
  final String _label;
  String get label => tr(_label);
}

class CommandResult {
  const CommandResult(this.ok, [this.error, this.data]);
  final bool ok;
  final String? error;

  /// Datos de respuesta del anfitrión (p. ej. la tirada hecha).
  final Map<String, dynamic>? data;
}

/// Sesión de juego activa. La interfaz trabaja siempre contra esta clase,
/// sin saber si es el máster (anfitrión) o un jugador conectado por red.
abstract class GameSession extends ChangeNotifier {
  Campaign get campaign;
  ChatState get chat;
  bool get isDm;
  String get myUserId;
  String get myName;
  ConnectionStatus get status;
  String get statusMessage;

  /// Mensajes de chat no leídos por canal.
  final Map<String, int> unread = {};
  String? openChannelId;

  Future<CommandResult> send(Command cmd);
  Future<void> close();

  /// Tiradas visibles para este usuario (el máster ve también las suyas).
  List<RollEntry> get rolls;

  /// Imagen guardada por el anfitrión (mapa o ficha). Null si no existe.
  Future<Uint8List?> loadAsset(String id);

  /// Sube una imagen y devuelve su id (null si falla).
  Future<String?> uploadAsset(Uint8List bytes);

  final Map<String, Future<Uint8List?>> _assetFutures = {};

  /// Igual que [loadAsset] pero comparte la petición entre widgets.
  Future<Uint8List?> asset(String id) => _assetFutures.putIfAbsent(id, () => loadAsset(id));

  /// Hace una tirada registrada en el tablero. El resultado lo genera el
  /// anfitrión. Devuelve null y el error si no se pudo.
  Future<(RollEntry?, String?)> roll(String label, String expression, {String? characterId}) async {
    final r = await send(Command.roll(label, expression, characterId: characterId));
    final data = r.data?['roll'];
    if (!r.ok || data is! Map) return (null, r.error);
    return (RollEntry.fromJson(data.cast<String, dynamic>()), null);
  }

  bool get canEdit => isDm || status == ConnectionStatus.online;

  List<Character> get myCharacters => campaign.charactersOf(myUserId);

  /// Personaje que el usuario está mirando ahora mismo (si tiene varios).
  String? selectedCharacterId;

  Character? get activeCharacter {
    final mine = myCharacters;
    if (mine.isEmpty) return null;
    return mine.where((c) => c.id == selectedCharacterId).firstOrNull ?? mine.first;
  }

  int get totalUnread => unread.values.fold(0, (a, b) => a + b);

  /// Jugadores conectados ahora mismo.
  int get onlineCount => campaign.online.length;
  Set<String> get onlineIds => campaign.online.toSet();

  void refresh() => notifyListeners();

  void selectCharacter(String id) {
    selectedCharacterId = id;
    notifyListeners();
  }

  void markRead(String channelId) {
    if ((unread[channelId] ?? 0) == 0) return;
    unread[channelId] = 0;
    notifyListeners();
  }

  @protected
  void countUnread(ChatMessage m) {
    if (m.authorId == myUserId || m.channelId == openChannelId) return;
    unread[m.channelId] = (unread[m.channelId] ?? 0) + 1;
  }

  /// Atajo: guardar un personaje modificado.
  Future<CommandResult> saveCharacter(Character c) => send(Command.putCharacter(c));

  /// Edita una copia del personaje y la guarda.
  Future<CommandResult> editCharacter(String id, void Function(Character c) edit) {
    final current = campaign.character(id);
    if (current == null) return Future.value(CommandResult(false, tr('El personaje no existe')));
    final copy = current.copy();
    edit(copy);
    return saveCharacter(copy);
  }
}

/// Da acceso a la sesión a todo el árbol de la partida y reconstruye a los
/// widgets que la usan cuando cambia.
class SessionScope extends InheritedNotifier<GameSession> {
  const SessionScope({super.key, required GameSession session, required super.child}) : super(notifier: session);

  static GameSession of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope no encontrado');
    return scope!.notifier!;
  }

  static GameSession? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SessionScope>()?.notifier;

  static GameSession read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<SessionScope>();
    return scope!.notifier!;
  }
}
