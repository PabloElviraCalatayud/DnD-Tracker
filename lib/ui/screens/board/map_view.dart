import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n.dart';
import '../../../domain/board.dart';
import '../../../domain/campaign.dart';
import '../../../domain/character.dart';
import '../../../domain/ruleset.dart';
import '../../../engine/commands.dart';
import '../../../state/providers.dart';
import '../../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'token_panel.dart';

typedef Cell = (int, int);

/// Datos que se pintan en cada ficha (salen del personaje o del combatiente).
class TokenInfo {
  TokenInfo({
    required this.token,
    required this.name,
    required this.icon,
    this.character,
    this.combatant,
    this.hp,
    this.hpMax,
    this.labels = const [],
    this.isTurn = false,
    this.movable = false,
  });

  final BoardToken token;
  final String name;
  final String icon;
  final Character? character;
  final Combatant? combatant;
  final int? hp;
  final int? hpMax;

  /// Estados (PJ) o etiquetas del máster (enemigos).
  final List<String> labels;
  final bool isTurn;
  final bool movable;

  Color get color => switch (token.kind) {
    TokenKind.pc => AppColors.gold,
    TokenKind.monster => AppColors.crimson,
    TokenKind.npc => AppColors.arcane,
    TokenKind.object => AppColors.muted,
  };
}

/// Reúne la información de una ficha según quién mira: los PG de los PJ los
/// ve todo el mundo; los de los enemigos, sólo el máster.
TokenInfo tokenInfo(GameSession s, BoardToken t) {
  final c = s.campaign;
  final ch = t.characterId == null ? null : c.character(t.characterId!);
  final cb = t.combatantId == null ? null : c.encounter.combatants.where((x) => x.id == t.combatantId).firstOrNull;
  final current = c.encounter.active ? c.encounter.current : null;
  final isTurn =
      current != null &&
      ((cb != null && current.id == cb.id) ||
          (ch != null && current.characterId == ch.id && current.characterId != null));
  if (ch != null) {
    return TokenInfo(
      token: t,
      name: ch.name,
      icon: ch.portrait,
      character: ch,
      combatant: cb,
      hp: ch.hpCurrent,
      hpMax: ch.effectiveHpMax(c.ruleset),
      labels: [
        ...ch.conditions.map(conditionLabel),
        if (ch.exhaustion > 0) tr('Cansancio {0}', [ch.exhaustion]),
      ],
      isTurn: isTurn,
      movable: s.isDm || ch.ownerId == s.myUserId,
    );
  }
  return TokenInfo(
    token: t,
    name: cb?.name ?? (t.label.isEmpty ? tr('Ficha') : t.label),
    icon: t.icon.isNotEmpty ? t.icon : (t.kind == TokenKind.monster ? 'dragon' : 'person'),
    combatant: cb,
    hp: s.isDm ? cb?.hp : null,
    hpMax: s.isDm ? cb?.hpMax : null,
    labels: [...?cb?.tags, ...t.tags, ...?cb?.conditions.map(conditionLabel)],
    isTurn: isTurn,
    movable: s.isDm,
  );
}

class MapView extends ConsumerStatefulWidget {
  const MapView({super.key, required this.map});
  final BoardMap map;

  @override
  ConsumerState<MapView> createState() => MapViewState();
}

class MapViewState extends ConsumerState<MapView> {
  final _tc = TransformationController();
  String? _selectedId;
  bool _measure = false;
  Cell? _mStart;
  Cell? _mEnd;
  Cell? _hover;
  int? _rangeFeet;
  Size? _viewport;
  String? _fittedMapId;

  BoardMap get map => widget.map;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void select(String? tokenId) => setState(() {
    _selectedId = tokenId;
    _rangeFeet = null;
  });

  void _fit() {
    final vp = _viewport;
    if (vp == null || map.width <= 0 || map.height <= 0) return;
    final scale = min(vp.width / map.width, vp.height / map.height) * 0.96;
    final tx = (vp.width - map.width * scale) / 2;
    final ty = (vp.height - map.height * scale) / 2;
    _tc.value = Matrix4.diagonal3Values(scale, scale, 1)..setTranslationRaw(tx, ty, 0);
  }

  Cell? _cellAt(Offset local) {
    final cx = ((local.dx - map.offsetX) / map.cellPx).floor();
    final cy = ((local.dy - map.offsetY) / map.cellPx).floor();
    if (cx < 0 || cy < 0 || cx >= map.cols || cy >= map.rows) return null;
    return (cx, cy);
  }

  BoardToken? _tokenAt(List<BoardToken> tokens, Cell cell) {
    for (final t in tokens.reversed) {
      if (cell.$1 >= t.x && cell.$1 < t.x + t.size && cell.$2 >= t.y && cell.$2 < t.y + t.size) return t;
    }
    return null;
  }

  /// Distancia en casillas desde la ficha (que puede ocupar varias) a una casilla.
  int _distanceFromToken(BoardToken t, Cell c, bool alternate) {
    int axis(int v, int start, int size) => v < start ? start - v : (v > start + size - 1 ? v - (start + size - 1) : 0);
    return gridDistance(axis(c.$1, t.x, t.size), axis(c.$2, t.y, t.size), alternate: alternate);
  }

  Future<void> _onTap(TapUpDetails d, List<BoardToken> tokens, GameSession s) async {
    final cell = _cellAt(d.localPosition);
    if (cell == null) return;
    if (_measure) {
      setState(() {
        if (_mStart == null || _mEnd != null) {
          _mStart = cell;
          _mEnd = null;
        } else {
          _mEnd = cell;
        }
      });
      return;
    }
    final hit = _tokenAt(tokens, cell);
    final selected = tokens.where((t) => t.id == _selectedId).firstOrNull;
    if (hit != null && hit.id != selected?.id) {
      select(hit.id);
      return;
    }
    if (hit != null && hit.id == selected?.id) {
      select(null);
      return;
    }
    if (selected == null) return;
    final info = tokenInfo(s, selected);
    if (!info.movable) {
      select(null);
      return;
    }
    // Mover la ficha seleccionada a la casilla tocada.
    final nx = min(cell.$1, map.cols - selected.size);
    final ny = min(cell.$2, map.rows - selected.size);
    final occupied = tokens.any(
      (t) =>
          t.id != selected.id &&
          nx < t.x + t.size &&
          nx + selected.size > t.x &&
          ny < t.y + t.size &&
          ny + selected.size > t.y,
    );
    if (occupied) {
      showSnack(context, tr('Esa casilla está ocupada'), error: true);
      return;
    }
    final alternate = s.campaign.settings.diagonals == DiagonalRule.alternate;
    final cells = gridDistance(nx - selected.x, ny - selected.y, alternate: alternate);
    final r = await s.send(Command.moveToken(selected.id, nx, ny));
    if (!mounted) return;
    if (!r.ok) {
      showSnack(context, r.error ?? tr('No se pudo mover'), error: true);
      return;
    }
    final units = ref.read(unitsProvider);
    showSnack(
      context,
      tr('{0} se mueve {1} casillas ({2})', [info.name, cells, units.distance(cells * Rules.gridFeet)]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final units = ref.watch(unitsProvider);
    final tokens = s.campaign.board.tokensOn(map.id);
    final infos = {for (final t in tokens) t.id: tokenInfo(s, t)};
    final selected = tokens.where((t) => t.id == _selectedId).firstOrNull;
    if (selected == null && _selectedId != null) _selectedId = null;
    final alternate = s.campaign.settings.diagonals == DiagonalRule.alternate;

    // Zona resaltada: alcance pedido o, para tu ficha, tu velocidad.
    final highlight = <Cell>{};
    var highlightIsRange = false;
    if (selected != null) {
      final info = infos[selected.id]!;
      final feet = _rangeFeet ?? (info.movable ? info.character?.speed : null);
      highlightIsRange = _rangeFeet != null;
      if (feet != null && feet > 0) {
        final maxCells = feet ~/ Rules.gridFeet;
        for (var y = 0; y < map.rows; y++) {
          for (var x = 0; x < map.cols; x++) {
            if (_distanceFromToken(selected, (x, y), alternate) <= maxCells) highlight.add((x, y));
          }
        }
      }
    }

    // Línea de medición (herramienta regla o ficha seleccionada → casilla bajo el ratón).
    Cell? lineFrom;
    Cell? lineTo;
    if (_measure && _mStart != null) {
      lineFrom = _mStart;
      lineTo = _mEnd ?? _hover;
    } else if (selected != null && _hover != null) {
      lineFrom = (selected.x + (selected.size - 1) ~/ 2, selected.y + (selected.size - 1) ~/ 2);
      lineTo = _hover;
    }
    String? lineLabel;
    if (lineFrom != null && lineTo != null) {
      final cells = gridDistance(lineTo.$1 - lineFrom.$1, lineTo.$2 - lineFrom.$2, alternate: alternate);
      lineLabel = '$cells · ${units.distance(cells * Rules.gridFeet)}';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        if (_fittedMapId != map.id) {
          _fittedMapId = map.id;
          WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
        }
        return Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.background,
                child: InteractiveViewer(
                  transformationController: _tc,
                  constrained: false,
                  minScale: 0.05,
                  maxScale: 6,
                  boundaryMargin: const EdgeInsets.all(400),
                  child: MouseRegion(
                    onHover: (e) {
                      final c = _cellAt(e.localPosition);
                      if (c != _hover) setState(() => _hover = c);
                    },
                    onExit: (_) => setState(() => _hover = null),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) => _onTap(d, tokens, s),
                      child: SizedBox(
                        width: map.width,
                        height: map.height,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(child: _MapBackground(map: map)),
                            if (map.showGrid) Positioned.fill(child: CustomPaint(painter: GridPainter(map))),
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _OverlayPainter(
                                  map: map,
                                  highlight: highlight,
                                  highlightColor: highlightIsRange ? AppColors.arcane : AppColors.gold,
                                  lineFrom: lineFrom,
                                  lineTo: lineTo,
                                  lineLabel: lineLabel,
                                ),
                              ),
                            ),
                            for (final t in tokens)
                              Positioned(
                                left: map.offsetX + t.x * map.cellPx,
                                top: map.offsetY + t.y * map.cellPx,
                                width: t.size * map.cellPx,
                                height: t.size * map.cellPx,
                                child: IgnorePointer(
                                  child: TokenView(
                                    info: infos[t.id]!,
                                    selected: t.id == _selectedId,
                                    showHidden: s.isDm,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (s.campaign.encounter.active && s.campaign.encounter.combatants.isNotEmpty)
              Positioned(
                left: 8,
                right: 8,
                top: 8,
                child: _TurnStrip(
                  onSelect: (combatantId, characterId) {
                    final t = tokens
                        .where(
                          (t) =>
                              (combatantId != null && t.combatantId == combatantId) ||
                              (characterId != null && t.characterId == characterId),
                        )
                        .firstOrNull;
                    if (t != null) select(t.id);
                  },
                ),
              ),
            Positioned(
              right: 8,
              top: s.campaign.encounter.active ? 64 : 8,
              child: Column(
                children: [
                  _MapButton(
                    icon: Icons.straighten,
                    tooltip: tr('Medir distancias'),
                    active: _measure,
                    onTap: () => setState(() {
                      _measure = !_measure;
                      _mStart = null;
                      _mEnd = null;
                      if (_measure) _selectedId = null;
                    }),
                  ),
                  Gap.s,
                  _MapButton(icon: Icons.fit_screen, tooltip: tr('Encuadrar el mapa'), onTap: _fit),
                ],
              ),
            ),
            if (_measure)
              Positioned(
                left: 8,
                bottom: 8,
                child: _Hint(
                  text: lineLabel == null
                      ? tr('Toca una casilla de inicio y otra de destino. 1 casilla = {0}.', [
                          units.distance(Rules.gridFeet),
                        ])
                      : tr('Distancia: {0}', [lineLabel]),
                ),
              ),
            if (selected != null && !_measure)
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: TokenPanel(
                  info: infos[selected.id]!,
                  rangeFeet: _rangeFeet,
                  onRange: (feet) => setState(() => _rangeFeet = feet),
                  onClose: () => select(null),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.tooltip, required this.onTap, this.active = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.primaryContainer : AppColors.surface.withValues(alpha: 0.9),
      shape: const CircleBorder(side: BorderSide(color: AppColors.outline)),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: active ? AppColors.gold : AppColors.parchment),
        onPressed: onTap,
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.outline),
    ),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );
}

/// Imagen del mapa (o fondo liso si es un mapa en blanco).
class _MapBackground extends StatelessWidget {
  const _MapBackground({required this.map});
  final BoardMap map;

  @override
  Widget build(BuildContext context) {
    if (!map.hasImage) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFF2A2420),
          image: DecorationImage(
            image: AssetImage('assets/images/parchment_dark.png'),
            repeat: ImageRepeat.repeat,
            opacity: 0.6,
          ),
        ),
      );
    }
    final s = SessionScope.of(context);
    return FutureBuilder<Uint8List?>(
      future: s.asset(map.assetId!),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null) {
          return ColoredBox(
            color: AppColors.surfaceHigh,
            child: Center(
              child: snap.connectionState == ConnectionState.done
                  ? Text(tr('No se pudo cargar el mapa'))
                  : const CircularProgressIndicator(),
            ),
          );
        }
        return Image.memory(bytes, fit: BoxFit.fill, gaplessPlayback: true, filterQuality: FilterQuality.medium);
      },
    );
  }
}

class GridPainter extends CustomPainter {
  GridPainter(this.map);
  final BoardMap map;

  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()
      ..color = Colors.black.withValues(alpha: map.gridOpacity)
      ..strokeWidth = max(1, map.cellPx / 40);
    final light = Paint()
      ..color = Colors.white.withValues(alpha: map.gridOpacity * 0.5)
      ..strokeWidth = max(0.5, map.cellPx / 80);
    final right = map.offsetX + map.cols * map.cellPx;
    final bottom = map.offsetY + map.rows * map.cellPx;
    for (var c = 0; c <= map.cols; c++) {
      final x = map.offsetX + c * map.cellPx;
      canvas.drawLine(Offset(x, map.offsetY), Offset(x, bottom), dark);
      canvas.drawLine(Offset(x + 1, map.offsetY), Offset(x + 1, bottom), light);
    }
    for (var r = 0; r <= map.rows; r++) {
      final y = map.offsetY + r * map.cellPx;
      canvas.drawLine(Offset(map.offsetX, y), Offset(right, y), dark);
      canvas.drawLine(Offset(map.offsetX, y + 1), Offset(right, y + 1), light);
    }
  }

  @override
  bool shouldRepaint(GridPainter old) =>
      old.map.cellPx != map.cellPx ||
      old.map.offsetX != map.offsetX ||
      old.map.offsetY != map.offsetY ||
      old.map.cols != map.cols ||
      old.map.rows != map.rows ||
      old.map.gridOpacity != map.gridOpacity;
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.map,
    required this.highlight,
    required this.highlightColor,
    this.lineFrom,
    this.lineTo,
    this.lineLabel,
  });

  final BoardMap map;
  final Set<Cell> highlight;
  final Color highlightColor;
  final Cell? lineFrom;
  final Cell? lineTo;
  final String? lineLabel;

  Offset _center(Cell c) => Offset(map.offsetX + (c.$1 + 0.5) * map.cellPx, map.offsetY + (c.$2 + 0.5) * map.cellPx);

  @override
  void paint(Canvas canvas, Size size) {
    if (highlight.isNotEmpty) {
      final fill = Paint()..color = highlightColor.withValues(alpha: 0.18);
      for (final c in highlight) {
        canvas.drawRect(
          Rect.fromLTWH(map.offsetX + c.$1 * map.cellPx, map.offsetY + c.$2 * map.cellPx, map.cellPx, map.cellPx),
          fill,
        );
      }
    }
    final from = lineFrom;
    final to = lineTo;
    if (from != null) {
      final start = _center(from);
      canvas.drawCircle(start, map.cellPx * 0.18, Paint()..color = AppColors.arcane);
      if (to != null) {
        final end = _center(to);
        final paint = Paint()
          ..color = AppColors.arcane
          ..strokeWidth = max(2, map.cellPx / 18)
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(start, end, paint);
        canvas.drawCircle(end, map.cellPx * 0.18, Paint()..color = AppColors.arcane);
        final label = lineLabel;
        if (label != null) {
          final tp = TextPainter(
            text: TextSpan(
              text: label,
              style: TextStyle(color: Colors.white, fontSize: max(12, map.cellPx * 0.3), fontWeight: FontWeight.w700),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final pos = end + Offset(map.cellPx * 0.35, -map.cellPx * 0.6);
          final bg = RRect.fromRectAndRadius(
            Rect.fromLTWH(pos.dx - 6, pos.dy - 3, tp.width + 12, tp.height + 6),
            const Radius.circular(8),
          );
          canvas.drawRRect(bg, Paint()..color = Colors.black.withValues(alpha: 0.75));
          tp.paint(canvas, pos);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => true;
}

/// Ficha redonda con imagen o icono, nombre, barra de PG y avisos.
class TokenView extends StatelessWidget {
  const TokenView({super.key, required this.info, this.selected = false, this.showHidden = false});
  final TokenInfo info;
  final bool selected;
  final bool showHidden;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final t = info.token;
    return LayoutBuilder(
      builder: (context, c) {
        final side = c.maxWidth;
        final border = max(2.0, side * 0.06);
        final ringColor = selected ? AppColors.arcane : (info.isTurn ? AppColors.gold : info.color);
        final hp = info.hp;
        final hpMax = info.hpMax;
        final ratio = (hp != null && hpMax != null && hpMax > 0) ? (hp / hpMax).clamp(0.0, 1.0) : null;
        Widget face;
        if (t.assetId != null) {
          face = FutureBuilder<Uint8List?>(
            future: s.asset(t.assetId!),
            builder: (context, snap) => snap.data == null
                ? Center(
                    child: GameIcon(info.icon, size: side * 0.6, color: info.color),
                  )
                : Image.memory(snap.data!, fit: BoxFit.cover, gaplessPlayback: true),
          );
        } else {
          face = Center(
            child: GameIcon(info.icon, size: side * 0.62, color: info.color),
          );
        }
        final down = hp != null && hp <= 0;
        return Opacity(
          opacity: t.hidden && showHidden ? 0.5 : 1,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(side * 0.06),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                      border: Border.all(color: ringColor, width: border),
                      boxShadow: [
                        if (info.isTurn || selected)
                          BoxShadow(color: ringColor.withValues(alpha: 0.8), blurRadius: side * 0.25),
                        BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: side * 0.08),
                      ],
                    ),
                    child: ClipOval(
                      child: ColorFiltered(
                        colorFilter: down
                            ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                            : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                        child: face,
                      ),
                    ),
                  ),
                ),
              ),
              if (ratio != null)
                Positioned(
                  left: side * 0.12,
                  right: side * 0.12,
                  bottom: side * 0.02,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(side),
                    child: Container(
                      height: max(3, side * 0.08),
                      color: Colors.black87,
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: ratio,
                        child: Container(color: AppColors.hpColor(ratio)),
                      ),
                    ),
                  ),
                ),
              if (info.labels.isNotEmpty)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: EdgeInsets.all(side * 0.04),
                    decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle),
                    child: Text(
                      '${info.labels.length}',
                      style: TextStyle(fontSize: max(8, side * 0.18), color: Colors.black, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              if (t.hidden && showHidden)
                Positioned(
                  left: 0,
                  top: 0,
                  child: Icon(Icons.visibility_off, size: max(10, side * 0.25), color: AppColors.parchment),
                ),
              Positioned(
                left: -side * 0.5,
                right: -side * 0.5,
                top: side * 0.98,
                child: Text(
                  info.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: max(8, side * 0.2),
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(blurRadius: 3, color: Colors.black),
                      Shadow(blurRadius: 6, color: Colors.black),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Orden de turnos encima del mapa.
class _TurnStrip extends StatelessWidget {
  const _TurnStrip({required this.onSelect});
  final void Function(String? combatantId, String? characterId) onSelect;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final e = s.campaign.encounter;
    final t = Theme.of(context).textTheme;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(tr('Ronda {0}', [e.round]), style: t.titleSmall?.copyWith(color: AppColors.gold)),
          ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < e.combatants.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                    child: ActionChip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: i == e.turn ? AppColors.primaryContainer : null,
                      side: BorderSide(color: i == e.turn ? AppColors.gold : AppColors.outlineSoft),
                      label: Text('${e.combatants[i].initiative} · ${e.combatants[i].name}'),
                      onPressed: () => onSelect(e.combatants[i].id, e.combatants[i].characterId),
                    ),
                  ),
              ],
            ),
          ),
          if (s.isDm)
            IconButton(
              tooltip: tr('Siguiente turno'),
              icon: const Icon(Icons.skip_next, color: AppColors.gold),
              onPressed: () => s.send(Command.putEncounter(e.copy()..next())),
            ),
        ],
      ),
    );
  }
}
