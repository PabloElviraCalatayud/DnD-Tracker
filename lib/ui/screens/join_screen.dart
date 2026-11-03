import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../net/invite.dart';
import '../../net/lan_discovery.dart';
import '../../net/protocol.dart';
import '../../state/client_session.dart';
import '../../state/providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'campaign_shell.dart';

class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _inviteText = TextEditingController();
  final _code = TextEditingController();
  final _host = TextEditingController();
  final _port = TextEditingController(text: '${Proto.defaultPort}');
  Invite? _parsed;
  final _scanner = LanScanner();
  List<DiscoveredGame> _games = [];
  StreamSubscription<List<DiscoveredGame>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _scanner.games.listen((g) => setState(() => _games = g));
    _scanner.start();
    _pasteFromClipboard(silent: true);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scanner.stop();
    super.dispose();
  }

  Future<void> _pasteFromClipboard({bool silent = false}) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    final inv = Invite.tryParse(text);
    if (inv != null) {
      _inviteText.text = text;
      _onInviteChanged(text);
    } else if (!silent && mounted) {
      showSnack(context, 'El portapapeles no contiene una invitación', error: true);
    }
  }

  void _onInviteChanged(String text) {
    final inv = Invite.tryParse(text);
    setState(() {
      _parsed = inv;
      if (inv != null) _code.text = inv.code;
    });
  }

  Future<void> _join(Invite invite) async {
    final session = ClientSession(
      invite: invite,
      profile: ref.read(profileProvider),
      storage: ref.read(storageProvider),
    )..start();
    await Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute(builder: (_) => CampaignShell(session: session)),
    );
  }

  void _joinParsed() {
    final p = _parsed;
    if (p == null) return;
    _join(
      Invite(
        campaignId: p.campaignId,
        campaignName: p.campaignName,
        code: _code.text.trim().toUpperCase(),
        hosts: p.hosts,
        port: p.port,
        relayUrl: p.relayUrl,
        dmName: p.dmName,
      ),
    );
  }

  Future<void> _joinDiscovered(DiscoveredGame g) async {
    final code = await promptText(
      context,
      'Código de "${g.name}"',
      hint: 'Código de 6 letras (si ya jugabas en ella, déjalo vacío)',
      ok: 'Unirse',
    );
    if (code == null) return;
    await _join(
      Invite(
        campaignId: g.campaignId,
        campaignName: g.name,
        code: code.trim().toUpperCase(),
        hosts: [g.address],
        port: g.port,
        dmName: g.dmName,
      ),
    );
  }

  void _joinManual() {
    final host = _host.text.trim();
    if (host.isEmpty) return;
    _join(
      Invite(
        campaignId: '',
        campaignName: 'Partida',
        code: _code.text.trim().toUpperCase(),
        hosts: [host],
        port: int.tryParse(_port.text) ?? Proto.defaultPort,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = _parsed;
    return AppScaffold(
      title: 'Unirse a una partida',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'Invitación del máster',
            icon: 'scroll_quill',
            trailing: TextButton.icon(
              onPressed: _pasteFromClipboard,
              icon: const Icon(Icons.content_paste),
              label: const Text('Pegar'),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _inviteText,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: 'Pega aquí el mensaje que empieza por DNDT1:…'),
                  onChanged: _onInviteChanged,
                ),
                if (p != null) ...[
                  Gap.m,
                  Row(
                    children: [
                      const GameIcon('castle', size: 30),
                      Gap.s,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.campaignName, style: t.titleMedium),
                            Text(
                              [
                                if (p.dmName.isNotEmpty) 'Máster: ${p.dmName}',
                                if (p.hosts.isNotEmpty) p.hosts.join(', '),
                                if (p.hasRelay) 'relay',
                              ].join(' · '),
                              style: t.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Gap.m,
                  TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Código de la partida'),
                  ),
                  Gap.m,
                  FilledButton.icon(onPressed: _joinParsed, icon: const Icon(Icons.login), label: const Text('Unirse')),
                ],
              ],
            ),
          ),
          SectionCard(
            title: 'Partidas en tu red',
            icon: 'radar',
            trailing: const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            child: _games.isEmpty
                ? Text(
                    _scanner.error != null
                        ? 'No se puede buscar en esta red (${_scanner.error}). Usa la invitación.'
                        : 'Buscando partidas en la misma wifi… Si el máster comparte datos (zona wifi) '
                              'conéctate a ella.',
                    style: t.bodySmall,
                  )
                : Column(
                    children: [
                      for (final g in _games)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const GameIcon('tower_flag', size: 30),
                          title: Text(g.name),
                          subtitle: Text('Máster: ${g.dmName} · ${g.ruleset} · ${g.address}'),
                          trailing: const Icon(Icons.login),
                          onTap: () => _joinDiscovered(g),
                        ),
                    ],
                  ),
          ),
          ExpansionTile(
            title: Text('Conexión manual', style: t.titleMedium),
            subtitle: const Text('IP y puerto del máster (p. ej. su IP de Tailscale)'),
            childrenPadding: const EdgeInsets.all(12),
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _host,
                      decoration: const InputDecoration(labelText: 'IP del máster'),
                    ),
                  ),
                  Gap.s,
                  Expanded(
                    child: TextField(
                      controller: _port,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Puerto'),
                    ),
                  ),
                ],
              ),
              Gap.m,
              TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Código de la partida'),
              ),
              Gap.m,
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(onPressed: _joinManual, child: const Text('Conectar')),
              ),
            ],
          ),
          Gap.m,
          Text(
            '¿No estáis en la misma red? El máster puede usar Tailscale (gratis) o un relay. '
            'Mira «Partida → Conexión» en la app del máster.',
            style: t.bodySmall?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
