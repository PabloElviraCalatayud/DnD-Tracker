import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/i18n.dart';
import '../../../domain/board.dart';
import '../../../domain/roll.dart';
import '../../../engine/commands.dart';
import '../../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/dice_animation.dart';
import '../dm/bestiary_screen.dart';
import '../shared/dice_roller.dart';
import 'map_editor.dart';
import 'map_view.dart';
import 'roll_feed.dart';

/// Tablero de juego: mapa con cuadrícula y fichas, y todas las tiradas de la
/// partida (las del máster sólo las ve él).
class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final _mapKey = GlobalKey<MapViewState>();
  String? _lastSeenRollId;
  RollEntry? _incoming;
  Timer? _incomingTimer;

  @override
  void dispose() {
    _incomingTimer?.cancel();
    super.dispose();
  }

  /// Cuando llega una tirada de otro jugador se ve rodar en una esquina del
  /// tablero, como si la tiraran en la mesa.
  void _watchRolls(GameSession s) {
    final last = s.rolls.lastOrNull;
    if (last == null) return;
    if (_lastSeenRollId == null) {
      _lastSeenRollId = last.id;
      return;
    }
    if (last.id == _lastSeenRollId) return;
    _lastSeenRollId = last.id;
    if (last.userId == s.myUserId) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _incoming = last);
      _incomingTimer?.cancel();
      _incomingTimer = Timer(const Duration(milliseconds: 3600), () {
        if (mounted) setState(() => _incoming = null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    _watchRolls(s);
    final map = s.campaign.board.activeMap;
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final mapArea = Stack(
      children: [
        Positioned.fill(
          child: map == null
              ? const _NoMap()
              : KeyedSubtree(
                  key: ValueKey(map.id),
                  child: MapView(key: _mapKey, map: map, desktop: wide),
                ),
        ),
        if (_incoming != null)
          Positioned(
            left: 8,
            bottom: 8,
            width: 300,
            height: 260,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        tr('{0} tira', [_incoming!.who]),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.gold),
                      ),
                    ),
                    Expanded(
                      child: DiceRollAnimation(key: ValueKey(_incoming!.id), roll: _incoming!),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
    final toolbar = _BoardToolbar(
      map: map,
      onPlace: (tokens, label) => _mapKey.currentState?.startPlacing(tokens, label),
    );
    if (wide) {
      return Row(
        children: [
          Expanded(
            child: Column(
              children: [
                toolbar,
                Expanded(child: mapArea),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 340,
            child: Material(
              color: AppColors.surface.withValues(alpha: 0.85),
              child: Column(
                children: [
                  _FeedHeader(),
                  const QuickDiceBar(),
                  const Divider(height: 1),
                  const Expanded(child: RollFeed()),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        toolbar,
        Expanded(child: mapArea),
        const _RollTicker(),
      ],
    );
  }
}

class _FeedHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          const GameIcon('dice', size: 22),
          Gap.s,
          Expanded(child: Text(tr('Tiradas'), style: Theme.of(context).textTheme.titleLarge)),
          if (s.isDm)
            Tooltip(
              message: tr('Tus tiradas son secretas'),
              child: Icon(Icons.visibility_off, size: 18, color: AppColors.muted),
            ),
        ],
      ),
    );
  }
}

/// En móvil: la última tirada abajo, y al tocarla se abre el registro completo.
class _RollTicker extends StatelessWidget {
  const _RollTicker();

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final last = s.rolls.lastOrNull;
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (ctx) => SessionScope(
                    session: s,
                    child: DraggableScrollableSheet(
                      expand: false,
                      initialChildSize: 0.7,
                      maxChildSize: 0.95,
                      builder: (ctx, scroll) => Column(
                        children: [
                          _FeedHeader(),
                          const QuickDiceBar(),
                          const Expanded(child: RollFeed()),
                        ],
                      ),
                    ),
                  ),
                ),
                child: last == null
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(tr('Toca para ver las tiradas'), style: Theme.of(context).textTheme.bodySmall),
                      )
                    : RollCard(key: ValueKey(last.id), roll: last, animate: true),
              ),
            ),
            IconButton.filled(
              tooltip: tr('Tirar dados'),
              icon: GameIcon('d20', size: 24, color: AppColors.background),
              onPressed: () => showDiceRoller(context),
            ),
            Gap.s,
          ],
        ),
      ),
    );
  }
}

class _NoMap extends StatelessWidget {
  const _NoMap();

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return EmptyState(
      icon: 'treasure_map',
      title: s.isDm ? tr('Aún no hay mapa') : tr('El máster aún no ha puesto un mapa'),
      message: s.isDm
          ? tr('Sube la imagen de un mapa (con o sin cuadrícula) o crea un tablero en blanco para los combates.')
          : tr('Mientras tanto, las tiradas de todos aparecen aquí.'),
      action: s.isDm
          ? Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => createMapFromImage(context),
                  icon: const Icon(Icons.image),
                  label: Text(tr('Subir imagen')),
                ),
                OutlinedButton.icon(
                  onPressed: () => createBlankMap(context),
                  icon: const Icon(Icons.grid_on),
                  label: Text(tr('Mapa en blanco')),
                ),
              ],
            )
          : null,
    );
  }
}

class _BoardToolbar extends StatelessWidget {
  const _BoardToolbar({required this.map, required this.onPlace});
  final BoardMap? map;

  /// Pasa fichas al mapa para que se coloquen tocando la casilla.
  final void Function(List<BoardToken> tokens, String label) onPlace;

  void _addParty(BuildContext context, BoardMap map) {
    final s = SessionScope.read(context);
    final tokens = partyTokens(s, map);
    if (tokens.isEmpty) {
      showSnack(context, tr('Todo el grupo está ya en el mapa'));
      return;
    }
    onPlace(tokens, tr('Grupo'));
  }

  void _placeMine(BuildContext context, BoardMap map) {
    final s = SessionScope.read(context);
    final c = s.activeCharacter;
    if (c == null) return;
    final (x, y) = s.campaign.board.freeCell(map, startX: map.cols ~/ 2, startY: map.rows ~/ 2);
    onPlace([BoardToken(mapId: map.id, kind: TokenKind.pc, characterId: c.id, x: x, y: y)], c.name);
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final t = Theme.of(context).textTheme;
    final m = map;
    final maps = s.campaign.board.maps;
    final mine = s.activeCharacter;
    final placed =
        m != null && mine != null && s.campaign.board.tokens.any((x) => x.mapId == m.id && x.characterId == mine.id);
    return Material(
      color: AppColors.surface.withValues(alpha: 0.85),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            const GameIcon('treasure_map', size: 22),
            Gap.s,
            if (s.isDm && maps.length > 1)
              DropdownButton<String>(
                value: m?.id,
                underline: const SizedBox.shrink(),
                items: [for (final x in maps) DropdownMenuItem(value: x.id, child: Text(x.name))],
                onChanged: (id) {
                  if (id != null) s.send(Command.setActiveMap(id));
                },
              )
            else
              Flexible(
                child: Text(m?.name ?? tr('Tablero'), style: t.titleMedium, overflow: TextOverflow.ellipsis),
              ),
            const Spacer(),
            if (!s.isDm && m != null && mine != null && !placed)
              FilledButton.tonalIcon(
                onPressed: s.canEdit ? () => _placeMine(context, m) : null,
                icon: GameIcon(mine.portrait, size: 18),
                label: Text(tr('Colocar a {0}', [mine.name])),
              ),
            if (s.isDm && m != null)
              PopupMenuButton<String>(
                tooltip: tr('Añadir fichas'),
                icon: Icon(Icons.person_add_alt_1, color: AppColors.gold),
                onSelected: (v) async {
                  if (v == 'party') {
                    _addParty(context, m);
                  } else if (v == 'monster') {
                    final monster = await pickMonster(context);
                    if (monster != null && context.mounted) {
                      await addMonsterDialog(context, monster, onPlace: (tokens) => onPlace(tokens, monster.name));
                    }
                  } else if (v == 'marker') {
                    final token = await askMarker(context, m);
                    if (token != null) onPlace([token], token.label);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'party', child: Text(tr('Colocar al grupo'))),
                  PopupMenuItem(value: 'monster', child: Text(tr('Criatura del grimorio…'))),
                  PopupMenuItem(value: 'marker', child: Text(tr('Marcador (PNJ, cofre, trampa…)'))),
                ],
              ),
            if (s.isDm)
              PopupMenuButton<String>(
                tooltip: tr('Mapas'),
                icon: Icon(Icons.map_outlined, color: AppColors.gold),
                onSelected: (v) async {
                  switch (v) {
                    case 'image':
                      await createMapFromImage(context);
                    case 'blank':
                      await createBlankMap(context);
                    case 'edit':
                      if (m != null) await openMapEditor(context, m);
                    case 'delete':
                      if (m == null) return;
                      final ok = await confirm(
                        context,
                        tr('Borrar mapa'),
                        tr('¿Borrar «{0}» y sus fichas?', [m.name]),
                        danger: true,
                      );
                      if (ok) await s.send(Command.deleteMap(m.id));
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'image', child: Text(tr('Nuevo mapa desde imagen…'))),
                  PopupMenuItem(value: 'blank', child: Text(tr('Nuevo mapa en blanco'))),
                  if (m != null) PopupMenuItem(value: 'edit', child: Text(tr('Ajustar cuadrícula…'))),
                  if (m != null) PopupMenuItem(value: 'delete', child: Text(tr('Borrar este mapa'))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
