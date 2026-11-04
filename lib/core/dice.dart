import 'dart:math';
import 'i18n.dart';

/// Tirador de dados con expresiones del tipo "2d6+3", "1d20+5", "4d6kh3"
/// (quedarse con los 3 más altos), "2d20kl1" (desventaja) o "d8+1d4-1".
class DiceRoller {
  DiceRoller([Random? random]) : _random = random ?? Random();
  final Random _random;

  static final RegExp _term = RegExp(r'([+-])?\s*(?:(\d*)d(\d+|%)(?:(kh|kl|k)(\d+))?|(\d+))', caseSensitive: false);

  int die(int sides) => _random.nextInt(sides) + 1;

  /// Lanza una expresión. Lanza [FormatException] si no se entiende.
  DiceResult roll(String expression) {
    final expr = expression.replaceAll(' ', '').toLowerCase();
    if (expr.isEmpty) throw FormatException(tr('Expresión vacía'));
    var pos = 0;
    final parts = <DicePart>[];
    var total = 0;
    while (pos < expr.length) {
      final m = _term.matchAsPrefix(expr, pos);
      if (m == null || m.end == pos) {
        throw FormatException(tr('No entiendo "{0}"', [expr.substring(pos)]));
      }
      if (parts.isNotEmpty && m.group(1) == null) {
        throw FormatException(tr('Falta + o - antes de "{0}"', [m.group(0)]));
      }
      final sign = m.group(1) == '-' ? -1 : 1;
      if (m.group(6) != null) {
        final v = int.parse(m.group(6)!);
        parts.add(DicePart(label: '${sign < 0 ? '−' : ''}$v', rolls: const [], kept: const [], value: sign * v));
        total += sign * v;
      } else {
        final count = m.group(2)!.isEmpty ? 1 : int.parse(m.group(2)!);
        final sides = m.group(3) == '%' ? 100 : int.parse(m.group(3)!);
        if (count < 1 || count > 100) throw FormatException(tr('Entre 1 y 100 dados, por favor'));
        if (sides < 2 || sides > 1000) throw FormatException(tr('Dado no válido'));
        final rolls = [for (var i = 0; i < count; i++) die(sides)];
        var kept = List<int>.from(rolls);
        final keepMode = m.group(4);
        if (keepMode != null) {
          final k = int.parse(m.group(5)!).clamp(1, count);
          final sorted = List<int>.from(rolls)..sort();
          kept = keepMode == 'kl' ? sorted.take(k).toList() : sorted.reversed.take(k).toList();
        }
        final sum = kept.fold<int>(0, (a, b) => a + b);
        parts.add(
          DicePart(
            label: '${sign < 0 ? '−' : ''}${count}d$sides${keepMode != null ? '$keepMode${m.group(5)}' : ''}',
            rolls: rolls,
            kept: kept,
            value: sign * sum,
            sides: sides,
          ),
        );
        total += sign * sum;
      }
      pos = m.end;
    }
    return DiceResult(expression: expression.trim(), parts: parts, total: total);
  }

  /// Tirada de d20 con modificador y ventaja/desventaja.
  DiceResult d20(int modifier, {Advantage advantage = Advantage.normal}) {
    final mod = modifier == 0 ? '' : (modifier > 0 ? '+$modifier' : '$modifier');
    final dice = switch (advantage) {
      Advantage.normal => '1d20',
      Advantage.advantage => '2d20kh1',
      Advantage.disadvantage => '2d20kl1',
    };
    return roll('$dice$mod');
  }
}

enum Advantage { normal, advantage, disadvantage }

class DicePart {
  const DicePart({required this.label, required this.rolls, required this.kept, required this.value, this.sides});
  final String label;
  final List<int> rolls;
  final List<int> kept;
  final int value;
  final int? sides;

  bool get isDice => sides != null;
}

class DiceResult {
  const DiceResult({required this.expression, required this.parts, required this.total});
  final String expression;
  final List<DicePart> parts;
  final int total;

  /// ¿Algún d20 conservado sacó 20 / 1?
  bool get natural20 => parts.any((p) => p.sides == 20 && p.kept.length == 1 && p.kept.first == 20);
  bool get natural1 => parts.any((p) => p.sides == 20 && p.kept.length == 1 && p.kept.first == 1);

  String get breakdown => parts
      .map((p) {
        if (!p.isDice) return p.label;
        final shown = p.rolls.length == p.kept.length
            ? p.rolls.join(', ')
            : '${p.rolls.join(', ')} → ${p.kept.join(', ')}';
        return '${p.label} [$shown]';
      })
      .join(' ');

  @override
  String toString() => '$expression = $total  ($breakdown)';
}

/// Valor medio de una expresión simple ("2d6+3" -> 10). Útil para PG de monstruos.
int averageOf(String expression) {
  final expr = expression.replaceAll(' ', '').toLowerCase();
  var total = 0.0;
  for (final m in RegExp(r'([+-])?(?:(\d*)d(\d+)|(\d+))').allMatches(expr)) {
    final sign = m.group(1) == '-' ? -1 : 1;
    if (m.group(4) != null) {
      total += sign * int.parse(m.group(4)!);
    } else {
      final count = m.group(2)!.isEmpty ? 1 : int.parse(m.group(2)!);
      final sides = int.parse(m.group(3)!);
      total += sign * count * (sides + 1) / 2;
    }
  }
  return max(0, total.floor());
}

String signed(int v) => v >= 0 ? '+$v' : '−${v.abs()}';
