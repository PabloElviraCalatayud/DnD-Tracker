import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/json.dart';
import 'protocol.dart';

/// Partida anunciada en la red local.
class DiscoveredGame {
  DiscoveredGame({
    required this.address,
    required this.port,
    required this.campaignId,
    required this.name,
    required this.dmName,
    required this.ruleset,
    required this.seenAt,
  });

  final String address;
  final int port;
  final String campaignId;
  final String name;
  final String dmName;
  final String ruleset;
  DateTime seenAt;

  String get key => '$campaignId@$address:$port';
}

/// El anfitrión anuncia su partida por broadcast UDP cada 2 segundos para que
/// los jugadores de la misma wifi la vean sin escribir la IP.
class LanBeacon {
  LanBeacon({
    required this.port,
    required this.campaignId,
    required this.name,
    required this.dmName,
    required this.ruleset,
  });

  final int port;
  final String campaignId;
  String name;
  final String dmName;
  String ruleset;
  RawDatagramSocket? _socket;
  Timer? _timer;

  Future<void> start() async {
    try {
      final s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      s.broadcastEnabled = true;
      _socket = s;
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _send());
      _send();
    } on Object {
      // Sin broadcast (algunas redes lo bloquean): se puede entrar con la invitación.
    }
  }

  void _send() {
    final payload = utf8.encode(
      jsonEncode({
        'app': 'dndt',
        'v': Proto.version,
        'port': port,
        'id': campaignId,
        'name': name,
        'dm': dmName,
        'rs': ruleset,
      }),
    );
    try {
      _socket?.send(payload, InternetAddress('255.255.255.255'), Proto.discoveryPort);
    } on Object {
      // Ignorado: la red no permite broadcast.
    }
  }

  void stop() {
    _timer?.cancel();
    _socket?.close();
    _socket = null;
  }
}

/// Escucha los anuncios de los anfitriones.
class LanScanner {
  RawDatagramSocket? _socket;
  Timer? _cleanup;
  final Map<String, DiscoveredGame> _games = {};
  final _controller = StreamController<List<DiscoveredGame>>.broadcast();
  String? error;

  Stream<List<DiscoveredGame>> get games => _controller.stream;
  List<DiscoveredGame> get current => _games.values.toList();

  Future<void> start() async {
    try {
      final s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, Proto.discoveryPort, reuseAddress: true);
      _socket = s;
      s.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = s.receive();
        if (dg == null) return;
        try {
          final m = asMap(jsonDecode(utf8.decode(dg.data)));
          if (m['app'] != 'dndt') return;
          final g = DiscoveredGame(
            address: dg.address.address,
            port: asInt(m['port'], Proto.defaultPort),
            campaignId: asString(m['id']),
            name: asString(m['name']),
            dmName: asString(m['dm']),
            ruleset: asString(m['rs']),
            seenAt: DateTime.now(),
          );
          final isNew = !_games.containsKey(g.key);
          _games[g.key] = g;
          if (isNew) _controller.add(current);
        } on Object {
          // Paquete ajeno: se ignora.
        }
      });
      _cleanup = Timer.periodic(const Duration(seconds: 3), (_) {
        final before = _games.length;
        _games.removeWhere((_, g) => DateTime.now().difference(g.seenAt) > const Duration(seconds: 8));
        if (_games.length != before) _controller.add(current);
      });
    } on Object catch (e) {
      error = e.toString();
    }
  }

  void stop() {
    _cleanup?.cancel();
    _socket?.close();
    _socket = null;
    _controller.close();
  }
}
