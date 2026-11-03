import 'dart:convert';

/// Protocolo entre anfitrión (máster) y jugadores: mensajes JSON de texto por
/// WebSocket. El campo "t" indica el tipo.
///
/// Jugador → anfitrión
///   hello  {v, userId, name, secret, code, campaignId}
///   cmd    {id, cmd: {type, data}}
/// Anfitrión → jugador
///   welcome {role, campaignId, view, chat}
///   denied  {reason}
///   view    {view}
///   ack     {id, ok, error}
///   chat    {message}
///   channel {channel}
///   kicked  {reason}
class Proto {
  static const int version = 1;
  static const String path = '/ws';
  static const int defaultPort = 4040;
  static const int discoveryPort = 40404;

  static const hello = 'hello';
  static const cmd = 'cmd';
  static const welcome = 'welcome';
  static const denied = 'denied';
  static const view = 'view';
  static const ack = 'ack';
  static const chat = 'chat';
  static const channel = 'channel';
  static const kicked = 'kicked';

  static String encode(String type, [Map<String, dynamic> body = const {}]) => jsonEncode({'t': type, ...body});

  static Map<String, dynamic>? decode(Object? raw) {
    if (raw is! String) return null;
    try {
      final v = jsonDecode(raw);
      if (v is Map<String, dynamic> && v['t'] is String) return v;
    } on FormatException {
      return null;
    }
    return null;
  }
}
