import 'package:flutter/material.dart';

import '../../../domain/currency.dart';
import '../../../domain/item.dart';
import '../../../domain/recipe.dart';
import '../../../engine/commands.dart';
import '../../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../character/item_dialogs.dart';

/// Recetas de artesanía de la partida.
class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final recipes = List.of(s.campaign.recipes)..sort((a, b) => a.name.compareTo(b.name));
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openRecipeEditor(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Receta'),
      ),
      body: recipes.isEmpty
          ? const EmptyState(
              icon: 'anvil',
              title: 'Sin recetas',
              message:
                  'Crea recetas de objetos personalizados (pociones, venenos, armas especiales…) y decide qué '
                  'personajes las conocen. La app comprobará si tienen los materiales.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                for (final r in recipes)
                  Card(
                    child: ListTile(
                      leading: GameIcon(r.result.iconName, size: 32),
                      title: Text(r.name),
                      subtitle: Text(
                        [
                          '${r.resultQuantity}× ${r.result.name}',
                          if (r.ingredients.isNotEmpty) r.ingredients.map((i) => '${i.quantity} ${i.name}').join(', '),
                          if (r.goldCostCp > 0) formatCp(r.goldCostCp),
                          r.availableToAll
                              ? 'todos'
                              : r.characterIds.map((id) => s.campaign.character(id)?.name ?? '?').join(', '),
                        ].join(' · '),
                      ),
                      onTap: () => openRecipeEditor(context, r),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final ok = await confirm(context, 'Borrar receta', '¿Borrar ${r.name}?', danger: true);
                          if (ok) await s.send(Command.deleteRecipe(r.id));
                        },
                      ),
                    ),
                  ),
                Text('Toca una receta para editarla.', style: t.bodySmall),
              ],
            ),
    );
  }
}

Future<void> openRecipeEditor(BuildContext context, Recipe? recipe, {String? forCharacterId}) {
  final s = SessionScope.read(context);
  return Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => SessionScope(
        session: s,
        child: _RecipeEditor(initial: recipe, forCharacterId: forCharacterId),
      ),
    ),
  );
}

class _RecipeEditor extends StatefulWidget {
  const _RecipeEditor({this.initial, this.forCharacterId});
  final Recipe? initial;
  final String? forCharacterId;

  @override
  State<_RecipeEditor> createState() => _RecipeEditorState();
}

class _RecipeEditorState extends State<_RecipeEditor> {
  late Recipe _r;
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _gold;
  late final TextEditingController _tool;
  late final TextEditingController _days;
  late final TextEditingController _check;

  @override
  void initState() {
    super.initState();
    _r =
        widget.initial?.copy() ??
        Recipe(
          name: '',
          result: InventoryItem(name: '', custom: true),
          characterIds: [?widget.forCharacterId],
        );
    _name = TextEditingController(text: _r.name);
    _desc = TextEditingController(text: _r.description);
    final cp = _r.goldCostCp;
    _gold = TextEditingController(
      text: cp == 0 ? '' : (cp % 100 == 0 ? '${cp ~/ 100} po' : (cp % 10 == 0 ? '${cp ~/ 10} pp' : '$cp pc')),
    );
    _tool = TextEditingController(text: _r.tool);
    _days = TextEditingController(text: _r.days == 0 ? '' : '${_r.days}');
    _check = TextEditingController(text: _r.check);
  }

  Future<void> _save() async {
    final s = SessionScope.read(context);
    final gold = parseCost(_gold.text);
    if (gold == null) {
      showSnack(context, 'Coste no válido (ej.: 25 po)', error: true);
      return;
    }
    _r
      ..name = _name.text.trim().isEmpty ? _r.result.name : _name.text.trim()
      ..description = _desc.text.trim()
      ..goldCostCp = gold
      ..tool = _tool.text.trim()
      ..days = int.tryParse(_days.text) ?? 0
      ..check = _check.text.trim();
    _r.ingredients.removeWhere((i) => i.name.trim().isEmpty);
    if (_r.result.name.trim().isEmpty) {
      showSnack(context, 'Define el objeto resultante', error: true);
      return;
    }
    final res = await s.send(Command.putRecipe(_r));
    if (!mounted) return;
    if (res.ok) {
      Navigator.pop(context);
    } else {
      showSnack(context, res.error ?? 'Error', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final t = Theme.of(context).textTheme;
    final chars = s.isDm ? s.campaign.characters : s.myCharacters;
    return AppScaffold(
      title: widget.initial == null ? 'Nueva receta' : 'Editar receta',
      actions: [TextButton(onPressed: _save, child: const Text('Guardar'))],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nombre de la receta'),
          ),
          Gap.m,
          TextField(
            controller: _desc,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Descripción / instrucciones'),
          ),
          Gap.l,
          Text('Resultado', style: t.titleMedium),
          Card(
            child: ListTile(
              leading: GameIcon(_r.result.iconName, size: 30),
              title: Text(_r.result.name.isEmpty ? 'Definir objeto…' : _r.result.name),
              subtitle: Text(
                _r.result.description.isEmpty ? 'Toca para editar' : _r.result.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () async {
                final choice = await showModalBottomSheet<String>(
                  context: context,
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(title: const Text('Objeto personalizado'), onTap: () => Navigator.pop(ctx, 'custom')),
                        ListTile(title: const Text('Objeto del SRD'), onTap: () => Navigator.pop(ctx, 'srd')),
                        if (s.isDm && s.campaign.itemLibrary.isNotEmpty)
                          ListTile(title: const Text('De mi biblioteca'), onTap: () => Navigator.pop(ctx, 'lib')),
                      ],
                    ),
                  ),
                );
                if (!context.mounted || choice == null) return;
                InventoryItem? item;
                if (choice == 'custom') {
                  item = await showItemForm(
                    context,
                    initial: _r.result.name.isEmpty ? null : _r.result,
                    dmMode: s.isDm,
                    title: 'Objeto resultante',
                  );
                } else if (choice == 'srd') {
                  final p = await pickSrdItem(context, s.campaign.ruleset);
                  item = p?.$1.toInventoryItem();
                } else {
                  item = await showDialog<InventoryItem>(
                    context: context,
                    builder: (ctx) => SimpleDialog(
                      children: [
                        for (final i in s.campaign.itemLibrary)
                          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, i.copy()), child: Text(i.name)),
                      ],
                    ),
                  );
                }
                if (item != null) {
                  setState(() {
                    _r.result = item!..quantity = 1;
                    if (_name.text.trim().isEmpty) _name.text = item.name;
                  });
                }
              },
            ),
          ),
          Row(
            children: [
              const Text('Cantidad que se obtiene'),
              const Spacer(),
              NumberStepper(value: _r.resultQuantity, min: 1, onChanged: (v) => setState(() => _r.resultQuantity = v)),
            ],
          ),
          Gap.l,
          Row(
            children: [
              Text('Materiales', style: t.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _r.ingredients.add(Ingredient(name: ''))),
                icon: const Icon(Icons.add),
                label: const Text('Añadir'),
              ),
            ],
          ),
          Text('Escribe el nombre exacto del objeto o una etiqueta (p. ej. «hierba»).', style: t.bodySmall),
          for (final ing in _r.ingredients)
            Padding(
              key: ObjectKey(ing),
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: ing.name,
                      decoration: const InputDecoration(labelText: 'Material'),
                      onChanged: (v) => ing.name = v,
                    ),
                  ),
                  NumberStepper(
                    compact: true,
                    value: ing.quantity,
                    min: 1,
                    onChanged: (v) => setState(() => ing.quantity = v),
                  ),
                  Tooltip(
                    message: 'Se gasta al fabricar',
                    child: Checkbox(value: ing.consumed, onChanged: (v) => setState(() => ing.consumed = v ?? true)),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _r.ingredients.remove(ing)),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          Gap.l,
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _gold,
                  decoration: const InputDecoration(labelText: 'Coste extra', hintText: '25 po'),
                ),
              ),
              Gap.m,
              Expanded(
                child: TextField(
                  controller: _days,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Días de trabajo', hintText: '0 = al momento'),
                ),
              ),
            ],
          ),
          Gap.m,
          TextField(
            controller: _tool,
            decoration: const InputDecoration(labelText: 'Herramienta necesaria', hintText: 'Útiles de alquimista'),
          ),
          Gap.m,
          TextField(
            controller: _check,
            decoration: const InputDecoration(labelText: 'Prueba (opcional)', hintText: 'CD 15 INT (Arcanos)'),
          ),
          Gap.l,
          Text('¿Quién conoce esta receta?', style: t.titleMedium),
          if (s.isDm)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Todos los personajes'),
              value: _r.availableToAll,
              onChanged: (v) => setState(() => _r.availableToAll = v),
            ),
          if (!_r.availableToAll)
            for (final c in chars)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _r.characterIds.contains(c.id),
                title: Text(c.name),
                onChanged: (v) => setState(() => v == true ? _r.characterIds.add(c.id) : _r.characterIds.remove(c.id)),
              ),
          Gap.l,
          FilledButton(onPressed: _save, child: const Text('Guardar receta')),
          if (!s.isDm)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'El máster verá tus recetas y puede editarlas.',
                style: t.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}
