import 'package:flutter/material.dart';

import '../../../domain/character.dart';
import '../../../domain/currency.dart';
import '../../../domain/item.dart';
import '../../../engine/commands.dart';
import '../../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../character/character_views.dart';
import '../character/item_dialogs.dart';

/// Biblioteca de objetos del máster y reparto de botín.
class ItemsScreen extends StatelessWidget {
  const ItemsScreen({super.key});

  Future<void> _newItem(BuildContext context) async {
    final s = SessionScope.read(context);
    final item = await showItemForm(context, dmMode: true, title: 'Nuevo objeto personalizado');
    if (item == null) return;
    item.custom = true;
    await s.send(Command.putLibraryItem(item));
  }

  Future<void> _fromSrd(BuildContext context) async {
    final s = SessionScope.read(context);
    final picked = await pickSrdItem(context, s.campaign.ruleset, title: 'Repartir objeto del SRD');
    if (picked == null || !context.mounted) return;
    final item = picked.$1.toInventoryItem(quantity: picked.$2);
    item.hideWeight = s.campaign.settings.hideItemWeights;
    item.hideValue = s.campaign.settings.hideItemValues;
    await giveItemDialog(context, item);
  }

  Future<void> _splitGold(BuildContext context) async {
    final s = SessionScope.read(context);
    final pcs = s.campaign.characters.where((c) => c.ownerId != s.myUserId).toList();
    if (pcs.isEmpty) {
      showSnack(context, 'No hay personajes de jugadores', error: true);
      return;
    }
    final selected = pcs.map((c) => c.id).toSet();
    final amount = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Repartir dinero'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amount,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Cantidad total', hintText: '250 po'),
              ),
              Gap.s,
              for (final c in pcs)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: selected.contains(c.id),
                  title: Text(c.name),
                  onChanged: (v) => setState(() => v == true ? selected.add(c.id) : selected.remove(c.id)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Repartir')),
          ],
        ),
      ),
    );
    if (ok != true || selected.isEmpty) return;
    final total = parseCost(amount.text);
    if (total == null || total <= 0) {
      if (context.mounted) showSnack(context, 'Cantidad no válida', error: true);
      return;
    }
    final share = total ~/ selected.length;
    for (final id in selected) {
      await s.editCharacter(id, (c) {
        c.currency.gp += share ~/ 100;
        c.currency.sp += (share % 100) ~/ 10;
        c.currency.cp += share % 10;
      });
    }
    if (context.mounted) showSnack(context, 'Cada personaje recibe ${formatCp(share)}');
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final lib = s.campaign.itemLibrary;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newItem(context),
        icon: const Icon(Icons.add),
        label: const Text('Objeto personalizado'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _fromSrd(context),
                icon: const GameIcon('book', size: 18),
                label: const Text('Dar objeto del SRD'),
              ),
              OutlinedButton.icon(
                onPressed: () => _splitGold(context),
                icon: const GameIcon('coins', size: 18),
                label: const Text('Repartir dinero'),
              ),
            ],
          ),
          Gap.m,
          Text('Tu biblioteca de objetos', style: t.titleLarge),
          Text(
            'Crea objetos una vez y entrégalos a quien quieras. Puedes ocultar su peso y valor.',
            style: t.bodySmall,
          ),
          Gap.s,
          if (lib.isEmpty)
            const EmptyState(
              icon: 'open_chest',
              title: 'Biblioteca vacía',
              message: 'Pulsa «Objeto personalizado» para crear el primero.',
            )
          else
            Card(
              child: Column(
                children: [
                  for (final i in lib)
                    ItemTile(
                      item: i,
                      showShared: false,
                      onTap: () async {
                        final edited = await showItemForm(context, initial: i, dmMode: true, title: 'Editar ${i.name}');
                        if (edited != null) await s.send(Command.putLibraryItem(edited));
                      },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Entregar',
                            icon: const Icon(Icons.card_giftcard, color: AppColors.gold),
                            onPressed: () => giveItemDialog(context, i.copy()..templateId = i.id),
                          ),
                          IconButton(
                            tooltip: 'Borrar de la biblioteca',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final ok = await confirm(
                                context,
                                'Borrar',
                                '¿Borrar ${i.name} de la biblioteca? '
                                    'Los que ya tienen los jugadores no cambian.',
                                danger: true,
                              );
                              if (ok) await s.send(Command.deleteLibraryItem(i.id));
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Elige a qué personajes entregar un objeto.
Future<void> giveItemDialog(BuildContext context, InventoryItem item) async {
  final s = SessionScope.read(context);
  final chars = s.campaign.characters;
  if (chars.isEmpty) {
    showSnack(context, 'No hay personajes a los que dar objetos', error: true);
    return;
  }
  final selected = <String>{};
  var qty = item.quantity;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text('Entregar ${item.name}'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('Cantidad a cada uno'),
                    const Spacer(),
                    NumberStepper(value: qty, min: 1, onChanged: (v) => setState(() => qty = v)),
                  ],
                ),
                const Divider(),
                for (final Character c in chars)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selected.contains(c.id),
                    title: Text(c.name),
                    subtitle: Text(s.campaign.memberName(c.ownerId)),
                    onChanged: (v) => setState(() => v == true ? selected.add(c.id) : selected.remove(c.id)),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx, true),
            child: const Text('Entregar'),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return;
  for (final id in selected) {
    final r = await s.send(Command.giveItem(id, item.copy(quantity: qty)));
    if (!r.ok && context.mounted) showSnack(context, r.error ?? 'Error', error: true);
  }
  if (context.mounted) showSnack(context, '${item.name} entregado a ${selected.length} personaje(s)');
}

/// Para abrir la ficha desde otras pantallas del máster.
void openCharacter(BuildContext context, String id) => openCharacterDetail(context, id);
