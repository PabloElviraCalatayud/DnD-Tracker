import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';
import '../../core/i18n.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppScaffold(
      title: tr('Créditos y licencias'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(child: GameIcon('dragon_spiral', size: 90)),
          Gap.m,
          Text(
            tr('DnD Tracker'),
            textAlign: TextAlign.center,
            style: t.headlineSmall?.copyWith(color: AppColors.gold),
          ),
          Text(
            tr('Aplicación no oficial para gestionar partidas de rol de quinta edición.'),
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          Gap.l,
          SectionCard(
            title: tr('Reglas y contenido (SRD)'),
            icon: 'book',
            child: RichDescription(
              tr(
                'Esta obra incluye material del **System Reference Document 5.1 ("SRD 5.1")** y del **System Reference Document 5.2 ("SRD 5.2")** de Wizards of the Coast LLC, disponibles en https://dnd.wizards.com/resources/systems-reference-document. Ambos se distribuyen bajo la licencia Creative Commons Attribution 4.0 International (https://creativecommons.org/licenses/by/4.0/legalcode).\n\nLos datos se han obtenido del proyecto 5e-bits/5e-srd-api (licencia MIT).\n\nDnD Tracker no está afiliada, respaldada ni patrocinada por Wizards of the Coast.',
              ),
            ),
          ),
          SectionCard(
            title: tr('Iconos'),
            icon: 'sparkles',
            child: const RichDescription(
              'Iconos de **game-icons.net** creados por Lorc, Delapouite, Skoll, Sbed, Carl Olsen, Willdabeast, '
              'Faithtoken, Zeromancer, Kier Heyl y otros autores, bajo licencia Creative Commons Attribution 3.0 '
              '(https://creativecommons.org/licenses/by/3.0/). Lista completa en assets/icons/CREDITS.md.',
            ),
          ),
          SectionCard(
            title: tr('Tipografías'),
            icon: 'quill',
            child: RichDescription(
              tr(
                '**Cinzel** y **Cinzel Decorative** (Natanael Gama) y **Alegreya Sans** (Huerta Tipográfica), bajo la SIL Open Font License 1.1.',
              ),
            ),
          ),
          SectionCard(
            title: tr('Texturas'),
            icon: 'stone',
            child: Text(tr('La textura de fondo se genera por procedimiento con tool/make_texture.py (obra propia).')),
          ),
          Gap.m,
          OutlinedButton.icon(
            icon: const Icon(Icons.description_outlined),
            label: Text(tr('Licencias de las librerías')),
            onPressed: () => showLicensePage(context: context, applicationName: 'DnD Tracker'),
          ),
        ],
      ),
    );
  }
}
