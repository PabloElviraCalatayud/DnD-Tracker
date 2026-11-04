import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  const MapView({super.key, required this.map, this.desktop = false});
  final BoardMap map;

  /// En escritorio la vista inicial usa casillas más grandes y hay atajos de teclado.
  final bool desktop;

  @override
  ConsumerState<MapView> createState() => MapViewState();
}

/// Ficha que se está arrastrando.
class _Drag {
  _Drag(this.tokenId, this.grab, this.topLeft);
  final String tokenId;
  final Offset grab;
  Offset topLeft;
}

class MapViewState extends ConsumerState<MapView> {
  final _tc = TransformationController();
  final _focus = FocusNode(debugLabel: 'mapa');
  String? _selectedId;
  bool _measure = false;
  Cell? _mStart;
  Cell? _mEnd;
  Cell? _hover;
  int? _rangeFeet;
  Size? _viewport;
  String? _fittedMapId;
  _Drag? _drag;

  /// Fichas pendientes de colocar: el máster (o el jugador) toca dónde va cada una.
  List<BoardToken> _placing = [];
  String _placingLabel = '';

  BoardMap get map => widget.map;

  static const _minZoom = 0.05;
  static const _maxZoom = 8.0;

  @override
  void dispose() {
    _tc.dispose();
    _focus.dispose();
    super.dispose();
  }

  void select(String? tokenId) => setState(() {
    _selectedId = tokenId;
    _rangeFeet = null;
  });

  /// Empieza el modo «colocar»: cada toque en el mapa coloca la siguiente ficha.
  void startPlacing(List<BoardToken> tokens, String label) {
    if (tokens.isEmpty) return;
    setState(() {
      _placing = [...tokens];
      _placingLabel = label;
      _measure = false;
      _selectedId = null;
    });
    _focus.requestFocus();
  }

  void _cancelPlacing() => setState(() => _placing = []);

  Future<void> _placeAt(Cell cell) async {
    if (_placing.isEmpty) return;
    final s = SessionScope.read(context);
    final t = _placing.first;
    t
      ..x = cell.$1.clamp(0, max(0, map.cols - t.size))
      ..y = cell.$2.clamp(0, max(0, map.rows - t.size));
    setState(() => _placing = _placing.sublist(1));
    final r = await s.send(Command.putToken(t));
    if (!mounted) return;
    if (!r.ok) showSnack(context, r.error ?? tr('No se pudo colocar'), error: true);
  }

  /// Coloca automáticamente las fichas que quedan, en casillas libres.
  Future<void> _autoPlaceRest() async {
    final s = SessionScope.read(context);
    final board = s.campaign.board.copy();
    final rest = _placing;
    setState(() => _placing = []);
    for (final t in rest) {
      final (x, y) = board.freeCell(map, startX: map.cols ~/ 2, startY: map.rows ~/ 2);
      t
        ..x = x
        ..y = y;
      board.tokens.add(t);
      await s.send(Command.putToken(t));
    }
  }

  // ---------------------------------------------------------------- zoom

  double get _scale => _tc.value.getMaxScaleOnAxis();

  void _setView(double scale, Offset sceneCenter) {
    final vp = _viewport;
    if (vp == null) return;
    final sc = scale.clamp(_minZoom, _maxZoom);
    _tc.value = Matrix4.diagonal3Values(sc, sc, 1)
      ..setTranslationRaw(vp.width / 2 - sceneCenter.dx * sc, vp.height / 2 - sceneCenter.dy * sc, 0);
  }

  void _zoom(double factor) {
    final vp = _viewport;
    if (vp == null) return;
    final center = _tc.toScene(Offset(vp.width / 2, vp.height / 2));
    _setView(_scale * factor, center);
  }

  void _fit() {
    final vp = _viewport;
    if (vp == null || map.width <= 0 || map.height <= 0) return;
    final scale = min(vp.width / map.width, vp.height / map.height) * 0.96;
    _setView(scale, Offset(map.width / 2, map.height / 2));
  }

  Offset _cellCenter(int x, int y, [int size = 1]) =>
      Offset(map.offsetX + (x + size / 2) * map.cellPx, map.offsetY + (y + size / 2) * map.cellPx);

  /// Vista inicial: todo el mapa si cabe con casillas cómodas; si no, casillas
  /// grandes centradas en el grupo (o en tu personaje).
  void _initialView() {
    final vp = _viewport;
    if (vp == null || map.width <= 0 || map.height <= 0) return;
    final fit = min(vp.width / map.width, vp.height / map.height) * 0.96;
    final comfortable = (widget.desktop ? 64.0 : 52.0) / map.cellPx;
    if (fit >= comfortable) {
      _fit();
      return;
    }
    final s = SessionScope.read(context);
    final tokens = s.campaign.board.tokensOn(map.id);
    final mine = s.activeCharacter;
    // El máster ve a todos; el jugador, a su personaje y al grupo.
    final focus = s.isDm
        ? tokens
        : [
            ...tokens.where((t) => mine != null && t.characterId == mine.id),
            ...tokens.where((t) => t.kind == TokenKind.pc),
          ];
    if (focus.isEmpty) {
      _setView(comfortable, Offset(map.width / 2, map.height / 2));
      return;
    }
    var left = double.infinity, top = double.infinity, right = -double.infinity, bottom = -double.infinity;
    for (final t in focus) {
      left = min(left, map.offsetX + (t.x - 1) * map.cellPx);
      top = min(top, map.offsetY + (t.y - 1) * map.cellPx);
      right = max(right, map.offsetX + (t.x + t.size + 1) * map.cellPx);
      bottom = max(bottom, map.offsetY + (t.y + t.size + 1) * map.cellPx);
    }
    final box = Rect.fromLTRB(left, top, right, bottom);
    final boxFit = min(vp.width / box.width, vp.height / box.height);
    _setView(boxFit >= comfortable ? min(boxFit, comfortable * 1.6) : comfortable, box.center);
  }

  void _centerOn(BoardToken t) => _setView(_scale, _cellCenter(t.x, t.y, t.size));

  // ---------------------------------------------------------------- casillas

  Cell? _cellAt(Offset local) {
    final cx = ((local.dx - map.offsetX) / map.cellPx).floor();
    final cy = ((local.dy - map.offsetY) / map.cellPx).floor();
    if (cx < 0 || cy < 0 || cx >= map.cols || cy >= map.rows) return null;
    return (cx, cy);
  }

  /// Distancia en casillas desde la ficha (que puede ocupar varias) a una casilla.
  int _distanceFromToken(BoardToken t, Cell c, bool alternate) {
    int axis(int v, int start, int size) => v < start ? start - v : (v > start + size - 1 ? v - (start + size - 1) : 0);
    return gridDistance(axis(c.$1, t.x, t.size), axis(c.$2, t.y, t.size), alternate: alternate);
  }

  bool _occupied(List<BoardToken> tokens, BoardToken moving, int nx, int ny) => tokens.any(
    (t) =>
        t.id != moving.id && nx < t.x + t.size && nx + moving.size > t.x && ny < t.y + t.size && ny + moving.size > t.y,
  );

  /// Mueve una ficha. El máster puede dejarla donde quiera (incluso encima de
  /// otra); los jugadores, en casillas libres.
  Future<void> _move(BoardToken t, int x, int y, GameSession s) async {
    final int nx = x.clamp(0, max(0, map.cols - t.size));
    final int ny = y.clamp(0, max(0, map.rows - t.size));
    if (nx == t.x && ny == t.y) return;
    final tokens = s.campaign.board.tokensOn(map.id);
    if (!s.isDm && _occupied(tokens, t, nx, ny)) {
      showSnack(context, tr('Esa casilla está ocupada'), error: true);
      return;
    }
    final alternate = s.campaign.settings.diagonals == DiagonalRule.alternate;
    final cells = gridDistance(nx - t.x, ny - t.y, alternate: alternate);
    final name = tokenInfo(s, t).name;
    final r = await s.send(Command.moveToken(t.id, nx, ny));
    if (!mounted) return;
    if (!r.ok) {
      showSnack(context, r.error ?? tr('No se pudo mover'), error: true);
      return;
    }
    final units = ref.read(unitsProvider);
    showSnack(context, tr('{0} se mueve {1} casillas ({2})', [name, cells, units.distance(cells * Rules.gridFeet)]));
  }

  Future<void> _onCell(Cell cell, GameSession s) async {
    _focus.requestFocus();
    if (_placing.isNotEmpty) {
      await _placeAt(cell);
      return;
    }
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
    final tokens = s.campaign.board.tokensOn(map.id);
    final selected = tokens.where((t) => t.id == _selectedId).firstOrNull;
    if (selected == null) return;
    if (!tokenInfo(s, selected).movable) {
      select(null);
      return;
    }
    await _move(selected, cell.$1, cell.$2, s);
  }

  void _onTokenTap(BoardToken t, GameSession s) {
    _focus.requestFocus();
    if (_placing.isNotEmpty || _measure) {
      _onCell((t.x, t.y), s);
      return;
    }
    select(t.id == _selectedId ? null : t.id);
  }

  // ---------------------------------------------------------------- arrastrar

  void _dragStart(BoardToken t, DragStartDetails d) {
    _focus.requestFocus();
    setState(() {
      _selectedId = t.id;
      _rangeFeet = null;
      _drag = _Drag(t.id, d.localPosition, Offset(map.offsetX + t.x * map.cellPx, map.offsetY + t.y * map.cellPx));
    });
  }

  void _dragUpdate(BoardToken t, DragUpdateDetails d) {
    final drag = _drag;
    if (drag == null) return;
    setState(() {
      drag.topLeft =
          Offset(map.offsetX + t.x * map.cellPx, map.offsetY + t.y * map.cellPx) + d.localPosition - drag.grab;
    });
  }

  Cell _dropCell(BoardToken t, _Drag drag) {
    final x = ((drag.topLeft.dx - map.offsetX) / map.cellPx).round();
    final y = ((drag.topLeft.dy - map.offsetY) / map.cellPx).round();
    return (x.clamp(0, max(0, map.cols - t.size)), y.clamp(0, max(0, map.rows - t.size)));
  }

  Future<void> _dragEnd(BoardToken t, GameSession s) async {
    final drag = _drag;
    if (drag == null) return;
    final cell = _dropCell(t, drag);
    setState(() => _drag = null);
    await _move(t, cell.$1, cell.$2, s);
  }

  // ---------------------------------------------------------------- teclado

  KeyEventResult _onKey(KeyEvent e, GameSession s) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = e.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      setState(() {
        _placing = [];
        _measure = false;
        _mStart = null;
        _mEnd = null;
        _selectedId = null;
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.equal || key == LogicalKeyboardKey.add || key == LogicalKeyboardKey.numpadAdd) {
      _zoom(1.25);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.minus || key == LogicalKeyboardKey.numpadSubtract) {
      _zoom(0.8);
      return KeyEventResult.handled;
    }
    final tokens = s.campaign.board.tokensOn(map.id);
    final selected = tokens.where((t) => t.id == _selectedId).firstOrNull;
    if (selected == null || !tokenInfo(s, selected).movable) return KeyEventResult.ignored;
    final (dx, dy) = switch (key) {
      LogicalKeyboardKey.arrowLeft => (-1, 0),
      LogicalKeyboardKey.arrowRight => (1, 0),
      LogicalKeyboardKey.arrowUp => (0, -1),
      LogicalKeyboardKey.arrowDown => (0, 1),
      _ => (0, 0),
    };
    if (dx == 0 && dy == 0) return KeyEventResult.ignored;
    _move(selected, selected.x + dx, selected.y + dy, s);
    return KeyEventResult.handled;
  }

  // ---------------------------------------------------------------- dibujo

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final units = ref.watch(unitsProvider);
    final tokens = s.campaign.board.tokensOn(map.id);
    final infos = {for (final t in tokens) t.id: tokenInfo(s, t)};
    final selected = tokens.where((t) => t.id == _selectedId).firstOrNull;
    if (selected == null && _selectedId != null) _selectedId = null;
    final alternate = s.campaign.settings.diagonals == DiagonalRule.alternate;
    final dragging = _drag == null ? null : tokens.where((t) => t.id == _drag!.tokenId).firstOrNull;
    final dropCell = dragging == null ? null : _dropCell(dragging, _drag!);

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

    // Línea de medición: regla, arrastre o ficha seleccionada → casilla bajo el ratón.
    Cell? lineFrom;
    Cell? lineTo;
    if (_measure && _mStart != null) {
      lineFrom = _mStart;
      lineTo = _mEnd ?? _hover;
    } else if (dragging != null && dropCell != null) {
      lineFrom = (dragging.x + (dragging.size - 1) ~/ 2, dragging.y + (dragging.size - 1) ~/ 2);
      lineTo = (dropCell.$1 + (dragging.size - 1) ~/ 2, dropCell.$2 + (dragging.size - 1) ~/ 2);
    } else if (selected != null && _hover != null && _placing.isEmpty) {
      lineFrom = (selected.x + (selected.size - 1) ~/ 2, selected.y + (selected.size - 1) ~/ 2);
      lineTo = _hover;
    }
    String? lineLabel;
    if (lineFrom != null && lineTo != null) {
      final cells = gridDistance(lineTo.$1 - lineFrom.$1, lineTo.$2 - lineFrom.$2, alternate: alternate);
      lineLabel = '$cells · ${units.distance(cells * Rules.gridFeet)}';
    }
    final placingNext = _placing.firstOrNull;

    Widget tokenWidget(BoardToken t) {
      final info = infos[t.id]!;
      final canDrag = info.movable && !_measure && _placing.isEmpty;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTokenTap(t, s),
        onSecondaryTap: () => select(t.id),
        onDoubleTap: () => _centerOn(t),
        onPanStart: canDrag ? (d) => _dragStart(t, d) : null,
        onPanUpdate: canDrag ? (d) => _dragUpdate(t, d) : null,
        onPanEnd: canDrag ? (_) => _dragEnd(t, s) : null,
        onPanCancel: canDrag ? () => setState(() => _drag = null) : null,
        child: MouseRegion(
          cursor: canDrag ? SystemMouseCursors.grab : SystemMouseCursors.click,
          child: Opacity(
            opacity: _drag?.tokenId == t.id ? 0.35 : 1,
            child: TokenView(info: info, selected: t.id == _selectedId, showHidden: s.isDm),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        if (_fittedMapId != map.id) {
          _fittedMapId = map.id;
          WidgetsBinding.instance.addPostFrameCallback((_) => _initialView());
        }
        return Focus(
          focusNode: _focus,
          onKeyEvent: (_, e) => _onKey(e, s),
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: AppColors.background,
                  child: InteractiveViewer(
                    transformationController: _tc,
                    constrained: false,
                    minScale: _minZoom,
                    maxScale: _maxZoom,
                    boundaryMargin: const EdgeInsets.all(600),
                    child: MouseRegion(
                      cursor: _placing.isNotEmpty || _measure ? SystemMouseCursors.precise : MouseCursor.defer,
                      onHover: (e) {
                        final c = _cellAt(e.localPosition);
                        if (c != _hover) setState(() => _hover = c);
                      },
                      onExit: (_) => setState(() => _hover = null),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) {
                          final cell = _cellAt(d.localPosition);
                          if (cell != null) _onCell(cell, s);
                        },
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
                                    target: dropCell == null || dragging == null ? null : (dropCell, dragging.size),
                                    hoverPlace: placingNext == null || _hover == null
                                        ? null
                                        : (_hover!, placingNext.size),
                                    lineFrom: lineFrom,
                                    lineTo: lineTo,
                                    lineLabel: lineLabel,
                                  ),
                                ),
                              ),
                              for (final t in tokens)
                                Positioned(
                                  key: ValueKey(t.id),
                                  left: map.offsetX + t.x * map.cellPx,
                                  top: map.offsetY + t.y * map.cellPx,
                                  width: t.size * map.cellPx,
                                  height: t.size * map.cellPx,
                                  child: tokenWidget(t),
                                ),
                              if (dragging != null && _drag != null)
                                Positioned(
                                  left: _drag!.topLeft.dx,
                                  top: _drag!.topLeft.dy,
                                  width: dragging.size * map.cellPx,
                                  height: dragging.size * map.cellPx,
                                  child: IgnorePointer(
                                    child: Transform.scale(
                                      scale: 1.08,
                                      child: TokenView(info: infos[dragging.id]!, selected: true, lifted: true),
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
                      if (t != null) {
                        select(t.id);
                        _centerOn(t);
                      }
                    },
                  ),
                ),
              Positioned(
                right: 8,
                top: s.campaign.encounter.active ? 64 : 8,
                child: _MapControls(
                  measure: _measure,
                  onMeasure: () => setState(() {
                    _measure = !_measure;
                    _mStart = null;
                    _mEnd = null;
                    if (_measure) {
                      _selectedId = null;
                      _placing = [];
                    }
                  }),
                  onZoomIn: () => _zoom(1.25),
                  onZoomOut: () => _zoom(0.8),
                  onFit: _fit,
                ),
              ),
              if (placingNext != null)
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: _PlacingBanner(
                    name: infos[placingNext.id]?.name ?? tokenInfo(s, placingNext).name,
                    label: _placingLabel,
                    remaining: _placing.length,
                    onAuto: _autoPlaceRest,
                    onCancel: _cancelPlacing,
                  ),
                )
              else if (_measure)
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
                )
              else if (selected != null && _drag == null)
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
          ),
        );
      },
    );
  }
}

/// Botones flotantes del mapa: regla y zoom.
class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.measure,
    required this.onMeasure,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
  });
  final bool measure;
  final VoidCallback onMeasure;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MapButton(icon: Icons.straighten, tooltip: tr('Medir distancias'), active: measure, onTap: onMeasure),
        Gap.s,
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            children: [
              IconButton(tooltip: tr('Acercar'), icon: const Icon(Icons.add), onPressed: onZoomIn),
              IconButton(tooltip: tr('Alejar'), icon: const Icon(Icons.remove), onPressed: onZoomOut),
              IconButton(tooltip: tr('Encuadrar el mapa'), icon: const Icon(Icons.fit_screen), onPressed: onFit),
            ],
          ),
        ),
      ],
    );
  }
}

/// Aviso del modo «colocar fichas».
class _PlacingBanner extends StatelessWidget {
  const _PlacingBanner({
    required this.name,
    required this.label,
    required this.remaining,
    required this.onAuto,
    required this.onCancel,
  });
  final String name;
  final String label;
  final int remaining;
  final VoidCallback onAuto;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surfaceHigh.withValues(alpha: 0.96),
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Row(
          children: [
            Icon(Icons.ads_click, color: AppColors.gold),
            Gap.m,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tr('Toca el mapa para colocar a {0}', [name]), style: t.titleSmall),
                  Text(remaining > 1 ? tr('{0} · quedan {1}', [label, remaining]) : label, style: t.bodySmall),
                ],
              ),
            ),
            if (remaining > 1) TextButton(onPressed: onAuto, child: Text(tr('Colocar el resto'))),
            IconButton(tooltip: tr('Cancelar'), icon: const Icon(Icons.close), onPressed: onCancel),
          ],
        ),
      ),
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
      shape: CircleBorder(side: BorderSide(color: AppColors.outline)),
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
      return RepaintBoundary(child: CustomPaint(painter: FloorPainter(map, AppColors.mapFloor)));
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
        return Image.memory(bytes, fit: BoxFit.fill, gaplessPlayback: true, filterQuality: FilterQuality.high);
      },
    );
  }
}

/// Suelo de baldosas de piedra alineadas con la cuadrícula, para los mapas en
/// blanco. Se dibuja por código: se ve nítido a cualquier zoom.
class FloorPainter extends CustomPainter {
  FloorPainter(this.map, this.base);
  final BoardMap map;
  final Color base;

  Color _shade(Color c, double amount) =>
      amount >= 0 ? Color.lerp(c, Colors.white, amount)! : Color.lerp(c, Colors.black, -amount)!;

  @override
  void paint(Canvas canvas, Size size) {
    final cp = map.cellPx;
    final light = AppColors.palette.isDark;
    // Mortero entre baldosas.
    canvas.drawRect(Offset.zero & size, Paint()..color = _shade(base, light ? -0.45 : -0.3));
    final gap = cp * 0.035;
    final radius = Radius.circular(cp * 0.07);
    final seed = map.id.hashCode;
    final speck = Paint();
    final crack = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, cp * 0.012)
      ..strokeCap = StrokeCap.round;
    for (var y = 0; y < map.rows; y++) {
      for (var x = 0; x < map.cols; x++) {
        final r = Random(seed ^ (x * 73856093) ^ (y * 19349663));
        final tone = r.nextDouble() * 0.16 - 0.08;
        final color = _shade(base, tone);
        final rect = Rect.fromLTWH(map.offsetX + x * cp, map.offsetY + y * cp, cp, cp).deflate(gap);
        final rr = RRect.fromRectAndRadius(rect, radius);
        canvas.drawRRect(
          rr,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_shade(color, 0.07), color, _shade(color, -0.1)],
            ).createShader(rect),
        );
        // Bisel: luz arriba a la izquierda, sombra abajo a la derecha.
        final bevel = max(1.0, cp * 0.02);
        canvas.drawLine(
          rect.topLeft + Offset(radius.x, bevel / 2),
          rect.topRight + Offset(-radius.x, bevel / 2),
          Paint()
            ..color = _shade(color, 0.18).withValues(alpha: 0.6)
            ..strokeWidth = bevel,
        );
        canvas.drawLine(
          rect.bottomLeft + Offset(radius.x, -bevel / 2),
          rect.bottomRight + Offset(-radius.x, -bevel / 2),
          Paint()
            ..color = _shade(color, -0.3).withValues(alpha: 0.6)
            ..strokeWidth = bevel,
        );
        // Motas y alguna grieta.
        for (var i = 0; i < 5; i++) {
          speck.color = _shade(color, r.nextBool() ? -0.25 : 0.15).withValues(alpha: 0.35);
          canvas.drawCircle(
            Offset(rect.left + r.nextDouble() * rect.width, rect.top + r.nextDouble() * rect.height),
            cp * (0.008 + r.nextDouble() * 0.018),
            speck,
          );
        }
        if (r.nextDouble() < 0.16) {
          crack.color = _shade(color, -0.4).withValues(alpha: 0.7);
          final path = Path();
          var p = Offset(rect.left + r.nextDouble() * rect.width, rect.top);
          path.moveTo(p.dx, p.dy);
          for (var k = 0; k < 4; k++) {
            p = Offset(
              (p.dx + (r.nextDouble() - 0.5) * cp * 0.35).clamp(rect.left, rect.right),
              p.dy + rect.height / 4,
            );
            path.lineTo(p.dx, p.dy);
          }
          canvas.drawPath(path, crack);
        }
      }
    }
  }

  @override
  bool shouldRepaint(FloorPainter old) =>
      old.base != base ||
      old.map.cols != map.cols ||
      old.map.rows != map.rows ||
      old.map.cellPx != map.cellPx ||
      old.map.offsetX != map.offsetX ||
      old.map.offsetY != map.offsetY;
}

class GridPainter extends CustomPainter {
  GridPainter(this.map, {Color? ink})
    : ink = ink ?? (map.hasImage || AppColors.palette.isDark ? Colors.black : AppColors.palette.text);
  final BoardMap map;

  /// Color de las líneas: negras sobre imágenes y suelos oscuros.
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()
      ..color = ink.withValues(alpha: map.gridOpacity)
      ..strokeWidth = max(1, map.cellPx / 45);
    final light = Paint()
      ..color = Colors.white.withValues(alpha: map.gridOpacity * (map.hasImage ? 0.45 : 0.25))
      ..strokeWidth = max(0.6, map.cellPx / 90);
    final right = map.offsetX + map.cols * map.cellPx;
    final bottom = map.offsetY + map.rows * map.cellPx;
    final shift = max(1.0, map.cellPx / 70);
    for (var c = 0; c <= map.cols; c++) {
      final x = map.offsetX + c * map.cellPx;
      canvas.drawLine(Offset(x, map.offsetY), Offset(x, bottom), dark);
      canvas.drawLine(Offset(x + shift, map.offsetY), Offset(x + shift, bottom), light);
    }
    for (var r = 0; r <= map.rows; r++) {
      final y = map.offsetY + r * map.cellPx;
      canvas.drawLine(Offset(map.offsetX, y), Offset(right, y), dark);
      canvas.drawLine(Offset(map.offsetX, y + shift), Offset(right, y + shift), light);
    }
    // Marco exterior más marcado.
    canvas.drawRect(
      Rect.fromLTRB(map.offsetX, map.offsetY, right, bottom),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = ink.withValues(alpha: min(1, map.gridOpacity * 2))
        ..strokeWidth = max(2, map.cellPx / 25),
    );
  }

  @override
  bool shouldRepaint(GridPainter old) =>
      old.map.cellPx != map.cellPx ||
      old.map.offsetX != map.offsetX ||
      old.map.offsetY != map.offsetY ||
      old.map.cols != map.cols ||
      old.map.rows != map.rows ||
      old.map.gridOpacity != map.gridOpacity ||
      old.ink != ink;
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.map,
    required this.highlight,
    required this.highlightColor,
    this.target,
    this.hoverPlace,
    this.lineFrom,
    this.lineTo,
    this.lineLabel,
  });

  final BoardMap map;
  final Set<Cell> highlight;
  final Color highlightColor;

  /// Casilla donde caerá la ficha que se arrastra (y su tamaño).
  final (Cell, int)? target;

  /// Casilla donde se colocaría la siguiente ficha pendiente.
  final (Cell, int)? hoverPlace;
  final Cell? lineFrom;
  final Cell? lineTo;
  final String? lineLabel;

  Offset _center(Cell c) => Offset(map.offsetX + (c.$1 + 0.5) * map.cellPx, map.offsetY + (c.$2 + 0.5) * map.cellPx);

  Rect _rect(Cell c, int size) => Rect.fromLTWH(
    map.offsetX + c.$1 * map.cellPx,
    map.offsetY + c.$2 * map.cellPx,
    size * map.cellPx,
    size * map.cellPx,
  );

  void _box(Canvas canvas, Rect r, Color color) {
    final rr = RRect.fromRectAndRadius(r.deflate(map.cellPx * 0.04), Radius.circular(map.cellPx * 0.12));
    canvas.drawRRect(rr, Paint()..color = color.withValues(alpha: 0.22));
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(2, map.cellPx / 22)
        ..color = color,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (highlight.isNotEmpty) {
      final fill = Paint()..color = highlightColor.withValues(alpha: 0.16);
      for (final c in highlight) {
        canvas.drawRect(_rect(c, 1), fill);
      }
    }
    final tg = target;
    if (tg != null) _box(canvas, _rect(tg.$1, tg.$2), AppColors.arcane);
    final hp = hoverPlace;
    if (hp != null) _box(canvas, _rect(hp.$1, hp.$2), AppColors.gold);
    final from = lineFrom;
    final to = lineTo;
    if (from != null) {
      final start = _center(from);
      canvas.drawCircle(start, map.cellPx * 0.14, Paint()..color = AppColors.arcane);
      if (to != null) {
        final end = _center(to);
        final paint = Paint()
          ..color = AppColors.arcane
          ..strokeWidth = max(2, map.cellPx / 16)
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(start, end, paint);
        canvas.drawCircle(end, map.cellPx * 0.14, Paint()..color = AppColors.arcane);
        final label = lineLabel;
        if (label != null) {
          final tp = TextPainter(
            text: TextSpan(
              text: label,
              style: TextStyle(color: Colors.white, fontSize: max(13, map.cellPx * 0.3), fontWeight: FontWeight.w700),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final pos = end + Offset(map.cellPx * 0.35, -map.cellPx * 0.6);
          final bg = RRect.fromRectAndRadius(
            Rect.fromLTWH(pos.dx - 8, pos.dy - 4, tp.width + 16, tp.height + 8),
            Radius.circular(map.cellPx * 0.15),
          );
          canvas.drawRRect(bg, Paint()..color = Colors.black.withValues(alpha: 0.78));
          canvas.drawRRect(
            bg,
            Paint()
              ..style = PaintingStyle.stroke
              ..color = AppColors.arcane
              ..strokeWidth = 1.5,
          );
          tp.paint(canvas, pos);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => true;
}

/// Ficha redonda tipo moneda: aro metálico del color de su bando, imagen o
/// icono en relieve, anillo de PG (si quien mira puede verlos), nombre y avisos.
class TokenView extends StatelessWidget {
  const TokenView({super.key, required this.info, this.selected = false, this.showHidden = false, this.lifted = false});
  final TokenInfo info;
  final bool selected;
  final bool showHidden;

  /// Se está arrastrando: sombra más grande.
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final t = info.token;
    return LayoutBuilder(
      builder: (context, c) {
        final side = c.maxWidth;
        final hp = info.hp;
        final hpMax = info.hpMax;
        final ratio = (hp != null && hpMax != null && hpMax > 0) ? (hp / hpMax).clamp(0.0, 1.0) : null;
        final down = hp != null && hp <= 0;
        final base = info.color;
        final inset = side * 0.09;
        final faceSide = side - inset * 2;
        Widget face;
        final icon = Center(
          child: GameIcon(info.icon, size: faceSide * 0.66, color: Colors.white.withValues(alpha: 0.95)),
        );
        final imageId = t.assetId ?? info.character?.portraitAssetId;
        if (imageId != null) {
          face = FutureBuilder<Uint8List?>(
            future: s.asset(imageId),
            builder: (context, snap) => snap.data == null
                ? icon
                : Image.memory(snap.data!, fit: BoxFit.cover, gaplessPlayback: true, filterQuality: FilterQuality.high),
          );
        } else {
          face = icon;
        }
        final glow = selected ? AppColors.arcane : (info.isTurn ? AppColors.glow : null);
        return Opacity(
          opacity: t.hidden && showHidden ? 0.55 : 1,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Sombra y resplandor.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (glow != null)
                        BoxShadow(
                          color: glow.withValues(alpha: 0.85),
                          blurRadius: side * 0.28,
                          spreadRadius: side * 0.02,
                        ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: lifted ? 0.7 : 0.55),
                        blurRadius: side * (lifted ? 0.3 : 0.1),
                        offset: Offset(0, side * (lifted ? 0.12 : 0.04)),
                      ),
                    ],
                  ),
                ),
              ),
              // Aro, fondo y anillo de PG.
              Positioned.fill(
                child: CustomPaint(
                  painter: _TokenRimPainter(color: base, hpRatio: ratio, selected: selected),
                ),
              ),
              Positioned(
                left: inset,
                top: inset,
                width: faceSide,
                height: faceSide,
                child: ClipOval(
                  child: ColorFiltered(
                    colorFilter: down
                        ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                        : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.3, -0.4),
                          radius: 1.0,
                          colors: [
                            Color.lerp(base, Colors.white, 0.15)!,
                            Color.lerp(base, Colors.black, 0.35)!,
                            Color.lerp(base, Colors.black, 0.7)!,
                          ],
                          stops: const [0, 0.6, 1],
                        ),
                      ),
                      child: face,
                    ),
                  ),
                ),
              ),
              if (down)
                Positioned.fill(
                  child: Center(
                    child: GameIcon('crossbones', size: side * 0.5, color: Colors.black.withValues(alpha: 0.75)),
                  ),
                ),
              if (info.labels.isNotEmpty)
                Positioned(
                  right: -side * 0.02,
                  top: -side * 0.02,
                  child: Container(
                    constraints: BoxConstraints(minWidth: side * 0.3, minHeight: side * 0.3),
                    padding: EdgeInsets.all(side * 0.03),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: max(1, side * 0.02)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${info.labels.length}',
                      style: TextStyle(fontSize: max(8, side * 0.17), color: Colors.black, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              if (t.hidden && showHidden)
                Positioned(
                  left: -side * 0.02,
                  top: -side * 0.02,
                  child: Container(
                    padding: EdgeInsets.all(side * 0.04),
                    decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                    child: Icon(Icons.visibility_off, size: max(9, side * 0.18), color: Colors.white),
                  ),
                ),
              Positioned(
                left: -side * 0.6,
                right: -side * 0.6,
                top: side * 0.96,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: side * 0.08, vertical: side * 0.015),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(side * 0.12),
                      border: Border.all(color: base.withValues(alpha: 0.8), width: max(0.8, side * 0.012)),
                    ),
                    child: Text(
                      info.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: max(8, min(side, 140) * 0.17),
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
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

/// Aro metálico (degradado cónico) y, alrededor, el anillo de PG.
class _TokenRimPainter extends CustomPainter {
  _TokenRimPainter({required this.color, required this.hpRatio, required this.selected});
  final Color color;
  final double? hpRatio;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final rimWidth = r * 0.2;
    final rimRect = Rect.fromCircle(center: center, radius: r - rimWidth / 2 - r * 0.02);
    final light = Color.lerp(color, Colors.white, 0.55)!;
    final dark = Color.lerp(color, Colors.black, 0.55)!;
    canvas.drawCircle(
      center,
      r - rimWidth / 2 - r * 0.02,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rimWidth
        ..shader = SweepGradient(
          colors: [light, color, dark, color, light, color, dark, color, light],
          transform: const GradientRotation(-pi / 4),
        ).createShader(rimRect),
    );
    // Filos del aro.
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, r * 0.025)
      ..color = Colors.black.withValues(alpha: 0.6);
    canvas.drawCircle(center, r - r * 0.02, edge);
    canvas.drawCircle(center, r - rimWidth - r * 0.02, edge);
    final ratio = hpRatio;
    if (ratio != null) {
      final arcRect = Rect.fromCircle(center: center, radius: r + r * 0.07);
      final w = max(2.0, r * 0.11);
      canvas.drawArc(
        arcRect,
        -pi / 2,
        2 * pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..color = Colors.black.withValues(alpha: 0.65),
      );
      canvas.drawArc(
        arcRect,
        -pi / 2,
        2 * pi * ratio,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.7
          ..strokeCap = StrokeCap.round
          ..color = AppColors.hpColor(ratio),
      );
    }
  }

  @override
  bool shouldRepaint(_TokenRimPainter old) => old.color != color || old.hpRatio != hpRatio || old.selected != selected;
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
              icon: Icon(Icons.skip_next, color: AppColors.gold),
              onPressed: () => s.send(Command.putEncounter(e.copy()..next())),
            ),
        ],
      ),
    );
  }
}
