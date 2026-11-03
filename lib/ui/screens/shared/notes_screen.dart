import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/campaign.dart';
import '../../../domain/chat.dart';
import '../../../domain/player_note.dart';
import '../../../engine/commands.dart';
import '../../../state/providers.dart';
import '../../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

String _date(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    if (s.isDm) return const _DmNotes();
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: 'Mi cuaderno'),
              Tab(text: 'Diario de la partida'),
            ],
          ),
          Expanded(child: TabBarView(children: [_PlayerNotebook(), _SharedJournal()])),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Máster

class _DmNotes extends StatelessWidget {
  const _DmNotes();

  Future<void> _edit(BuildContext context, CampaignNote? note) async {
    final s = SessionScope.read(context);
    final result = await Navigator.push<_NoteResult>(
      context,
      MaterialPageRoute(
        builder: (_) => _NoteEditor(
          title: note?.title ?? '',
          body: note?.body ?? '',
          extraSwitchLabel: 'Compartida con los jugadores',
          extraSwitch: note?.shared ?? false,
        ),
      ),
    );
    if (result == null) return;
    final n = note == null ? CampaignNote(title: result.title) : CampaignNote.fromJson(note.toJson());
    n
      ..title = result.title
      ..body = result.body
      ..shared = result.flag;
    await s.send(Command.putNote(n));
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final t = Theme.of(context).textTheme;
    final notes = List.of(s.campaign.notes)
      ..sort((a, b) => a.pinned != b.pinned ? (a.pinned ? -1 : 1) : b.updatedAt.compareTo(a.updatedAt));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Nota'),
      ),
      body: notes.isEmpty
          ? const EmptyState(
              icon: 'quill',
              title: 'Notas del máster',
              message:
                  'Apunta tramas, PNJ, pistas… Las notas son privadas, salvo que las compartas: entonces '
                  'aparecen en el «Diario de la partida» de los jugadores (handouts, cartas, mapas descritos…).',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                for (final n in notes)
                  Card(
                    child: ListTile(
                      leading: Icon(n.pinned ? Icons.push_pin : Icons.sticky_note_2_outlined, color: AppColors.gold),
                      title: Text(n.title.isEmpty ? 'Sin título' : n.title),
                      subtitle: Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                      onTap: () => _edit(context, n),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: n.shared ? 'Compartida con los jugadores' : 'Privada',
                            icon: Icon(
                              n.shared ? Icons.visibility : Icons.visibility_off,
                              color: n.shared ? AppColors.gold : AppColors.muted,
                            ),
                            onPressed: () =>
                                s.send(Command.putNote(CampaignNote.fromJson(n.toJson())..shared = !n.shared)),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'pin') {
                                await s.send(Command.putNote(CampaignNote.fromJson(n.toJson())..pinned = !n.pinned));
                              } else if (v == 'delete') {
                                final ok = await confirm(context, 'Borrar nota', '¿Borrar «${n.title}»?', danger: true);
                                if (ok) await s.send(Command.deleteNote(n.id));
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'pin', child: Text(n.pinned ? 'Desfijar' : 'Fijar arriba')),
                              const PopupMenuItem(value: 'delete', child: Text('Borrar')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ------------------------------------------------------------------ Jugador

class _SharedJournal extends StatelessWidget {
  const _SharedJournal();

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final notes = List.of(s.campaign.notes)
      ..sort((a, b) => a.pinned != b.pinned ? (a.pinned ? -1 : 1) : b.updatedAt.compareTo(a.updatedAt));
    if (notes.isEmpty) {
      return const EmptyState(
        icon: 'scroll',
        title: 'Diario vacío',
        message: 'Aquí aparecerán los documentos y notas que el máster comparta con el grupo.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final n in notes)
          SectionCard(
            title: n.title.isEmpty ? 'Sin título' : n.title,
            icon: n.pinned ? 'key' : 'scroll',
            trailing: Text(_date(n.updatedAt), style: Theme.of(context).textTheme.bodySmall),
            child: RichDescription(n.body),
          ),
      ],
    );
  }
}

class _PlayerNotebook extends ConsumerStatefulWidget {
  const _PlayerNotebook();

  @override
  ConsumerState<_PlayerNotebook> createState() => _PlayerNotebookState();
}

class _PlayerNotebookState extends ConsumerState<_PlayerNotebook> {
  List<PlayerNote>? _notes;
  String _query = '';

  String get _campaignId => SessionScope.read(context).campaign.id;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_notes == null) _load();
  }

  Future<void> _load() async {
    final notes = await ref.read(storageProvider).loadNotes(_campaignId);
    if (mounted) setState(() => _notes = notes);
  }

  Future<void> _persist() => ref.read(storageProvider).saveNotes(_campaignId, _notes ?? []);

  Future<void> _edit(PlayerNote? note) async {
    final result = await Navigator.push<_NoteResult>(
      context,
      MaterialPageRoute(
        builder: (_) => _NoteEditor(
          title: note?.title ?? '',
          body: note?.body ?? '',
          extraSwitchLabel: 'Fijar arriba',
          extraSwitch: note?.pinned ?? false,
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      if (note == null) {
        _notes!.add(PlayerNote(title: result.title, body: result.body, pinned: result.flag));
      } else {
        note
          ..title = result.title
          ..body = result.body
          ..pinned = result.flag
          ..updatedAt = DateTime.now().millisecondsSinceEpoch;
      }
    });
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    final notes = _notes;
    final t = Theme.of(context).textTheme;
    if (notes == null) return const Center(child: CircularProgressIndicator());
    final q = _query.toLowerCase();
    final visible =
        notes.where((n) => q.isEmpty || n.title.toLowerCase().contains(q) || n.body.toLowerCase().contains(q)).toList()
          ..sort((a, b) => a.pinned != b.pinned ? (a.pinned ? -1 : 1) : b.updatedAt.compareTo(a.updatedAt));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null),
        icon: const Icon(Icons.edit),
        label: const Text('Nueva nota'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline, size: 16, color: AppColors.muted),
              Gap.s,
              Expanded(
                child: Text(
                  'Tu cuaderno se guarda sólo en este dispositivo. Ni el máster lo ve.',
                  style: t.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ),
            ],
          ),
          Gap.s,
          if (notes.isNotEmpty) SearchField(onChanged: (v) => setState(() => _query = v), hint: 'Buscar en tus notas'),
          if (notes.isEmpty)
            const EmptyState(
              icon: 'notebook',
              title: 'Cuaderno en blanco',
              message: 'Apunta nombres, pistas, deudas, sospechas…',
            ),
          for (final n in visible)
            Card(
              child: ListTile(
                leading: Icon(n.pinned ? Icons.push_pin : Icons.description_outlined, color: AppColors.gold),
                title: Text(n.title.isEmpty ? 'Sin título' : n.title),
                subtitle: Text('${_date(n.updatedAt)} · ${n.body}', maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => _edit(n),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'share') {
                      final s = SessionScope.read(context);
                      final r = await s.send(Command.sendChat(ChatChannel.generalId, '📜 **${n.title}**\n${n.body}'));
                      if (context.mounted) {
                        showSnack(context, r.ok ? 'Compartida en la taberna' : r.error ?? '', error: !r.ok);
                      }
                    } else if (v == 'delete') {
                      final ok = await confirm(context, 'Borrar nota', '¿Borrar «${n.title}»?', danger: true);
                      if (!ok) return;
                      setState(() => _notes!.remove(n));
                      await _persist();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'share', child: Text('Compartir en el chat')),
                    PopupMenuItem(value: 'delete', child: Text('Borrar')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Editor

class _NoteResult {
  _NoteResult(this.title, this.body, this.flag);
  final String title;
  final String body;
  final bool flag;
}

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({
    required this.title,
    required this.body,
    required this.extraSwitchLabel,
    required this.extraSwitch,
  });
  final String title;
  final String body;
  final String extraSwitchLabel;
  final bool extraSwitch;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final _title = TextEditingController(text: widget.title);
  late final _body = TextEditingController(text: widget.body);
  late bool _flag = widget.extraSwitch;
  bool _preview = false;

  void _done() => Navigator.pop(context, _NoteResult(_title.text.trim(), _body.text, _flag));

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: AppScaffold(
        title: 'Nota',
        actions: [
          IconButton(
            tooltip: _preview ? 'Editar' : 'Vista previa',
            icon: Icon(_preview ? Icons.edit : Icons.visibility),
            onPressed: () => setState(() => _preview = !_preview),
          ),
          TextButton(onPressed: _done, child: const Text('Guardar')),
        ],
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(widget.extraSwitchLabel),
                value: _flag,
                onChanged: (v) => setState(() => _flag = v),
              ),
              Expanded(
                child: _preview
                    ? SingleChildScrollView(child: RichDescription(_body.text))
                    : TextField(
                        controller: _body,
                        expands: true,
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          hintText: 'Escribe… (admite **negrita**, *cursiva*, listas con -)',
                          alignLabelWithHint: true,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
