import 'package:flutter/material.dart';

import '../../state/client_session.dart';
import '../../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'character/character_editor.dart';
import 'board/board_screen.dart';
import 'character/character_views.dart';
import 'dm/bestiary_screen.dart';
import 'dm/campaign_settings_screen.dart';
import 'dm/characters_screen.dart';
import 'dm/dashboard_screen.dart';
import 'dm/items_screen.dart';
import 'dm/recipes_screen.dart';
import 'player/party_screen.dart';
import 'shared/chat_screen.dart';
import 'shared/dice_roller.dart';
import 'shared/initiative_screen.dart';
import 'shared/notes_screen.dart';
import 'shared/reference_screen.dart';
import '../../core/i18n.dart';

class _Section {
  _Section(this.label, this.icon, this.builder, {this.badge = false});
  final String label;
  final String icon;
  final WidgetBuilder builder;
  final bool badge;
}

/// Pantalla principal de una partida: navegación adaptable a móvil y escritorio.
class CampaignShell extends StatefulWidget {
  const CampaignShell({super.key, required this.session});
  final GameSession session;

  @override
  State<CampaignShell> createState() => _CampaignShellState();
}

class _CampaignShellState extends State<CampaignShell> {
  int _index = 0;

  @override
  void dispose() {
    widget.session.close();
    super.dispose();
  }

  List<_Section> _sections(GameSession s) {
    if (s.isDm) {
      return [
        // Las cuatro primeras van en la barra inferior del móvil.
        _Section(tr('Tablero'), 'treasure_map', (_) => const BoardScreen()),
        _Section(tr('Resumen'), 'castle', (_) => const DashboardScreen()),
        _Section(tr('Combate'), 'crossed_swords', (_) => const InitiativeScreen()),
        _Section(tr('Chat'), 'conversation', (_) => const ChatScreen(), badge: true),
        _Section(tr('Grimorio'), 'dragon', (_) => const BestiaryScreen()),
        _Section(tr('Personajes'), 'party', (_) => const CharactersScreen()),
        _Section(tr('Objetos'), 'open_chest', (_) => const ItemsScreen()),
        _Section(tr('Artesanía'), 'anvil', (_) => const RecipesScreen()),
        _Section(tr('Notas'), 'quill', (_) => const NotesScreen()),
        _Section(tr('Referencia'), 'book', (_) => const ReferenceScreen()),
        _Section(tr('Partida'), 'settings', (_) => const CampaignSettingsScreen()),
      ];
    }
    return [
      _Section(tr('Tablero'), 'treasure_map', (_) => const BoardScreen()),
      _Section(tr('Ficha'), 'hood', (_) => const _PlayerCharacterSection(view: CharacterView.sheet)),
      _Section(tr('Inventario'), 'backpack', (_) => const _PlayerCharacterSection(view: CharacterView.inventory)),
      _Section(tr('Conjuros'), 'spell_book', (_) => const _PlayerCharacterSection(view: CharacterView.spells)),
      _Section(tr('Chat'), 'conversation', (_) => const ChatScreen(), badge: true),
      _Section(tr('Artesanía'), 'anvil', (_) => const _PlayerCharacterSection(view: CharacterView.crafting)),
      _Section(tr('Grupo'), 'party', (_) => const PartyScreen()),
      _Section(tr('Combate'), 'crossed_swords', (_) => const InitiativeScreen()),
      _Section(tr('Notas'), 'quill', (_) => const NotesScreen()),
      _Section(tr('Referencia'), 'book', (_) => const ReferenceScreen()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: widget.session,
      child: Builder(
        builder: (context) {
          final s = SessionScope.of(context);
          final sections = _sections(s);
          if (_index >= sections.length) _index = 0;
          final wide = MediaQuery.sizeOf(context).width >= 900;
          final extended = MediaQuery.sizeOf(context).width >= 1280;
          final current = sections[_index];
          final body = Column(
            children: [
              const _ConnectionBanner(),
              Expanded(
                child: KeyedSubtree(key: ValueKey(current.label), child: current.builder(context)),
              ),
            ],
          );
          return Scaffold(
            appBar: AppBar(
              title: _Title(section: current.label),
              actions: [
                if (!s.isDm && s.myCharacters.length > 1) const _CharacterSwitcher(),
                IconButton(
                  tooltip: tr('Tirar dados'),
                  icon: const GameIcon('d20', size: 24),
                  onPressed: () => showDiceRoller(context),
                ),
              ],
            ),
            body: Backdrop(
              child: wide
                  ? Row(
                      children: [
                        NavigationRail(
                          extended: extended,
                          selectedIndex: _index,
                          onDestinationSelected: (i) => setState(() => _index = i),
                          labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                          destinations: [
                            for (final sec in sections)
                              NavigationRailDestination(
                                icon: _NavIcon(section: sec, selected: false),
                                selectedIcon: _NavIcon(section: sec, selected: true),
                                label: Text(sec.label),
                              ),
                          ],
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(child: body),
                      ],
                    )
                  : body,
            ),
            bottomNavigationBar: wide ? null : _bottomBar(context, sections),
          );
        },
      ),
    );
  }

  Widget _bottomBar(BuildContext context, List<_Section> sections) {
    const primary = 4;
    final inMore = _index >= primary;
    return NavigationBar(
      selectedIndex: inMore ? primary : _index,
      onDestinationSelected: (i) async {
        if (i < primary) {
          setState(() => _index = i);
          return;
        }
        final chosen = await showModalBottomSheet<int>(
          context: context,
          builder: (ctx) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (var j = primary; j < sections.length; j++)
                  ListTile(
                    leading: GameIcon(sections[j].icon, size: 26),
                    title: Text(sections[j].label),
                    selected: j == _index,
                    onTap: () => Navigator.pop(ctx, j),
                  ),
              ],
            ),
          ),
        );
        if (chosen != null) setState(() => _index = chosen);
      },
      destinations: [
        for (var j = 0; j < primary; j++)
          NavigationDestination(
            icon: _NavIcon(section: sections[j], selected: false),
            selectedIcon: _NavIcon(section: sections[j], selected: true),
            label: sections[j].label,
          ),
        NavigationDestination(
          icon: Builder(
            builder: (context) {
              final s = SessionScope.of(context);
              final hiddenBadge = sections.skip(primary).any((x) => x.badge) && s.totalUnread > 0;
              const icon = Icon(Icons.more_horiz);
              return hiddenBadge ? Badge(label: Text('${s.totalUnread}'), child: icon) : icon;
            },
          ),
          label: inMore ? sections[_index].label : tr('Más'),
        ),
      ],
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.section, required this.selected});
  final _Section section;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final icon = GameIcon(section.icon, size: 24, color: selected ? AppColors.gold : AppColors.muted);
    if (!section.badge || s.totalUnread == 0) return icon;
    return Badge(label: Text('${s.totalUnread}'), child: icon);
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.section});
  final String section;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(s.campaign.name, overflow: TextOverflow.ellipsis),
        Row(
          children: [
            Text('$section · ${s.campaign.ruleset.short} · ', style: t.labelMedium?.copyWith(color: AppColors.muted)),
            Icon(Icons.circle, size: 9, color: _statusColor(s.status)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                s.isDm ? tr('{0} conectados', [s.onlineCount]) : s.status.label,
                style: t.labelMedium?.copyWith(color: AppColors.muted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Color _statusColor(ConnectionStatus s) => switch (s) {
  ConnectionStatus.hosting || ConnectionStatus.online => AppColors.success,
  ConnectionStatus.connecting => AppColors.warning,
  _ => AppColors.danger,
};

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner();

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    if (s.isDm || s.status == ConnectionStatus.online) return const SizedBox.shrink();
    final fatal = s.status == ConnectionStatus.denied || s.status == ConnectionStatus.kicked;
    final color = fatal ? AppColors.crimson : AppColors.warning;
    return Material(
      color: color.withValues(alpha: 0.18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(fatal ? Icons.block : Icons.wifi_off, color: color, size: 20),
            Gap.s,
            Expanded(
              child: Text(
                [s.status.label, if (s.statusMessage.isNotEmpty) s.statusMessage].join(' · '),
                style: TextStyle(color: color),
              ),
            ),
            if (s is ClientSession)
              TextButton(
                onPressed: fatal ? () => Navigator.pop(context) : s.retryNow,
                child: Text(fatal ? tr('Salir') : tr('Reintentar')),
              ),
          ],
        ),
      ),
    );
  }
}

class _CharacterSwitcher extends StatelessWidget {
  const _CharacterSwitcher();

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final active = s.activeCharacter;
    return PopupMenuButton<String>(
      tooltip: tr('Cambiar de personaje'),
      icon: GameIcon(active?.portrait ?? 'hood', size: 26),
      onSelected: s.selectCharacter,
      itemBuilder: (_) => [
        for (final c in s.myCharacters) PopupMenuItem(value: c.id, child: Text('${c.name} (${c.classSummary})')),
      ],
    );
  }
}

/// Sección del jugador que muestra una parte de su personaje activo.
class _PlayerCharacterSection extends StatelessWidget {
  const _PlayerCharacterSection({required this.view});
  final CharacterView view;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final c = s.activeCharacter;
    if (c == null) {
      final waiting = s is ClientSession && !s.hasData && s.status != ConnectionStatus.online;
      return EmptyState(
        icon: 'hood',
        title: waiting ? tr('Conectando con el máster…') : tr('Aún no tienes personaje'),
        message: waiting
            ? tr('En cuanto conecte verás tu ficha. Si ya jugaste antes, se usará la última copia guardada.')
            : tr('Crea tu personaje para esta partida. El máster lo verá al instante.'),
        action: waiting
            ? null
            : FilledButton.icon(
                onPressed: s.canEdit ? () => openCharacterEditor(context, null) : null,
                icon: const Icon(Icons.add),
                label: Text(tr('Crear personaje')),
              ),
      );
    }
    return CharacterViewBody(characterId: c.id, view: view);
  }
}
