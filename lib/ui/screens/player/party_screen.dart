import 'package:flutter/material.dart';

import '../../../domain/currency.dart';
import '../../../domain/ruleset.dart';
import '../../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../character/item_dialogs.dart';

/// Lo que un jugador sabe de sus compañeros.
class PartyScreen extends StatelessWidget {
  const PartyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final c = s.campaign;
    final t = Theme.of(context).textTheme;
    final others = c.characters.where((x) => x.ownerId != s.myUserId).toList();
    final online = c.online.toSet();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SectionCard(
          title: 'Mesa',
          icon: 'castle',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Máster: ${c.dmName}', style: t.titleSmall),
              if (c.description.isNotEmpty) Text(c.description, style: t.bodySmall),
              Gap.s,
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final m in c.members)
                    Chip(
                      avatar: Icon(
                        Icons.circle,
                        size: 10,
                        color: online.contains(m.userId) ? AppColors.success : AppColors.outline,
                      ),
                      label: Text(m.userId == s.myUserId ? '${m.name} (tú)' : m.name),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (others.isEmpty)
          const EmptyState(
            icon: 'party',
            title: 'Aún no hay compañeros',
            message: 'Cuando otros jugadores creen su personaje aparecerán aquí.',
          ),
        for (final pc in others)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      GameIcon(pc.portrait, size: 40),
                      Gap.m,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(pc.name, style: t.titleLarge),
                            Text(
                              [
                                pc.classSummary,
                                if (pc.species.isNotEmpty) pc.species,
                                c.memberName(pc.ownerId),
                              ].join(' · '),
                              style: t.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      StatBox(label: 'CA', value: '${pc.armorClass}', width: 60),
                    ],
                  ),
                  if (!pc.hpHidden && pc.hpMax > 0) ...[
                    Gap.s,
                    Row(
                      children: [
                        Expanded(
                          child: HpBar(current: pc.hpCurrent, max: pc.hpMax, temp: pc.hpTemp),
                        ),
                        Gap.s,
                        Text('${pc.hpCurrent}/${pc.hpMax}'),
                      ],
                    ),
                  ],
                  if (pc.conditions.isNotEmpty || pc.exhaustion > 0) ...[
                    Gap.s,
                    Wrap(
                      spacing: 4,
                      children: [
                        for (final cond in pc.conditions) Pill(conditionLabel(cond), color: AppColors.warning),
                        if (pc.exhaustion > 0) Pill('Cansancio ${pc.exhaustion}', color: AppColors.danger),
                      ],
                    ),
                  ],
                  if (pc.shareCurrency) ...[Gap.s, Text('Bolsa: ${pc.currency}  (≈ ${formatCp(pc.currency.totalCp)})')],
                  if (pc.inventory.isNotEmpty) ...[
                    const Divider(height: 20),
                    Text('Objetos que comparte', style: t.titleSmall),
                    for (final i in pc.inventory)
                      ItemTile(
                        item: i,
                        showShared: false,
                        onTap: () => showItemDetail(context, pc, i, editable: false),
                      ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
