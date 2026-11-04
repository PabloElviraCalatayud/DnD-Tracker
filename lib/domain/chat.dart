import '../core/ids.dart';
import '../core/json.dart';

enum ChannelKind { general, group, direct }

class ChatChannel {
  ChatChannel({
    String? id,
    required this.name,
    this.kind = ChannelKind.group,
    List<String>? memberIds,
    this.createdBy = '',
  }) : id = id ?? newId(),
       memberIds = memberIds ?? <String>[];

  static const generalId = 'general';

  String id;
  String name;
  ChannelKind kind;

  /// Miembros del canal. El canal general incluye a todos y lo deja vacío.
  List<String> memberIds;
  String createdBy;

  bool includes(String userId) => kind == ChannelKind.general || memberIds.contains(userId);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'memberIds': memberIds,
    'createdBy': createdBy,
  };

  factory ChatChannel.fromJson(Map<String, dynamic> j) => ChatChannel(
    id: asString(j['id'], newId()),
    name: asString(j['name'], 'Canal'),
    kind: enumByName(ChannelKind.values, j['kind'], ChannelKind.group),
    memberIds: asStringList(j['memberIds']),
    createdBy: asString(j['createdBy']),
  );

  static ChatChannel general() => ChatChannel(id: generalId, name: 'Taberna (todos)', kind: ChannelKind.general);
}

enum MessageKind { text, roll, system }

class ChatMessage {
  ChatMessage({
    String? id,
    required this.channelId,
    required this.authorId,
    required this.authorName,
    required this.text,
    this.kind = MessageKind.text,
    int? ts,
  }) : id = id ?? newId(),
       ts = ts ?? DateTime.now().millisecondsSinceEpoch;

  String id;
  String channelId;
  String authorId;
  String authorName;
  String text;
  MessageKind kind;
  int ts;

  Map<String, dynamic> toJson() => {
    'id': id,
    'channelId': channelId,
    'authorId': authorId,
    'authorName': authorName,
    'text': text,
    'kind': kind.name,
    'ts': ts,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: asString(j['id'], newId()),
    channelId: asString(j['channelId'], ChatChannel.generalId),
    authorId: asString(j['authorId']),
    authorName: asString(j['authorName']),
    text: asString(j['text']),
    kind: enumByName(MessageKind.values, j['kind'], MessageKind.text),
    ts: asIntOrNull(j['ts']),
  );
}

class ChatState {
  ChatState({List<ChatChannel>? channels, List<ChatMessage>? messages})
    : channels = channels ?? [ChatChannel.general()],
      messages = messages ?? <ChatMessage>[] {
    if (!this.channels.any((c) => c.id == ChatChannel.generalId)) {
      this.channels.insert(0, ChatChannel.general());
    }
  }

  static const maxMessagesPerChannel = 300;

  List<ChatChannel> channels;
  List<ChatMessage> messages;

  ChatChannel? channel(String id) {
    for (final c in channels) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<ChatMessage> messagesIn(String channelId) => messages.where((m) => m.channelId == channelId).toList();

  void add(ChatMessage m) {
    if (messages.any((x) => x.id == m.id)) return;
    messages.add(m);
    final inChannel = messages.where((x) => x.channelId == m.channelId).length;
    if (inChannel > maxMessagesPerChannel) {
      final oldest = messages.firstWhere((x) => x.channelId == m.channelId);
      messages.remove(oldest);
    }
  }

  void upsertChannel(ChatChannel c) {
    final i = channels.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      channels[i] = c;
    } else {
      channels.add(c);
    }
  }

  /// Copia con lo que puede ver [userId]. El máster ([isDm]) ve todas las
  /// conversaciones de la partida, también las de los jugadores entre sí.
  ChatState visibleTo(String userId, {bool isDm = false}) {
    final visible = channels.where((c) => isDm || c.includes(userId)).toList();
    final ids = visible.map((c) => c.id).toSet();
    return ChatState(
      channels: visible.map((c) => ChatChannel.fromJson(c.toJson())).toList(),
      messages: messages.where((m) => ids.contains(m.channelId)).map((m) => ChatMessage.fromJson(m.toJson())).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'channels': channels.map((c) => c.toJson()).toList(),
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory ChatState.fromJson(Map<String, dynamic> j) => ChatState(
    channels: asList(j['channels'], ChatChannel.fromJson),
    messages: asList(j['messages'], ChatMessage.fromJson),
  );
}
