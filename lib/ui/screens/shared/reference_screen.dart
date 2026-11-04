import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/srd.dart';
import '../../../domain/currency.dart';
import '../../../domain/item.dart';
import '../../../domain/ruleset.dart';
import '../../../state/providers.dart';
import '../../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../character/spells_view.dart';
import '../../../core/i18n.dart';
import '../../../core/text.dart';

/// Material de consulta rápida de la edición de la partida.
class ReferenceScreen extends ConsumerWidget {
  const ReferenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = SessionScope.of(context);
    final rs = s.campaign.ruleset;
    final srd = ref.watch(srdProvider(rs));
    return srd.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (data) => DefaultTabController(
        length: 5,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: tr('Estados')),
                Tab(text: tr('Conjuros')),
                Tab(text: tr('Objetos')),
                Tab(text: tr('Reglas')),
                Tab(text: tr('5e vs 5.5e')),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _Conditions(data: data),
                  SpellBrowser(srd: data),
                  _Items(data: data),
                  _Rules(data: data, rules: s.campaign.rules),
                  const _Differences(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Conditions extends StatelessWidget {
  const _Conditions({required this.data});
  final SrdData data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final c in data.conditions)
          Card(
            child: ExpansionTile(
              leading: const GameIcon('eye_target', size: 24),
              title: Text('${c.label}${c.label != c.name ? '  ·  ${c.name}' : ''}'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [RichDescription(c.description)],
            ),
          ),
      ],
    );
  }
}

class _Items extends ConsumerStatefulWidget {
  const _Items({required this.data});
  final SrdData data;

  @override
  ConsumerState<_Items> createState() => _ItemsState();
}

class _ItemsState extends ConsumerState<_Items> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(unitsProvider);
    final q = foldText(_q);
    final list = widget.data.items
        .where((i) => q.isEmpty || foldText(i.name).contains(q) || foldText(i.nameEn).contains(q))
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SearchField(onChanged: (v) => setState(() => _q = v)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, idx) {
              final i = list[idx];
              return ExpansionTile(
                leading: GameIcon(
                  ItemCategory.fromSrd(i.category).icon,
                  size: 24,
                  color: i.isMagic ? AppColors.arcane : AppColors.gold,
                ),
                title: Text(i.name),
                subtitle: Text(
                  [
                    if (i.subcategory.isNotEmpty) i.subcategory,
                    if (i.rarity.isNotEmpty) rarityLabel(i.rarity),
                    if (!i.isMagic) '${formatCp(i.costCp)} · ${units.weight(i.weight)}',
                  ].join(' · '),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (i.damage.isNotEmpty) Text(tr('Daño: {0}', [i.damage])),
                  if (i.armorClass.isNotEmpty) Text(tr('CA: {0}', [i.armorClass])),
                  if (i.propertiesText.isNotEmpty) Text(i.propertiesText),
                  if (i.description.isNotEmpty) RichDescription(i.description),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Rules extends StatelessWidget {
  const _Rules({required this.data, required this.rules});
  final SrdData data;
  final Rules rules;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final coins = Currency.coinLabels;
    final quick = [
      '### ${tr('Descansos')}',
      rules.longRestSummary,
      '',
      tr(
        'Descanso corto: gastas dados de golpe (1dX + mod. de CON cada uno) y recuperas los rasgos de descanso corto.',
      ),
      '',
      '### ${tr('Cansancio')} (${rules.ruleset.short})',
      for (var i = 1; i <= 6; i++) '- **${tr('Nivel {0}', [i])}:** ${rules.exhaustionEffect(i)}',
      '',
      '### ${tr('Artesanía')}',
      rules.craftingRulesSummary,
      '',
      '### ${tr('Bonificador por competencia')}',
      tr('Nivel 1-4: +2 · 5-8: +3 · 9-12: +4 · 13-16: +5 · 17-20: +6'),
      '',
      '### ${tr('Tablero')}',
      tr('Cada casilla mide 5 pies (1,5 m) en 2014 y en 2024. Por defecto cada diagonal cuenta como una casilla.'),
      '',
      '### ${tr('Carga')}',
      tr(
        'Capacidad = FUE × 15 libras (criatura mediana). Variante: más de FUE × 5 cargado (−10 pies), más de FUE × 10 muy cargado (−20 pies y desventaja en pruebas de FUE, DES y CON).',
      ),
      '',
      '### ${tr('Dinero')}',
      '1 ${coins[3]} = 10 ${coins[1]} = 100 ${coins[0]} · 1 ${coins[2]} = 5 ${coins[1]} · 1 ${coins[4]} = 10 ${coins[3]} · ${tr('50 monedas pesan 1 libra.')}',
    ].join('\n');
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SectionCard(title: tr('Resumen rápido'), icon: 'scroll', child: RichDescription(quick)),
        if (data.rules.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              tr(
                'El texto completo de reglas sólo está incluido para el SRD 5.1. Los estados, conjuros, objetos y criaturas de {0} sí están completos.',
                [rules.ruleset.srdName],
              ),
              style: t.bodySmall,
            ),
          ),
        for (final ch in data.rules)
          Card(
            child: ExpansionTile(
              title: Text(ch.name),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [
                for (final sec in ch.sections)
                  ExpansionTile(
                    title: Text(sec.name, style: t.titleSmall),
                    childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [RichDescription(sec.description)],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Differences extends StatelessWidget {
  const _Differences();

  static const _textEs = '''
Resumen orientativo de los cambios más visibles en mesa entre las reglas de 2014 (5e) y las de 2024 (5.5e).

| Tema | 5e (2014) | 5.5e (2024) |
|---|---|---|
| Origen | **Raza** con aumentos de característica | **Especie** sin aumentos; el **trasfondo** da +2/+1 (o +1/+1/+1) y una dote de origen |
| Inspiración | Inspiración que da el máster | **Inspiración heroica** (la da el máster y algunos rasgos; p. ej. los humanos la recuperan con cada descanso largo) |
| Cansancio | 6 niveles con efectos distintos | Cada nivel: −2 a las pruebas de d20 y −5 pies de velocidad; nivel 6 muerte |
| Descanso largo | Recuperas la mitad de los dados de golpe | Recuperas **todos** los dados de golpe |
| Conjuros preparados | Fórmula (mod. + nivel) o conocidos | Tabla fija de preparados por clase y nivel |
| Armas | Propiedades | Propiedades + **maestrías** (Sap, Slow, Topple…) |
| Paladín y explorador | Lanzan conjuros desde nivel 2 | Desde nivel 1 |
| Artesanía | 5 po de avance por día | 10 po de avance por día; cada herramienta indica qué puede fabricar |
| Monstruos | VD, salvaciones y habilidades aparte | Bloques más compactos con iniciativa incluida, salvaciones junto a las características |

La app adapta automáticamente: nombre de raza/especie, cansancio, descansos, conjuros preparados sugeridos, ritmo de artesanía y los datos SRD (criaturas, conjuros, objetos).
''';

  static const _textEn = '''
A rough summary of the most visible table changes between the 2014 rules (5e) and the 2024 rules (5.5e).

| Topic | 5e (2014) | 5.5e (2024) |
|---|---|---|
| Origin | **Race** with ability score increases | **Species** without increases; the **background** grants +2/+1 (or +1/+1/+1) and an origin feat |
| Inspiration | Inspiration granted by the DM | **Heroic Inspiration** (from the DM and some traits; e.g. humans regain it on each long rest) |
| Exhaustion | 6 levels with different effects | Each level: −2 to d20 tests and −5 ft of speed; level 6 is death |
| Long rest | You regain half your hit dice | You regain **all** your hit dice |
| Prepared spells | Formula (mod + level) or spells known | Fixed prepared-spells table per class and level |
| Weapons | Properties | Properties + **masteries** (Sap, Slow, Topple…) |
| Paladin and ranger | Cast spells from level 2 | From level 1 |
| Crafting | 5 gp of progress per day | 10 gp of progress per day; each tool lists what it can craft |
| Monsters | CR, saves and skills listed separately | More compact stat blocks with initiative, saves next to the abilities |

The app adapts automatically: race/species naming, exhaustion, rests, suggested prepared spells, crafting pace and the SRD data (creatures, spells, items).
''';

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(12),
    child: Card(
      child: Padding(padding: const EdgeInsets.all(14), child: RichDescription(I18n.isEnglish ? _textEn : _textEs)),
    ),
  );
}
