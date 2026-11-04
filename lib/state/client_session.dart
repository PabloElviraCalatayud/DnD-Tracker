import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/json.dart';
import '../data/storage.dart';
import '../domain/campaign.dart';
import '../domain/character.dart';
import '../domain/chat.dart';
import '../domain/roll.dart';
import '../domain/profile.dart';
import '../engine/commands.dart';
import '../net/invite.dart';
import '../net/protocol.dart';
import 'session.dart';
import '../core/i18n.dart';

/// Sesión de un jugador conectado al dispositivo del máster.
///
/// - Prueba todas las direcciones de la invitación a la vez (LAN, VPN, relay)
///   y se queda con la primera que responde.
/// - Se reconecta sola si se cae la conexión.
/// - Guarda la última vista para poder consultar la ficha sin conexión.
/// - Aplica al momento sus propios cambios de ficha (optimista) y los
///   reemplaza por la vista del máster cuando éste confirma.
class ClientSession extends GameSession {
  ClientSession({
    required this.invite,
    required this.profile,
    this.storage,
    Campaign? cachedView,
    ChatState? cachedChat,
  }) : _view = cachedView ?? _placeholder(invite),
       _serverView = cachedView,
       _chat = cachedChat ?? ChatState();

  Invite invite;
  final UserProfile profile;
  final AppStorage? storage;

  Campaign _view;
  Campaign? _serverView;
  ChatState _chat;
  ConnectionStatus _status = ConnectionStatus.connecting;
  String _statusMessage = '';
  WebSocket? _ws;
  Uri? connectedVia;
  bool _closed = false;
  int _nextId = 1;
  final Map<int, Completer<CommandResult>> _pending = {};
  Timer? _cacheTimer;
  Completer<void>? _wakeUp;

  static Campaign _placeholder(Invite inv) => Campaign(
    id: inv.campaignId,
    name: inv.campaignName,
    dmUserId: '',
    dmName: inv.dmName,
    joinCode: '',
    isView: true,
  );

  bool get hasData => _serverView != null;

  @override
  Campaign get campaign => _view;

  @override
  ChatState get chat => _chat;

  final List<RollEntry> _rolls = [];

  @override
  List<RollEntry> get rolls => _rolls;

  @override
  bool get isDm => false;

  @override
  String get myUserId => profile.userId;

  @override
  String get myName => profile.displayName;

  @override
  ConnectionStatus get status => _status;

  @override
  String get statusMessage => _statusMessage;

  void _setStatus(ConnectionStatus s, [String message = '']) {
    _status = s;
    _statusMessage = message;
    notifyListeners();
  }

  /// Arranca el bucle de conexión (no espera a que conecte).
  void start() => unawaited(_loop());

  /// Fuerza un reintento inmediato si estaba esperando.
  void retryNow() {
    if (_status == ConnectionStatus.denied || _status == ConnectionStatus.kicked) {
      _status = ConnectionStatus.connecting;
      unawaited(_loop());
    }
    _wakeUp?.complete();
    _wakeUp = null;
  }

  Future<void> _loop() async {
    var attempt = 0;
    while (!_closed) {
      _setStatus(ConnectionStatus.connecting, tr('Buscando al máster…'));
      final ws = await _connectAny(invite.candidates);
      if (_closed) {
        await ws?.close();
        return;
      }
      if (ws == null) {
        attempt++;
        _setStatus(ConnectionStatus.offline, tr('No se encuentra al máster. ¿Tiene la partida abierta? Reintentando…'));
      } else {
        attempt = 0;
        final outcome = await _runConnection(ws);
        if (outcome == _Outcome.stop || _closed) return;
      }
      final wait = [2, 3, 5, 8, 13, 20][attempt.clamp(0, 5)];
      _wakeUp = Completer<void>();
      await Future.any([Future<void>.delayed(Duration(seconds: wait)), _wakeUp!.future]);
      _wakeUp = null;
    }
  }

  /// Intenta todas las direcciones en paralelo y devuelve la primera que conecta.
  Future<WebSocket?> _connectAny(List<Uri> uris) async {
    if (uris.isEmpty) return null;
    final completer = Completer<WebSocket?>();
    var remaining = uris.length;
    for (final uri in uris) {
      WebSocket.connect(uri.toString())
          .timeout(const Duration(seconds: 6))
          .then(
            (ws) {
              if (completer.isCompleted) {
                ws.close();
              } else {
                connectedVia = uri;
                completer.complete(ws);
              }
            },
            onError: (Object _) {
              remaining--;
              if (remaining == 0 && !completer.isCompleted) completer.complete(null);
            },
          );
    }
    return completer.future;
  }

  Future<_Outcome> _runConnection(WebSocket ws) async {
    _ws = ws;
    ws.pingInterval = const Duration(seconds: 15);
    ws.add(
      Proto.encode(Proto.hello, {
        'v': Proto.version,
        'userId': profile.userId,
        'name': profile.displayName,
        'secret': profile.secret,
        'code': invite.code,
        'campaignId': invite.campaignId,
      }),
    );
    var outcome = _Outcome.retry;
    final welcomeTimer = Timer(const Duration(seconds: 12), () {
      if (_status != ConnectionStatus.online) ws.close(WebSocketStatus.normalClosure, 'sin respuesta');
    });
    try {
      await for (final raw in ws) {
        final msg = Proto.decode(raw);
        if (msg == null) continue;
        final r = _handle(msg);
        if (r != null) outcome = r;
      }
    } on Object {
      // Conexión rota: se reintentará.
    }
    welcomeTimer.cancel();
    _ws = null;
    for (final c in _pending.values) {
      if (!c.isCompleted) c.complete(CommandResult(false, tr('Se perdió la conexión')));
    }
    _pending.clear();
    if (_serverView != null) _view = _serverView!;
    if (outcome == _Outcome.retry && !_closed) {
      _setStatus(ConnectionStatus.offline, tr('Conexión perdida. Reintentando…'));
    }
    return outcome;
  }

  _Outcome? _handle(Map<String, dynamic> msg) {
    switch (msg['t']) {
      case Proto.welcome:
        _applyServerView(Campaign.fromJson(asMap(msg['view'])), force: true);
        _chat = ChatState.fromJson(asMap(msg['chat']));
        _rolls
          ..clear()
          ..addAll(asList(msg['rolls'], RollEntry.fromJson));
        _setStatus(ConnectionStatus.online, connectedVia == null ? '' : tr('Vía {0}', [connectedVia!.host]));
        _saveCacheSoon(updateInvite: true);
      case Proto.view:
        _applyServerView(Campaign.fromJson(asMap(msg['view'])));
      case Proto.ack:
        final ok = asBool(msg['ok']);
        final c = _pending.remove(asInt(msg['id']));
        c?.complete(CommandResult(ok, asStringOrNull(msg['error']), msg['data'] is Map ? asMap(msg['data']) : null));
        // Si el máster acepta, su nueva vista llegará enseguida: mantenemos la
        // versión optimista hasta entonces para que no "parpadee". Si lo
        // rechaza, volvemos a la última vista buena.
        if (!ok && _pending.isEmpty && _serverView != null) {
          _view = _serverView!;
          notifyListeners();
        }
      case Proto.roll:
        final r = RollEntry.fromJson(asMap(msg['roll']));
        if (!_rolls.any((x) => x.id == r.id)) {
          _rolls.add(r);
          if (_rolls.length > 300) _rolls.removeAt(0);
          notifyListeners();
        }
      case Proto.asset:
        final id = asString(msg['id']);
        final data = msg['data'];
        final bytes = data is String ? base64Decode(data) : null;
        if (bytes != null) {
          _assetCache[id] = bytes;
          unawaited(storage?.saveAsset(id, bytes));
        }
        _assetRequests.remove(id)?.complete(bytes);
      case Proto.assetSaved:
        _uploads.remove(asInt(msg['req']))?.complete(asStringOrNull(msg['id']));
      case Proto.chat:
        final m = ChatMessage.fromJson(asMap(msg['message']));
        _chat.add(m);
        countUnread(m);
        _saveCacheSoon();
        notifyListeners();
      case Proto.channel:
        _chat.upsertChannel(ChatChannel.fromJson(asMap(msg['channel'])));
        notifyListeners();
      case Proto.denied:
        _setStatus(ConnectionStatus.denied, asString(msg['reason'], tr('El máster ha rechazado la conexión.')));
        return _Outcome.stop;
      case Proto.kicked:
        _setStatus(ConnectionStatus.kicked, asString(msg['reason'], tr('Has sido expulsado.')));
        return _Outcome.stop;
    }
    return null;
  }

  void _applyServerView(Campaign view, {bool force = false}) {
    _serverView = view;
    // Mientras haya cambios propios sin confirmar, mantenemos la versión local.
    if (force || _pending.isEmpty) {
      _view = view;
      notifyListeners();
    }
    _saveCacheSoon();
  }

  // ------------------------------------------------------------ Imágenes

  final Map<String, Uint8List> _assetCache = {};
  final Map<String, Completer<Uint8List?>> _assetRequests = {};
  final Map<int, Completer<String?>> _uploads = {};

  @override
  Future<Uint8List?> loadAsset(String id) async {
    final cached = _assetCache[id] ?? await storage?.loadAsset(id);
    if (cached != null) {
      _assetCache[id] = cached;
      return cached;
    }
    final ws = _ws;
    if (ws == null) return null;
    final completer = _assetRequests.putIfAbsent(id, () {
      ws.add(Proto.encode(Proto.getAsset, {'id': id}));
      return Completer<Uint8List?>();
    });
    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        _assetRequests.remove(id);
        return null;
      },
    );
  }

  @override
  Future<String?> uploadAsset(Uint8List bytes) async {
    final ws = _ws;
    if (ws == null) return null;
    final req = _nextId++;
    final completer = Completer<String?>();
    _uploads[req] = completer;
    ws.add(Proto.encode(Proto.putAsset, {'req': req, 'data': base64Encode(bytes)}));
    final id = await completer.future.timeout(const Duration(seconds: 60), onTimeout: () => null);
    if (id != null) {
      _assetCache[id] = bytes;
      await storage?.saveAsset(id, bytes);
    }
    return id;
  }

  @override
  Future<CommandResult> send(Command cmd) async {
    final ws = _ws;
    if (ws == null || _status != ConnectionStatus.online) {
      return CommandResult(false, tr('Sin conexión con el máster'));
    }
    if (cmd.type == 'character.put') {
      // Actualización optimista: la ficha cambia al instante en pantalla.
      final edited = Character.fromJson(asMap(cmd.data['character']));
      final local = _view.copy();
      final i = local.characters.indexWhere((c) => c.id == edited.id);
      if (i >= 0) {
        local.characters[i] = edited;
      } else {
        local.characters.add(edited);
      }
      _view = local;
      notifyListeners();
    }
    final id = _nextId++;
    final completer = Completer<CommandResult>();
    _pending[id] = completer;
    ws.add(Proto.encode(Proto.cmd, {'id': id, 'cmd': cmd.toJson()}));
    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        _pending.remove(id);
        return CommandResult(false, tr('El máster no ha respondido'));
      },
    );
  }

  void _saveCacheSoon({bool updateInvite = false}) {
    final s = storage;
    if (s == null) return;
    _cacheTimer?.cancel();
    _cacheTimer = Timer(const Duration(milliseconds: 600), () async {
      final view = _serverView;
      if (updateInvite && view != null) {
        invite = Invite(
          campaignId: view.id,
          campaignName: view.name,
          code: invite.code,
          hosts: invite.hosts,
          port: invite.port,
          relayUrl: invite.relayUrl,
          dmName: view.dmName,
        );
      }
      await s.saveJoined(
        JoinedCampaign(
          invite: invite,
          lastView: view,
          chat: _chat,
          lastConnectedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    });
  }

  @override
  Future<void> close() async {
    _closed = true;
    _wakeUp?.complete();
    await _ws?.close();
    _cacheTimer?.cancel();
    final s = storage;
    if (s != null && _serverView != null) {
      await s.saveJoined(
        JoinedCampaign(
          invite: invite,
          lastView: _serverView,
          chat: _chat,
          lastConnectedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
  }
}

enum _Outcome { retry, stop }
