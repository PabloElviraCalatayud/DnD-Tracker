import 'dart:math';

import '../core/ids.dart';
import '../core/json.dart';

/// Mapa del tablero: una imagen (o un fondo liso) con su cuadrícula.
class BoardMap {
  BoardMap({
    String? id,
    required this.name,
    this.assetId,
    this.imageWidth = 0,
    this.imageHeight = 0,
    this.cellPx = 70,
    this.offsetX = 0,
    this.offsetY = 0,
    this.cols = 20,
    this.rows = 14,
    this.showGrid = true,
    this.gridOpacity = 0.35,
  }) : id = id ?? newId();

  String id;
  String name;

  /// Imagen del mapa (id del recurso). Null = mapa en blanco.
  String? assetId;
  int imageWidth;
  int imageHeight;

  /// Tamaño de una casilla en píxeles de la imagen.
  double cellPx;

  /// Desplazamiento de la cuadrícula para alinearla con la del dibujo.
  double offsetX;
  double offsetY;
  int cols;
  int rows;
  bool showGrid;
  double gridOpacity;

  bool get hasImage => assetId != null && imageWidth > 0 && imageHeight > 0;

  /// Tamaño total del lienzo en píxeles.
  double get width => hasImage ? imageWidth.toDouble() : offsetX + cols * cellPx;
  double get height => hasImage ? imageHeight.toDouble() : offsetY + rows * cellPx;

  /// Recalcula columnas y filas para cubrir la imagen.
  void fitGridToImage() {
    if (!hasImage || cellPx <= 0) return;
    cols = max(1, ((imageWidth - offsetX) / cellPx).floor());
    rows = max(1, ((imageHeight - offsetY) / cellPx).floor());
  }

  BoardMap copy() => BoardMap.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'assetId': ?assetId,
    'imageWidth': imageWidth,
    'imageHeight': imageHeight,
    'cellPx': cellPx,
    'offsetX': offsetX,
    'offsetY': offsetY,
    'cols': cols,
    'rows': rows,
    'showGrid': showGrid,
    'gridOpacity': gridOpacity,
  };

  factory BoardMap.fromJson(Map<String, dynamic> j) => BoardMap(
    id: asString(j['id'], newId()),
    name: asString(j['name'], 'Mapa'),
    assetId: asStringOrNull(j['assetId']),
    imageWidth: asInt(j['imageWidth']),
    imageHeight: asInt(j['imageHeight']),
    cellPx: asDouble(j['cellPx'], 70),
    offsetX: asDouble(j['offsetX']),
    offsetY: asDouble(j['offsetY']),
    cols: asInt(j['cols'], 20),
    rows: asInt(j['rows'], 14),
    showGrid: asBool(j['showGrid'], true),
    gridOpacity: asDouble(j['gridOpacity'], 0.35),
  );
}

/// Distancia en casillas entre dos casillas. Con [alternate] se usa la
/// variante 5/10 de las diagonales (cada segunda diagonal cuenta doble).
int gridDistance(int dx, int dy, {bool alternate = false}) {
  final ax = dx.abs();
  final ay = dy.abs();
  final diagonal = min(ax, ay);
  final straight = max(ax, ay) - diagonal;
  return alternate ? straight + diagonal + diagonal ~/ 2 : straight + diagonal;
}

enum TokenKind { pc, monster, npc, object }

/// Ficha sobre el mapa. Puede representar a un personaje (sus PG y estados
/// salen de la ficha), a un combatiente del rastreador (PG sólo para el
/// máster) o ser un marcador libre.
class BoardToken {
  BoardToken({
    String? id,
    required this.mapId,
    this.kind = TokenKind.monster,
    this.characterId,
    this.combatantId,
    this.monsterId,
    this.label = '',
    this.x = 0,
    this.y = 0,
    this.size = 1,
    this.icon = '',
    this.assetId,
    this.hidden = false,
    List<String>? tags,
  }) : id = id ?? newId(),
       tags = tags ?? <String>[];

  String id;
  String mapId;
  TokenKind kind;
  String? characterId;
  String? combatantId;
  String? monsterId;
  String label;

  /// Casilla (columna, fila) de la esquina superior izquierda.
  int x;
  int y;

  /// Casillas que ocupa por lado (1 mediano, 2 grande, 3 enorme…).
  int size;
  String icon;

  /// Imagen propia de la ficha (PNG subido por el máster o el jugador).
  String? assetId;

  /// Oculta a los jugadores (emboscadas).
  bool hidden;

  /// Etiquetas que pone el máster ("envenenado", "se le ve cansado"…) en
  /// fichas que no están en el rastreador de combate.
  List<String> tags;

  BoardToken copy() => BoardToken.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'id': id,
    'mapId': mapId,
    'kind': kind.name,
    'characterId': ?characterId,
    'combatantId': ?combatantId,
    'monsterId': ?monsterId,
    if (label.isNotEmpty) 'label': label,
    'x': x,
    'y': y,
    if (size != 1) 'size': size,
    if (icon.isNotEmpty) 'icon': icon,
    'assetId': ?assetId,
    if (hidden) 'hidden': true,
    if (tags.isNotEmpty) 'tags': tags,
  };

  factory BoardToken.fromJson(Map<String, dynamic> j) => BoardToken(
    id: asString(j['id'], newId()),
    mapId: asString(j['mapId']),
    kind: enumByName(TokenKind.values, j['kind'], TokenKind.monster),
    characterId: asStringOrNull(j['characterId']),
    combatantId: asStringOrNull(j['combatantId']),
    monsterId: asStringOrNull(j['monsterId']),
    label: asString(j['label']),
    x: asInt(j['x']),
    y: asInt(j['y']),
    size: asInt(j['size'], 1).clamp(1, 6),
    icon: asString(j['icon']),
    assetId: asStringOrNull(j['assetId']),
    hidden: asBool(j['hidden']),
    tags: asStringList(j['tags']),
  );
}

class Board {
  Board({List<BoardMap>? maps, this.activeMapId, List<BoardToken>? tokens})
    : maps = maps ?? <BoardMap>[],
      tokens = tokens ?? <BoardToken>[];

  List<BoardMap> maps;
  String? activeMapId;
  List<BoardToken> tokens;

  BoardMap? get activeMap => maps.where((m) => m.id == activeMapId).firstOrNull ?? maps.firstOrNull;

  BoardMap? map(String id) => maps.where((m) => m.id == id).firstOrNull;
  BoardToken? token(String id) => tokens.where((t) => t.id == id).firstOrNull;

  List<BoardToken> tokensOn(String mapId) => tokens.where((t) => t.mapId == mapId).toList();

  /// Primera casilla libre empezando por (startX, startY), en espiral.
  (int, int) freeCell(BoardMap map, {int startX = 0, int startY = 0}) {
    final occupied = <(int, int)>{
      for (final t in tokensOn(map.id))
        for (var dx = 0; dx < t.size; dx++)
          for (var dy = 0; dy < t.size; dy++) (t.x + dx, t.y + dy),
    };
    for (var r = 0; r < max(map.cols, map.rows); r++) {
      for (var y = startY - r; y <= startY + r; y++) {
        for (var x = startX - r; x <= startX + r; x++) {
          if (x < 0 || y < 0 || x >= map.cols || y >= map.rows) continue;
          if (!occupied.contains((x, y))) return (x, y);
        }
      }
    }
    return (startX.clamp(0, map.cols - 1), startY.clamp(0, map.rows - 1));
  }

  Board copy() => Board.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'maps': maps.map((m) => m.toJson()).toList(),
    'activeMapId': ?activeMapId,
    'tokens': tokens.map((t) => t.toJson()).toList(),
  };

  factory Board.fromJson(Map<String, dynamic> j) => Board(
    maps: asList(j['maps'], BoardMap.fromJson),
    activeMapId: asStringOrNull(j['activeMapId']),
    tokens: asList(j['tokens'], BoardToken.fromJson),
  );
}
