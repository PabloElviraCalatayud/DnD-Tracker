import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dice.dart';
import '../../../domain/abilities.dart';
import '../../../domain/character.dart';
import '../../../domain/ruleset.dart';
import '../../../state/providers.dart';
import '../../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../shared/dice_roller.dart';
import 'character_editor.dart';
import 'crafting_view.dart';
import 'inventory_view.dart';
import 'spells_view.dart';

enum CharacterView { sheet, inventory, spells, crafting }

/// ¿Puede el usuario actual modificar este personaje?
bool canEditCharacter(GameSession s, Character c) =>
    !c.isSummary && (s.isDm || (c.ownerId == s.myUserId && s.status == ConnectionStatus.online));

/// Aplica un cambio al personaje y avisa si el máster lo rechaza.
Future<void> editCharacter(BuildContext context, String id, void Function(Character c) change) async {
  final s = SessionScope.read(context);
  final r = await s.editCharacter(id, change);
  if (!r.ok && context.mounted) showSnack(context, r.error ?? 'No se pudo guardar', error: true);
}

class CharacterViewBody extends StatelessWidget {
  const CharacterViewBody({super.key, required this.characterId, required this.view});
  final String characterId;
  final CharacterView view;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final c = s.campaign.character(characterId);
    if (c == null) return const EmptyState(icon: 'skull', title: 'Este personaje ya no existe');
    return switch (view) {
      CharacterView.sheet => CharacterSheet(character: c),
      CharacterView.inventory => InventoryView(character: c),
      CharacterView.spells => SpellsView(character: c),
      CharacterView.crafting => CraftingView(character: c),
    };
  }
}

/// Pantalla completa de un personaje con pestañas (la usa el máster).
class CharacterDetailScreen extends StatelessWidget {
  const CharacterDetailScreen({super.key, required this.characterId});
  final String characterId;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final c = s.campaign.character(characterId);
    return DefaultTabController(
      length: 4,
      child: AppScaffold(
        title: c?.name ?? 'Personaje',
        actions: [
          if (c != null && canEditCharacter(s, c))
            IconButton(
              tooltip: 'Editar ficha',
              icon: const Icon(Icons.edit),
              onPressed: () => openCharacterEditor(context, c),
            ),
        ],
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Ficha'),
            Tab(text: 'Inventario'),
            Tab(text: 'Conjuros'),
            Tab(text: 'Artesanía'),
          ],
        ),
        body: TabBarView(
          children: [for (final v in CharacterView.values) CharacterViewBody(characterId: characterId, view: v)],
        ),
      ),
    );
  }
}

/// Abre la ficha completa manteniendo el acceso a la sesión.
void openCharacterDetail(BuildContext context, String id) {
  final s = SessionScope.read(context);
  Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => SessionScope(
        session: s,
        child: CharacterDetailScreen(characterId: id),
      ),
    ),
  );
}

// ======================================================================= Ficha

class CharacterSheet extends ConsumerWidget {
  const CharacterSheet({super.key, required this.character});
  final Character character;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = SessionScope.of(context);
    final c = character;
    final editable = canEditCharacter(s, c);
    final rules = s.campaign.rules;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 980;
        final left = <Widget>[
          _Header(character: c, editable: editable),
          _Vitals(character: c, editable: editable),
          if (c.hpCurrent <= 0) _DeathSaves(character: c, editable: editable),
          _Conditions(character: c, editable: editable, rules: rules),
          _Abilities(character: c, rules: rules),
          _HitDiceAndRest(character: c, editable: editable),
        ];
        final right = <Widget>[
          _Skills(character: c, rules: rules),
          _Features(character: c, editable: editable),
          _Attacks(character: c, editable: editable),
          _Proficiencies(character: c),
          _Personality(character: c),
          if (s.isDm) _DmNotes(character: c),
        ];
        if (wide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(children: left)),
                Gap.m,
                Expanded(child: Column(children: right)),
              ],
            ),
          );
        }
        return ListView(padding: const EdgeInsets.all(12), children: [...left, ...right]);
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.character, required this.editable});
  final Character character;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final c = character;
    final t = Theme.of(context).textTheme;
    final rs = s.campaign.ruleset;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceHigh,
                border: Border.all(color: AppColors.goldSoft, width: 2),
              ),
              padding: const EdgeInsets.all(10),
              child: GameIcon(c.portrait, color: AppColors.gold),
            ),
            Gap.m,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, style: t.headlineSmall),
                  Text(c.classSummary, style: t.titleSmall?.copyWith(color: AppColors.gold)),
                  Text(
                    [
                      if (c.species.isNotEmpty)
                        '${rs.speciesLabel}: ${c.species}${c.subspecies.isNotEmpty ? ' (${c.subspecies})' : ''}',
                      if (c.background.isNotEmpty) 'Trasfondo: ${c.background}',
                      if (c.alignment.isNotEmpty) c.alignment,
                      'Nivel ${c.level} · ${c.xp} PX',
                    ].join(' · '),
                    style: t.bodySmall,
                  ),
                  if (s.isDm) Text('Jugador: ${s.campaign.memberName(c.ownerId)}', style: t.bodySmall),
                ],
              ),
            ),
            if (editable)
              IconButton(
                tooltip: 'Editar ficha',
                icon: const Icon(Icons.edit_note),
                onPressed: () => openCharacterEditor(context, c),
              ),
          ],
        ),
      ),
    );
  }
}

const _compact = EdgeInsets.symmetric(horizontal: 12, vertical: 10);

class _Vitals extends ConsumerWidget {
  const _Vitals({required this.character, required this.editable});
  final Character character;
  final bool editable;

  Future<void> _damage(BuildContext context) async {
    final v = await promptNumber(context, 'Daño recibido', hint: 'Primero se restan los PG temporales');
    if (v == null || !context.mounted) return;
    await editCharacter(context, character.id, (c) => c.takeDamage(v));
  }

  Future<void> _heal(BuildContext context, Ruleset rs) async {
    final v = await promptNumber(context, 'Curación');
    if (v == null || !context.mounted) return;
    await editCharacter(context, character.id, (c) => c.heal(v, rs));
  }

  Future<void> _temp(BuildContext context) async {
    final v = await promptNumber(
      context,
      'PG temporales',
      initial: character.hpTemp,
      hint: 'No se acumulan: se queda el valor más alto',
    );
    if (v == null || !context.mounted) return;
    await editCharacter(context, character.id, (c) => c.hpTemp = v);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = SessionScope.of(context);
    final c = character;
    final t = Theme.of(context).textTheme;
    final units = ref.watch(unitsProvider);
    final rs = s.campaign.ruleset;
    final maxHp = c.effectiveHpMax(rs);
    return SectionCard(
      title: 'Puntos de golpe',
      icon: 'heart',
      trailing: Text(
        '${c.hpCurrent} / $maxHp${c.hpTemp > 0 ? '  +${c.hpTemp}' : ''}',
        style: t.titleLarge?.copyWith(color: AppColors.hpColor(maxHp == 0 ? 0 : c.hpCurrent / maxHp)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HpBar(current: c.hpCurrent, max: maxHp, temp: c.hpTemp, height: 12),
          if (editable) ...[
            Gap.s,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.secondaryDark, padding: _compact),
                  onPressed: () => _damage(context),
                  icon: const GameIcon('sword_wound', size: 18, color: AppColors.parchment),
                  label: const Text('Daño'),
                ),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(padding: _compact),
                  onPressed: () => _heal(context, rs),
                  icon: const GameIcon('heart_plus', size: 18, color: AppColors.parchment),
                  label: const Text('Curar'),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: _compact),
                  onPressed: () => _temp(context),
                  child: const Text('PG temp.'),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: '−1 PG',
                  onPressed: () => editCharacter(context, c.id, (x) => x.takeDamage(1)),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: '+1 PG',
                  onPressed: () => editCharacter(context, c.id, (x) => x.heal(1, rs)),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
          Gap.m,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatBox(label: 'CA', value: '${c.armorClass}'),
              StatBox(
                label: 'Iniciativa',
                value: signed(c.initiative),
                onTap: () => showD20Roll(
                  context,
                  'Iniciativa de ${c.name}',
                  c.initiative + s.campaign.rules.exhaustionD20Penalty(c.exhaustion),
                ),
              ),
              StatBox(label: 'Velocidad', value: units.distance(c.speed)),
              StatBox(label: 'Compet.', value: signed(c.proficiencyBonus)),
              StatBox(label: 'Perc. pasiva', value: '${c.passive(Skill.perception)}', width: 100),
              StatBox(
                label: 'Inspiración',
                value: c.inspiration ? 'Sí' : 'No',
                valueWidget: Icon(
                  c.inspiration ? Icons.star : Icons.star_border,
                  color: c.inspiration ? AppColors.gold : AppColors.muted,
                  size: 28,
                ),
                highlight: c.inspiration,
                width: 100,
                onTap: editable ? () => editCharacter(context, c.id, (x) => x.inspiration = !x.inspiration) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeathSaves extends StatelessWidget {
  const _DeathSaves({required this.character, required this.editable});
  final Character character;
  final bool editable;

  Widget _row(BuildContext context, String label, int value, Color color, void Function(Character, int) set) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label)),
        for (var i = 1; i <= 3; i++)
          IconButton(
            onPressed: editable
                ? () => editCharacter(context, character.id, (c) => set(c, value >= i ? i - 1 : i))
                : null,
            icon: Icon(value >= i ? Icons.circle : Icons.circle_outlined, color: color),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = character;
    final dead = c.deathFailures >= 3;
    final stable = c.deathSuccesses >= 3;
    return SectionCard(
      title: dead ? 'Muerto' : (stable ? 'Estable' : 'Tiradas de salvación contra la muerte'),
      icon: 'skull',
      trailing: editable
          ? TextButton(
              onPressed: () => showD20Roll(context, 'Salvación contra la muerte', 0),
              child: const Text('Tirar'),
            )
          : null,
      child: Column(
        children: [
          _row(context, 'Éxitos', c.deathSuccesses, AppColors.success, (x, v) => x.deathSuccesses = v),
          _row(context, 'Fallos', c.deathFailures, AppColors.danger, (x, v) => x.deathFailures = v),
        ],
      ),
    );
  }
}

class _Conditions extends ConsumerWidget {
  const _Conditions({required this.character, required this.editable, required this.rules});
  final Character character;
  final bool editable;
  final Rules rules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = character;
    final srd = ref.watch(srdProvider(rules.ruleset)).value;
    final t = Theme.of(context).textTheme;
    final ids = conditionNamesEs.keys.where((k) => k != 'exhaustion').toList();
    return SectionCard(
      title: 'Estados',
      icon: 'eye_target',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in ids)
                if (editable || c.conditions.contains(id))
                  FilterChip(
                    label: Text(conditionLabel(id)),
                    selected: c.conditions.contains(id),
                    tooltip: srd?.condition(id)?.description,
                    onSelected: editable
                        ? (v) => editCharacter(context, c.id, (x) => v ? x.conditions.add(id) : x.conditions.remove(id))
                        : null,
                  ),
              if (!editable && c.conditions.isEmpty) Text('Ninguno', style: t.bodySmall),
            ],
          ),
          Gap.m,
          Row(
            children: [
              Text('Cansancio', style: t.titleSmall),
              Gap.s,
              if (editable)
                NumberStepper(
                  compact: true,
                  value: c.exhaustion,
                  max: Rules.maxExhaustion,
                  onChanged: (v) => editCharacter(context, c.id, (x) => x.exhaustion = v),
                )
              else
                Text('${c.exhaustion}', style: t.titleMedium),
            ],
          ),
          if (c.exhaustion > 0)
            Text(rules.exhaustionEffect(c.exhaustion), style: t.bodySmall?.copyWith(color: AppColors.warning)),
        ],
      ),
    );
  }
}

class _Abilities extends StatelessWidget {
  const _Abilities({required this.character, required this.rules});
  final Character character;
  final Rules rules;

  @override
  Widget build(BuildContext context) {
    final c = character;
    final t = Theme.of(context).textTheme;
    final penalty = rules.exhaustionD20Penalty(c.exhaustion);
    return SectionCard(
      title: 'Características',
      icon: 'muscle',
      trailing: Text('Toca para tirar', style: t.bodySmall),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (final a in Ability.values)
            _AbilityBox(
              ability: a,
              score: c.score(a),
              mod: c.mod(a),
              save: c.saveBonus(a),
              proficientSave: c.saveProficiencies.contains(a),
              onCheck: () => showD20Roll(context, 'Prueba de ${a.label}', c.mod(a) + penalty),
              onSave: () => showD20Roll(context, 'Salvación de ${a.label}', c.saveBonus(a) + penalty),
            ),
        ],
      ),
    );
  }
}

class _AbilityBox extends StatelessWidget {
  const _AbilityBox({
    required this.ability,
    required this.score,
    required this.mod,
    required this.save,
    required this.proficientSave,
    required this.onCheck,
    required this.onSave,
  });

  final Ability ability;
  final int score;
  final int mod;
  final int save;
  final bool proficientSave;
  final VoidCallback onCheck;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      width: 104,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineSoft),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onCheck,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
              child: Column(
                children: [
                  Text(ability.abbr, style: t.labelLarge?.copyWith(color: AppColors.gold)),
                  Text(signed(mod), style: t.headlineSmall),
                  Text('$score', style: t.bodySmall),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          InkWell(
            onTap: onSave,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(proficientSave ? Icons.circle : Icons.circle_outlined, size: 10, color: AppColors.gold),
                  const SizedBox(width: 4),
                  Text('Salv. ${signed(save)}', style: t.labelMedium),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Skills extends StatelessWidget {
  const _Skills({required this.character, required this.rules});
  final Character character;
  final Rules rules;

  @override
  Widget build(BuildContext context) {
    final c = character;
    final t = Theme.of(context).textTheme;
    final penalty = rules.exhaustionD20Penalty(c.exhaustion);
    final skills = List.of(Skill.values)..sort((a, b) => a.label.compareTo(b.label));
    return SectionCard(
      title: 'Habilidades',
      icon: 'brain',
      child: Column(
        children: [
          for (final sk in skills)
            InkWell(
              onTap: () => showD20Roll(context, sk.label, c.skillBonus(sk) + penalty),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text(
                        c.skillProficiency(sk).badge,
                        style: t.labelMedium?.copyWith(color: AppColors.gold, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(child: Text(sk.label)),
                    Text(sk.ability.abbr, style: t.bodySmall),
                    SizedBox(
                      width: 44,
                      child: Text(signed(c.skillBonus(sk)), textAlign: TextAlign.right, style: t.titleSmall),
                    ),
                  ],
                ),
              ),
            ),
          Gap.s,
          Text('C = competente · P = pericia · ½ = media competencia', style: t.bodySmall),
        ],
      ),
    );
  }
}

class _HitDiceAndRest extends StatelessWidget {
  const _HitDiceAndRest({required this.character, required this.editable});
  final Character character;
  final bool editable;

  Future<void> _shortRest(BuildContext context) async {
    final c = character;
    final dice = c.hitDiceTotal.keys.toList()..sort((a, b) => b.compareTo(a));
    final spend = {for (final d in dice) d: 0};
    final roller = DiceRoller();
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Descanso corto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Elige cuántos dados de golpe gastas. Cada uno cura 1dX + mod. de CON. '
                'También se recargan los rasgos de descanso corto y los espacios de pacto.',
              ),
              Gap.m,
              for (final d in dice)
                Row(
                  children: [
                    Expanded(child: Text('d$d (quedan ${c.hitDiceAvailable(d)})')),
                    NumberStepper(
                      compact: true,
                      value: spend[d]!,
                      max: c.hitDiceAvailable(d),
                      onChanged: (v) => setState(() => spend[d] = v),
                    ),
                  ],
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                var healed = 0;
                spend.forEach((d, n) {
                  for (var i = 0; i < n; i++) {
                    healed += max(0, roller.die(d) + c.mod(Ability.con));
                  }
                });
                Navigator.pop(ctx, healed);
              },
              child: const Text('Descansar'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    final rs = SessionScope.read(context).campaign.ruleset;
    await editCharacter(context, c.id, (x) {
      spend.forEach((d, n) => x.hitDiceUsed[d] = (x.hitDiceUsed[d] ?? 0) + n);
      x.heal(result, rs);
      x.shortRest();
    });
    if (context.mounted) showSnack(context, 'Descanso corto: recuperas $result PG');
  }

  Future<void> _longRest(BuildContext context) async {
    final s = SessionScope.read(context);
    final ok = await confirm(context, 'Descanso largo', s.campaign.rules.longRestSummary, ok: 'Descansar');
    if (!ok || !context.mounted) return;
    await editCharacter(context, character.id, (x) => x.longRest(s.campaign.ruleset));
  }

  @override
  Widget build(BuildContext context) {
    final c = character;
    final t = Theme.of(context).textTheme;
    final totals = c.hitDiceTotal;
    return SectionCard(
      title: 'Dados de golpe y descansos',
      icon: 'campfire',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            children: [
              for (final e in totals.entries)
                Text('d${e.key}: ${c.hitDiceAvailable(e.key)}/${e.value}', style: t.titleSmall),
              if (totals.isEmpty) Text('Añade una clase para tener dados de golpe.', style: t.bodySmall),
            ],
          ),
          if (editable) ...[
            Gap.s,
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _shortRest(context),
                  icon: const GameIcon('hourglass', size: 18),
                  label: const Text('Descanso corto'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _longRest(context),
                  icon: const GameIcon('sleep', size: 18),
                  label: const Text('Descanso largo'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Features extends StatelessWidget {
  const _Features({required this.character, required this.editable});
  final Character character;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final c = character;
    final t = Theme.of(context).textTheme;
    return SectionCard(
      title: 'Rasgos y recursos',
      icon: 'sparkles',
      child: c.features.isEmpty
          ? Text('Sin rasgos. Añádelos desde «Editar ficha».', style: t.bodySmall)
          : Column(
              children: [
                for (final f in c.features)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(f.name),
                    subtitle: Text(
                      [
                        if (f.source.isNotEmpty) f.source,
                        if (f.maxUses != null) '${f.maxUses! - f.used}/${f.maxUses} usos · ${f.recharge.label}',
                      ].join(' · '),
                    ),
                    trailing: f.maxUses == null || !editable
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Gastar un uso',
                                onPressed: f.used < f.maxUses!
                                    ? () => editCharacter(
                                        context,
                                        c.id,
                                        (x) => x.features.firstWhere((y) => y.id == f.id).used++,
                                      )
                                    : null,
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              IconButton(
                                tooltip: 'Recuperar un uso',
                                onPressed: f.used > 0
                                    ? () => editCharacter(
                                        context,
                                        c.id,
                                        (x) => x.features.firstWhere((y) => y.id == f.id).used--,
                                      )
                                    : null,
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [if (f.description.isNotEmpty) RichDescription(f.description)],
                  ),
              ],
            ),
    );
  }
}

class _Attacks extends StatelessWidget {
  const _Attacks({required this.character, required this.editable});
  final Character character;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final c = character;
    final t = Theme.of(context).textTheme;
    final weapons = c.inventory.where((i) => i.equipped && i.damage.isNotEmpty).toList();
    if (c.attacks.isEmpty && weapons.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: 'Ataques',
      icon: 'crossed_swords',
      child: Column(
        children: [
          for (final a in c.attacks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(a.name),
              subtitle: Text([a.bonus, a.damage, a.notes].where((x) => x.isNotEmpty).join(' · ')),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (int.tryParse(a.bonus.replaceAll('+', '')) != null)
                    TextButton(
                      onPressed: () =>
                          showD20Roll(context, 'Ataque: ${a.name}', int.parse(a.bonus.replaceAll('+', ''))),
                      child: const Text('Atacar'),
                    ),
                  if (a.damage.isNotEmpty)
                    TextButton(
                      onPressed: () => showExpressionRoll(context, 'Daño: ${a.name}', a.damage.split(' ').first),
                      child: const Text('Daño'),
                    ),
                ],
              ),
            ),
          for (final w in weapons)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: GameIcon(w.iconName, size: 24),
              title: Text(w.name),
              subtitle: Text([w.damage, w.properties].where((x) => x.isNotEmpty).join(' · '), style: t.bodySmall),
              trailing: TextButton(
                onPressed: () => showExpressionRoll(context, 'Daño: ${w.name}', w.damage.split(' ').first),
                child: const Text('Daño'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Proficiencies extends StatelessWidget {
  const _Proficiencies({required this.character});
  final Character character;

  @override
  Widget build(BuildContext context) {
    final c = character;
    final s = SessionScope.of(context);
    final rows = <(String, String)>[
      ('Armaduras', c.armorProficiencies),
      ('Armas', c.weaponProficiencies),
      ('Herramientas', c.toolProficiencies.join(', ')),
      ('Idiomas', c.languages),
      if (s.campaign.ruleset == Ruleset.v2024) ('Maestrías de armas', c.weaponMasteries),
    ].where((r) => r.$2.trim().isNotEmpty).toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return SectionCard(
      title: 'Competencias e idiomas',
      icon: 'scroll',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: RichText(
                text: TextSpan(
                  style: t.bodyMedium,
                  children: [
                    TextSpan(
                      text: '${r.$1}: ',
                      style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: r.$2),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Personality extends StatelessWidget {
  const _Personality({required this.character});
  final Character character;

  @override
  Widget build(BuildContext context) {
    final c = character;
    final rows = <(String, String)>[
      ('Rasgos de personalidad', c.personality),
      ('Ideales', c.ideals),
      ('Vínculos', c.bonds),
      ('Defectos', c.flaws),
      ('Apariencia', c.appearance),
      ('Historia', c.backstory),
    ].where((r) => r.$2.trim().isNotEmpty).toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: 'Personalidad e historia',
      icon: 'quill',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final r in rows)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(r.$1),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(r.$2)],
            ),
        ],
      ),
    );
  }
}

class _DmNotes extends StatelessWidget {
  const _DmNotes({required this.character});
  final Character character;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Notas del máster (privadas)',
      icon: 'padlock',
      trailing: IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () async {
          final v = await promptText(
            context,
            'Notas sobre ${character.name}',
            initial: character.dmNotes,
            multiline: true,
          );
          if (v == null || !context.mounted) return;
          await editCharacter(context, character.id, (c) => c.dmNotes = v);
        },
      ),
      child: Text(character.dmNotes.isEmpty ? 'El jugador nunca ve estas notas.' : character.dmNotes),
    );
  }
}
