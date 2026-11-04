import '../core/dice.dart';
import '../core/ids.dart';
import '../core/json.dart';

/// Un dado de una tirada registrada (para pintarlo en la animación).
class RollDie {
  const RollDie({required this.sides, required this.value, this.kept = true, this.negative = false});

  final int sides;
  final int value;

  /// false si se descartó (ventaja/desventaja, 4d6 quitando el menor…).
  final bool kept;
  final bool negative;

  Map<String, dynamic> toJson() => {'s': sides, 'v': value, if (!kept) 'k': false, if (negative) 'n': true};

  factory RollDie.fromJson(Map<String, dynamic> j) =>
      RollDie(sides: asInt(j['s'], 20), value: asInt(j['v'], 1), kept: asBool(j['k'], true), negative: asBool(j['n']));
}

/// Tirada hecha en la app. La genera el dispositivo del máster (anfitrión)
/// para que nadie pueda inventarse el resultado, y queda en el tablero.
class RollEntry {
  RollEntry({
    String? id,
    required this.userId,
    required this.authorName,
    this.characterId,
    this.characterName = '',
    this.portrait = '',
    required this.label,
    required this.expression,
    required this.total,
    List<RollDie>? dice,
    this.modifier = 0,
    this.breakdown = '',
    this.hidden = false,
    int? ts,
  }) : id = id ?? newId(),
       dice = dice ?? const [],
       ts = ts ?? DateTime.now().millisecondsSinceEpoch;

  final String id;
  final String userId;
  final String authorName;
  final String? characterId;
  final String characterName;
  final String portrait;
  final String label;
  final String expression;
  final int total;
  final List<RollDie> dice;
  final int modifier;
  final String breakdown;

  /// Tiradas del máster: los jugadores no las ven.
  final bool hidden;
  final int ts;

  String get who => characterName.isNotEmpty ? characterName : authorName;

  /// 20 natural en una tirada de un único d20 conservado.
  bool get natural20 {
    final kept = dice.where((d) => d.sides == 20 && d.kept).toList();
    return kept.length == 1 && kept.first.value == 20;
  }

  bool get natural1 {
    final kept = dice.where((d) => d.sides == 20 && d.kept).toList();
    return kept.length == 1 && kept.first.value == 1;
  }

  static RollEntry fromResult(
    DiceResult r, {
    required String userId,
    required String authorName,
    String? characterId,
    String characterName = '',
    String portrait = '',
    required String label,
    bool hidden = false,
  }) {
    final dice = <RollDie>[];
    var modifier = 0;
    for (final p in r.parts) {
      if (!p.isDice) {
        modifier += p.value;
        continue;
      }
      final keptLeft = List<int>.from(p.kept);
      for (final v in p.rolls) {
        final kept = keptLeft.remove(v);
        dice.add(RollDie(sides: p.sides!, value: v, kept: kept, negative: p.value < 0));
      }
    }
    return RollEntry(
      userId: userId,
      authorName: authorName,
      characterId: characterId,
      characterName: characterName,
      portrait: portrait,
      label: label,
      expression: r.expression,
      total: r.total,
      dice: dice,
      modifier: modifier,
      breakdown: r.breakdown,
      hidden: hidden,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'author': authorName,
    'characterId': ?characterId,
    if (characterName.isNotEmpty) 'character': characterName,
    if (portrait.isNotEmpty) 'portrait': portrait,
    'label': label,
    'expr': expression,
    'total': total,
    'dice': dice.map((d) => d.toJson()).toList(),
    if (modifier != 0) 'mod': modifier,
    if (breakdown.isNotEmpty) 'breakdown': breakdown,
    if (hidden) 'hidden': true,
    'ts': ts,
  };

  factory RollEntry.fromJson(Map<String, dynamic> j) => RollEntry(
    id: asString(j['id'], newId()),
    userId: asString(j['userId']),
    authorName: asString(j['author']),
    characterId: asStringOrNull(j['characterId']),
    characterName: asString(j['character']),
    portrait: asString(j['portrait']),
    label: asString(j['label']),
    expression: asString(j['expr']),
    total: asInt(j['total']),
    dice: asList(j['dice'], RollDie.fromJson),
    modifier: asInt(j['mod']),
    breakdown: asString(j['breakdown']),
    hidden: asBool(j['hidden']),
    ts: asIntOrNull(j['ts']),
  );
}
