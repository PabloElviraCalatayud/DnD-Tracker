import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/i18n.dart';
import '../../../domain/roll.dart';
import '../../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/dice_animation.dart';
import '../shared/dice_roller.dart';

String _hhmm(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Fila de dados para tirar rápido desde el tablero.
class QuickDiceBar extends StatelessWidget {
  const QuickDiceBar({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          for (final d in [4, 6, 8, 10, 12, 20, 100])
            Tooltip(
              message: tr('Tirar 1d{0}', [d]),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => rollDice(context, '', '1d$d'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Column(
                    children: [
                      DieIcon(sides: d, value: d, size: 30),
                      Text('d$d', style: t.labelSmall),
                    ],
                  ),
                ),
              ),
            ),
          Gap.s,
          IconButton(
            tooltip: tr('Más opciones'),
            icon: const GameIcon('dice', size: 24),
            onPressed: () => showDiceRoller(context),
          ),
        ],
      ),
    );
  }
}

/// Registro de tiradas de la partida, la más reciente arriba.
class RollFeed extends StatelessWidget {
  const RollFeed({super.key, this.shrinkWrap = false, this.limit});
  final bool shrinkWrap;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final rolls = s.rolls.reversed.take(limit ?? 200).toList();
    if (rolls.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GameIcon('d20', size: 48, color: AppColors.goldSoft),
            Gap.s,
            Text(
              s.isDm
                  ? tr('Aquí verás todas las tiradas de los jugadores. Las tuyas son secretas.')
                  : tr('Aquí aparecen las tiradas de todo el grupo.'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
    final newestId = rolls.first.id;
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.all(8),
      itemCount: rolls.length,
      itemBuilder: (context, i) => RollCard(
        key: ValueKey(rolls[i].id),
        roll: rolls[i],
        mine: rolls[i].userId == s.myUserId,
        animate: rolls[i].id == newestId,
      ),
    );
  }
}

class RollCard extends StatefulWidget {
  const RollCard({super.key, required this.roll, this.mine = false, this.animate = false});
  final RollEntry roll;
  final bool mine;
  final bool animate;

  @override
  State<RollCard> createState() => _RollCardState();
}

class _RollCardState extends State<RollCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  final _random = Random();

  @override
  void initState() {
    super.initState();
    final fresh = DateTime.now().millisecondsSinceEpoch - widget.roll.ts < 4000;
    if (widget.animate && fresh) {
      _c.forward();
    } else {
      _c.value = 1;
    }
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
    final color = r.natural20 ? AppColors.success : (r.natural1 ? AppColors.danger : AppColors.gold);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final p = Curves.easeOut.transform(_c.value);
        final settled = _c.value >= 1;
        return Opacity(
          opacity: 0.3 + 0.7 * p,
          child: Transform.translate(
            offset: Offset(0, (1 - p) * -12),
            child: Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: r.hidden ? AppColors.surfaceHigh.withValues(alpha: 0.9) : null,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GameIcon(r.portrait.isNotEmpty ? r.portrait : 'person', size: 30),
                    Gap.s,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  r.who,
                                  style: t.titleSmall?.copyWith(color: AppColors.gold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (r.hidden)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Pill(tr('secreta'), color: AppColors.muted, icon: Icons.visibility_off),
                                ),
                              const Spacer(),
                              Text(_hhmm(r.ts), style: t.labelSmall?.copyWith(color: AppColors.muted)),
                            ],
                          ),
                          Text(
                            r.label.isEmpty ? r.expression : '${r.label} · ${r.expression}',
                            style: t.bodySmall?.copyWith(color: AppColors.parchment),
                          ),
                          Gap.xs,
                          Wrap(
                            spacing: 2,
                            runSpacing: 2,
                            children: [
                              for (final d in r.dice.take(10))
                                Transform.rotate(
                                  angle: (1 - p) * 6,
                                  child: DieIcon(
                                    sides: d.sides,
                                    value: settled ? d.value : 1 + _random.nextInt(d.sides),
                                    kept: d.kept,
                                    size: 26,
                                  ),
                                ),
                              if (r.dice.length > 10) Text('+${r.dice.length - 10}', style: t.labelSmall),
                              if (r.modifier != 0)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, top: 4),
                                  child: Text(
                                    r.modifier > 0 ? '+${r.modifier}' : '−${r.modifier.abs()}',
                                    style: t.labelLarge,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Gap.s,
                    Column(
                      children: [
                        Text(
                          settled ? '${r.total}' : '…',
                          style: t.headlineMedium?.copyWith(color: color, fontSize: 30),
                        ),
                        if (settled && r.natural20) Text(tr('¡Crítico!'), style: t.labelSmall?.copyWith(color: color)),
                        if (settled && r.natural1) Text(tr('Pifia'), style: t.labelSmall?.copyWith(color: color)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
