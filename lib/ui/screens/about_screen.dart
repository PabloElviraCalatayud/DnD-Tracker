import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppScaffold(
      title: 'Créditos y licencias',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(child: GameIcon('dragon_spiral', size: 90)),
          Gap.m,
          Text(
            'DnD Tracker',
            textAlign: TextAlign.center,
            style: t.headlineSmall?.copyWith(color: AppColors.gold),
          ),
          Text(
            'Aplicación no oficial para gestionar partidas de rol de quinta edición.',
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          Gap.l,
          const SectionCard(
            title: 'Reglas y contenido (SRD)',
            icon: 'book',
            child: RichDescription(
              'Esta obra incluye material del **System Reference Document 5.1 ("SRD 5.1")** y del '
              '**System Reference Document 5.2 ("SRD 5.2")** de Wizards of the Coast LLC, disponibles en '
              'https://dnd.wizards.com/resources/systems-reference-document. Ambos se distribuyen bajo la '
              'licencia Creative Commons Attribution 4.0 International '
              '(https://creativecommons.org/licenses/by/4.0/legalcode).\n\n'
              'Los datos se han obtenido del proyecto 5e-bits/5e-srd-api (licencia MIT).\n\n'
              'DnD Tracker no está afiliada, respaldada ni patrocinada por Wizards of the Coast.',
            ),
          ),
          const SectionCard(
            title: 'Iconos',
            icon: 'sparkles',
            child: RichDescription(
              'Iconos de **game-icons.net** creados por Lorc, Delapouite, Skoll, Sbed, Carl Olsen, Willdabeast, '
              'Faithtoken, Zeromancer, Kier Heyl y otros autores, bajo licencia Creative Commons Attribution 3.0 '
              '(https://creativecommons.org/licenses/by/3.0/). Lista completa en assets/icons/CREDITS.md.',
            ),
          ),
          const SectionCard(
            title: 'Tipografías',
            icon: 'quill',
            child: RichDescription(
              '**Cinzel** y **Cinzel Decorative** (Natanael Gama) y **Alegreya Sans** (Huerta Tipográfica), '
              'bajo la SIL Open Font License 1.1.',
            ),
          ),
          const SectionCard(
            title: 'Texturas',
            icon: 'stone',
            child: Text('La textura de fondo se genera por procedimiento con tool/make_texture.py (obra propia).'),
          ),
          Gap.m,
          OutlinedButton.icon(
            icon: const Icon(Icons.description_outlined),
            label: const Text('Licencias de las librerías'),
            onPressed: () => showLicensePage(context: context, applicationName: 'DnD Tracker'),
          ),
        ],
      ),
    );
  }
}
