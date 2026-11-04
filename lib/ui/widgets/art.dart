import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/character.dart';
import '../../state/session.dart';

import '../theme.dart';
import 'common.dart';

/// Icono dentro de un medallón con relieve (cabeceras de sección, listas).
class IconMedallion extends StatelessWidget {
  const IconMedallion(this.icon, {super.key, this.size = 32, this.color});
  final String icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.gold;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.35),
          colors: [Color.lerp(AppColors.surfaceHighest, c, 0.28)!, AppColors.surfaceHigh, AppColors.surface],
          stops: const [0, 0.65, 1],
        ),
        border: Border.all(color: c.withValues(alpha: 0.75), width: max(1, size * 0.045)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: size * 0.18,
            offset: Offset(0, size * 0.06),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: GameIcon(icon, size: size * 0.6, color: c),
    );
  }
}

/// Filete decorativo bajo los títulos: una línea dorada que se desvanece con
/// un rombo al principio.
class Flourish extends StatelessWidget {
  const Flourish({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 10,
    width: double.infinity,
    child: CustomPaint(painter: _FlourishPainter(color ?? AppColors.gold)),
  );
}

class _FlourishPainter extends CustomPainter {
  _FlourishPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final line = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.85), color.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(10, y), Offset(size.width, y), line);
    final d = Path()
      ..moveTo(0, y)
      ..lineTo(4, y - 4)
      ..lineTo(8, y)
      ..lineTo(4, y + 4)
      ..close();
    canvas.drawPath(d, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FlourishPainter old) => old.color != color;
}

/// Ilustración de cabecera: un castillo en lo alto de unas montañas bajo un
/// cielo nocturno, dibujada por código con los colores del tema (obra propia).
class HeroBanner extends StatelessWidget {
  const HeroBanner({super.key, required this.height, this.child});
  final double height;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final castle = height * 0.62;
            return Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _SkyPainter(p))),
                // Castillo sobre la cumbre del fondo.
                Positioned(
                  right: w * 0.12,
                  bottom: height * 0.28,
                  child: GameIcon('castle', size: castle, color: Color.lerp(p.background, Colors.black, 0.35)),
                ),
                Positioned.fill(child: CustomPaint(painter: _ForegroundPainter(p))),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [p.background.withValues(alpha: 0.75), p.background.withValues(alpha: 0)],
                        stops: const [0, 0.7],
                      ),
                      border: Border.all(color: p.primary.withValues(alpha: 0.35)),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                if (child != null) Positioned.fill(child: child!),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Cielo, luna, estrellas y montañas lejanas.
class _SkyPainter extends CustomPainter {
  _SkyPainter(this.p);
  final AppPalette p;

  Path _ridge(Size s, double base, double amp, int seed, int peaks) {
    final r = Random(seed);
    final path = Path()..moveTo(0, s.height);
    path.lineTo(0, s.height * base);
    final step = s.width / peaks;
    for (var i = 0; i <= peaks; i++) {
      final x = i * step;
      final y = s.height * (base - amp * (0.4 + 0.6 * r.nextDouble()));
      path.lineTo(x + step * 0.5, y);
      path.lineTo(x + step, s.height * (base - amp * 0.25 * r.nextDouble()));
    }
    path
      ..lineTo(s.width, s.height)
      ..close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final skyTop = p.isDark
        ? Color.lerp(p.surfaceLowest, Colors.black, 0.2)!
        : Color.lerp(p.tertiary, Colors.white, 0.55)!;
    final skyBottom = p.isDark
        ? Color.lerp(p.primaryContainer, p.background, 0.35)!
        : Color.lerp(p.primary, Colors.white, 0.7)!;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [skyTop, skyBottom],
        ).createShader(rect),
    );
    // Estrellas.
    final r = Random(7);
    final star = Paint();
    for (var i = 0; i < 90; i++) {
      final o = Offset(r.nextDouble() * size.width, r.nextDouble() * size.height * 0.6);
      star.color = Colors.white.withValues(alpha: (p.isDark ? 0.25 : 0.12) + r.nextDouble() * 0.5);
      canvas.drawCircle(o, 0.5 + r.nextDouble() * 1.1, star);
    }
    // Luna con halo.
    final moon = Offset(size.width * 0.72, size.height * 0.26);
    final mr = size.height * 0.11;
    canvas.drawCircle(
      moon,
      mr * 3,
      Paint()
        ..shader = RadialGradient(
          colors: [p.glow.withValues(alpha: 0.35), p.glow.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: moon, radius: mr * 3)),
    );
    canvas.drawCircle(moon, mr, Paint()..color = Color.lerp(p.text, p.glow, 0.25)!);
    canvas.drawCircle(moon + Offset(mr * 0.35, -mr * 0.15), mr * 0.85, Paint()..color = skyTop.withValues(alpha: 0.55));
    // Montañas lejanas (dos capas).
    canvas.drawPath(_ridge(size, 0.78, 0.38, 3, 6), Paint()..color = Color.lerp(skyBottom, p.background, 0.55)!);
    canvas.drawPath(_ridge(size, 0.86, 0.3, 11, 9), Paint()..color = Color.lerp(skyBottom, p.background, 0.8)!);
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.p != p;
}

/// Colina en primer plano y bruma.
class _ForegroundPainter extends CustomPainter {
  _ForegroundPainter(this.p);
  final AppPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final hill = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.84)
      ..quadraticBezierTo(size.width * 0.35, size.height * 0.7, size.width * 0.62, size.height * 0.78)
      ..quadraticBezierTo(size.width * 0.82, size.height * 0.66, size.width, size.height * 0.74)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(hill, Paint()..color = Color.lerp(p.background, Colors.black, 0.25)!);
    final mist = Rect.fromLTWH(0, size.height * 0.6, size.width, size.height * 0.4);
    canvas.drawRect(
      mist,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.background.withValues(alpha: 0), p.background.withValues(alpha: 0.65)],
        ).createShader(mist),
    );
  }

  @override
  bool shouldRepaint(_ForegroundPainter old) => old.p != p;
}

/// Retrato de un personaje: su imagen si la tiene, si no su icono, dentro de
/// un marco redondo.
class CharacterPortrait extends StatelessWidget {
  const CharacterPortrait({super.key, required this.character, this.size = 48, this.borderColor});
  final Character character;
  final double size;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final asset = character.portraitAssetId;
    final icon = Center(
      child: GameIcon(character.portrait, size: size * 0.6, color: AppColors.gold),
    );
    Widget inner = icon;
    if (asset != null) {
      final s = SessionScope.maybeOf(context);
      if (s != null) {
        inner = FutureBuilder(
          future: s.asset(asset),
          builder: (context, snap) => snap.data == null
              ? icon
              : Image.memory(snap.data!, fit: BoxFit.cover, gaplessPlayback: true, filterQuality: FilterQuality.high),
        );
      }
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [AppColors.surfaceHighest, AppColors.surfaceHigh]),
        border: Border.all(color: borderColor ?? AppColors.goldSoft, width: max(1.5, size * 0.04)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: size * 0.15)],
      ),
      child: ClipOval(child: inner),
    );
  }
}
