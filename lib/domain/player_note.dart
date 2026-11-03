import '../core/ids.dart';
import '../core/json.dart';

/// Nota del cuaderno personal. Se guarda sólo en el dispositivo del jugador
/// y nunca se envía al anfitrión: es privada de verdad.
class PlayerNote {
  PlayerNote({
    String? id,
    this.title = '',
    this.body = '',
    this.pinned = false,
    int? createdAt,
    int? updatedAt,
    List<String>? tags,
  }) : id = id ?? newId(),
       createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch,
       tags = tags ?? <String>[];

  String id;
  String title;
  String body;
  bool pinned;
  int createdAt;
  int updatedAt;
  List<String> tags;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'pinned': pinned,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'tags': tags,
  };

  factory PlayerNote.fromJson(Map<String, dynamic> j) => PlayerNote(
    id: asString(j['id'], newId()),
    title: asString(j['title']),
    body: asString(j['body']),
    pinned: asBool(j['pinned']),
    createdAt: asIntOrNull(j['createdAt']),
    updatedAt: asIntOrNull(j['updatedAt']),
    tags: asStringList(j['tags']),
  );
}
