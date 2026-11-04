import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/profile.dart';
import '../../state/providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../../core/i18n.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _name = TextEditingController();
  UnitSystem _units = UnitSystem.metric;
  late AppLanguage _language = ref.read(profileProvider).language;
  ThemeChoice _theme = ThemeChoice.dungeon;

  Future<void> _continue() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final p = ref.read(profileProvider).copy()
      ..displayName = name
      ..units = _units
      ..language = _language
      ..theme = _theme;
    await ref.read(profileProvider.notifier).save(p);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppScaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                // Selector de idioma arriba del todo.
                key: ValueKey(_language),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: GameIcon('dragon', size: 110, color: AppColors.gold)),
                  Gap.m,
                  Text(
                    tr('DnD Tracker'),
                    textAlign: TextAlign.center,
                    style: t.displaySmall?.copyWith(fontFamily: 'CinzelDecorative', color: AppColors.gold),
                  ),
                  Gap.s,
                  Text(
                    tr(
                      'Tu mesa de rol en el bolsillo: el máster lleva la partida y los jugadores se conectan desde su móvil u ordenador.',
                    ),
                    textAlign: TextAlign.center,
                    style: t.bodyLarge?.copyWith(color: AppColors.muted),
                  ),
                  Gap.l,
                  Text(tr('¿Cómo te llamas?'), style: t.titleLarge),
                  Gap.s,
                  TextField(
                    controller: _name,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(hintText: tr('Tu nombre (lo verán los demás jugadores)')),
                    onSubmitted: (_) => _continue(),
                  ),
                  Gap.l,
                  Text(tr('Idioma'), style: t.titleLarge),
                  Gap.s,
                  LanguageSelector(
                    value: _language,
                    onChanged: (v) => setState(() {
                      _language = v;
                      I18n.language = v;
                    }),
                  ),
                  Gap.l,
                  Text(tr('Tema'), style: t.titleLarge),
                  Gap.s,
                  ThemePicker(value: _theme, onChanged: (v) => setState(() => _theme = v)),
                  Gap.l,
                  Text(tr('Unidades'), style: t.titleLarge),
                  Gap.s,
                  RadioGroup<UnitSystem>(
                    groupValue: _units,
                    onChanged: (v) => setState(() => _units = v ?? _units),
                    child: Column(
                      children: [
                        for (final u in UnitSystem.values)
                          RadioListTile<UnitSystem>(value: u, title: Text(u.label), contentPadding: EdgeInsets.zero),
                      ],
                    ),
                  ),
                  Gap.l,
                  ListenableBuilder(
                    listenable: _name,
                    builder: (context, _) => FilledButton.icon(
                      onPressed: _name.text.trim().isEmpty ? null : _continue,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(tr('Empezar')),
                    ),
                  ),
                  Gap.m,
                  Text(
                    tr('Podrás ser máster en unas partidas y jugador en otras con el mismo perfil.'),
                    textAlign: TextAlign.center,
                    style: t.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
