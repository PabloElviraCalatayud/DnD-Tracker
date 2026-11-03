import 'package:flutter/material.dart';

import '../../../engine/commands.dart';
import '../../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../character/character_editor.dart';
import '../character/character_views.dart';

/// Lista de todos los personajes de la partida (jugadores y PNJ).
class CharactersScreen extends StatelessWidget {
  const CharactersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final c = s.campaign;
    final t = Theme.of(context).textTheme;
    final players = c.members.where((m) => !m.banned).toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openCharacterEditor(context, null),
        icon: const Icon(Icons.person_add),
        label: const Text('Personaje / PNJ'),
      ),
      body: c.characters.isEmpty
          ? const EmptyState(
              icon: 'party',
              title: 'Sin personajes',
              message:
                  'Los jugadores crean los suyos al unirse. Tú puedes crear PNJ o preparar fichas y '
                  'asignárselas después a un jugador.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                for (final ch in c.characters)
                  Card(
                    child: ListTile(
                      leading: GameIcon(ch.portrait, size: 34),
                      title: Text(ch.name, style: t.titleMedium),
                      subtitle: Text(
                        '${ch.classSummary} · ${ch.ownerId == s.myUserId ? 'PNJ (tuyo)' : c.memberName(ch.ownerId)}'
                        ' · PG ${ch.hpCurrent}/${ch.hpMax}',
                      ),
                      onTap: () => openCharacterDetail(context, ch.id),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'assign') {
                            final owner = await showDialog<String>(
                              context: context,
                              builder: (ctx) => SimpleDialog(
                                title: Text('¿De quién es ${ch.name}?'),
                                children: [
                                  SimpleDialogOption(
                                    onPressed: () => Navigator.pop(ctx, s.myUserId),
                                    child: const Text('Mío (PNJ)'),
                                  ),
                                  for (final m in players)
                                    SimpleDialogOption(
                                      onPressed: () => Navigator.pop(ctx, m.userId),
                                      child: Text(m.name),
                                    ),
                                ],
                              ),
                            );
                            if (owner != null) await s.send(Command.assignCharacter(ch.id, owner));
                          } else if (v == 'delete') {
                            final ok = await confirm(
                              context,
                              'Eliminar personaje',
                              '¿Eliminar a ${ch.name} con todo su inventario? No se puede deshacer.',
                              ok: 'Eliminar',
                              danger: true,
                            );
                            if (ok) await s.send(Command.deleteCharacter(ch.id));
                          } else if (v == 'edit') {
                            if (context.mounted) await openCharacterEditor(context, ch);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Editar ficha')),
                          PopupMenuItem(value: 'assign', child: Text('Asignar a un jugador')),
                          PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                        ],
                      ),
                    ),
                  ),
                Gap.s,
                Text(
                  'Consejo: si un jugador cambia de móvil, se unirá como jugador nuevo; asígnale su personaje '
                  'desde este menú.',
                  style: t.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
    );
  }
}
