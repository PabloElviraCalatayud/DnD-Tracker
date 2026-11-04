import 'package:flutter/material.dart';

import '../../../core/i18n.dart';
import '../../../domain/roll.dart';
import '../../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/dice_animation.dart';

GameSession? _sessionOf(BuildContext context) => context.getInheritedWidgetOfExactType<SessionScope>()?.notifier;

/// Hace una tirada registrada (la genera el dispositivo del máster), la
/// anima y la deja en el tablero. Los jugadores ven las tiradas de todos;
/// las del máster sólo las ve él.
Future<RollEntry?> rollDice(BuildContext context, String label, String expression, {String? characterId}) async {
  final s = _sessionOf(context);
  if (s == null) return null;
  final charId = characterId ?? (s.isDm ? null : s.activeCharacter?.id);
  final (roll, error) = await s.roll(label, expression, characterId: charId);
  if (!context.mounted) return roll;
  if (roll == null) {
    showSnack(
      context,
      s.isDm || s.status == ConnectionStatus.online
          ? (error ?? tr('No se pudo tirar'))
          : tr('Necesitas conexión con el máster para tirar: así todos ven el resultado.'),
      error: true,
    );
    return null;
  }
  await showRollAnimation(context, roll);
  return roll;
}

String _withModifier(String dice, int modifier) =>
    modifier == 0 ? dice : (modifier > 0 ? '$dice+$modifier' : '$dice$modifier');

/// Tirada de d20 (característica, salvación, habilidad, ataque): se elige
/// normal, ventaja o desventaja y se tira.
Future<void> showD20Roll(BuildContext context, String label, int modifier, {String? characterId}) async {
  final t = Theme.of(context).textTheme;
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: t.titleLarge, textAlign: TextAlign.center),
            Text(
              'd20 ${modifier >= 0 ? '+' : '−'} ${modifier.abs()}',
              style: t.bodyMedium?.copyWith(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            Gap.m,
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => Navigator.pop(ctx, '2d20kl1'), child: Text(tr('Desventaja'))),
                ),
                Gap.s,
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx, '1d20'),
                    icon: const GameIcon('d20', size: 20, color: AppColors.background),
                    label: Text(tr('Tirar')),
                  ),
                ),
                Gap.s,
                Expanded(
                  child: OutlinedButton(onPressed: () => Navigator.pop(ctx, '2d20kh1'), child: Text(tr('Ventaja'))),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  final suffix = switch (choice) {
    '2d20kh1' => ' (${tr('ventaja')})',
    '2d20kl1' => ' (${tr('desventaja')})',
    _ => '',
  };
  await rollDice(context, '$label$suffix', _withModifier(choice, modifier), characterId: characterId);
}

/// Tirada de una expresión cualquiera ("2d6+3").
Future<void> showExpressionRoll(BuildContext context, String label, String expression, {String? characterId}) =>
    rollDice(context, label, expression, characterId: characterId);

/// Bandeja de dados libre.
Future<void> showDiceRoller(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (ctx) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
    child: DiceTray(rollContext: context, onRolled: () => Navigator.of(ctx).pop()),
  ),
);

/// Selector de dados: un toque tira ese dado; también se puede componer una
/// expresión.
class DiceTray extends StatefulWidget {
  const DiceTray({super.key, required this.rollContext, this.onRolled});

  /// Contexto desde el que se lanza la animación (debe tener la sesión).
  final BuildContext rollContext;
  final VoidCallback? onRolled;

  @override
  State<DiceTray> createState() => _DiceTrayState();
}

class _DiceTrayState extends State<DiceTray> {
  final _expr = TextEditingController();
  final _label = TextEditingController();

  void _add(int sides) {
    final text = _expr.text.trim();
    final m = RegExp(
      r'^(\d*)d'
      '$sides'
      r'$',
    ).firstMatch(text);
    if (m != null) {
      final n = m.group(1)!.isEmpty ? 1 : int.parse(m.group(1)!);
      _expr.text = '${n + 1}d$sides';
    } else if (text.isEmpty) {
      _expr.text = '1d$sides';
    } else {
      _expr.text = '$text+1d$sides';
    }
    setState(() {});
  }

  Future<void> _roll([String? quick]) async {
    final expr = (quick ?? _expr.text).trim();
    if (expr.isEmpty) return;
    final label = _label.text.trim();
    widget.onRolled?.call();
    await rollDice(widget.rollContext, label, expr);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = _sessionOf(widget.rollContext);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const GameIcon('dice', size: 28),
                Gap.s,
                Expanded(child: Text(tr('Bandeja de dados'), style: t.titleLarge)),
              ],
            ),
            Text(
              s?.isDm ?? false
                  ? tr('Tus tiradas de máster son secretas: los jugadores no las ven.')
                  : tr('Todos los jugadores verán la tirada en el tablero.'),
              style: t.bodySmall,
            ),
            Gap.m,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in [4, 6, 8, 10, 12, 20, 100])
                  Tooltip(
                    message: tr('Toca para tirar 1d{0}', [d]),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _roll('1d$d'),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          children: [
                            DieIcon(sides: d, value: d, size: 40),
                            Text('d$d', style: t.labelMedium),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Gap.m,
            Text(tr('O compón una tirada:'), style: t.bodySmall),
            Gap.s,
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final d in [4, 6, 8, 10, 12, 20]) ActionChip(label: Text('+d$d'), onPressed: () => _add(d)),
                ActionChip(label: Text(tr('Ventaja')), onPressed: () => setState(() => _expr.text = '2d20kh1')),
                ActionChip(label: Text(tr('Desventaja')), onPressed: () => setState(() => _expr.text = '2d20kl1')),
                ActionChip(label: Text(tr('Borrar')), onPressed: () => setState(_expr.clear)),
              ],
            ),
            Gap.m,
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _expr,
                    decoration: InputDecoration(labelText: tr('Expresión'), hintText: '2d6+3'),
                    onSubmitted: (_) => _roll(),
                  ),
                ),
                Gap.s,
                Expanded(
                  child: TextField(
                    controller: _label,
                    decoration: InputDecoration(labelText: tr('Para qué (opcional)'), hintText: tr('Daño, sigilo…')),
                    onSubmitted: (_) => _roll(),
                  ),
                ),
                Gap.s,
                FilledButton(onPressed: _roll, child: Text(tr('Tirar'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
