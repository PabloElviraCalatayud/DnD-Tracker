import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/i18n.dart';
import '../../domain/roll.dart';
import '../theme.dart';

/// Dibuja la silueta de un dado (según sus caras) con un número dentro.
class DieShapePainter extends CustomPainter {
  DieShapePainter({
    required this.sides,
    required this.value,
    required this.fill,
    required this.edge,
    Color? textColor,
    this.dimmed = false,
  }) : textColor = textColor ?? const Color(0xFF16110A);

  final int sides;
  final int value;
  final Color fill;
  final Color edge;
  final Color textColor;
  final bool dimmed;

  Path _polygon(Size s, int n, {double rotation = -pi / 2, double scale = 0.48}) {
    final c = s.center(Offset.zero);
    final r = s.shortestSide * scale;
    final path = Path();
    for (var i = 0; i < n; i++) {
      final a = rotation + 2 * pi * i / n;
      final p = c + Offset(cos(a) * r, sin(a) * r);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  Path shape(Size s) {
    switch (sides) {
      case 4:
        return _polygon(s, 3, scale: 0.55);
      case 6:
        return Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: s.center(Offset.zero), width: s.width * 0.82, height: s.height * 0.82),
            Radius.circular(s.width * 0.14),
          ),
        );
      case 8:
        return _polygon(s, 4, scale: 0.52);
      case 10:
      case 100:
        // Cometa: rombo alargado.
        final c = s.center(Offset.zero);
        final w = s.width * 0.42;
        final h = s.height * 0.5;
        return Path()
          ..moveTo(c.dx, c.dy - h)
          ..lineTo(c.dx + w, c.dy - h * 0.1)
          ..lineTo(c.dx, c.dy + h)
          ..lineTo(c.dx - w, c.dy - h * 0.1)
          ..close();
      case 12:
        return _polygon(s, 5, scale: 0.5);
      default:
        return _polygon(s, 6, rotation: -pi / 2, scale: 0.5);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = shape(size);
    canvas.drawShadow(path, Colors.black, 4, false);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [Color.lerp(fill, Colors.white, 0.25)!, fill, Color.lerp(fill, Colors.black, 0.25)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.04
        ..color = edge,
    );
    // Aristas interiores sugeridas para dar volumen al d20.
    if (sides == 20) {
      final inner = _polygon(size, 3, rotation: -pi / 2, scale: 0.3);
      canvas.drawPath(
        inner,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.shortestSide * 0.02
          ..color = edge.withValues(alpha: 0.6),
      );
    }
    final label = sides == 100
        ? value == 100
              ? '00'
              : value.toString().padLeft(2, '0')
        : '$value';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'Cinzel',
          fontVariations: const [FontVariation('wght', 800)],
          fontSize: size.shortestSide * (label.length > 2 ? 0.26 : 0.34),
          color: textColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      size.center(Offset.zero) - Offset(tp.width / 2, tp.height / 2 - (sides == 4 ? size.height * 0.08 : 0)),
    );
    if (dimmed) {
      canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.45));
    }
  }

  @override
  bool shouldRepaint(DieShapePainter old) =>
      old.value != value || old.sides != sides || old.fill != fill || old.dimmed != dimmed;
}

/// Un dado estático (se usa en el registro de tiradas).
class DieIcon extends StatelessWidget {
  const DieIcon({super.key, required this.sides, required this.value, this.size = 34, this.kept = true, this.color});
  final int sides;
  final int value;
  final double size;
  final bool kept;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? _dieColor(sides, value);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: DieShapePainter(sides: sides, value: value, fill: fill, edge: Colors.black54, dimmed: !kept),
      ),
    );
  }
}

Color _dieColor(int sides, int value) {
  if (sides == 20 && value == 20) return AppColors.success;
  if (sides == 20 && value == 1) return AppColors.crimson;
  return AppColors.gold;
}

/// Animación de dados rodando sobre la mesa, al estilo de los dados de
/// Google: entran girando, rebotan, cambian de número y se paran en el
/// resultado. Después aparece el total.
class DiceRollAnimation extends StatefulWidget {
  const DiceRollAnimation({super.key, required this.roll, this.onDone});
  final RollEntry roll;
  final VoidCallback? onDone;

  @override
  State<DiceRollAnimation> createState() => _DiceRollAnimationState();
}

class _DiceRollAnimationState extends State<DiceRollAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
    ..forward().whenComplete(() => widget.onDone?.call());
  final _random = Random();
  late final List<_DieMotion> _motions;

  @override
  void initState() {
    super.initState();
    final dice = widget.roll.dice.take(12).toList();
    _motions = [
      for (var i = 0; i < dice.length; i++)
        _DieMotion(
          die: dice[i],
          startAngle: _random.nextDouble() * 2 * pi,
          turns: 2 + _random.nextDouble() * 2,
          from: Offset(-0.7 - _random.nextDouble() * 0.4, 0.5 + _random.nextDouble() * 0.4),
          delay: i * 0.05,
          bounce: 0.25 + _random.nextDouble() * 0.15,
        ),
    ];
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.roll;
    final t = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final dieSize = (min(w, h) / 5.5).clamp(48.0, 96.0);
        // Posiciones finales repartidas en filas centradas.
        final perRow = max(1, min(_motions.length, ((w * 0.9) / (dieSize * 1.2)).floor()));
        final rows = (_motions.length / perRow).ceil();
        return AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final children = <Widget>[];
            for (var i = 0; i < _motions.length; i++) {
              final m = _motions[i];
              final row = i ~/ perRow;
              final inRow = min(perRow, _motions.length - row * perRow);
              final col = i % perRow;
              final target = Offset(
                w / 2 + (col - (inRow - 1) / 2) * dieSize * 1.2,
                h * 0.42 + (row - (rows - 1) / 2) * dieSize * 1.2,
              );
              final raw = ((_c.value - m.delay) / (0.8 - m.delay)).clamp(0.0, 1.0);
              final p = Curves.easeOutCubic.transform(raw);
              final start = Offset(target.dx + m.from.dx * w, target.dy + m.from.dy * h * 0.6);
              // Pequeños botes al llegar.
              final hop = sin(raw * pi * 3) * (1 - raw) * dieSize * m.bounce * 2;
              final pos = Offset.lerp(start, target, p)! - Offset(0, hop.abs());
              final angle = m.startAngle * (1 - p) + (1 - p) * m.turns * 2 * pi;
              final settled = raw >= 1;
              final shown = settled ? m.die.value : 1 + _random.nextInt(m.die.sides);
              children.add(
                Positioned(
                  left: pos.dx - dieSize / 2,
                  top: pos.dy - dieSize / 2,
                  child: Transform.rotate(
                    angle: angle,
                    child: Transform.scale(
                      scale: 0.85 + 0.15 * p,
                      child: SizedBox(
                        width: dieSize,
                        height: dieSize,
                        child: CustomPaint(
                          painter: DieShapePainter(
                            sides: m.die.sides,
                            value: shown,
                            fill: settled ? _dieColor(m.die.sides, m.die.value) : AppColors.gold,
                            edge: Colors.black54,
                            dimmed: settled && !m.die.kept,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            final totalOpacity = ((_c.value - 0.78) / 0.15).clamp(0.0, 1.0);
            final color = r.natural20 ? AppColors.success : (r.natural1 ? AppColors.danger : AppColors.gold);
            children.add(
              Positioned(
                left: 0,
                right: 0,
                top: h * 0.42 + rows * dieSize * 0.6 + 16,
                child: Opacity(
                  opacity: totalOpacity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${r.total}',
                        style: t.displaySmall?.copyWith(
                          fontSize: 64,
                          color: color,
                          shadows: const [Shadow(blurRadius: 12, color: Colors.black)],
                        ),
                      ),
                      if (r.natural20)
                        Text(tr('¡20 natural!'), style: t.titleLarge?.copyWith(color: AppColors.success)),
                      if (r.natural1) Text(tr('1 natural…'), style: t.titleLarge?.copyWith(color: AppColors.danger)),
                      Text(
                        r.label.isEmpty ? r.expression : '${r.label} · ${r.expression}',
                        style: t.titleMedium?.copyWith(color: AppColors.parchment),
                        textAlign: TextAlign.center,
                      ),
                      if (r.modifier != 0)
                        Text(
                          r.breakdown,
                          style: t.bodySmall?.copyWith(color: AppColors.muted),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
              ),
            );
            return Stack(children: children);
          },
        );
      },
    );
  }
}

class _DieMotion {
  _DieMotion({
    required this.die,
    required this.startAngle,
    required this.turns,
    required this.from,
    required this.delay,
    required this.bounce,
  });
  final RollDie die;
  final double startAngle;
  final double turns;
  final Offset from;
  final double delay;
  final double bounce;
}

/// Muestra la animación a pantalla completa sobre lo que haya debajo. Se
/// cierra sola al poco de terminar o al tocar.
Future<void> showRollAnimation(BuildContext context, RollEntry roll) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: tr('Cerrar'),
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (ctx, _, _) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(ctx).maybePop(),
      child: DiceRollAnimation(
        roll: roll,
        onDone: () => Future<void>.delayed(const Duration(milliseconds: 1400), () {
          if (ctx.mounted) Navigator.of(ctx).maybePop();
        }),
      ),
    ),
  );
}
