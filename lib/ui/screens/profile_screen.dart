import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/profile.dart';
import '../../state/providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../../core/i18n.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late UserProfile _p;
  late final TextEditingController _name;
  late final TextEditingController _port;
  late final TextEditingController _relay;

  @override
  void initState() {
    super.initState();
    _p = ref.read(profileProvider).copy();
    _name = TextEditingController(text: _p.displayName);
    _port = TextEditingController(text: '${_p.hostPort}');
    _relay = TextEditingController(text: _p.relayUrl);
  }

  Future<void> _save() async {
    _p.displayName = _name.text.trim().isEmpty ? _p.displayName : _name.text.trim();
    _p.hostPort = int.tryParse(_port.text) ?? 4040;
    _p.relayUrl = _relay.text.trim();
    await ref.read(profileProvider.notifier).save(_p);
    if (mounted) {
      showSnack(context, tr('Perfil guardado'));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppScaffold(
      title: tr('Perfil y ajustes'),
      actions: [TextButton(onPressed: _save, child: Text(tr('Guardar')))],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: tr('Tú'),
            icon: 'person',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _name,
                  decoration: InputDecoration(labelText: tr('Nombre visible')),
                ),
                Gap.m,
                Text(tr('Idioma'), style: t.titleSmall),
                Gap.s,
                LanguageSelector(value: _p.language, onChanged: (v) => setState(() => _p.language = v)),
                Gap.m,
                Text(tr('Unidades'), style: t.titleSmall),
                RadioGroup<UnitSystem>(
                  groupValue: _p.units,
                  onChanged: (v) => setState(() => _p.units = v ?? _p.units),
                  child: Column(
                    children: [
                      for (final u in UnitSystem.values)
                        RadioListTile<UnitSystem>(value: u, title: Text(u.label), contentPadding: EdgeInsets.zero),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SectionCard(
            title: tr('Cuando eres máster (anfitrión)'),
            icon: 'wifi',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _port,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: tr('Puerto'),
                    helperText: tr('Por defecto 4040. Cámbialo sólo si está ocupado.'),
                  ),
                ),
                Gap.m,
                TextField(
                  controller: _relay,
                  decoration: InputDecoration(
                    labelText: tr('Relay para jugar por internet (opcional)'),
                    hintText: tr('wss://mi-relay.ejemplo.com'),
                    helperText: tr('Déjalo vacío si jugáis en la misma wifi o con Tailscale.'),
                    helperMaxLines: 2,
                  ),
                ),
              ],
            ),
          ),
          SectionCard(
            title: tr('Identidad del dispositivo'),
            icon: 'key',
            child: Text(
              tr(
                'Tu identificador: {0}\nCon él y una clave secreta guardada en este dispositivo el máster te reconoce al volver a conectar. Si cambias de dispositivo, el máster puede reasignarte tu personaje.',
                [_p.userId],
              ),
              style: t.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}
