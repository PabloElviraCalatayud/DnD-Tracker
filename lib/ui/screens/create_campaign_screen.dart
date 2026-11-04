import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/campaign.dart';
import '../../domain/chat.dart';
import '../../domain/ruleset.dart';
import '../../state/providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../../core/i18n.dart';

class CreateCampaignScreen extends ConsumerStatefulWidget {
  const CreateCampaignScreen({super.key});

  @override
  ConsumerState<CreateCampaignScreen> createState() => _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends ConsumerState<CreateCampaignScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  Ruleset _ruleset = Ruleset.v2024;
  final _settings = CampaignSettings();

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showSnack(context, tr('Ponle un nombre a la partida'), error: true);
      return;
    }
    final profile = ref.read(profileProvider);
    final c = Campaign(
      name: name,
      description: _description.text.trim(),
      ruleset: _ruleset,
      dmUserId: profile.userId,
      dmName: profile.displayName,
      settings: _settings,
      chat: ChatState(),
    );
    c.addLog(tr('Partida creada ({0})', [_ruleset.label]), actor: profile.displayName);
    await ref.read(storageProvider).saveHosted(c);
    if (mounted) Navigator.pop(context, c);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppScaffold(
      title: tr('Nueva partida'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: tr('Nombre de la partida'), hintText: tr('La maldición de Strahd')),
          ),
          Gap.m,
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(labelText: tr('Descripción (opcional)')),
          ),
          Gap.l,
          Text(tr('Edición de reglas'), style: t.titleLarge),
          Gap.s,
          Row(
            children: [
              Expanded(
                child: _rulesetCard(
                  Ruleset.v2014,
                  'scroll',
                  'SRD 5.1 · Manual del Jugador 2014.\nRazas, '
                      'aumentos de característica por raza, cansancio clásico.',
                ),
              ),
              Gap.m,
              Expanded(
                child: _rulesetCard(
                  Ruleset.v2024,
                  'spell_book',
                  'SRD 5.2 · Manual del Jugador 2024.\n'
                      'Especies, trasfondos con características, maestrías de armas.',
                ),
              ),
            ],
          ),
          Gap.s,
          Text(tr('Podrás cambiarla más adelante desde los ajustes de la partida.'), style: t.bodySmall),
          Gap.l,
          Text(tr('Opciones iniciales'), style: t.titleLarge),
          SwitchListTile(
            title: Text(tr('Ocultar el peso de los objetos a los jugadores')),
            value: _settings.hideItemWeights,
            onChanged: (v) => setState(() => _settings.hideItemWeights = v),
          ),
          SwitchListTile(
            title: Text(tr('Ocultar el valor de los objetos a los jugadores')),
            value: _settings.hideItemValues,
            onChanged: (v) => setState(() => _settings.hideItemValues = v),
          ),
          Gap.l,
          FilledButton.icon(onPressed: _create, icon: const Icon(Icons.check), label: Text(tr('Crear partida'))),
        ],
      ),
    );
  }

  Widget _rulesetCard(Ruleset r, String icon, String text) {
    final selected = _ruleset == r;
    final t = Theme.of(context).textTheme;
    return Card(
      color: selected ? AppColors.primaryContainer.withValues(alpha: 0.6) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? AppColors.gold : AppColors.outlineSoft, width: selected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _ruleset = r),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GameIcon(icon, size: 30, color: selected ? AppColors.gold : AppColors.muted),
                  Gap.s,
                  Expanded(
                    child: Text(r.short, style: t.headlineSmall?.copyWith(color: AppColors.gold)),
                  ),
                  if (selected) const Icon(Icons.check_circle, color: AppColors.gold),
                ],
              ),
              Gap.xs,
              Text(r.label, style: t.titleSmall),
              Gap.xs,
              Text(text, style: t.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
