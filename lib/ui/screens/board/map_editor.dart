import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/i18n.dart';
import '../../../domain/board.dart';
import '../../../engine/commands.dart';
import '../../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'image_tools.dart';
import 'map_view.dart';

/// Crea un mapa a partir de una imagen elegida por el máster.
Future<void> createMapFromImage(BuildContext context) async {
  final s = SessionScope.read(context);
  final bytes = await pickImageFile();
  if (bytes == null || !context.mounted) return;
  showSnack(context, tr('Preparando el mapa…'));
  final prepared = await prepareMapImage(bytes);
  if (!context.mounted) return;
  if (prepared == null) {
    showSnack(context, tr('No se pudo leer la imagen'), error: true);
    return;
  }
  final id = await s.uploadAsset(prepared.bytes);
  if (id == null || !context.mounted) return;
  // Suposición inicial: unas 25 casillas a lo ancho. Luego se ajusta.
  final cell = (prepared.width / 25).clamp(20, 300).toDouble();
  final map = BoardMap(
    name: tr('Mapa {0}', [s.campaign.board.maps.length + 1]),
    assetId: id,
    imageWidth: prepared.width,
    imageHeight: prepared.height,
    cellPx: cell,
  )..fitGridToImage();
  await openMapEditor(context, map, isNew: true, preview: prepared.bytes);
}

/// Crea un mapa liso con cuadrícula (para combates sin dibujo).
Future<void> createBlankMap(BuildContext context) {
  final s = SessionScope.read(context);
  final map = BoardMap(name: tr('Mapa {0}', [s.campaign.board.maps.length + 1]), cellPx: 100, cols: 30, rows: 20);
  return openMapEditor(context, map, isNew: true);
}

Future<void> openMapEditor(BuildContext context, BoardMap map, {bool isNew = false, Uint8List? preview}) {
  final s = SessionScope.read(context);
  return Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => SessionScope(
        session: s,
        child: _MapEditor(initial: map, isNew: isNew, preview: preview),
      ),
    ),
  );
}

class _MapEditor extends StatefulWidget {
  const _MapEditor({required this.initial, required this.isNew, this.preview});
  final BoardMap initial;
  final bool isNew;
  final Uint8List? preview;

  @override
  State<_MapEditor> createState() => _MapEditorState();
}

class _MapEditorState extends State<_MapEditor> {
  late final BoardMap _m = widget.initial.copy();
  late final _name = TextEditingController(text: _m.name);
  final _tc = TransformationController();
  bool _fitted = false;

  void _changed(VoidCallback f) => setState(() {
    f();
    if (_m.hasImage) {
      _m.offsetX = _m.offsetX.clamp(0, _m.cellPx);
      _m.offsetY = _m.offsetY.clamp(0, _m.cellPx);
      _m.fitGridToImage();
    }
  });

  Future<void> _save() async {
    final s = SessionScope.read(context);
    _m.name = _name.text.trim().isEmpty ? _m.name : _name.text.trim();
    final r = await s.send(Command.putMap(_m));
    if (!mounted) return;
    if (!r.ok) {
      showSnack(context, r.error ?? '', error: true);
      return;
    }
    if (widget.isNew) await s.send(Command.setActiveMap(_m.id));
    if (mounted) Navigator.pop(context);
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    double step = 1,
  }) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        SizedBox(width: 150, child: Text(label, style: t.bodyMedium)),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove),
          onPressed: () => onChanged((value - step).clamp(min, max)),
        ),
        Expanded(
          child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add),
          onPressed: () => onChanged((value + step).clamp(min, max)),
        ),
        SizedBox(width: 56, child: Text(value.toStringAsFixed(step < 1 ? 1 : 0), textAlign: TextAlign.right)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final t = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final preview = LayoutBuilder(
      builder: (context, c) {
        if (!_fitted && _m.width > 0) {
          _fitted = true;
          final scale = (c.maxWidth / _m.width).clamp(0.05, 4.0);
          final scale2 = (c.maxHeight / _m.height).clamp(0.05, 4.0);
          final sc = scale < scale2 ? scale : scale2;
          _tc.value = Matrix4.diagonal3Values(sc, sc, 1);
        }
        return ClipRect(
          child: InteractiveViewer(
            transformationController: _tc,
            constrained: false,
            minScale: 0.05,
            maxScale: 8,
            boundaryMargin: const EdgeInsets.all(200),
            child: SizedBox(
              width: _m.width,
              height: _m.height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _m.hasImage
                        ? FutureBuilder<Uint8List?>(
                            future: widget.preview != null ? Future.value(widget.preview) : s.asset(_m.assetId!),
                            builder: (context, snap) => snap.data == null
                                ? const Center(child: CircularProgressIndicator())
                                : Image.memory(snap.data!, fit: BoxFit.fill, gaplessPlayback: true),
                          )
                        : ColoredBox(color: AppColors.mapFloor),
                  ),
                  Positioned.fill(child: CustomPaint(painter: GridPainter(_m))),
                ],
              ),
            ),
          ),
        );
      },
    );
    final controls = ListView(
      padding: const EdgeInsets.all(12),
      children: [
        TextField(
          controller: _name,
          decoration: InputDecoration(labelText: tr('Nombre del mapa')),
        ),
        Gap.m,
        if (_m.hasImage) ...[
          Text(
            tr(
              'Ajusta la cuadrícula hasta que coincida con las casillas del dibujo. Cada casilla mide 5 pies (1,5 m).',
            ),
            style: t.bodySmall,
          ),
          _slider(tr('Tamaño de casilla (px)'), _m.cellPx, 10, 300, (v) => _changed(() => _m.cellPx = v), step: 0.5),
          _slider(tr('Desplazamiento X'), _m.offsetX, 0, _m.cellPx, (v) => _changed(() => _m.offsetX = v), step: 0.5),
          _slider(tr('Desplazamiento Y'), _m.offsetY, 0, _m.cellPx, (v) => _changed(() => _m.offsetY = v), step: 0.5),
          Text(tr('{0} × {1} casillas', [_m.cols, _m.rows]), style: t.bodySmall),
        ] else ...[
          Row(
            children: [
              Expanded(child: Text(tr('Columnas'))),
              NumberStepper(value: _m.cols, min: 4, max: 120, onChanged: (v) => _changed(() => _m.cols = v)),
            ],
          ),
          Row(
            children: [
              Expanded(child: Text(tr('Filas'))),
              NumberStepper(value: _m.rows, min: 4, max: 120, onChanged: (v) => _changed(() => _m.rows = v)),
            ],
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr('Mostrar cuadrícula')),
          value: _m.showGrid,
          onChanged: (v) => _changed(() => _m.showGrid = v),
        ),
        _slider(
          tr('Intensidad de la cuadrícula'),
          _m.gridOpacity,
          0.05,
          1,
          (v) => _changed(() => _m.gridOpacity = v),
          step: 0.05,
        ),
        Gap.m,
        FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: Text(tr('Guardar mapa'))),
      ],
    );
    return AppScaffold(
      title: widget.isNew ? tr('Nuevo mapa') : tr('Editar mapa'),
      actions: [TextButton(onPressed: _save, child: Text(tr('Guardar')))],
      body: wide
          ? Row(
              children: [
                Expanded(child: preview),
                const VerticalDivider(width: 1),
                SizedBox(width: 420, child: controls),
              ],
            )
          : Column(
              children: [
                Expanded(flex: 5, child: preview),
                const Divider(height: 1),
                Expanded(flex: 6, child: controls),
              ],
            ),
    );
  }
}

/// Fichas de los personajes jugadores que aún no están en el mapa.
List<BoardToken> partyTokens(GameSession s, BoardMap map) {
  final board = s.campaign.board.copy();
  final out = <BoardToken>[];
  for (final c in s.campaign.characters.where((c) => c.ownerId != s.campaign.dmUserId)) {
    if (board.tokens.any((t) => t.mapId == map.id && t.characterId == c.id)) continue;
    final (x, y) = board.freeCell(map, startX: map.cols ~/ 2, startY: map.rows ~/ 2);
    final t = BoardToken(mapId: map.id, kind: TokenKind.pc, characterId: c.id, x: x, y: y);
    board.tokens.add(t);
    out.add(t);
  }
  return out;
}

/// Iconos para marcadores libres del máster.
const markerIcons = [
  'person',
  'hood',
  'wizard_face',
  'chest',
  'open_chest',
  'torch',
  'campfire',
  'key',
  'skull',
  'tower_flag',
  'dungeon_gate',
  'magic_gate',
  'crystal_ball',
  'treasure_map',
  'stone',
  'wolf',
];

/// Pide nombre e icono para un marcador (PNJ, cofre, trampa…).
Future<BoardToken?> askMarker(BuildContext context, BoardMap map) async {
  final name = TextEditingController();
  var icon = markerIcons.first;
  var kind = TokenKind.npc;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(tr('Nuevo marcador')),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: InputDecoration(labelText: tr('Nombre'), hintText: tr('Tabernero, cofre, trampa…')),
              ),
              Gap.s,
              SegmentedButton<TokenKind>(
                segments: [
                  ButtonSegment(value: TokenKind.npc, label: Text(tr('PNJ'))),
                  ButtonSegment(value: TokenKind.monster, label: Text(tr('Enemigo'))),
                  ButtonSegment(value: TokenKind.object, label: Text(tr('Objeto'))),
                ],
                selected: {kind},
                onSelectionChanged: (v) => setState(() => kind = v.first),
              ),
              Gap.s,
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final ic in markerIcons)
                    InkWell(
                      onTap: () => setState(() => icon = ic),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: icon == ic ? AppColors.gold : AppColors.outlineSoft),
                        ),
                        child: GameIcon(ic, size: 24),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancelar'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Añadir'))),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return null;
  final s = SessionScope.read(context);
  final (x, y) = s.campaign.board.freeCell(map, startX: map.cols ~/ 2, startY: map.rows ~/ 2);
  return BoardToken(mapId: map.id, kind: kind, label: name.text.trim(), icon: icon, x: x, y: y);
}
