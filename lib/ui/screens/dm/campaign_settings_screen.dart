import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/campaign.dart';
import '../../../domain/ruleset.dart';
import '../../../engine/commands.dart';
import '../../../state/host_session.dart';
import '../../../state/providers.dart';
import '../../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'invite_panel.dart';
import '../../../core/i18n.dart';

/// Ajustes de la partida, conexión, jugadores y registro.
class CampaignSettingsScreen extends ConsumerWidget {
  const CampaignSettingsScreen({super.key});

  Future<void> _update(BuildContext context, void Function(CampaignSettings s) change) async {
    final s = SessionScope.read(context);
    final copy = s.campaign.settings.copy();
    change(copy);
    await s.send(Command.putSettings(copy));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = SessionScope.of(context) as HostSession;
    final c = s.campaign;
    final st = c.settings;
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const InvitePanel(),
        SectionCard(
          title: tr('Jugar por internet / datos móviles'),
          icon: 'globe',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichDescription(
                tr(
                  '- **Misma wifi** (o el máster comparte datos con su móvil y los demás se conectan a esa zona wifi): funciona tal cual, sin gastar datos.\n- **Cada uno en su casa o con datos móviles**: instalad **Tailscale** (gratis) en todos los dispositivos e iniciad sesión en la misma red. La invitación incluirá la IP 100.x del máster.\n- **Sin instalar nada más**: usad un **relay** (un pequeño servidor que reenvía mensajes, ver la carpeta relay/ del proyecto). Escribe aquí su dirección.',
                ),
              ),
              Gap.m,
              _RelayField(session: s),
            ],
          ),
        ),
        SectionCard(
          title: tr('Partida'),
          icon: 'castle',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(c.name),
                subtitle: Text(c.description.isEmpty ? tr('Sin descripción') : c.description),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final name = await promptText(context, tr('Nombre de la partida'), initial: c.name);
                  if (name == null || !context.mounted) return;
                  final desc = await promptText(context, tr('Descripción'), initial: c.description, multiline: true);
                  await s.send(Command.putSettings(st.copy(), name: name, description: desc ?? c.description));
                },
              ),
              Text(tr('Edición de reglas'), style: t.titleSmall),
              Gap.s,
              SegmentedButton<Ruleset>(
                segments: [for (final r in Ruleset.values) ButtonSegment(value: r, label: Text(r.label))],
                selected: {c.ruleset},
                onSelectionChanged: (v) async {
                  final ok = await confirm(
                    context,
                    tr('Cambiar edición'),
                    tr(
                      'Las fichas se conservan, pero las reglas automáticas (descansos, cansancio, artesanía, conjuros preparados) y los datos SRD pasarán a {0}.',
                      [v.first.label],
                    ),
                  );
                  if (ok) await s.send(Command.putSettings(st.copy(), ruleset: v.first));
                },
              ),
            ],
          ),
        ),
        SectionCard(
          title: tr('Qué ven los jugadores'),
          icon: 'eye_target',
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Ocultar el peso de todos los objetos')),
                subtitle: Text(tr('También puedes ocultarlo objeto a objeto')),
                value: st.hideItemWeights,
                onChanged: (v) => _update(context, (x) => x.hideItemWeights = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Ocultar el valor de todos los objetos')),
                value: st.hideItemValues,
                onChanged: (v) => _update(context, (x) => x.hideItemValues = v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.favorite_outline, color: AppColors.gold),
                title: Text(tr('Los PG y estados de los personajes jugadores los ve todo el grupo.')),
                subtitle: Text(
                  tr('Los PG de los enemigos sólo los ves tú: describe su estado con etiquetas desde el tablero.'),
                ),
              ),
            ],
          ),
        ),
        SectionCard(
          title: tr('Reglas de la mesa'),
          icon: 'scroll',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<EncumbranceRule>(
                initialValue: st.encumbrance,
                decoration: InputDecoration(labelText: tr('Carga')),
                items: [for (final e in EncumbranceRule.values) DropdownMenuItem(value: e, child: Text(e.label))],
                onChanged: (v) => _update(context, (x) => x.encumbrance = v ?? x.encumbrance),
              ),
              Gap.s,
              DropdownButtonFormField<DiagonalRule>(
                initialValue: st.diagonals,
                decoration: InputDecoration(labelText: tr('Diagonales en el tablero (1 casilla = 5 pies)')),
                items: [for (final d in DiagonalRule.values) DropdownMenuItem(value: d, child: Text(d.label))],
                onChanged: (v) => _update(context, (x) => x.diagonals = v ?? x.diagonals),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Las monedas pesan (50 = 1 lb)')),
                value: st.countCoinWeight,
                onChanged: (v) => _update(context, (x) => x.countCoinWeight = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Permitir fabricar objetos mágicos con las reglas estándar')),
                value: st.allowMagicCrafting,
                onChanged: (v) => _update(context, (x) => x.allowMagicCrafting = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Los jugadores pueden crear sus propias recetas')),
                value: st.playersCanCreateRecipes,
                onChanged: (v) => _update(context, (x) => x.playersCanCreateRecipes = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Los jugadores pueden darse objetos y dinero')),
                value: st.playersCanTrade,
                onChanged: (v) => _update(context, (x) => x.playersCanTrade = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Admitir jugadores nuevos')),
                subtitle: Text(tr('Desactívalo cuando el grupo esté completo')),
                value: st.allowNewPlayers,
                onChanged: (v) => _update(context, (x) => x.allowNewPlayers = v),
              ),
            ],
          ),
        ),
        SectionCard(
          title: tr('Jugadores ({0}/{1})', [c.members.where((m) => !m.banned).length, Campaign.maxPlayers]),
          icon: 'party',
          child: c.members.isEmpty
              ? Text(tr('Nadie se ha unido todavía.'), style: t.bodySmall)
              : Column(
                  children: [
                    for (final m in c.members)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.circle,
                          size: 12,
                          color: m.banned
                              ? AppColors.danger
                              : (s.onlineUserIds.contains(m.userId) ? AppColors.success : AppColors.outline),
                        ),
                        title: Text(m.name),
                        subtitle: Text(
                          m.banned ? tr('Expulsado') : c.charactersOf(m.userId).map((x) => x.name).join(', '),
                        ),
                        trailing: m.banned
                            ? TextButton(
                                onPressed: () => s.send(Command.unbanMember(m.userId)),
                                child: Text(tr('Readmitir')),
                              )
                            : TextButton(
                                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                                onPressed: () async {
                                  final ok = await confirm(
                                    context,
                                    tr('Expulsar'),
                                    tr('¿Expulsar a {0}? Sus personajes se conservan.', [m.name]),
                                    ok: tr('Expulsar'),
                                    danger: true,
                                  );
                                  if (ok) await s.send(Command.kickMember(m.userId));
                                },
                                child: Text(tr('Expulsar')),
                              ),
                      ),
                  ],
                ),
        ),
        SectionCard(
          title: tr('Copias de seguridad'),
          icon: 'backup',
          child: Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.save_alt),
                label: Text(tr('Exportar partida')),
                onPressed: () async {
                  await s.saveNow();
                  final path = await ref.read(storageProvider).exportCampaign(c);
                  if (context.mounted) showSnack(context, tr('Guardada en {0}', [path]));
                },
              ),
            ],
          ),
        ),
        SectionCard(
          title: tr('Registro completo'),
          icon: 'scroll',
          child: SizedBox(
            height: 300,
            child: ListView(
              children: [
                for (final e in c.log.reversed)
                  Text(
                    '${DateTime.fromMillisecondsSinceEpoch(e.ts).toString().substring(0, 16)}  ${e.text}',
                    style: t.bodySmall?.copyWith(color: AppColors.parchment),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RelayField extends StatefulWidget {
  const _RelayField({required this.session});
  final HostSession session;

  @override
  State<_RelayField> createState() => _RelayFieldState();
}

class _RelayFieldState extends State<_RelayField> {
  late final _ctrl = TextEditingController(text: widget.session.relayUrl);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            decoration: InputDecoration(labelText: tr('URL del relay'), hintText: tr('wss://mi-relay.ejemplo.com')),
          ),
        ),
        Gap.s,
        FilledButton(
          onPressed: () async {
            await widget.session.setRelayUrl(_ctrl.text);
            if (context.mounted) {
              showSnack(
                context,
                _ctrl.text.trim().isEmpty
                    ? tr('Relay desactivado')
                    : tr('Conectando al relay… Vuelve a copiar la invitación.'),
              );
            }
          },
          child: Text(tr('Aplicar')),
        ),
      ],
    );
  }
}
