import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/json.dart';
import 'invite.dart';
import 'protocol.dart';

/// Una conexión de un jugador vista desde el anfitrión, venga directa o a
/// través del relay.
abstract class Peer {
  String get id;
  String get description;
  Stream<String> get messages;
  void send(String data);
  Future<void> close([String reason = '']);
}

/// Servidor WebSocket que corre dentro de la app del máster.
class DirectServer {
  HttpServer? _server;
  final _peers = StreamController<Peer>.broadcast();
  int _counter = 0;

  Stream<Peer> get onPeer => _peers.stream;
  bool get isRunning => _server != null;
  int? get port => _server?.port;

  Future<void> start(int port) async {
    if (_server != null) return;
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server = server;
    server.listen((request) async {
      if (request.uri.path == Proto.path && WebSocketTransformer.isUpgradeRequest(request)) {
        try {
          final ws = await WebSocketTransformer.upgrade(request, compression: CompressionOptions.compressionDefault);
          ws.pingInterval = const Duration(seconds: 15);
          final addr = request.connectionInfo?.remoteAddress.address ?? '?';
          _peers.add(_WebSocketPeer('d${++_counter}', 'directo · $addr', ws));
        } on Object {
          // Conexión rota durante el saludo: la ignoramos.
        }
        return;
      }
      // Página mínima para comprobar desde un navegador que el anfitrión responde.
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.text
        ..write('DnD Tracker: anfitrión activo. Conecta desde la app.');
      await request.response.close();
    }, onError: (_) {});
  }

  Future<void> stop() async {
    final s = _server;
    _server = null;
    await s?.close(force: true);
  }
}

class _WebSocketPeer implements Peer {
  _WebSocketPeer(this.id, this.description, this._ws) {
    _ws.listen(
      (data) {
        if (data is String) _messages.add(data);
      },
      onDone: () => _messages.close(),
      onError: (_) => _messages.close(),
      cancelOnError: true,
    );
  }

  @override
  final String id;
  @override
  final String description;
  final WebSocket _ws;
  final _messages = StreamController<String>();

  @override
  Stream<String> get messages => _messages.stream;

  @override
  void send(String data) {
    if (_ws.readyState != WebSocket.open) return;
    try {
      _ws.add(data);
    } on StateError {
      // El socket se está cerrando.
    }
  }

  @override
  Future<void> close([String reason = '']) async {
    try {
      await _ws.close(WebSocketStatus.normalClosure, reason);
    } on Object {
      // Ya estaba cerrado.
    }
  }
}

enum RelayState { disabled, connecting, online, error }

/// Enlace del anfitrión con un servidor relay (ver carpeta relay/). El
/// anfitrión abre UNA conexión saliente y el relay le reenvía las de los
/// jugadores, así funciona aunque el máster esté detrás de CGNAT (datos
/// móviles) o de un router sin puertos abiertos.
class RelayLink {
  RelayLink({required this.relayUrl, required this.room, required this.hostKey});

  final String relayUrl;
  final String room;
  final String hostKey;

  final _peers = StreamController<Peer>.broadcast();
  final _state = StreamController<RelayState>.broadcast();
  final Map<String, _RelayPeer> _active = {};
  WebSocket? _ws;
  bool _stopped = false;
  int _attempt = 0;
  RelayState state = RelayState.connecting;
  String lastError = '';

  Stream<Peer> get onPeer => _peers.stream;
  Stream<RelayState> get onState => _state.stream;

  void _setState(RelayState s) {
    state = s;
    if (!_state.isClosed) _state.add(s);
  }

  Future<void> start() async {
    _stopped = false;
    unawaited(_connectLoop());
  }

  Future<void> _connectLoop() async {
    while (!_stopped) {
      _setState(RelayState.connecting);
      try {
        final ws = await WebSocket.connect(
          Invite.relayHostUri(relayUrl, room, hostKey).toString(),
        ).timeout(const Duration(seconds: 10));
        ws.pingInterval = const Duration(seconds: 20);
        _ws = ws;
        _attempt = 0;
        _setState(RelayState.online);
        await for (final data in ws) {
          if (data is String) _handle(data);
        }
        lastError = ws.closeReason ?? '';
      } on Object catch (e) {
        lastError = e.toString();
      }
      _ws = null;
      for (final p in _active.values.toList()) {
        p._closed();
      }
      _active.clear();
      if (_stopped) break;
      _setState(RelayState.error);
      final wait = [1, 2, 4, 8, 15, 30][_attempt.clamp(0, 5)];
      _attempt++;
      await Future<void>.delayed(Duration(seconds: wait));
    }
    _setState(RelayState.disabled);
  }

  void _handle(String raw) {
    Map<String, dynamic> msg;
    try {
      msg = asMap(jsonDecode(raw));
    } on FormatException {
      return;
    }
    final peerId = asString(msg['peer']);
    switch (msg['rt']) {
      case 'open':
        final p = _RelayPeer(this, peerId, 'relay · ${asString(msg['addr'], '?')}');
        _active[peerId] = p;
        _peers.add(p);
      case 'msg':
        _active[peerId]?._incoming.add(asString(msg['d']));
      case 'close':
        _active.remove(peerId)?._closed();
    }
  }

  void _sendTo(String peerId, String data) => _sendRaw({'rt': 'msg', 'peer': peerId, 'd': data});

  void _closePeer(String peerId, String reason) {
    _active.remove(peerId);
    _sendRaw({'rt': 'close', 'peer': peerId, 'reason': reason});
  }

  void _sendRaw(Map<String, dynamic> msg) {
    final ws = _ws;
    if (ws == null || ws.readyState != WebSocket.open) return;
    try {
      ws.add(jsonEncode(msg));
    } on StateError {
      // El socket se está cerrando.
    }
  }

  Future<void> stop() async {
    _stopped = true;
    for (final p in _active.values.toList()) {
      p._closed();
    }
    _active.clear();
    final ws = _ws;
    _ws = null;
    await ws?.close();
  }
}

class _RelayPeer implements Peer {
  _RelayPeer(this._link, this.id, this.description);

  final RelayLink _link;
  @override
  final String id;
  @override
  final String description;
  final _incoming = StreamController<String>();
  bool _isClosed = false;

  @override
  Stream<String> get messages => _incoming.stream;

  @override
  void send(String data) {
    if (!_isClosed) _link._sendTo(id, data);
  }

  void _closed() {
    if (_isClosed) return;
    _isClosed = true;
    _incoming.close();
  }

  @override
  Future<void> close([String reason = '']) async {
    _link._closePeer(id, reason);
    _closed();
  }
}
