import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../core/ids.dart';
import '../core/json.dart';
import '../data/storage.dart';
import '../domain/campaign.dart';
import '../domain/chat.dart';
import '../domain/roll.dart';
import '../domain/profile.dart';
import '../engine/campaign_engine.dart';
import '../engine/commands.dart';
import '../engine/view_filter.dart';
import '../net/invite.dart';
import '../net/lan_discovery.dart';
import '../net/network_info.dart';
import '../net/protocol.dart';
import '../net/transport.dart';
import 'session.dart';
import '../core/i18n.dart';

class ConnectedPlayer {
  ConnectedPlayer(this.peer);
  final Peer peer;
  String? userId;
  String name = '';
  bool get authed => userId != null;
  String lastViewJson = '';
  Timer? helloTimeout;
  StreamSubscription<String>? sub;
}

/// Sesión del máster: guarda la partida, abre el servidor y atiende a los
/// jugadores. Es la única fuente de verdad.
class HostSession extends GameSession {
  HostSession({
    required Campaign campaign,
    required this.profile,
    required this.storage,
    int? port,
    String? relayUrl,
    this.enableLanBeacon = true,
  }) : _campaign = campaign, // ignore: prefer_initializing_formals
       port = port ?? profile.hostPort,
       relayUrl = (relayUrl ?? profile.relayUrl).trim() {
    engine = CampaignEngine(_campaign);
  }

  final UserProfile profile;
  final AppStorage? storage;
  final bool enableLanBeacon;
  int port;
  String relayUrl;

  final Campaign _campaign;
  late final CampaignEngine engine;
  final DirectServer _server = DirectServer();
  RelayLink? _relay;
  LanBeacon? _beacon;
  final List<StreamSubscription<Object?>> _subs = [];
  final Map<String, ConnectedPlayer> _players = {};
  List<LocalAddress> addresses = [];
  String _statusMessage = '';
  bool _serverOk = false;
  Timer? _saveTimer;
  Timer? _broadcastTimer;
  bool _closed = false;

  @override
  Campaign get campaign => _campaign;

  @override
  ChatState get chat => _campaign.chat.visibleTo(myUserId, isDm: true);

  @override
  List<RollEntry> get rolls => _campaign.rolls;

  @override
  bool get isDm => true;

  @override
  String get myUserId => profile.userId;

  @override
  String get myName => profile.displayName;

  @override
  ConnectionStatus get status => ConnectionStatus.hosting;

  @override
  String get statusMessage => _statusMessage;

  bool get serverRunning => _serverOk;
  RelayState get relayState => _relay?.state ?? RelayState.disabled;
  String get relayError => _relay?.lastError ?? '';

  Set<String> get onlineUserIds => {
    for (final p in _players.values)
      if (p.authed) p.userId!,
  };

  @override
  int get onlineCount => onlineUserIds.length;

  List<ConnectedPlayer> get connectedPlayers => _players.values.where((p) => p.authed).toList();

  Invite get invite {
    final hosts = addresses.where((a) => a.kind != AddressKind.other).map((a) => a.address).toList();
    if (hosts.isEmpty) hosts.addAll(addresses.map((a) => a.address));
    return Invite(
      campaignId: _campaign.id,
      campaignName: _campaign.name,
      code: _campaign.joinCode,
      hosts: hosts,
      port: port,
      relayUrl: relayUrl,
      dmName: _campaign.dmName,
    );
  }

  Future<void> start() async {
    if (_campaign.dmUserId != profile.userId) {
      _campaign.dmUserId = profile.userId;
    }
    _campaign.dmName = profile.displayName;
    addresses = await localAddresses();
    try {
      await _server.start(port);
      port = _server.port ?? port;
      _serverOk = true;
      _statusMessage = 'Escuchando en el puerto $port';
    } on Object catch (e) {
      _serverOk = false;
      _statusMessage = 'No se pudo abrir el puerto $port: $e';
    }
    _subs.add(_server.onPeer.listen(_onPeer));
    if (enableLanBeacon && _serverOk) {
      _beacon = LanBeacon(
        port: port,
        campaignId: _campaign.id,
        name: _campaign.name,
        dmName: _campaign.dmName,
        ruleset: _campaign.ruleset.short,
      );
      await _beacon!.start();
    }
    if (relayUrl.isNotEmpty) await _startRelay();
    notifyListeners();
  }

  Future<void> _startRelay() async {
    final relay = RelayLink(relayUrl: relayUrl, room: _campaign.id, hostKey: profile.secret);
    _relay = relay;
    _subs.add(relay.onPeer.listen(_onPeer));
    _subs.add(relay.onState.listen((_) => notifyListeners()));
    await relay.start();
  }

  /// Cambia la URL del relay en caliente (vacía = desactivar).
  Future<void> setRelayUrl(String url) async {
    await _relay?.stop();
    _relay = null;
    relayUrl = url.trim();
    if (relayUrl.isNotEmpty) await _startRelay();
    notifyListeners();
  }

  Future<void> refreshAddresses() async {
    addresses = await localAddresses();
    notifyListeners();
  }

  // ------------------------------------------------------------ Conexiones

  void _onPeer(Peer peer) {
    final p = ConnectedPlayer(peer);
    _players[peer.id] = p;
    p.helloTimeout = Timer(const Duration(seconds: 15), () {
      if (!p.authed) peer.close('sin saludo');
    });
    p.sub = peer.messages.listen((raw) => _onMessage(p, raw), onDone: () => _onClosed(p), onError: (_) => _onClosed(p));
  }

  void _onClosed(ConnectedPlayer p) {
    p.helloTimeout?.cancel();
    if (_players.remove(p.peer.id) == null) return;
    if (p.authed) {
      _campaign.member(p.userId!)?.lastSeenAt = DateTime.now().millisecondsSinceEpoch;
      _scheduleBroadcast();
      notifyListeners();
    }
  }

  void _onMessage(ConnectedPlayer p, String raw) {
    final msg = Proto.decode(raw);
    if (msg == null) return;
    if (!p.authed) {
      if (msg['t'] == Proto.hello) _handleHello(p, msg);
      return;
    }
    switch (msg['t']) {
      case Proto.cmd:
        final id = msg['id'];
        final cmd = Command.fromJson(asMap(msg['cmd']));
        final result = _apply(cmd, Actor(userId: p.userId!, name: p.name, isDm: false));
        p.peer.send(Proto.encode(Proto.ack, {'id': id, 'ok': result.ok, 'error': result.error, 'data': ?result.data}));
      case Proto.getAsset:
        unawaited(_sendAsset(p, asString(msg['id'])));
      case Proto.putAsset:
        unawaited(_receiveAsset(p, msg));
    }
  }

  // ------------------------------------------------------------ Imágenes

  final Map<String, Uint8List> _assetCache = {};

  /// Tamaño máximo de una imagen subida por un jugador (fichas).
  static const maxPlayerAssetBytes = 512 * 1024;

  Future<void> _sendAsset(ConnectedPlayer p, String id) async {
    final bytes = await loadAsset(id);
    p.peer.send(Proto.encode(Proto.asset, {'id': id, if (bytes != null) 'data': base64Encode(bytes)}));
  }

  Future<void> _receiveAsset(ConnectedPlayer p, Map<String, dynamic> msg) async {
    final req = msg['req'];
    try {
      final bytes = base64Decode(asString(msg['data']));
      if (bytes.length > maxPlayerAssetBytes) throw const FormatException('demasiado grande');
      final id = await uploadAsset(bytes);
      p.peer.send(Proto.encode(Proto.assetSaved, {'req': req, 'id': id}));
    } on Object {
      p.peer.send(Proto.encode(Proto.assetSaved, {'req': req}));
    }
  }

  @override
  Future<Uint8List?> loadAsset(String id) async {
    final cached = _assetCache[id];
    if (cached != null) return cached;
    final bytes = await storage?.loadAsset(id);
    if (bytes != null) _assetCache[id] = bytes;
    return bytes;
  }

  @override
  Future<String?> uploadAsset(Uint8List bytes) async {
    final id = newId();
    _assetCache[id] = bytes;
    await storage?.saveAsset(id, bytes);
    return id;
  }

  void _deny(ConnectedPlayer p, String reason) {
    p.peer.send(Proto.encode(Proto.denied, {'reason': reason}));
    Future<void>.delayed(const Duration(milliseconds: 200), () => p.peer.close(reason));
  }

  void _handleHello(ConnectedPlayer p, Map<String, dynamic> msg) {
    p.helloTimeout?.cancel();
    final userId = asString(msg['userId']);
    final name = asString(msg['name']).trim();
    final secret = asString(msg['secret']);
    final code = asString(msg['code']).trim().toUpperCase();
    final campaignId = asString(msg['campaignId']);
    if (asInt(msg['v']) != Proto.version) {
      return _deny(p, tr('Versión de la app distinta a la del máster. Actualizad los dos.'));
    }
    if (campaignId.isNotEmpty && campaignId != _campaign.id) {
      return _deny(p, tr('Este anfitrión está alojando otra partida ("{0}").', [_campaign.name]));
    }
    if (userId.isEmpty || secret.isEmpty) return _deny(p, tr('Perfil no válido'));
    if (userId == _campaign.dmUserId) return _deny(p, tr('Eres el máster de esta partida.'));
    var member = _campaign.member(userId);
    if (member != null) {
      if (member.banned) return _deny(p, tr('El máster te ha expulsado de esta partida.'));
      if (member.deviceKey.isNotEmpty && member.deviceKey != secret) {
        return _deny(p, tr('Tu identidad no coincide con la registrada en la partida.'));
      }
      member.deviceKey = secret;
    } else {
      if (!_campaign.settings.allowNewPlayers) {
        return _deny(p, tr('La partida no admite jugadores nuevos ahora mismo.'));
      }
      if (code != _campaign.joinCode.toUpperCase()) return _deny(p, tr('Código de partida incorrecto.'));
      if (_campaign.members.where((m) => !m.banned).length >= Campaign.maxPlayers) {
        return _deny(p, tr('La partida está completa (máximo {0} jugadores).', [Campaign.maxPlayers]));
      }
      member = Member(userId: userId, name: name.isEmpty ? tr('Jugador') : name, deviceKey: secret);
      _campaign.members.add(member);
      _campaign.addLog(tr('{0} se ha unido a la partida', [member.name]), actor: member.name);
    }
    if (name.isNotEmpty) member.name = name;
    member.lastSeenAt = DateTime.now().millisecondsSinceEpoch;

    // Si el jugador ya estaba conectado (otra pestaña, reconexión) cerramos la vieja.
    for (final other in _players.values.toList()) {
      if (other != p && other.userId == userId) {
        other.userId = null;
        other.peer.close('sesión sustituida');
        _players.remove(other.peer.id);
      }
    }
    p.userId = userId;
    p.name = member.name;
    final view = _viewFor(userId);
    p.lastViewJson = Proto.encode(Proto.view, {'view': view});
    p.peer.send(
      Proto.encode(Proto.welcome, {
        'role': 'player',
        'campaignId': _campaign.id,
        'view': view,
        'chat': _campaign.chat.visibleTo(userId).toJson(),
        'rolls': _visibleRolls().map((r) => r.toJson()).toList(),
      }),
    );
    _scheduleSave();
    _scheduleBroadcast();
    notifyListeners();
  }

  /// Últimas tiradas que pueden ver los jugadores (las del máster no).
  List<RollEntry> _visibleRolls() {
    final visible = _campaign.rolls.where((r) => !r.hidden).toList();
    return visible.length > 100 ? visible.sublist(visible.length - 100) : visible;
  }

  Map<String, dynamic> _viewFor(String userId) =>
      ViewFilter.forPlayer(_campaign, userId, online: onlineUserIds).toJson(includeChat: false);

  // ------------------------------------------------------------ Comandos

  EngineResult _apply(Command cmd, Actor actor) {
    final result = engine.apply(cmd, actor);
    if (!result.ok) return result;
    if (result.changed) {
      _scheduleSave();
      _scheduleBroadcast();
      _beacon?.name = _campaign.name;
      _beacon?.ruleset = _campaign.ruleset.short;
    }
    for (final m in result.messages) {
      _deliverChat(m);
    }
    for (final c in result.channels) {
      _deliverChannel(c);
    }
    for (final r in result.rolls) {
      _deliverRoll(r);
    }
    if (result.messages.isNotEmpty || result.channels.isNotEmpty || result.rolls.isNotEmpty) _scheduleSave();
    if (result.kickedUserId != null) _kick(result.kickedUserId!);
    notifyListeners();
    return result;
  }

  @override
  Future<CommandResult> send(Command cmd) async {
    final r = _apply(cmd, Actor(userId: myUserId, name: myName, isDm: true));
    return CommandResult(r.ok, r.error, r.data);
  }

  void _deliverRoll(RollEntry r) {
    if (r.hidden) return;
    final encoded = Proto.encode(Proto.roll, {'roll': r.toJson()});
    for (final p in _players.values) {
      if (p.authed) p.peer.send(encoded);
    }
  }

  void _deliverChat(ChatMessage m) {
    final channel = _campaign.chat.channel(m.channelId);
    if (channel == null) return;
    final encoded = Proto.encode(Proto.chat, {'message': m.toJson()});
    for (final p in _players.values) {
      if (p.authed && channel.includes(p.userId!)) p.peer.send(encoded);
    }
    // El máster ve todas las conversaciones.
    countUnread(m);
  }

  void _deliverChannel(ChatChannel c) {
    final encoded = Proto.encode(Proto.channel, {'channel': c.toJson()});
    for (final p in _players.values) {
      if (p.authed && c.includes(p.userId!)) p.peer.send(encoded);
    }
  }

  void _kick(String userId) {
    for (final p in _players.values.toList()) {
      if (p.userId == userId) {
        p.peer.send(Proto.encode(Proto.kicked, {'reason': tr('El máster te ha expulsado de la partida.')}));
        Future<void>.delayed(const Duration(milliseconds: 200), () => p.peer.close('expulsado'));
      }
    }
  }

  // ------------------------------------------------------------ Difusión y guardado

  void _scheduleBroadcast() {
    _broadcastTimer ??= Timer(const Duration(milliseconds: 40), () {
      _broadcastTimer = null;
      broadcastNow();
    });
  }

  /// Envía a cada jugador su vista, sólo si ha cambiado para él.
  void broadcastNow() {
    for (final p in _players.values) {
      if (!p.authed) continue;
      final encoded = Proto.encode(Proto.view, {'view': _viewFor(p.userId!)});
      if (encoded == p.lastViewJson) continue;
      p.lastViewJson = encoded;
      p.peer.send(encoded);
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () => unawaited(saveNow()));
  }

  Future<void> saveNow() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await storage?.saveHosted(_campaign);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _broadcastTimer?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    _beacon?.stop();
    await _relay?.stop();
    for (final p in _players.values.toList()) {
      await p.sub?.cancel();
      await p.peer.close('el máster ha cerrado la partida');
    }
    _players.clear();
    await _server.stop();
    await saveNow();
  }
}
