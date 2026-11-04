import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/campaign.dart';
import '../../../domain/character.dart';
import '../../../domain/currency.dart';
import '../../../domain/item.dart';
import '../../../engine/commands.dart';
import '../../../state/providers.dart';
import '../../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'character_views.dart';
import 'item_dialogs.dart';
import '../../../core/i18n.dart';

class InventoryView extends ConsumerStatefulWidget {
  const InventoryView({super.key, required this.character});
  final Character character;

  @override
  ConsumerState<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends ConsumerState<InventoryView> {
  String _query = '';
  ItemCategory? _category;

  Future<void> _add() async {
    final s = SessionScope.read(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const GameIcon('book', size: 26),
              title: Text(tr('Del SRD (armas, armaduras, equipo, objetos mágicos…)')),
              onTap: () => Navigator.pop(ctx, 'srd'),
            ),
            ListTile(
              leading: const GameIcon('quill', size: 26),
              title: Text(tr('Objeto personalizado')),
              onTap: () => Navigator.pop(ctx, 'custom'),
            ),
            if (s.isDm && s.campaign.itemLibrary.isNotEmpty)
              ListTile(
                leading: const GameIcon('open_chest', size: 26),
                title: Text(tr('De la biblioteca del máster')),
                onTap: () => Navigator.pop(ctx, 'library'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    InventoryItem? item;
    if (choice == 'srd') {
      final picked = await pickSrdItem(context, s.campaign.ruleset);
      if (picked != null) item = picked.$1.toInventoryItem(quantity: picked.$2);
    } else if (choice == 'custom') {
      item = await showItemForm(context, dmMode: s.isDm);
    } else if (choice == 'library') {
      item = await _pickLibrary(s.campaign);
    }
    if (item == null || !mounted) return;
    final added = item;
    if (s.isDm) {
      // El máster entrega el objeto: respeta sus opciones de ocultación.
      final r = await s.send(Command.giveItem(widget.character.id, added));
      if (!r.ok && mounted) showSnack(context, r.error ?? tr('Error'), error: true);
    } else {
      await editCharacter(context, widget.character.id, (c) => c.inventory.add(added));
    }
  }

  Future<InventoryItem?> _pickLibrary(Campaign campaign) => showDialog<InventoryItem>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(tr('Biblioteca del máster')),
      children: [
        for (final i in campaign.itemLibrary)
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, i.copy()), child: Text(i.name)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final c = widget.character;
    final editable = canEditCharacter(s, c);
    final units = ref.watch(unitsProvider);
    final settings = s.campaign.settings;
    final t = Theme.of(context).textTheme;

    final q = _query.toLowerCase();
    final items =
        c.inventory.where((i) {
          if (_category != null && i.category != _category) return false;
          return q.isEmpty || i.name.toLowerCase().contains(q) || i.tags.any((x) => x.toLowerCase().contains(q));
        }).toList()..sort((a, b) {
          if (a.equipped != b.equipped) return a.equipped ? -1 : 1;
          final cat = a.category.index.compareTo(b.category.index);
          return cat != 0 ? cat : a.name.compareTo(b.name);
        });
    final usedCategories = c.inventory.map((i) => i.category).toSet().toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    final anyHidden = c.inventory.any((i) => i.weight == null);
    final totalWeight = c.totalWeight(includeCoins: settings.countCoinWeight);
    final totalValue = c.inventory.fold<int>(0, (a, i) => a + (i.totalValueCp ?? 0));
    final capacity = c.carryCapacity;
    final enc = c.encumbrance(
      variant: settings.encumbrance == EncumbranceRule.variant,
      includeCoins: settings.countCoinWeight,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: editable
          ? FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: Text(tr('Añadir')))
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          _CurrencyCard(character: c, editable: editable),
          if (settings.encumbrance != EncumbranceRule.none)
            SectionCard(
              title: tr('Carga'),
              icon: 'knapsack',
              trailing: Text(
                '${units.weight(totalWeight)}${anyHidden ? '+?' : ''} / ${units.weight(capacity)}',
                style: t.titleSmall,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: capacity <= 0 ? 0 : (totalWeight / capacity).clamp(0, 1),
                      color: switch (enc) {
                        Encumbrance.none => AppColors.success,
                        Encumbrance.encumbered => AppColors.warning,
                        _ => AppColors.danger,
                      },
                      backgroundColor: AppColors.outlineSoft,
                    ),
                  ),
                  Gap.xs,
                  Text(switch (enc) {
                    Encumbrance.none => 'Sin penalizaciones.',
                    Encumbrance.encumbered => 'Cargado: −10 pies de velocidad.',
                    Encumbrance.heavilyEncumbered =>
                      'Muy cargado: −20 pies de velocidad y desventaja en pruebas, ataques y salvaciones de FUE, DES y CON.',
                    Encumbrance.overCapacity => 'Por encima de tu capacidad de carga: velocidad máxima 5 pies.',
                  }, style: t.bodySmall),
                  if (anyHidden) Text(tr('Hay objetos cuyo peso conoce sólo el máster.'), style: t.bodySmall),
                ],
              ),
            ),
          if (c.inventory.isNotEmpty) ...[
            Gap.s,
            SearchField(onChanged: (v) => setState(() => _query = v), hint: tr('Buscar en el inventario')),
            Gap.s,
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: Text(tr('Todo')),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                for (final cat in usedCategories)
                  ChoiceChip(
                    label: Text(cat.label),
                    selected: _category == cat,
                    onSelected: (v) => setState(() => _category = v ? cat : null),
                  ),
              ],
            ),
          ],
          Gap.s,
          if (c.inventory.isEmpty)
            EmptyState(
              icon: 'backpack',
              title: tr('Inventario vacío'),
              message: tr('Añade objetos del SRD o crea los tuyos.'),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final i in items)
                    ItemTile(
                      item: i,
                      onTap: () => showItemDetail(context, c, i, editable: editable),
                      trailing: editable
                          ? IconButton(
                              tooltip: visibilityText(context, i),
                              icon: VisibilityIcon(item: i),
                              onPressed: () => showVisibilityPicker(context, c, i),
                            )
                          : null,
                    ),
                ],
              ),
            ),
          if (c.inventory.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                tr('Valor total conocido: {0} · {1} objetos · {2} visibles para otros jugadores', [
                  formatCp(totalValue),
                  c.inventory.length,
                  c.inventory.where((i) => i.shared).length,
                ]),
                style: t.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _CurrencyCard extends StatelessWidget {
  const _CurrencyCard({required this.character, required this.editable});
  final Character character;
  final bool editable;

  Future<void> _editCoin(BuildContext context, int index) async {
    final current = character.currency.asList[index];
    final controller = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Monedas de {0} ({1})', [Currency.coinNames[index].toLowerCase(), Currency.coinLabels[index]])),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('Ahora: {0}', [current])),
            Gap.s,
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-+0-9]'))],
              decoration: InputDecoration(hintText: tr('+50 para sumar, -20 para restar, 120 para fijar')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancelar'))),
          FilledButton(
            onPressed: () {
              final txt = controller.text.trim();
              final n = int.tryParse(txt.replaceAll('+', ''));
              if (n == null) return Navigator.pop(ctx);
              final isDelta = txt.startsWith('+') || txt.startsWith('-');
              Navigator.pop(ctx, isDelta ? current + n : n);
            },
            child: Text(tr('Aplicar')),
          ),
        ],
      ),
    );
    if (result == null || !context.mounted) return;
    await editCharacter(context, character.id, (c) => c.currency.setIndex(index, result < 0 ? 0 : result));
  }

  Future<void> _giveMoney(BuildContext context) async {
    final s = SessionScope.read(context);
    final others = s.campaign.characters.where((x) => x.id != character.id).toList();
    if (others.isEmpty) return;
    String target = others.first.id;
    final amounts = List<int>.filled(5, 0);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(tr('Dar dinero')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: target,
                items: [for (final o in others) DropdownMenuItem(value: o.id, child: Text(o.name))],
                onChanged: (v) => setState(() => target = v ?? target),
              ),
              for (var i = 4; i >= 0; i--)
                Row(
                  children: [
                    SizedBox(width: 70, child: Text(Currency.coinLabels[i])),
                    const Spacer(),
                    NumberStepper(
                      compact: true,
                      value: amounts[i],
                      max: character.currency.asList[i],
                      onChanged: (v) => setState(() => amounts[i] = v),
                    ),
                  ],
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancelar'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Dar'))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final c = Currency(cp: amounts[0], sp: amounts[1], ep: amounts[2], gp: amounts[3], pp: amounts[4]);
    if (c.isZero) return;
    final r = await s.send(Command.transferCurrency(character.id, target, c));
    if (context.mounted && !r.ok) showSnack(context, r.error ?? tr('Error'), error: true);
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final c = character;
    final t = Theme.of(context).textTheme;
    final coins = c.currency.asList;
    return SectionCard(
      title: tr('Bolsa'),
      icon: 'coins',
      trailing: Text('≈ ${formatCp(c.currency.totalCp)}', style: t.titleSmall?.copyWith(color: AppColors.gold)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Siempre en una fila: en móvil caben las cinco monedas.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Row(
              children: [
                for (var i = 4; i >= 0; i--)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: StatBox(
                        label: Currency.coinNames[i],
                        value: '${coins[i]}',
                        sub: Currency.coinLabels[i],
                        width: double.infinity,
                        highlight: i == 3,
                        onTap: editable ? () => _editCoin(context, i) : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (editable && !c.isSummary) ...[
            Gap.s,
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(tr('El grupo ve mi dinero')),
                    value: c.shareCurrency,
                    onChanged: (v) => editCharacter(context, c.id, (x) => x.shareCurrency = v),
                  ),
                ),
                if (s.campaign.characters.length > 1 && (s.isDm || s.campaign.settings.playersCanTrade))
                  TextButton.icon(
                    onPressed: () => _giveMoney(context),
                    icon: const Icon(Icons.payments),
                    label: Text(tr('Dar')),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
