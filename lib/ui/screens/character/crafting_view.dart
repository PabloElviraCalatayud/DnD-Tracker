import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/srd.dart';
import '../../../domain/character.dart';
import '../../../domain/currency.dart';
import '../../../domain/recipe.dart';
import '../../../domain/ruleset.dart';
import '../../../engine/commands.dart';
import '../../../engine/crafting.dart';
import '../../../state/providers.dart';
import '../../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../dm/recipes_screen.dart';
import 'character_views.dart';
import 'item_dialogs.dart';

/// Palabras clave (inglés y castellano) para reconocer las herramientas de
/// artesano del SRD en las competencias escritas por el jugador.
const Map<String, List<String>> toolKeywords = {
  'alchemists-supplies': ['alchemist', 'alquimi'],
  'brewers-supplies': ['brewer', 'cervec'],
  'calligraphers-supplies': ['calligraph', 'calígraf', 'caligraf'],
  'carpenters-tools': ['carpenter', 'carpinter'],
  'cartographers-tools': ['cartographer', 'cartógraf', 'cartograf'],
  'cobblers-tools': ['cobbler', 'zapater'],
  'cooks-utensils': ['cook', 'cociner'],
  'glassblowers-tools': ['glassblower', 'vidri'],
  'jewelers-tools': ['jeweler', 'joyer'],
  'leatherworkers-tools': ['leatherworker', 'peleter', 'curtid', 'marroquin'],
  'masons-tools': ['mason', 'albañil', 'cantero'],
  'painters-supplies': ['painter', 'pintor'],
  'potters-tools': ['potter', 'alfarer'],
  'smiths-tools': ['smith', 'herrer'],
  'tinkers-tools': ['tinker', 'hojalater', 'chapuc'],
  'weavers-tools': ['weaver', 'tejedor'],
  'woodcarvers-tools': ['woodcarver', 'tallador', 'ebanist'],
  'herbalism-kit': ['herbalism', 'herbor'],
  'poisoners-kit': ['poisoner', 'envenenador'],
  'disguise-kit': ['disguise', 'disfraz'],
  'forgery-kit': ['forgery', 'falsific'],
  'navigators-tools': ['navigator', 'navegante'],
  'thieves-tools': ['thieves', 'ladrón', 'ladron'],
};

bool hasToolProficiency(Character c, CraftTool tool) {
  final keys = [...?toolKeywords[tool.toolId], tool.tool.toLowerCase()];
  return c.toolProficiencies.any((p) {
    final lp = p.toLowerCase();
    return keys.any(lp.contains);
  });
}

class CraftingView extends ConsumerWidget {
  const CraftingView({super.key, required this.character});
  final Character character;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = SessionScope.of(context);
    final c = character;
    final editable = canEditCharacter(s, c);
    final t = Theme.of(context).textTheme;
    final recipes = s.campaign.recipes.where((r) => r.isAvailableTo(c.id)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final canCreateRecipes = s.isDm || s.campaign.settings.playersCanCreateRecipes;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (c.projects.isNotEmpty)
          SectionCard(
            title: 'En el taller',
            icon: 'hourglass',
            child: Column(
              children: [for (final p in c.projects) _ProjectTile(character: c, project: p, editable: editable)],
            ),
          ),
        SectionCard(
          title: 'Recetas que conoces',
          icon: 'scroll_quill',
          trailing: canCreateRecipes && editable
              ? TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Nueva'),
                  onPressed: () => openRecipeEditor(context, null, forCharacterId: c.id),
                )
              : null,
          child: recipes.isEmpty
              ? Text(
                  'Todavía no conoces recetas especiales. El máster puede enseñártelas'
                  '${canCreateRecipes ? ' o puedes crearlas tú' : ''}.',
                  style: t.bodySmall,
                )
              : Column(
                  children: [for (final r in recipes) _RecipeTile(character: c, recipe: r, editable: editable)],
                ),
        ),
        _StandardCraftingCard(character: c, editable: editable),
      ],
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({required this.character, required this.project, required this.editable});
  final Character character;
  final CraftingProject project;
  final bool editable;

  Future<void> _send(BuildContext context, Command cmd) async {
    final r = await SessionScope.read(context).send(cmd);
    if (!r.ok && context.mounted) showSnack(context, r.error ?? 'Error', error: true);
  }

  @override
  Widget build(BuildContext context) {
    final p = project;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GameIcon(p.result.iconName, size: 26),
              Gap.s,
              Expanded(
                child: Text(
                  '${p.result.name}${p.result.quantity > 1 ? ' ×${p.result.quantity}' : ''}',
                  style: t.titleSmall,
                ),
              ),
              Text('${p.daysDone}/${p.daysRequired} días'),
            ],
          ),
          Gap.xs,
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: p.progress, minHeight: 8, backgroundColor: AppColors.outlineSoft),
          ),
          if (editable)
            Wrap(
              spacing: 6,
              children: [
                TextButton(
                  onPressed: () => _send(context, Command.craftProgress(character.id, p.id, 1)),
                  child: const Text('+1 día'),
                ),
                TextButton(
                  onPressed: () async {
                    final n = await promptNumber(context, 'Días trabajados', hint: 'Días de 8 horas');
                    if (n != null && n > 0 && context.mounted) {
                      await _send(context, Command.craftProgress(character.id, p.id, n));
                    }
                  },
                  child: const Text('+N días'),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: () async {
                    final ok = await confirm(
                      context,
                      'Abandonar',
                      'Se perderán los materiales gastados.',
                      ok: 'Abandonar',
                      danger: true,
                    );
                    if (ok && context.mounted) await _send(context, Command.craftCancel(character.id, p.id));
                  },
                  child: const Text('Abandonar'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RecipeTile extends StatelessWidget {
  const _RecipeTile({required this.character, required this.recipe, required this.editable});
  final Character character;
  final Recipe recipe;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final r = recipe;
    final check = Crafting.check(character, r);
    final t = Theme.of(context).textTheme;
    final color = check.canCraft ? AppColors.success : AppColors.muted;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: GameIcon(r.result.iconName, size: 30, color: check.canCraft ? AppColors.gold : AppColors.muted),
      title: Text(r.name),
      subtitle: Text(
        check.canCraft ? 'Puedes fabricarlo (×${check.maxTimes})' : 'Faltan: ${_missingText(check)}',
        style: t.bodySmall?.copyWith(color: color),
      ),
      childrenPadding: const EdgeInsets.only(bottom: 10),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.description.isNotEmpty) Text(r.description),
        Gap.s,
        Text('Resultado: ${r.resultQuantity}× ${r.result.name}', style: t.titleSmall),
        Gap.xs,
        for (final ing in check.ingredients)
          Row(
            children: [
              Icon(
                ing.ok ? Icons.check_circle : Icons.cancel,
                size: 18,
                color: ing.ok ? AppColors.success : AppColors.danger,
              ),
              Gap.s,
              Expanded(child: Text('${ing.ingredient.name}${ing.ingredient.consumed ? '' : ' (no se gasta)'}')),
              Text('${ing.have}/${ing.need}'),
            ],
          ),
        if (r.goldCostCp > 0)
          Row(
            children: [
              Icon(
                check.goldOk ? Icons.check_circle : Icons.cancel,
                size: 18,
                color: check.goldOk ? AppColors.success : AppColors.danger,
              ),
              Gap.s,
              Text('Coste adicional: ${formatCp(r.goldCostCp)}'),
            ],
          ),
        if (r.tool.isNotEmpty)
          Row(
            children: [
              Icon(
                check.toolOk ? Icons.handyman : Icons.warning_amber,
                size: 18,
                color: check.toolOk ? AppColors.success : AppColors.warning,
              ),
              Gap.s,
              Expanded(child: Text('Herramienta: ${r.tool}${check.toolOk ? '' : ' (no la tienes)'}')),
            ],
          ),
        if (r.days > 0) Text('Tiempo: ${r.days} día(s) de trabajo', style: t.bodySmall),
        if (r.check.isNotEmpty) Text('Prueba: ${r.check}', style: t.bodySmall),
        if (editable) ...[
          Gap.s,
          FilledButton.icon(
            onPressed: check.canCraft ? () => _craft(context, check.maxTimes) : null,
            icon: const GameIcon('anvil', size: 18, color: AppColors.background),
            label: const Text('Fabricar'),
          ),
        ],
      ],
    );
  }

  static String _missingText(CraftCheck c) => [
    for (final m in c.missing) '${m.missing}× ${m.ingredient.name}',
    if (!c.goldOk) formatCp(c.goldNeededCp),
  ].join(', ');

  Future<void> _craft(BuildContext context, int maxTimes) async {
    var times = 1;
    if (maxTimes > 1) {
      final chosen = await showDialog<int>(
        context: context,
        builder: (ctx) {
          var v = 1;
          return StatefulBuilder(
            builder: (ctx, setState) => AlertDialog(
              title: Text('Fabricar ${recipe.name}'),
              content: Row(
                children: [
                  const Text('Veces'),
                  const Spacer(),
                  NumberStepper(value: v, min: 1, max: maxTimes, onChanged: (x) => setState(() => v = x)),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                FilledButton(onPressed: () => Navigator.pop(ctx, v), child: const Text('Fabricar')),
              ],
            ),
          );
        },
      );
      if (chosen == null) return;
      times = chosen;
    }
    if (!context.mounted) return;
    final r = await SessionScope.read(context).send(Command.craftRecipe(character.id, recipe.id, times));
    if (!context.mounted) return;
    showSnack(
      context,
      r.ok
          ? (recipe.days > 0 ? 'Empiezas a trabajar en ${recipe.name}' : '¡${recipe.result.name} fabricado!')
          : r.error ?? 'Error',
      error: !r.ok,
    );
  }
}

class _StandardCraftingCard extends ConsumerWidget {
  const _StandardCraftingCard({required this.character, required this.editable});
  final Character character;
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = SessionScope.of(context);
    final rs = s.campaign.ruleset;
    final srd = ref.watch(srdProvider(rs)).value;
    final t = Theme.of(context).textTheme;
    final tools = srd?.craftTools.where((tool) => hasToolProficiency(character, tool)).toList() ?? const <CraftTool>[];
    return SectionCard(
      title: 'Fabricación según las reglas (${rs.short})',
      icon: 'anvil',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.campaign.rules.craftingRulesSummary, style: t.bodyMedium),
          Gap.s,
          if (rs == Ruleset.v2024)
            Text(
              tools.isEmpty
                  ? 'No tienes competencia con herramientas de artesano (añádelas en «Editar ficha → Competencias»).'
                  : 'Tus herramientas: ${tools.map((x) => x.tool).join(', ')}',
              style: t.bodySmall,
            ),
          if (editable && srd != null) ...[
            Gap.s,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  icon: const GameIcon('hammer', size: 18),
                  label: const Text('Fabricar objeto'),
                  onPressed: () => _craftMundane(context, srd),
                ),
                if (s.campaign.settings.allowMagicCrafting)
                  OutlinedButton.icon(
                    icon: const GameIcon('sparkles', size: 18),
                    label: const Text('Objeto mágico'),
                    onPressed: () => _craftMagic(context, srd),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _craftMundane(BuildContext context, SrdData srd) async {
    final s = SessionScope.read(context);
    final rules = s.campaign.rules;
    final picked = await pickSrdItem(context, s.campaign.ruleset, includeMagic: false, title: 'Elige qué fabricar');
    if (picked == null || !context.mounted) return;
    final (item, qty) = picked;
    final cost = item.costCp * qty;
    final materials = rules.craftingMaterialsCp(cost);
    final days = rules.craftingDays(cost);
    final tools = srd.toolsFor(item.id);
    final hasTool = tools.isEmpty ? null : tools.any((tool) => hasToolProficiency(character, tool));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Fabricar ${qty > 1 ? '$qty× ' : ''}${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Precio de mercado: ${formatCp(cost)}'),
            Text('Materias primas: ${formatCp(materials)} (se descuentan de tu bolsa)'),
            Text('Tiempo: $days día(s) de trabajo'),
            Gap.s,
            if (tools.isNotEmpty)
              Text(
                'Herramienta: ${tools.map((x) => x.tool).join(' o ')}${hasTool == true ? ' ✓' : ' — no tienes competencia'}',
                style: TextStyle(color: hasTool == true ? AppColors.success : AppColors.warning),
              )
            else
              const Text('Herramienta: la adecuada, a criterio del máster.'),
            if (!character.currency.canAfford(materials))
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'No tienes dinero suficiente para los materiales.',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: character.currency.canAfford(materials) ? () => Navigator.pop(ctx, true) : null,
            child: const Text('Empezar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final r = await s.send(Command.craftStandard(character.id, item.toInventoryItem(quantity: qty), materials, days));
    if (context.mounted) showSnack(context, r.ok ? 'Proyecto iniciado' : r.error ?? 'Error', error: !r.ok);
  }

  Future<void> _craftMagic(BuildContext context, SrdData srd) async {
    final s = SessionScope.read(context);
    final rules = s.campaign.rules;
    final picked = await pickSrdItem(
      context,
      s.campaign.ruleset,
      includeMundane: false,
      title: 'Objeto mágico a fabricar',
    );
    if (picked == null || !context.mounted) return;
    final item = picked.$1;
    final consumable = RegExp('potion|scroll|poción|pergamino', caseSensitive: false).hasMatch(item.name);
    final costs = rules.magicItemCrafting(item.rarity, consumable: consumable);
    if (costs == null) {
      showSnack(
        context,
        'La rareza «${item.rarity}» no tiene coste estándar: pídele una receta al máster.',
        error: true,
      );
      return;
    }
    final (gp, days) = costs;
    final ok = await confirm(
      context,
      'Fabricar ${item.name}',
      'Rareza: ${item.rarity}\nCoste: $gp po · Tiempo: $days días\n\n'
          'Las reglas piden además la fórmula del objeto, competencia en Arcanos o con la herramienta '
          'adecuada y, a veces, conjuros o ingredientes especiales. Consulta al máster.',
      ok: 'Empezar',
    );
    if (!ok || !context.mounted) return;
    final r = await s.send(Command.craftStandard(character.id, item.toInventoryItem(), gp * 100, days));
    if (context.mounted) showSnack(context, r.ok ? 'Proyecto mágico iniciado' : r.error ?? 'Error', error: !r.ok);
  }
}
