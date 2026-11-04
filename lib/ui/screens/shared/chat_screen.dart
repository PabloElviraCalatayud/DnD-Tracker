import 'package:flutter/material.dart';

import '../../../domain/chat.dart';
import '../../../engine/commands.dart';
import '../../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../../core/i18n.dart';

/// Chat de la partida: canal general, mensajes privados y grupos.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String _channelId = ChatChannel.generalId;
  bool _showingMessages = false;
  GameSession? _session;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _session = SessionScope.read(context);
  }

  @override
  void dispose() {
    _session?.openChannelId = null;
    super.dispose();
  }

  void _open(String id) {
    final s = SessionScope.read(context);
    s.openChannelId = id;
    s.markRead(id);
    setState(() {
      _channelId = id;
      _showingMessages = true;
    });
  }

  Future<void> _newChannel() async {
    final s = SessionScope.read(context);
    final c = s.campaign;
    final people = <String, String>{
      if (c.dmUserId != s.myUserId) c.dmUserId: tr('{0} (máster)', [c.dmName]),
      for (final m in c.members.where((m) => !m.banned && m.userId != s.myUserId)) m.userId: m.name,
    };
    if (people.isEmpty) {
      showSnack(context, tr('Todavía no hay nadie más en la partida'), error: true);
      return;
    }
    final selected = <String>{};
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(tr('Nueva conversación')),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr('Un solo destinatario = mensaje privado. Varios = grupo.')),
                Gap.s,
                for (final e in people.entries)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selected.contains(e.key),
                    title: Text(e.value),
                    onChanged: (v) => setState(() => v == true ? selected.add(e.key) : selected.remove(e.key)),
                  ),
                if (selected.length > 1)
                  TextField(
                    controller: name,
                    decoration: InputDecoration(labelText: tr('Nombre del grupo')),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancelar'))),
            FilledButton(onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx, true), child: Text(tr('Crear'))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final direct = selected.length == 1;
    final r = await s.send(Command.createChannel(name.text.trim(), selected.toList(), direct: direct));
    if (!mounted) return;
    if (!r.ok) {
      showSnack(context, r.error ?? tr('Error'), error: true);
      return;
    }
    // El canal llega por la red: buscamos el que coincide con los miembros.
    final members = {...selected, s.myUserId};
    final ch = s.chat.channels
        .where((c) => c.memberIds.toSet().containsAll(members) && c.memberIds.length == members.length)
        .lastOrNull;
    if (ch != null) _open(ch.id);
  }

  String _channelTitle(GameSession s, ChatChannel c) {
    if (c.kind == ChannelKind.general) return tr('Taberna (todos)');
    if (c.kind != ChannelKind.direct) return c.name;
    // El máster ve también las conversaciones privadas entre jugadores.
    if (!c.memberIds.contains(s.myUserId)) return '✉ ${c.memberIds.map(s.campaign.memberName).join(' ↔ ')}';
    final other = c.memberIds.firstWhere((id) => id != s.myUserId, orElse: () => '');
    return '✉ ${s.campaign.memberName(other)}';
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final channels = s.chat.channels;
    if (!channels.any((c) => c.id == _channelId)) _channelId = ChatChannel.generalId;

    final list = ListView(
      children: [
        ListTile(
          leading: Icon(Icons.group_add, color: AppColors.gold),
          title: Text(tr('Nueva conversación')),
          onTap: s.canEdit ? _newChannel : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            s.isDm
                ? tr('Como máster ves todas las conversaciones de la partida, también las de los jugadores entre sí.')
                : tr('El máster puede leer todas las conversaciones de la partida.'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
        ),
        const Divider(),
        for (final c in channels)
          ListTile(
            selected: wide && c.id == _channelId,
            leading: GameIcon(
              c.kind == ChannelKind.general ? 'campfire' : (c.kind == ChannelKind.direct ? 'feather' : 'party'),
              size: 26,
            ),
            title: Text(_channelTitle(s, c)),
            subtitle: c.kind == ChannelKind.group
                ? Text(c.memberIds.map(s.campaign.memberName).join(', '), maxLines: 1, overflow: TextOverflow.ellipsis)
                : null,
            trailing: (s.unread[c.id] ?? 0) > 0 ? Badge(label: Text('${s.unread[c.id]}')) : null,
            onTap: () => _open(c.id),
          ),
      ],
    );

    final channel = s.chat.channel(_channelId) ?? ChatChannel.general();
    final messages = _MessagesPane(
      key: ValueKey(channel.id),
      channel: channel,
      title: _channelTitle(s, channel),
      onBack: wide ? null : () => setState(() => _showingMessages = false),
    );

    if (wide) {
      if (s.openChannelId != _channelId) {
        s.openChannelId = _channelId;
        WidgetsBinding.instance.addPostFrameCallback((_) => s.markRead(_channelId));
      }
      return Row(
        children: [
          SizedBox(
            width: 280,
            child: Material(color: AppColors.surface.withValues(alpha: 0.6), child: list),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: messages),
        ],
      );
    }
    return _showingMessages ? messages : list;
  }
}

class _MessagesPane extends StatefulWidget {
  const _MessagesPane({super.key, required this.channel, required this.title, this.onBack});
  final ChatChannel channel;
  final String title;
  final VoidCallback? onBack;

  @override
  State<_MessagesPane> createState() => _MessagesPaneState();
}

class _MessagesPaneState extends State<_MessagesPane> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final s = SessionScope.read(context);
    _input.clear();
    final r = await s.send(Command.sendChat(widget.channel.id, text));
    if (!r.ok && mounted) {
      _input.text = text;
      showSnack(context, r.error ?? tr('No se pudo enviar'), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final t = Theme.of(context).textTheme;
    final msgs = s.chat.messagesIn(widget.channel.id);
    if ((s.unread[widget.channel.id] ?? 0) > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => s.markRead(widget.channel.id));
    }
    return Column(
      children: [
        Material(
          color: AppColors.surface.withValues(alpha: 0.8),
          child: ListTile(
            leading: widget.onBack == null
                ? null
                : IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
            title: Text(widget.title, style: t.titleMedium),
            subtitle: widget.channel.kind == ChannelKind.general
                ? Text(tr('Todos los jugadores y el máster'))
                : Text(widget.channel.memberIds.map(s.campaign.memberName).join(', ')),
          ),
        ),
        Expanded(
          child: msgs.isEmpty
              ? EmptyState(
                  icon: 'conversation',
                  title: tr('Sin mensajes'),
                  message: tr('Las tiradas compartidas también aparecen aquí.'),
                )
              : ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) => _Bubble(
                    message: msgs[msgs.length - 1 - i],
                    mine: msgs[msgs.length - 1 - i].authorId == s.myUserId,
                  ),
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    enabled: s.canEdit,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(hintText: s.canEdit ? tr('Mensaje…') : tr('Sin conexión')),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                Gap.s,
                IconButton.filled(onPressed: s.canEdit ? _send : null, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final d = DateTime.fromMillisecondsSinceEpoch(message.ts);
    final time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final isRoll = message.kind == MessageKind.roll;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isRoll
                ? AppColors.arcane.withValues(alpha: 0.15)
                : (mine ? AppColors.primaryContainer.withValues(alpha: 0.7) : AppColors.surfaceHigh),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isRoll ? AppColors.arcane.withValues(alpha: 0.5) : AppColors.outlineSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isRoll) ...[GameIcon('d20', size: 14, color: AppColors.arcane), const SizedBox(width: 4)],
                  Text(message.authorName, style: t.labelMedium?.copyWith(color: AppColors.gold)),
                  Gap.s,
                  Text(time, style: t.labelSmall?.copyWith(color: AppColors.muted)),
                ],
              ),
              RichDescription(message.text),
            ],
          ),
        ),
      ),
    );
  }
}
