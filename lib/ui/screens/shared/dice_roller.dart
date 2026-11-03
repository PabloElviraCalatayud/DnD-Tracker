import 'package:flutter/material.dart';

import '../../../core/dice.dart';
import '../../../domain/chat.dart';
import '../../../engine/commands.dart';
import '../../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

final DiceRoller _roller = DiceRoller();

GameSession? _sessionOf(BuildContext context) => context.getInheritedWidgetOfExactType<SessionScope>()?.notifier;

Future<void> _share(BuildContext context, String label, DiceResult r) async {
  final s = _sessionOf(context);
  if (s == null) return;
  final text =
      '🎲 ${label.isEmpty ? r.expression : label}: **${r.total}**  (${r.breakdown})'
      '${r.natural20 ? ' · ¡20 natural!' : ''}${r.natural1 ? ' · 1 natural' : ''}';
  final res = await s.send(Command.sendChat(ChatChannel.generalId, text, kind: 'roll'));
  if (context.mounted) {
    showSnack(context, res.ok ? 'Tirada compartida en la taberna' : res.error ?? 'Error', error: !res.ok);
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});
  final DiceResult result;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = result.natural20 ? AppColors.success : (result.natural1 ? AppColors.danger : AppColors.gold);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${result.total}', style: t.displaySmall?.copyWith(fontSize: 56, color: color)),
        if (result.natural20) Text('¡20 natural!', style: t.titleMedium?.copyWith(color: AppColors.success)),
        if (result.natural1) Text('1 natural…', style: t.titleMedium?.copyWith(color: AppColors.danger)),
        Gap.xs,
        Text(result.breakdown, style: t.bodySmall, textAlign: TextAlign.center),
      ],
    );
  }
}

/// Tirada de d20 (característica, salvación, habilidad, ataque) con
/// ventaja/desventaja.
Future<void> showD20Roll(BuildContext context, String label, int modifier) async {
  var adv = Advantage.normal;
  var result = _roller.d20(modifier);
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ResultView(result: result),
            Gap.m,
            SegmentedButton<Advantage>(
              segments: const [
                ButtonSegment(value: Advantage.disadvantage, label: Text('Desv.')),
                ButtonSegment(value: Advantage.normal, label: Text('Normal')),
                ButtonSegment(value: Advantage.advantage, label: Text('Ventaja')),
              ],
              selected: {adv},
              onSelectionChanged: (v) => setState(() {
                adv = v.first;
                result = _roller.d20(modifier, advantage: adv);
              }),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => _share(ctx, label, result), child: const Text('Compartir')),
          TextButton(
            onPressed: () => setState(() => result = _roller.d20(modifier, advantage: adv)),
            child: const Text('Repetir'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    ),
  );
}

/// Tirada de una expresión cualquiera ("2d6+3").
Future<void> showExpressionRoll(BuildContext context, String label, String expression) async {
  DiceResult result;
  try {
    result = _roller.roll(expression);
  } on FormatException catch (e) {
    showSnack(context, 'No entiendo "$expression": ${e.message}', error: true);
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(label),
        content: _ResultView(result: result),
        actions: [
          TextButton(onPressed: () => _share(ctx, label, result), child: const Text('Compartir')),
          TextButton(onPressed: () => setState(() => result = _roller.roll(expression)), child: const Text('Repetir')),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    ),
  );
}

/// Bandeja de dados libre.
Future<void> showDiceRoller(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (ctx) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
    child: _DiceTray(shareContext: context),
  ),
);

class _DiceTray extends StatefulWidget {
  const _DiceTray({required this.shareContext});
  final BuildContext shareContext;

  @override
  State<_DiceTray> createState() => _DiceTrayState();
}

class _DiceTrayState extends State<_DiceTray> {
  final _expr = TextEditingController(text: '1d20');
  final List<DiceResult> _history = [];
  String? _error;

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
  }

  void _roll() {
    try {
      final r = _roller.roll(_expr.text);
      setState(() {
        _error = null;
        _history.insert(0, r);
        if (_history.length > 20) _history.removeLast();
      });
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
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
                Text('Bandeja de dados', style: t.titleLarge),
              ],
            ),
            Gap.m,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in [4, 6, 8, 10, 12, 20, 100])
                  ActionChip(label: Text('d$d'), onPressed: () => setState(() => _add(d))),
                ActionChip(label: const Text('Ventaja'), onPressed: () => setState(() => _expr.text = '2d20kh1')),
                ActionChip(label: const Text('Desventaja'), onPressed: () => setState(() => _expr.text = '2d20kl1')),
                ActionChip(label: const Text('4d6 (−menor)'), onPressed: () => setState(() => _expr.text = '4d6kh3')),
                ActionChip(label: const Text('Borrar'), onPressed: () => setState(() => _expr.clear())),
              ],
            ),
            Gap.m,
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _expr,
                    decoration: InputDecoration(labelText: 'Expresión', hintText: '2d6+3', errorText: _error),
                    onSubmitted: (_) => _roll(),
                  ),
                ),
                Gap.s,
                FilledButton(onPressed: _roll, child: const Text('Tirar')),
              ],
            ),
            if (_history.isNotEmpty) ...[
              Gap.m,
              _ResultView(result: _history.first),
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: () => _share(widget.shareContext, '', _history.first),
                  icon: const Icon(Icons.share),
                  label: const Text('Compartir en la taberna'),
                ),
              ),
              const Divider(),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final r in _history.skip(1))
                      Text('${r.expression} = ${r.total}   (${r.breakdown})', style: t.bodySmall),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
