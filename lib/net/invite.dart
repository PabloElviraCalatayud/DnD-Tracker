import 'dart:convert';

import '../core/json.dart';
import 'protocol.dart';
import '../core/i18n.dart';

/// Invitación a una partida. Se comparte como texto (por WhatsApp, por
/// ejemplo) con el prefijo DNDT1: y contiene todo lo necesario para conectar:
/// las IP del anfitrión, el puerto, el código de la partida y, si se usa, el
/// relay para jugar por internet.
class Invite {
  Invite({
    required this.campaignId,
    required this.campaignName,
    required this.code,
    List<String>? hosts,
    this.port = Proto.defaultPort,
    this.relayUrl = '',
    this.dmName = '',
  }) : hosts = hosts ?? <String>[];

  static const prefix = 'DNDT1:';

  final String campaignId;
  final String campaignName;
  final String code;
  final List<String> hosts;
  final int port;
  final String relayUrl;
  final String dmName;

  bool get hasRelay => relayUrl.isNotEmpty;

  /// URLs a probar, en orden: direcciones directas y después el relay.
  List<Uri> get candidates => [
    for (final h in hosts) Uri(scheme: 'ws', host: h, port: port, path: Proto.path),
    if (hasRelay) relayJoinUri(relayUrl, campaignId),
  ];

  static Uri relayJoinUri(String relayUrl, String room) {
    final base = Uri.parse(relayUrl.trim());
    final scheme = base.scheme == 'https' ? 'wss' : (base.scheme == 'http' ? 'ws' : base.scheme);
    return base.replace(
      scheme: scheme,
      path: '${base.path.replaceAll(RegExp(r'/+$'), '')}/join',
      queryParameters: {'room': room},
    );
  }

  static Uri relayHostUri(String relayUrl, String room, String key) {
    final base = Uri.parse(relayUrl.trim());
    final scheme = base.scheme == 'https' ? 'wss' : (base.scheme == 'http' ? 'ws' : base.scheme);
    return base.replace(
      scheme: scheme,
      path: '${base.path.replaceAll(RegExp(r'/+$'), '')}/host',
      queryParameters: {'room': room, 'key': key},
    );
  }

  Map<String, dynamic> toJson() => {
    'id': campaignId,
    'n': campaignName,
    'c': code,
    if (hosts.isNotEmpty) 'h': hosts,
    'p': port,
    if (relayUrl.isNotEmpty) 'r': relayUrl,
    if (dmName.isNotEmpty) 'dm': dmName,
  };

  factory Invite.fromJson(Map<String, dynamic> j) => Invite(
    campaignId: asString(j['id']),
    campaignName: asString(j['n'], 'Partida'),
    code: asString(j['c']),
    hosts: asStringList(j['h']),
    port: asInt(j['p'], Proto.defaultPort),
    relayUrl: asString(j['r']),
    dmName: asString(j['dm']),
  );

  String encode() => prefix + base64Url.encode(utf8.encode(jsonEncode(toJson()))).replaceAll('=', '');

  /// Acepta la invitación aunque venga rodeada de texto (un mensaje de WhatsApp).
  static Invite? tryParse(String text) {
    final m = RegExp(r'DNDT1:([A-Za-z0-9_\-]+)').firstMatch(text);
    if (m == null) return null;
    var payload = m.group(1)!;
    while (payload.length % 4 != 0) {
      payload += '=';
    }
    try {
      final json = jsonDecode(utf8.decode(base64Url.decode(payload)));
      if (json is! Map) return null;
      final inv = Invite.fromJson(asMap(json));
      if (inv.campaignId.isEmpty) return null;
      return inv;
    } on FormatException {
      return null;
    }
  }

  /// Texto listo para pegar en un chat.
  String shareText() =>
      '${tr('¡Únete a "{0}" en DnD Tracker!', [campaignName])}\n'
      '${tr('Abre la app → Unirse a partida → pega este mensaje.')}\n\n${encode()}';
}
