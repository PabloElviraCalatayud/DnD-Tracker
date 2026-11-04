import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dice.dart';
import '../../../domain/abilities.dart';
import '../../../domain/campaign.dart';
import '../../../domain/monster.dart';
import '../../../domain/ruleset.dart';
import '../../../engine/commands.dart';
import '../../../state/session.dart';
import '../../../state/providers.dart';
import '../../layout.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../board/token_panel.dart';
import '../character/character_views.dart';
import '../dm/bestiary_screen.dart';
import '../../../core/i18n.dart';

final _roller = DiceRoller();

/// Añade [count] copias de una criatura al encuentro (con iniciativa tirada).
Encounter addMonstersToEncounter(Encounter e, Monster m, int count, {bool rollHp = false, bool hidden = false}) {
  final existing = e.combatants.where((c) => c.monsterId == m.id).length;
  for (var i = 0; i < count; i++) {
    final n = existing + i + 1;
    final hp = rollHp && m.hitDice.isNotEmpty ? _safeRoll(m.hitDiceExpression, m.hp) : m.hp;
    final dex = m.mod(Ability.dex);
    e.combatants.add(
      Combatant(
        name: (count > 1 || existing > 0) ? '${m.name} $n' : m.name,
        kind: CombatantKind.monster,
        monsterId: m.id,
        initiative: _roller.die(20) + dex,
        initiativeBonus: dex,
        hp: hp,
        hpMax: hp,
        ac: m.ac,
        hidden: hidden,
        xp: m.xp,
      ),
    );
  }
  e.sort();
  return e;
}

int _safeRoll(String expr, int fallback) {
  try {
    return _roller.roll(expr).total.clamp(1, 99999);
  } on FormatException {
    return fallback;
  }
}

class InitiativeScreen extends StatefulWidget {
  const InitiativeScreen({super.key});

  @override
  State<InitiativeScreen> createState() => _InitiativeScreenState();
}

class _InitiativeScreenState extends State<InitiativeScreen> {
  /// En PC: combatiente fijado en el panel derecho (si no, el del turno).
  String? _pinnedId;

  Future<void> _put(BuildContext context, void Function(Encounter e) change) async {
    final s = SessionScope.read(context);
    final e = s.campaign.encounter.copy();
    change(e);
    final r = await s.send(Command.putEncounter(e));
    if (!r.ok && context.mounted) showSnack(context, r.error ?? tr('Error'), error: true);
  }

  void _addParty(BuildContext context) => _put(context, (e) {
    final s = SessionScope.read(context);
    for (final ch in s.campaign.characters.where((x) => x.ownerId != s.myUserId)) {
      if (e.combatants.any((c) => c.characterId == ch.id)) continue;
      e.combatants.add(
        Combatant(
          name: ch.name,
          kind: CombatantKind.pc,
          characterId: ch.id,
          initiative: ch.initiativeRoll ?? 0,
          initiativeBonus: ch.initiative,
        ),
      );
    }
    e.sort();
  });

  Future<void> _addCustom(BuildContext context) async {
    final name = await promptText(
      context,
      tr('Nombre del combatiente'),
      hint: tr('PNJ, trampa, guardia…'),
      ok: tr('Añadir'),
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    final hp = await promptNumber(context, tr('PG (opcional)'));
    if (!context.mounted) return;
    await _put(context, (e) {
      e.combatants.add(
        Combatant(name: name.trim(), kind: CombatantKind.npc, initiative: _roller.die(20), hp: hp, hpMax: hp),
      );
      e.sort();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final e = s.campaign.encounter;
    final t = Theme.of(context).textTheme;
    if (!s.isDm) return _PlayerInitiative(encounter: e);

    final monsters = e.combatants.where((c) => c.kind == CombatantKind.monster).toList();
    final pcLevels = s.campaign.characters.where((c) => c.ownerId != s.myUserId).map((c) => c.level).toList();
    final rules = s.campaign.rules;
    final thresholds = rules.partyThresholds(pcLevels);
    final adjusted = rules.adjustedXp(monsters.map((m) => m.xp).toList(), pcLevels.length);
    final totalXp = monsters.fold<int>(0, (a, m) => a + m.xp);

    final list = ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: () => _put(context, (x) {
                x.active = !x.active;
                if (x.active) {
                  x.round = 1;
                  x.turn = 0;
                  x.sort();
                }
              }),
              icon: Icon(e.active ? Icons.stop : Icons.play_arrow),
              label: Text(e.active ? tr('Terminar combate') : tr('Empezar combate')),
            ),
            OutlinedButton.icon(
              onPressed: () => _addParty(context),
              icon: const GameIcon('party', size: 18),
              label: Text(tr('Grupo')),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final m = await pickMonster(context);
                if (m != null && context.mounted) await addMonsterDialog(context, m);
              },
              icon: const GameIcon('dragon', size: 18),
              label: Text(tr('Criatura')),
            ),
            OutlinedButton.icon(
              onPressed: () => _addCustom(context),
              icon: const Icon(Icons.add),
              label: Text(tr('Otro')),
            ),
            IconButton(
              tooltip: tr('Tirar iniciativa de las criaturas'),
              icon: const GameIcon('dice', size: 22),
              onPressed: () => _put(context, (x) {
                for (final c in x.combatants.where((c) => c.kind != CombatantKind.pc)) {
                  c.initiative = _roller.die(20) + c.initiativeBonus;
                }
                x.sort();
              }),
            ),
            IconButton(
              tooltip: tr('Vaciar'),
              icon: const Icon(Icons.delete_sweep),
              onPressed: () async {
                final ok = await confirm(
                  context,
                  tr('Vaciar combate'),
                  tr('¿Quitar a todos los combatientes?'),
                  danger: true,
                );
                if (ok && context.mounted) {
                  await _put(
                    context,
                    (x) => x
                      ..combatants.clear()
                      ..active = false
                      ..round = 1
                      ..turn = 0,
                  );
                }
              },
            ),
            FilterChip(
              label: Text(tr('Visible para jugadores')),
              selected: e.visibleToPlayers,
              onSelected: (v) => _put(context, (x) => x.visibleToPlayers = v),
            ),
          ],
        ),
        if (monsters.isNotEmpty && pcLevels.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 16,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    tr('Dificultad: {0}', [rules.difficultyFor(adjusted, thresholds)]),
                    style: t.titleMedium?.copyWith(color: AppColors.gold),
                  ),
                  Text(
                    rules.is2024
                        ? tr('PX {0} (total {1}, {2} por PJ)', [adjusted, totalXp, totalXp ~/ pcLevels.length])
                        : tr('PX ajustados {0} (total {1}, {2} por PJ)', [
                            adjusted,
                            totalXp,
                            totalXp ~/ pcLevels.length,
                          ]),
                  ),
                  Text(
                    [
                      for (var i = 0; i < thresholds.length; i++) '${rules.difficultyLabels[i]} ${thresholds[i]}',
                    ].join(' · '),
                    style: t.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        if (e.active)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(tr('Ronda {0}', [e.round]), style: t.headlineSmall?.copyWith(color: AppColors.gold)),
                const Spacer(),
                IconButton(onPressed: () => _put(context, (x) => x.previous()), icon: const Icon(Icons.skip_previous)),
                FilledButton.icon(
                  onPressed: () => _put(context, (x) => x.next()),
                  icon: const Icon(Icons.skip_next),
                  label: Text(tr('Siguiente turno')),
                ),
              ],
            ),
          ),
        if (e.combatants.isEmpty)
          EmptyState(
            icon: 'crossed_swords',
            title: tr('Sin combatientes'),
            message: tr(
              'Añade al grupo y a las criaturas del grimorio. Los jugadores pueden enviar su tirada de iniciativa desde su app.',
            ),
          ),
        for (var i = 0; i < e.combatants.length; i++)
          _CombatantTile(
            index: i,
            combatant: e.combatants[i],
            isTurn: e.active && i == e.turn,
            pinned: e.combatants[i].id == _pinnedId,
            onSelect: isDesktopLayout(context)
                ? () => setState(() => _pinnedId = _pinnedId == e.combatants[i].id ? null : e.combatants[i].id)
                : null,
          ),
      ],
    );
    if (!isDesktopLayout(context)) return list;
    // En PC, a la derecha: la criatura o el personaje fijado, o el del turno actual.
    final shown =
        e.combatants.where((c) => c.id == _pinnedId).firstOrNull ??
        (e.active && e.combatants.isNotEmpty ? e.combatants[e.turn.clamp(0, e.combatants.length - 1)] : null);
    return MasterDetail(
      masterWidth: MediaQuery.sizeOf(context).width >= 1500 ? 620 : 500,
      master: list,
      emptyIcon: Icons.shield_outlined,
      emptyText: tr('Elige un combatiente para ver sus estadísticas.'),
      detail: shown == null
          ? null
          : CombatantDetail(key: ValueKey(shown.id), combatant: shown, pinned: _pinnedId != null),
    );
  }
}

/// Panel de escritorio con lo necesario para jugar el turno de un combatiente:
/// el bloque de estadísticas de la criatura o el resumen del personaje.
class CombatantDetail extends ConsumerWidget {
  const CombatantDetail({super.key, required this.combatant, required this.pinned});
  final Combatant combatant;
  final bool pinned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = SessionScope.of(context);
    final c = combatant;
    final t = Theme.of(context).textTheme;
    final pc = c.characterId == null ? null : s.campaign.character(c.characterId!);
    final srd = ref.watch(srdProvider(s.campaign.ruleset)).value;
    final monster = c.monsterId == null
        ? null
        : (s.campaign.monsters.where((m) => m.id == c.monsterId).firstOrNull ??
              srd?.monsters.where((m) => m.id == c.monsterId).firstOrNull);
    final hp = pc?.hpCurrent ?? c.hp;
    final hpMax = pc?.effectiveHpMax(s.campaign.ruleset) ?? c.hpMax;
    final isTurn = s.campaign.encounter.active && s.campaign.encounter.current?.id == c.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.92),
            border: Border(bottom: BorderSide(color: AppColors.outlineSoft)),
          ),
          child: Row(
            children: [
              GameIcon(pc?.portrait ?? monster?.iconName ?? 'person', size: 34),
              Gap.m,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: t.headlineSmall),
                    Text(
                      [
                        if (isTurn) tr('Es su turno'),
                        if (hp != null) tr('PG {0}/{1}', [hp, hpMax ?? '?']),
                        if ((pc?.armorClass ?? c.ac) != null) tr('CA {0}', [pc?.armorClass ?? c.ac]),
                      ].join(' · '),
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
              if (pc != null)
                OutlinedButton.icon(
                  onPressed: () => openCharacterDetail(context, pc.id),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(tr('Abrir ficha')),
                ),
              if (pinned)
                Tooltip(
                  message: tr('Fijado'),
                  child: Icon(Icons.push_pin, color: AppColors.gold),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: monster != null
                ? StatBlock(monster: monster)
                : pc != null
                ? _PcSummary(characterId: pc.id)
                : Text(c.notes.isEmpty ? tr('Sin más datos.') : c.notes),
          ),
        ),
      ],
    );
  }
}

class _PcSummary extends StatelessWidget {
  const _PcSummary({required this.characterId});
  final String characterId;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final c = s.campaign.character(characterId);
    if (c == null) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(c.classSummary, style: t.titleMedium?.copyWith(color: AppColors.gold)),
        Gap.m,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatBox(label: tr('CA'), value: '${c.armorClass}'),
            StatBox(label: tr('Iniciativa'), value: signed(c.initiative)),
            StatBox(label: tr('Perc. pasiva'), value: '${c.passive(Skill.perception)}'),
            if (c.spellcasting.ability != null) StatBox(label: tr('CD salvación'), value: '${c.spellSaveDc}'),
          ],
        ),
        Gap.m,
        if (c.conditions.isNotEmpty || c.exhaustion > 0)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final x in c.conditions) Pill(conditionLabel(x), color: AppColors.warning),
              if (c.exhaustion > 0) Pill(tr('Cansancio {0}', [c.exhaustion]), color: AppColors.danger),
            ],
          ),
      ],
    );
  }
}

class _CombatantTile extends StatelessWidget {
  const _CombatantTile({
    required this.index,
    required this.combatant,
    required this.isTurn,
    this.pinned = false,
    this.onSelect,
  });
  final int index;
  final Combatant combatant;
  final bool isTurn;
  final bool pinned;

  /// En PC, tocar la fila la muestra en el panel derecho.
  final VoidCallback? onSelect;

  Future<void> _edit(BuildContext context, void Function(Combatant c) change) async {
    final s = SessionScope.read(context);
    final e = s.campaign.encounter.copy();
    final c = e.combatants.firstWhere((x) => x.id == combatant.id);
    change(c);
    await s.send(Command.putEncounter(e));
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final c = combatant;
    final t = Theme.of(context).textTheme;
    final pc = c.characterId == null ? null : s.campaign.character(c.characterId!);
    final hp = pc?.hpCurrent ?? c.hp;
    final hpMax = pc?.hpMax ?? c.hpMax;
    final conditions = pc?.conditions ?? c.conditions;
    final icon = switch (c.kind) {
      CombatantKind.pc => pc?.portrait ?? 'hood',
      CombatantKind.monster =>
        s.campaign.board.tokens.where((t) => t.combatantId == c.id && t.icon.isNotEmpty).firstOrNull?.icon ?? 'dragon',
      CombatantKind.npc => 'person',
    };
    return Card(
      color: isTurn ? AppColors.primaryContainer.withValues(alpha: 0.55) : null,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: pinned ? AppColors.arcane : (isTurn ? AppColors.gold : AppColors.outlineSoft),
          width: isTurn || pinned ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              InkWell(
                onTap: () async {
                  final v = await promptNumber(
                    context,
                    tr('Iniciativa de {0}', [c.name]),
                    initial: c.initiative,
                    allowNegative: true,
                  );
                  if (v != null && context.mounted) {
                    await _edit(context, (x) => x.initiative = v);
                    if (context.mounted) {
                      final e = s.campaign.encounter.copy()..sort();
                      await s.send(Command.putEncounter(e));
                    }
                  }
                },
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.surfaceHighest,
                  child: Text('${c.initiative}', style: t.titleMedium?.copyWith(color: AppColors.gold)),
                ),
              ),
              Gap.s,
              GameIcon(icon, size: 28, color: c.kind == CombatantKind.pc ? AppColors.gold : AppColors.crimson),
              Gap.s,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            c.name,
                            style: t.titleMedium?.copyWith(
                              decoration: (hp ?? 1) <= 0 ? TextDecoration.lineThrough : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (c.hidden)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Pill(tr('oculto'), color: AppColors.muted),
                          ),
                      ],
                    ),
                    if (hp != null && hpMax != null && hpMax > 0) ...[
                      Gap.xs,
                      Row(
                        children: [
                          Expanded(
                            child: HpBar(current: hp, max: hpMax, height: 8),
                          ),
                          Gap.s,
                          Text('$hp/$hpMax', style: t.bodySmall),
                          if ((pc?.armorClass ?? c.ac) != null)
                            Text(tr('  CA {0}', [pc?.armorClass ?? c.ac]), style: t.bodySmall),
                        ],
                      ),
                    ],
                    if (conditions.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        children: [for (final x in conditions) Pill(conditionLabel(x), color: AppColors.warning)],
                      ),
                  ],
                ),
              ),
              if (c.kind != CombatantKind.pc && hp != null) ...[
                IconButton(
                  tooltip: tr('Daño'),
                  icon: GameIcon('sword_wound', size: 20, color: AppColors.crimson),
                  onPressed: () async {
                    final v = await promptNumber(context, tr('Daño a {0}', [c.name]));
                    if (v != null && context.mounted) {
                      await _edit(context, (x) => x.hp = ((x.hp ?? 0) - v).clamp(0, 99999));
                    }
                  },
                ),
                IconButton(
                  tooltip: tr('Curar'),
                  icon: GameIcon('heart_plus', size: 20, color: AppColors.success),
                  onPressed: () async {
                    final v = await promptNumber(context, tr('Curar a {0}', [c.name]));
                    if (v != null && context.mounted) {
                      await _edit(context, (x) => x.hp = ((x.hp ?? 0) + v).clamp(0, x.hpMax ?? 99999));
                    }
                  },
                ),
              ],
              PopupMenuButton<String>(
                onSelected: (v) async {
                  final ss = SessionScope.read(context);
                  if (v == 'hide') {
                    await _edit(context, (x) => x.hidden = !x.hidden);
                  } else if (v == 'remove') {
                    final e = ss.campaign.encounter.copy();
                    final idx = e.combatants.indexWhere((x) => x.id == c.id);
                    e.combatants.removeAt(idx);
                    if (e.turn > idx || e.turn >= e.combatants.length) e.turn = (e.turn - 1).clamp(0, 999);
                    await ss.send(Command.putEncounter(e));
                  } else if (v == 'tags') {
                    await editTags(context, name: c.name, combatant: c);
                  } else if (v == 'cond') {
                    final chosen = await showDialog<String>(
                      context: context,
                      builder: (ctx) => SimpleDialog(
                        title: Text(tr('Estado')),
                        children: [
                          for (final id in conditionNamesEs.keys)
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(ctx, id),
                              child: Text('${conditions.contains(id) ? '✓ ' : ''}${conditionLabel(id)}'),
                            ),
                        ],
                      ),
                    );
                    if (chosen == null || !context.mounted) return;
                    if (pc != null) {
                      await ss.editCharacter(
                        pc.id,
                        (x) => x.conditions.contains(chosen) ? x.conditions.remove(chosen) : x.conditions.add(chosen),
                      );
                    } else {
                      await _edit(
                        context,
                        (x) => x.conditions.contains(chosen) ? x.conditions.remove(chosen) : x.conditions.add(chosen),
                      );
                    }
                  } else if (v == 'turn') {
                    final e = ss.campaign.encounter.copy()..turn = index;
                    await ss.send(Command.putEncounter(e));
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'turn', child: Text(tr('Es su turno'))),
                  PopupMenuItem(value: 'cond', child: Text(tr('Estados…'))),
                  if (c.kind != CombatantKind.pc) PopupMenuItem(value: 'tags', child: Text(tr('Etiquetas visibles…'))),
                  PopupMenuItem(
                    value: 'hide',
                    child: Text(c.hidden ? tr('Mostrar a jugadores') : tr('Ocultar a jugadores')),
                  ),
                  PopupMenuItem(value: 'remove', child: Text(tr('Quitar'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lo que ve un jugador: orden de turno y su botón de iniciativa.
class _PlayerInitiative extends StatelessWidget {
  const _PlayerInitiative({required this.encounter});
  final Encounter encounter;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final e = encounter;
    final t = Theme.of(context).textTheme;
    final me = s.activeCharacter;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (me != null)
          SectionCard(
            title: tr('Tu iniciativa'),
            icon: 'd20',
            child: Row(
              children: [
                Text(me.initiativeRoll == null ? tr('Sin enviar') : '${me.initiativeRoll}', style: t.headlineSmall),
                const Spacer(),
                FilledButton.icon(
                  onPressed: !s.canEdit
                      ? null
                      : () async {
                          final mod = me.initiative + s.campaign.rules.exhaustionD20Penalty(me.exhaustion);
                          final r = _roller.d20(mod);
                          final res = await s.send(Command.setInitiative(me.id, r.total));
                          if (context.mounted) {
                            showSnack(
                              context,
                              res.ok
                                  ? tr('Iniciativa {0} ({1}) enviada al máster', [r.total, r.breakdown])
                                  : res.error ?? '',
                              error: !res.ok,
                            );
                          }
                        },
                  icon: GameIcon('dice', size: 18, color: AppColors.background),
                  label: Text(tr('Tirar ({0})', [signed(me.initiative)])),
                ),
                Gap.s,
                OutlinedButton(
                  onPressed: !s.canEdit
                      ? null
                      : () async {
                          final v = await promptNumber(context, tr('Resultado de tu tirada'), allowNegative: true);
                          if (v != null) await s.send(Command.setInitiative(me.id, v));
                        },
                  child: Text(tr('Escribir')),
                ),
              ],
            ),
          ),
        if (!e.active || e.combatants.isEmpty)
          EmptyState(
            icon: 'campfire',
            title: tr('No hay combate'),
            message: tr('Cuando el máster empiece un combate verás aquí el orden de turnos.'),
          )
        else ...[
          Text(tr('Ronda {0}', [e.round]), style: t.headlineSmall?.copyWith(color: AppColors.gold)),
          Gap.s,
          for (var i = 0; i < e.combatants.length; i++)
            Card(
              color: i == e.turn ? AppColors.primaryContainer.withValues(alpha: 0.55) : null,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.surfaceHighest,
                  child: Text('${e.combatants[i].initiative}', style: TextStyle(color: AppColors.gold)),
                ),
                title: Text(i == e.turn ? tr('{0}  ← turno', [e.combatants[i].name]) : e.combatants[i].name),
                subtitle: Text(
                  [
                    if (e.combatants[i].hp != null && e.combatants[i].hpMax != null)
                      tr('PG {0}/{1}', [e.combatants[i].hp, e.combatants[i].hpMax]),
                    ...e.combatants[i].tags,
                    ...e.combatants[i].conditions.map(conditionLabel),
                  ].join(' · '),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
