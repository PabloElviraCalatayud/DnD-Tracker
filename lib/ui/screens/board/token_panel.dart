import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n.dart';
import '../../../domain/board.dart';
import '../../../domain/campaign.dart';
import '../../../domain/profile.dart';
import '../../../domain/ruleset.dart';
import '../../../engine/commands.dart';
import '../../../state/providers.dart';
import '../../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../character/character_views.dart';
import 'image_tools.dart';
import 'map_view.dart';

/// Etiquetas rápidas para describir a un enemigo sin dar sus PG.
List<String> get presetTags => [
  tr('Ileso'),
  tr('Rasguños'),
  tr('Herido'),
  tr('Malherido'),
  tr('Se le ve cansado'),
  tr('Debilitado'),
  tr('A punto de caer'),
  tr('Envenenado'),
  tr('Sangrando'),
  tr('Furioso'),
  tr('Asustado'),
  tr('Aturdido'),
  tr('Derribado'),
  tr('Inconsciente'),
];

/// Panel con la información y las acciones de la ficha seleccionada.
class TokenPanel extends ConsumerWidget {
  const TokenPanel({
    super.key,
    required this.info,
    required this.rangeFeet,
    required this.onRange,
    required this.onClose,
  });

  final TokenInfo info;
  final int? rangeFeet;
  final ValueChanged<int?> onRange;
  final VoidCallback onClose;

  Future<void> _askRange(BuildContext context, Units units) async {
    final metric = units.system == UnitSystem.metric;
    final v = await promptNumber(
      context,
      metric ? tr('Alcance en metros') : tr('Alcance en pies'),
      hint: metric ? tr('Ej.: 18 (un conjuro de 60 pies)') : tr('Ej.: 60'),
    );
    if (v == null || v <= 0) return;
    final feet = metric ? (v / 0.3).round() : v;
    onRange(((feet / Rules.gridFeet).round() * Rules.gridFeet).clamp(Rules.gridFeet, 2000));
  }

  Future<void> _hp(BuildContext context, {required bool damage}) async {
    final s = SessionScope.read(context);
    final v = await promptNumber(context, damage ? tr('Daño a {0}', [info.name]) : tr('Curar a {0}', [info.name]));
    if (v == null || !context.mounted) return;
    final ch = info.character;
    if (ch != null) {
      await editCharacter(context, ch.id, (x) => damage ? x.takeDamage(v) : x.heal(v, s.campaign.ruleset));
      return;
    }
    final cb = info.combatant;
    if (cb == null) return;
    final e = s.campaign.encounter.copy();
    final c = e.combatants.firstWhere((x) => x.id == cb.id);
    final max = c.hpMax ?? 99999;
    c.hp = ((c.hp ?? 0) + (damage ? -v : v)).clamp(0, max);
    await s.send(Command.putEncounter(e));
  }

  Future<void> _image(BuildContext context) async {
    final s = SessionScope.read(context);
    final bytes = await pickImageFile();
    if (bytes == null || !context.mounted) return;
    showSnack(context, tr('Preparando la imagen…'));
    final prepared = await prepareTokenImage(bytes);
    if (prepared == null) {
      if (context.mounted) showSnack(context, tr('No se pudo leer la imagen'), error: true);
      return;
    }
    final id = await s.uploadAsset(prepared.bytes);
    if (id == null) {
      if (context.mounted) showSnack(context, tr('No se pudo subir la imagen'), error: true);
      return;
    }
    final r = await s.send(Command.putToken(info.token.copy()..assetId = id));
    if (!r.ok && context.mounted) showSnack(context, r.error ?? '', error: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = SessionScope.of(context);
    final units = ref.watch(unitsProvider);
    final t = Theme.of(context).textTheme;
    final token = info.token;
    final ch = info.character;
    final ownsCharacter = ch != null && (s.isDm || ch.ownerId == s.myUserId);
    final hp = info.hp;
    final hpMax = info.hpMax;
    final ac = ch?.armorClass ?? (s.isDm ? info.combatant?.ac : null);
    return Card(
      color: AppColors.surface.withValues(alpha: 0.96),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                GameIcon(info.icon, size: 28, color: info.color),
                Gap.s,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(info.name, style: t.titleMedium, overflow: TextOverflow.ellipsis),
                      Text(
                        [
                          if (ch != null) ch.classSummary,
                          if (hp != null && hpMax != null) tr('PG {0}/{1}', [hp, hpMax]),
                          if (ac != null) tr('CA {0}', [ac]),
                          if (ch != null) tr('Velocidad {0}', [units.distance(ch.speed)]),
                          if (info.movable) tr('toca una casilla para moverla'),
                        ].join(' · '),
                        style: t.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: onClose),
              ],
            ),
            if (hp != null && hpMax != null && hpMax > 0)
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: HpBar(current: hp, max: hpMax),
              ),
            if (info.labels.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [for (final l in info.labels) Pill(l, color: AppColors.warning)],
                ),
              ),
            Gap.xs,
            Wrap(
              spacing: 4,
              runSpacing: 0,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.radar, size: 18),
                  label: Text(rangeFeet == null ? tr('Alcance') : tr('Alcance {0}', [units.distance(rangeFeet!)])),
                  onPressed: rangeFeet == null ? () => _askRange(context, units) : () => onRange(null),
                ),
                if (ownsCharacter || (s.isDm && info.combatant != null)) ...[
                  TextButton.icon(
                    icon: GameIcon('sword_wound', size: 16, color: AppColors.crimson),
                    label: Text(tr('Daño')),
                    onPressed: () => _hp(context, damage: true),
                  ),
                  TextButton.icon(
                    icon: GameIcon('heart_plus', size: 16, color: AppColors.success),
                    label: Text(tr('Curar')),
                    onPressed: () => _hp(context, damage: false),
                  ),
                ],
                if (s.isDm && ch == null)
                  TextButton.icon(
                    icon: const Icon(Icons.label_outline, size: 18),
                    label: Text(tr('Etiquetas')),
                    onPressed: () => editTags(context, name: info.name, combatant: info.combatant, token: info.token),
                  ),
                if (ownsCharacter || s.isDm)
                  TextButton.icon(
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: Text(tr('Imagen')),
                    onPressed: () => _image(context),
                  ),
                if (s.isDm) ...[
                  TextButton.icon(
                    icon: Icon(token.hidden ? Icons.visibility : Icons.visibility_off, size: 18),
                    label: Text(token.hidden ? tr('Mostrar') : tr('Ocultar')),
                    onPressed: () => s.send(Command.putToken(token.copy()..hidden = !token.hidden)),
                  ),
                  PopupMenuButton<int>(
                    tooltip: tr('Tamaño'),
                    icon: const Icon(Icons.open_in_full, size: 18),
                    onSelected: (v) => s.send(Command.putToken(token.copy()..size = v)),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 1, child: Text(tr('Pequeño o mediano (1×1)'))),
                      PopupMenuItem(value: 2, child: Text(tr('Grande (2×2)'))),
                      PopupMenuItem(value: 3, child: Text(tr('Enorme (3×3)'))),
                      PopupMenuItem(value: 4, child: Text(tr('Gargantuesco (4×4)'))),
                    ],
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(tr('Quitar')),
                    onPressed: () async {
                      onClose();
                      await s.send(Command.removeToken(token.id));
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Coloca una ficha en una casilla libre del mapa.
BoardToken placeToken(BoardMap map, Board board, BoardToken t) {
  final (x, y) = board.freeCell(map, startX: map.cols ~/ 2, startY: map.rows ~/ 2);
  return t
    ..x = x
    ..y = y;
}

/// Etiquetas que el máster pone a un enemigo para describirlo sin dar sus PG.
Future<void> editTags(BuildContext context, {required String name, Combatant? combatant, BoardToken? token}) async {
  final s = SessionScope.read(context);
  final cb = combatant;
  final current = {...(cb?.tags ?? token?.tags ?? const <String>[])};
  final custom = TextEditingController();
  final result = await showDialog<Set<String>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(tr('Etiquetas de {0}', [name])),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Los jugadores ven estas etiquetas, nunca los PG. Úsalas para describir cómo se ve.'),
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                Gap.m,
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in {...presetTags, ...current})
                      FilterChip(
                        label: Text(tag),
                        selected: current.contains(tag),
                        onSelected: (v) => setState(() => v ? current.add(tag) : current.remove(tag)),
                      ),
                  ],
                ),
                Gap.m,
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: custom,
                        decoration: InputDecoration(hintText: tr('Otra etiqueta…')),
                        onSubmitted: (v) => setState(() {
                          if (v.trim().isNotEmpty) current.add(v.trim());
                          custom.clear();
                        }),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => setState(() {
                        if (custom.text.trim().isNotEmpty) current.add(custom.text.trim());
                        custom.clear();
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancelar'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, current), child: Text(tr('Guardar'))),
        ],
      ),
    ),
  );
  if (result == null) return;
  if (cb != null) {
    final e = s.campaign.encounter.copy();
    e.combatants.firstWhere((x) => x.id == cb.id).tags = result.toList();
    await s.send(Command.putEncounter(e));
  } else {
    if (token != null) await s.send(Command.putToken(token.copy()..tags = result.toList()));
  }
}
