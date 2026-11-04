import 'package:flutter/material.dart';

import '../../../domain/abilities.dart';
import '../../../domain/character.dart';
import '../../../domain/currency.dart';
import '../../../domain/ruleset.dart';
import '../../../state/host_session.dart';
import '../../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../character/character_views.dart';
import 'invite_panel.dart';
import '../../../core/i18n.dart';

/// Vista general del máster: todo el grupo de un vistazo.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context) as HostSession;
    final c = s.campaign;
    final t = Theme.of(context).textTheme;
    final pcs = c.characters.where((x) => x.ownerId != s.myUserId).toList();
    final npcs = c.characters.where((x) => x.ownerId == s.myUserId).toList();
    final totalGold = c.characters.fold<int>(0, (a, x) => a + x.currency.totalCp);
    final avgLevel = pcs.isEmpty ? 0 : pcs.fold<int>(0, (a, x) => a + x.level) / pcs.length;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (s.onlineCount == 0) const InvitePanel(compact: true),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatBox(
              label: tr('Jugadores'),
              value: '${s.onlineCount}/${c.members.where((m) => !m.banned).length}',
              sub: tr('conectados'),
              width: 100,
            ),
            StatBox(label: tr('Personajes'), value: '${pcs.length}', width: 100),
            StatBox(label: tr('Nivel medio'), value: avgLevel == 0 ? '—' : avgLevel.toStringAsFixed(1), width: 100),
            StatBox(label: tr('Oro del grupo'), value: formatCp(totalGold), width: 150),
            if (c.encounter.active)
              StatBox(label: tr('Combate'), value: tr('Ronda {0}', [c.encounter.round]), highlight: true, width: 120),
          ],
        ),
        Gap.m,
        if (pcs.isEmpty)
          EmptyState(
            icon: 'party',
            title: tr('Aún no hay personajes'),
            message: tr('Comparte la invitación: cuando tus jugadores se unan y creen su personaje aparecerán aquí.'),
          ),
        LayoutBuilder(
          builder: (context, cons) {
            final columns = (cons.maxWidth / 360).floor().clamp(1, 4);
            final width = (cons.maxWidth - (columns - 1) * 8) / columns;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final pc in pcs)
                  SizedBox(
                    width: width,
                    child: _PartyCard(character: pc),
                  ),
              ],
            );
          },
        ),
        if (npcs.isNotEmpty) ...[
          Gap.l,
          Text(tr('PNJ y aliados'), style: t.titleLarge),
          Gap.s,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final n in npcs) SizedBox(width: 340, child: _PartyCard(character: n))],
          ),
        ],
        Gap.l,
        SectionCard(
          title: tr('Últimos sucesos'),
          icon: 'scroll',
          child: c.log.isEmpty
              ? Text(tr('Aquí aparecerán los cambios de PG, oro, objetos, artesanía…'), style: t.bodySmall)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in c.log.reversed.take(12))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 48, child: Text(_hhmm(e.ts), style: t.bodySmall)),
                            Expanded(child: Text(e.text)),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  static String _hhmm(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _PartyCard extends StatelessWidget {
  const _PartyCard({required this.character});
  final Character character;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final c = character;
    final t = Theme.of(context).textTheme;
    final online = (s as HostSession).onlineUserIds.contains(c.ownerId);
    final maxHp = c.effectiveHpMax(s.campaign.ruleset);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => openCharacterDetail(context, c.id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  GameIcon(c.portrait, size: 36),
                  Gap.s,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, style: t.titleMedium, overflow: TextOverflow.ellipsis),
                        Text(c.classSummary, style: t.bodySmall, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (c.ownerId != s.myUserId)
                    Tooltip(
                      message: online
                      ? tr('{0} conectado', [s.campaign.memberName(c.ownerId)])
                      : tr('{0} desconectado', [s.campaign.memberName(c.ownerId)]),
                      child: Icon(Icons.circle, size: 10, color: online ? AppColors.success : AppColors.outline),
                    ),
                ],
              ),
              Gap.s,
              Row(
                children: [
                  Expanded(
                    child: HpBar(current: c.hpCurrent, max: maxHp, temp: c.hpTemp),
                  ),
                  Gap.s,
                  Text('${c.hpCurrent}/$maxHp${c.hpTemp > 0 ? '+${c.hpTemp}' : ''}', style: t.titleSmall),
                ],
              ),
              Gap.s,
              Row(
                children: [
                  _mini(t, tr('CA'), '${c.armorClass}'),
                  _mini(t, tr('Perc.'), '${c.passive(Skill.perception)}'),
                  _mini(t, tr('Perspic.'), '${c.passive(Skill.insight)}'),
                  _mini(t, tr('Inv.'), '${c.passive(Skill.investigation)}'),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: tr('Daño'),
                    icon: const GameIcon('sword_wound', size: 20, color: AppColors.crimson),
                    onPressed: () async {
                      final v = await promptNumber(context, tr('Daño a {0}', [c.name]));
                      if (v != null && context.mounted) await editCharacter(context, c.id, (x) => x.takeDamage(v));
                    },
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: tr('Curar'),
                    icon: const GameIcon('heart_plus', size: 20, color: AppColors.success),
                    onPressed: () async {
                      final v = await promptNumber(context, tr('Curar a {0}', [c.name]));
                      if (v != null && context.mounted) {
                        await editCharacter(context, c.id, (x) => x.heal(v, s.campaign.ruleset));
                      }
                    },
                  ),
                ],
              ),
              if (c.conditions.isNotEmpty || c.exhaustion > 0 || c.spellcasting.concentratingOn.isNotEmpty)
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final cond in c.conditions) Pill(conditionLabel(cond), color: AppColors.warning),
                    if (c.exhaustion > 0) Pill(tr('Cansancio {0}', [c.exhaustion]), color: AppColors.danger),
                    if (c.spellcasting.concentratingOn.isNotEmpty)
                      Pill(tr('Conc.: {0}', [c.spellcasting.concentratingOn]), color: AppColors.arcane),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mini(TextTheme t, String label, String value) => Padding(
    padding: const EdgeInsets.only(right: 10),
    child: Column(
      children: [
        Text(label, style: t.labelSmall?.copyWith(color: AppColors.muted)),
        Text(value, style: t.titleSmall),
      ],
    ),
  );
}
