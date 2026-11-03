import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/srd.dart';
import '../../../domain/character.dart';
import '../../../domain/currency.dart';
import '../../../domain/item.dart';
import '../../../domain/profile.dart';
import '../../../domain/ruleset.dart';
import '../../../engine/commands.dart';
import '../../../state/providers.dart';
import '../../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Iconos que se pueden elegir para objetos personalizados.
const itemIconChoices = [
  'broadsword',
  'dagger',
  'axe',
  'mace',
  'spear',
  'bow',
  'crossbow',
  'arrows',
  'shield',
  'breastplate',
  'leather_armor',
  'helm',
  'backpack',
  'knapsack',
  'swap_bag',
  'chest',
  'coins',
  'gold_bar',
  'gem',
  'ring',
  'amulet',
  'potion',
  'flask',
  'bubbling_flask',
  'cauldron',
  'scroll',
  'spell_book',
  'book',
  'wizard_staff',
  'crystal_ball',
  'sparkles',
  'hammer',
  'anvil',
  'ore',
  'metal_bar',
  'herbs',
  'mushroom',
  'leaf',
  'hide',
  'wood',
  'wool',
  'stone',
  'torch',
  'lantern',
  'candle',
  'key',
  'lockpicks',
  'rope',
  'treasure_map',
  'compass',
  'gloves',
  'boots',
  'cape',
  'robe',
  'crown',
  'skull',
  'feather',
];

class ItemTile extends ConsumerWidget {
  const ItemTile({super.key, required this.item, this.onTap, this.trailing, this.showShared = true});
  final InventoryItem item;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showShared;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitsProvider);
    final t = Theme.of(context).textTheme;
    final i = item;
    final hiddenW = i.weight == null || i.hideWeight;
    final hiddenV = i.valueCp == null || i.hideValue;
    return ListTile(
      onTap: onTap,
      leading: GameIcon(i.iconName, size: 30, color: i.isMagic ? AppColors.arcane : AppColors.gold),
      title: Row(
        children: [
          Flexible(child: Text(i.quantity == 1 ? i.name : '${i.name} ×${i.quantity}', overflow: TextOverflow.ellipsis)),
          if (i.equipped)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Pill('equipado', color: AppColors.success),
            ),
          if (i.attuned)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Pill('vinculado', color: AppColors.arcane),
            ),
        ],
      ),
      subtitle: Text(
        [
          i.weight == null ? 'peso oculto' : '${units.weight(i.totalWeight)}${hiddenW ? ' (oculto)' : ''}',
          i.valueCp == null ? 'valor oculto' : '${formatCp(i.totalValueCp)}${hiddenV ? ' (oculto)' : ''}',
          if (i.rarity.isNotEmpty) rarityLabel(i.rarity),
          if (i.charges != null) 'cargas ${i.charges}${i.maxCharges != null ? '/${i.maxCharges}' : ''}',
        ].join(' · '),
        style: t.bodySmall,
      ),
      trailing:
          trailing ??
          (showShared
              ? Tooltip(
                  message: i.shared ? 'Visible para el grupo' : 'Sólo lo ves tú (y el máster)',
                  child: Icon(
                    i.shared ? Icons.visibility : Icons.visibility_off,
                    size: 20,
                    color: i.shared ? AppColors.gold : AppColors.muted,
                  ),
                )
              : null),
    );
  }
}

/// Detalle de un objeto del inventario con todas las acciones.
Future<void> showItemDetail(BuildContext context, Character character, InventoryItem item, {required bool editable}) {
  final session = SessionScope.read(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SessionScope(
      session: session,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (ctx, scroll) =>
            _ItemDetail(characterId: character.id, itemId: item.id, editable: editable, scroll: scroll),
      ),
    ),
  );
}

class _ItemDetail extends ConsumerWidget {
  const _ItemDetail({required this.characterId, required this.itemId, required this.editable, required this.scroll});
  final String characterId;
  final String itemId;
  final bool editable;
  final ScrollController scroll;

  Future<void> _edit(BuildContext context, void Function(InventoryItem i) change) async {
    final s = SessionScope.read(context);
    final r = await s.editCharacter(characterId, (c) {
      final it = c.itemById(itemId);
      if (it != null) change(it);
    });
    if (!r.ok && context.mounted) showSnack(context, r.error ?? 'Error', error: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = SessionScope.of(context);
    final c = s.campaign.character(characterId);
    final item = c?.itemById(itemId);
    final units = ref.watch(unitsProvider);
    final t = Theme.of(context).textTheme;
    if (c == null || item == null) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(32), child: Text('El objeto ya no está aquí.')),
      );
    }
    final others = s.campaign.characters.where((x) => x.id != c.id).toList();
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Row(
          children: [
            GameIcon(item.iconName, size: 44, color: item.isMagic ? AppColors.arcane : AppColors.gold),
            Gap.m,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: t.headlineSmall),
                  Text(
                    [
                      item.category.label,
                      if (item.rarity.isNotEmpty) rarityLabel(item.rarity),
                      if (item.requiresAttunement) 'requiere vinculación',
                    ].join(' · '),
                    style: t.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        Gap.m,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatBox(label: 'Cantidad', value: '${item.quantity}'),
            StatBox(
              label: 'Peso ud.',
              value: units.weight(item.weight),
              sub: item.hideWeight || item.weight == null ? 'oculto' : null,
            ),
            StatBox(
              label: 'Valor ud.',
              value: formatCp(item.valueCp),
              width: 110,
              sub: item.hideValue || item.valueCp == null ? 'oculto' : null,
            ),
            if (item.damage.isNotEmpty) StatBox(label: 'Daño', value: item.damage, width: 130),
            if (item.armorClass.isNotEmpty) StatBox(label: 'CA', value: item.armorClass, width: 110),
          ],
        ),
        if (item.properties.isNotEmpty) ...[Gap.s, Text(item.properties, style: t.bodySmall)],
        if (item.description.isNotEmpty) ...[Gap.m, RichDescription(item.description)],
        if (item.tags.isNotEmpty) ...[
          Gap.s,
          Wrap(spacing: 6, children: [for (final tag in item.tags) Pill(tag, color: AppColors.arcane)]),
        ],
        if (s.isDm && item.dmNote.isNotEmpty) ...[
          Gap.m,
          SectionCard(title: 'Nota del máster', icon: 'padlock', child: Text(item.dmNote)),
        ],
        if (editable) ...[
          const Divider(height: 28),
          Row(
            children: [
              Text('Cantidad', style: t.titleSmall),
              const Spacer(),
              NumberStepper(value: item.quantity, min: 0, onChanged: (v) => _edit(context, (i) => i.quantity = v)),
            ],
          ),
          if (item.maxCharges != null || item.charges != null)
            Row(
              children: [
                Text('Cargas', style: t.titleSmall),
                const Spacer(),
                NumberStepper(
                  value: item.charges ?? 0,
                  max: item.maxCharges ?? 999,
                  onChanged: (v) => _edit(context, (i) => i.charges = v),
                ),
              ],
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Visible para el grupo'),
            subtitle: const Text('Los demás jugadores lo verán en tu inventario'),
            value: item.shared,
            onChanged: (v) => _edit(context, (i) => i.shared = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Equipado'),
            value: item.equipped,
            onChanged: (v) => _edit(context, (i) => i.equipped = v),
          ),
          if (item.requiresAttunement)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vinculado'),
              subtitle: Text('${c.attunedCount}/3 objetos vinculados'),
              value: item.attuned,
              onChanged: (v) {
                if (v && c.attunedCount >= 3) {
                  showSnack(context, 'Máximo 3 objetos vinculados', error: true);
                  return;
                }
                _edit(context, (i) => i.attuned = v);
              },
            ),
          if (s.isDm) ...[
            const Divider(height: 24),
            Text('Opciones del máster', style: t.titleSmall?.copyWith(color: AppColors.gold)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ocultar peso al jugador'),
              value: item.hideWeight,
              onChanged: (v) => _edit(context, (i) => i.hideWeight = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ocultar valor al jugador'),
              value: item.hideValue,
              onChanged: (v) => _edit(context, (i) => i.hideValue = v),
            ),
          ],
          Gap.m,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (s.isDm || item.weight != null && item.valueCp != null || item.custom)
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar'),
                  onPressed: () async {
                    final edited = await showItemForm(context, initial: item, dmMode: s.isDm);
                    if (edited == null || !context.mounted) return;
                    await s.editCharacter(characterId, (ch) {
                      final idx = ch.inventory.indexWhere((x) => x.id == itemId);
                      if (idx >= 0) ch.inventory[idx] = edited..id = itemId;
                    });
                  },
                ),
              if (others.isNotEmpty && (s.isDm || s.campaign.settings.playersCanTrade))
                OutlinedButton.icon(
                  icon: const Icon(Icons.card_giftcard),
                  label: const Text('Dar a…'),
                  onPressed: () => _give(context, c, item, others),
                ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Tirar'),
                onPressed: () async {
                  final ok = await confirm(
                    context,
                    'Tirar objeto',
                    '¿Quitar ${item.name} del inventario?',
                    ok: 'Tirar',
                    danger: true,
                  );
                  if (!ok || !context.mounted) return;
                  await s.editCharacter(characterId, (ch) => ch.inventory.removeWhere((x) => x.id == itemId));
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _give(BuildContext context, Character from, InventoryItem item, List<Character> others) async {
    final s = SessionScope.read(context);
    var qty = item.quantity;
    String? targetId = others.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Dar ${item.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: targetId,
                decoration: const InputDecoration(labelText: 'A quién'),
                items: [for (final o in others) DropdownMenuItem(value: o.id, child: Text(o.name))],
                onChanged: (v) => setState(() => targetId = v),
              ),
              if (item.quantity > 1) ...[
                Gap.m,
                Row(
                  children: [
                    const Text('Cantidad'),
                    const Spacer(),
                    NumberStepper(value: qty, min: 1, max: item.quantity, onChanged: (v) => setState(() => qty = v)),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Dar')),
          ],
        ),
      ),
    );
    if (ok != true || targetId == null) return;
    final r = await s.send(Command.transferItem(from.id, targetId!, item.id, qty));
    if (!context.mounted) return;
    if (r.ok) {
      Navigator.pop(context);
      showSnack(context, 'Entregado');
    } else {
      showSnack(context, r.error ?? 'Error', error: true);
    }
  }
}

// ------------------------------------------------------------------ Selección SRD

/// Buscador de objetos del SRD. Devuelve el objeto elegido y la cantidad.
Future<(SrdItem, int)?> pickSrdItem(
  BuildContext context,
  Ruleset ruleset, {
  bool includeMagic = true,
  bool includeMundane = true,
  String title = 'Añadir objeto del SRD',
}) {
  return Navigator.push<(SrdItem, int)>(
    context,
    MaterialPageRoute(
      builder: (_) =>
          _SrdItemPicker(ruleset: ruleset, includeMagic: includeMagic, includeMundane: includeMundane, title: title),
    ),
  );
}

class _SrdItemPicker extends ConsumerStatefulWidget {
  const _SrdItemPicker({
    required this.ruleset,
    required this.includeMagic,
    required this.includeMundane,
    required this.title,
  });
  final Ruleset ruleset;
  final bool includeMagic;
  final bool includeMundane;
  final String title;

  @override
  ConsumerState<_SrdItemPicker> createState() => _SrdItemPickerState();
}

class _SrdItemPickerState extends ConsumerState<_SrdItemPicker> {
  String _query = '';
  String? _cat;

  static const _cats = {
    'weapon': 'Armas',
    'armor': 'Armaduras',
    'gear': 'Equipo',
    'tool': 'Herramientas',
    'ammunition': 'Munición',
    'magic': 'Mágicos',
  };

  @override
  Widget build(BuildContext context) {
    final srd = ref.watch(srdProvider(widget.ruleset));
    final units = ref.watch(unitsProvider);
    return AppScaffold(
      title: widget.title,
      body: srd.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) {
          final q = _query.toLowerCase();
          final list = data.items.where((i) {
            if (i.isMagic && !widget.includeMagic) return false;
            if (!i.isMagic && !widget.includeMundane) return false;
            if (_cat != null && i.category != _cat) return false;
            return q.isEmpty || i.name.toLowerCase().contains(q);
          }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: SearchField(
                  onChanged: (v) => setState(() => _query = v),
                  hint: 'Buscar (en inglés: sword, potion…)',
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final e in _cats.entries)
                      if ((e.key == 'magic' && widget.includeMagic) || (e.key != 'magic' && widget.includeMundane))
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(e.value),
                            selected: _cat == e.key,
                            onSelected: (v) => setState(() => _cat = v ? e.key : null),
                          ),
                        ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, idx) {
                    final i = list[idx];
                    return ListTile(
                      leading: GameIcon(
                        ItemCategory.fromSrd(i.category).icon,
                        size: 26,
                        color: i.isMagic ? AppColors.arcane : AppColors.gold,
                      ),
                      title: Text(i.name),
                      subtitle: Text(
                        [
                          if (i.subcategory.isNotEmpty) i.subcategory,
                          if (i.rarity.isNotEmpty) rarityLabel(i.rarity),
                          if (!i.isMagic) '${formatCp(i.costCp)} · ${units.weight(i.weight)}',
                          if (i.damage.isNotEmpty) i.damage,
                          if (i.armorClass.isNotEmpty) 'CA ${i.armorClass}',
                        ].join(' · '),
                      ),
                      onTap: () => _choose(i),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _choose(SrdItem item) async {
    var qty = item.quantity;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(item.name),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.propertiesText.isNotEmpty) Text(item.propertiesText),
                  if (item.description.isNotEmpty) ...[Gap.s, RichDescription(item.description)],
                  Gap.m,
                  Row(
                    children: [
                      const Text('Cantidad'),
                      const Spacer(),
                      NumberStepper(value: qty, min: 1, onChanged: (v) => setState(() => qty = v)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Elegir')),
          ],
        ),
      ),
    );
    if (ok == true && mounted) Navigator.pop(context, (item, qty));
  }
}

// ------------------------------------------------------------------ Formulario

/// Editor de objeto personalizado. En modo máster permite ocultar peso/valor.
Future<InventoryItem?> showItemForm(
  BuildContext context, {
  InventoryItem? initial,
  bool dmMode = false,
  String title = 'Objeto personalizado',
}) {
  return Navigator.push<InventoryItem>(
    context,
    MaterialPageRoute(
      builder: (_) => _ItemForm(initial: initial, dmMode: dmMode, title: title),
    ),
  );
}

class _ItemForm extends ConsumerStatefulWidget {
  const _ItemForm({this.initial, required this.dmMode, required this.title});
  final InventoryItem? initial;
  final bool dmMode;
  final String title;

  @override
  ConsumerState<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends ConsumerState<_ItemForm> {
  late InventoryItem _item;
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _weight;
  late final TextEditingController _value;
  late final TextEditingController _damage;
  late final TextEditingController _ac;
  late final TextEditingController _props;
  late final TextEditingController _tags;
  late final TextEditingController _charges;
  late final TextEditingController _dmNote;
  late Units _units;

  @override
  void initState() {
    super.initState();
    _units = ref.read(unitsProvider);
    _item = widget.initial?.copy() ?? InventoryItem(name: '', custom: true);
    _name = TextEditingController(text: _item.name);
    _desc = TextEditingController(text: _item.description);
    _weight = TextEditingController(text: _item.weight == null ? '' : _fmt(_units.fromLb(_item.weight!)));
    _value = TextEditingController(text: _item.valueCp == null ? '' : _cpToText(_item.valueCp!));
    _damage = TextEditingController(text: _item.damage);
    _ac = TextEditingController(text: _item.armorClass);
    _props = TextEditingController(text: _item.properties);
    _tags = TextEditingController(text: _item.tags.join(', '));
    _charges = TextEditingController(text: _item.maxCharges?.toString() ?? '');
    _dmNote = TextEditingController(text: _item.dmNote);
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  static String _cpToText(int cp) {
    if (cp % 100 == 0) return '${cp ~/ 100} po';
    if (cp % 10 == 0) return '${cp ~/ 10} pp';
    return '$cp pc';
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showSnack(context, 'El objeto necesita un nombre', error: true);
      return;
    }
    final cost = parseCost(_value.text);
    if (cost == null) {
      showSnack(context, 'No entiendo el valor. Ejemplos: 15 po, 3 pp, 20 pc', error: true);
      return;
    }
    final w = double.tryParse(_weight.text.replaceAll(',', '.'));
    _item
      ..name = name
      ..description = _desc.text.trim()
      ..weight = _weight.text.trim().isEmpty ? 0 : _units.toLb(w ?? 0)
      ..valueCp = cost
      ..damage = _damage.text.trim()
      ..armorClass = _ac.text.trim()
      ..properties = _props.text.trim()
      ..tags = _tags.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
      ..maxCharges = int.tryParse(_charges.text)
      ..dmNote = _dmNote.text.trim();
    if (_item.maxCharges != null) _item.charges ??= _item.maxCharges;
    if (_item.maxCharges == null) _item.charges = null;
    Navigator.pop(context, _item);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppScaffold(
      title: widget.title,
      actions: [TextButton(onPressed: _save, child: const Text('Guardar'))],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            autofocus: widget.initial == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          Gap.m,
          DropdownButtonFormField<ItemCategory>(
            initialValue: _item.category,
            decoration: const InputDecoration(labelText: 'Categoría'),
            items: [for (final c in ItemCategory.values) DropdownMenuItem(value: c, child: Text(c.label))],
            onChanged: (v) => setState(() => _item.category = v ?? _item.category),
          ),
          Gap.m,
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: InputDecoration(labelText: 'Peso por unidad (${_units.weightUnit})'),
                ),
              ),
              Gap.m,
              Expanded(
                child: TextField(
                  controller: _value,
                  decoration: const InputDecoration(labelText: 'Valor por unidad', hintText: '15 po · 3 pp · 20 pc'),
                ),
              ),
            ],
          ),
          Gap.m,
          Row(
            children: [
              Text('Cantidad', style: t.titleSmall),
              const Spacer(),
              NumberStepper(value: _item.quantity, min: 1, onChanged: (v) => setState(() => _item.quantity = v)),
            ],
          ),
          Gap.m,
          TextField(
            controller: _desc,
            minLines: 3,
            maxLines: 10,
            decoration: const InputDecoration(labelText: 'Descripción', alignLabelWithHint: true),
          ),
          Gap.m,
          DropdownButtonFormField<String>(
            initialValue: rarities.contains(_item.rarity) ? _item.rarity : '',
            decoration: const InputDecoration(labelText: 'Rareza'),
            items: [for (final r in rarities) DropdownMenuItem(value: r, child: Text(rarityLabel(r)))],
            onChanged: (v) => setState(() => _item.rarity = v ?? ''),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Requiere vinculación'),
            value: _item.requiresAttunement,
            onChanged: (v) => setState(() => _item.requiresAttunement = v),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _damage,
                  decoration: const InputDecoration(labelText: 'Daño (1d8 cortante)'),
                ),
              ),
              Gap.m,
              Expanded(
                child: TextField(
                  controller: _ac,
                  decoration: const InputDecoration(labelText: 'CA (armaduras)'),
                ),
              ),
            ],
          ),
          Gap.m,
          TextField(
            controller: _props,
            decoration: const InputDecoration(labelText: 'Propiedades'),
          ),
          Gap.m,
          TextField(
            controller: _charges,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Cargas máximas (vacío si no tiene)'),
          ),
          Gap.m,
          TextField(
            controller: _tags,
            decoration: const InputDecoration(
              labelText: 'Etiquetas para recetas',
              hintText: 'hierba, metal, componente…',
              helperText: 'Una receta que pida «hierba» aceptará cualquier objeto con esa etiqueta.',
            ),
          ),
          Gap.m,
          Text('Icono', style: t.titleSmall),
          Gap.s,
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final ic in itemIconChoices)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _item.icon = ic),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _item.iconName == ic ? AppColors.gold : AppColors.outlineSoft),
                      color: _item.iconName == ic ? AppColors.primaryContainer : null,
                    ),
                    child: GameIcon(ic, size: 26),
                  ),
                ),
            ],
          ),
          if (widget.dmMode) ...[
            const Divider(height: 32),
            Text('Opciones del máster', style: t.titleMedium?.copyWith(color: AppColors.gold)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ocultar peso a los jugadores'),
              value: _item.hideWeight,
              onChanged: (v) => setState(() => _item.hideWeight = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ocultar valor a los jugadores'),
              value: _item.hideValue,
              onChanged: (v) => setState(() => _item.hideValue = v),
            ),
            TextField(
              controller: _dmNote,
              minLines: 2,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Nota secreta del máster',
                helperText: 'P. ej. la verdadera naturaleza del objeto. Los jugadores nunca la ven.',
              ),
            ),
          ],
          Gap.l,
          FilledButton(onPressed: _save, child: const Text('Guardar')),
        ],
      ),
    );
  }
}
