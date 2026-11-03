// Relay de DnD Tracker.
//
// Un "tubo" tonto: el anfitrión (máster) abre una conexión saliente a /host y
// los jugadores abren conexiones salientes a /join. El relay sólo reenvía
// mensajes entre ellos; la partida sigue viviendo en el dispositivo del máster.
// Como todas las conexiones son salientes, funciona con datos móviles y CGNAT.
//
// Uso:  dart run bin/relay.dart [--port 8080]      (o variable de entorno PORT)
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const int maxRooms = 500;
const int maxClientsPerRoom = 32;
const int maxFrameBytes = 4 * 1024 * 1024;
final RegExp roomPattern = RegExp(r'^[A-Za-z0-9_-]{8,64}$');

class Room {
  Room(this.id, this.key, this.host);
  final String id;
  final String key;
  WebSocket host;
  final Map<String, WebSocket> clients = {};
  int counter = 0;
}

class Relay {
  final Map<String, Room> rooms = {};

  Future<HttpServer> serve(int port, {InternetAddress? address}) async {
    final server = await HttpServer.bind(address ?? InternetAddress.anyIPv4, port);
    server.listen(handle, onError: (_) {});
    return server;
  }

  Future<void> handle(HttpRequest req) async {
    final path = req.uri.path.replaceAll(RegExp(r'/+$'), '');
    final room = req.uri.queryParameters['room'] ?? '';
    final isUpgrade = WebSocketTransformer.isUpgradeRequest(req);
    if (path.endsWith('/host') && isUpgrade) return _host(req, room, req.uri.queryParameters['key'] ?? '');
    if (path.endsWith('/join') && isUpgrade) return _join(req, room);
    req.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.text
      ..write('DnD Tracker relay OK · salas activas: ${rooms.length}\n');
    await req.response.close();
  }

  Future<void> _reject(HttpRequest req, int status, String msg) async {
    req.response
      ..statusCode = status
      ..write(msg);
    await req.response.close();
  }

  Future<void> _host(HttpRequest req, String roomId, String key) async {
    if (!roomPattern.hasMatch(roomId) || key.length < 16) return _reject(req, 400, 'sala o clave no válidas');
    final existing = rooms[roomId];
    if (existing != null && existing.key != key) return _reject(req, 409, 'sala ocupada por otro anfitrión');
    if (existing == null && rooms.length >= maxRooms) return _reject(req, 503, 'relay lleno');
    final ws = await WebSocketTransformer.upgrade(req);
    ws.pingInterval = const Duration(seconds: 20);
    if (existing != null) {
      // El anfitrión se ha reconectado: la conexión vieja y sus jugadores se cierran.
      _closeRoom(existing, 'el anfitrión se ha reconectado');
    }
    final room = Room(roomId, key, ws);
    rooms[roomId] = room;
    ws.listen(
      (data) {
        if (data is! String || data.length > maxFrameBytes) return;
        Map<String, dynamic> msg;
        try {
          msg = jsonDecode(data) as Map<String, dynamic>;
        } on Object {
          return;
        }
        final peer = room.clients[msg['peer']];
        if (peer == null) return;
        if (msg['rt'] == 'msg' && msg['d'] is String) {
          peer.add(msg['d'] as String);
        } else if (msg['rt'] == 'close') {
          room.clients.remove(msg['peer']);
          peer.close(WebSocketStatus.normalClosure, (msg['reason'] ?? '').toString());
        }
      },
      onDone: () {
        if (rooms[roomId] == room) {
          rooms.remove(roomId);
          _closeRoom(room, 'el anfitrión se ha desconectado');
        }
      },
      onError: (_) {},
      cancelOnError: true,
    );
  }

  void _closeRoom(Room room, String reason) {
    for (final c in room.clients.values) {
      c.close(4001, reason);
    }
    room.clients.clear();
    room.host.close(WebSocketStatus.normalClosure, reason);
  }

  Future<void> _join(HttpRequest req, String roomId) async {
    final room = rooms[roomId];
    if (room == null) return _reject(req, 404, 'el anfitrión no está conectado');
    if (room.clients.length >= maxClientsPerRoom) return _reject(req, 503, 'sala llena');
    final ws = await WebSocketTransformer.upgrade(req);
    ws.pingInterval = const Duration(seconds: 20);
    final peerId = 'p${++room.counter}';
    room.clients[peerId] = ws;
    final addr = req.connectionInfo?.remoteAddress.address ?? '?';
    room.host.add(jsonEncode({'rt': 'open', 'peer': peerId, 'addr': addr}));
    ws.listen(
      (data) {
        if (data is! String || data.length > maxFrameBytes) return;
        room.host.add(jsonEncode({'rt': 'msg', 'peer': peerId, 'd': data}));
      },
      onDone: () {
        if (room.clients.remove(peerId) != null) {
          room.host.add(jsonEncode({'rt': 'close', 'peer': peerId}));
        }
      },
      onError: (_) {},
      cancelOnError: true,
    );
  }
}

Future<void> main(List<String> args) async {
  var port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final i = args.indexOf('--port');
  if (i >= 0 && i + 1 < args.length) port = int.tryParse(args[i + 1]) ?? port;
  final relay = Relay();
  final server = await relay.serve(port);
  stdout.writeln('DnD Tracker relay escuchando en el puerto ${server.port}');
  await ProcessSignal.sigint.watch().first;
  await server.close(force: true);
  exit(0);
}
