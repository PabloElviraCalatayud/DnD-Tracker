import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/client_session.dart';
import '../../state/session.dart';
import '../../engine/commands.dart';
import '../layout.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'character/character_editor.dart';
import 'board/board_screen.dart';
import 'board/roll_feed.dart';
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
  _Section(this.label, this.icon, this.group, this.builder, {this.badge = false});
  final String label;
  final String icon;

  /// Grupo de la barra lateral de escritorio.
  final String group;
  final WidgetBuilder builder;
  final bool badge;
}

/// Pantalla principal de una partida. Tiene dos interfaces distintas: la de
/// PC (barra lateral agrupada, cabecera de sección, panel de tiradas y turnos a
/// la derecha y atajos de teclado) y la de móvil (barra inferior y pantallas
/// completas).
class CampaignShell extends StatefulWidget {
  const CampaignShell({super.key, required this.session});
  final GameSession session;

  @override
  State<CampaignShell> createState() => _CampaignShellState();
}

class _CampaignShellState extends State<CampaignShell> {
  int _index = 0;
  bool _sidebarCollapsed = false;

  /// Panel derecho: abierto por defecto en pantallas grandes.
  bool? _panelOpen;

  @override
  void dispose() {
    widget.session.close();
    super.dispose();
  }

  List<_Section> _sections(GameSession s) {
    final table = tr('Mesa');
    final lookup = tr('Consulta');
    if (s.isDm) {
      final run = tr('Dirección');
      return [
        // Las cuatro primeras van en la barra inferior del móvil.
        _Section(tr('Tablero'), 'treasure_map', table, (_) => const BoardScreen()),
        _Section(tr('Resumen'), 'castle', run, (_) => const DashboardScreen()),
        _Section(tr('Combate'), 'crossed_swords', table, (_) => const InitiativeScreen()),
        _Section(tr('Chat'), 'conversation', table, (_) => const ChatScreen(), badge: true),
        _Section(tr('Grimorio'), 'dragon', run, (_) => const BestiaryScreen()),
        _Section(tr('Personajes'), 'party', run, (_) => const CharactersScreen()),
        _Section(tr('Objetos'), 'open_chest', run, (_) => const ItemsScreen()),
        _Section(tr('Artesanía'), 'anvil', run, (_) => const RecipesScreen()),
        _Section(tr('Notas'), 'quill', lookup, (_) => const NotesScreen()),
        _Section(tr('Referencia'), 'book', lookup, (_) => const ReferenceScreen()),
        _Section(tr('Partida'), 'settings', tr('Ajustes'), (_) => const CampaignSettingsScreen()),
      ];
    }
    final mine = tr('Mi personaje');
    return [
      _Section(tr('Tablero'), 'treasure_map', table, (_) => const BoardScreen()),
      _Section(tr('Ficha'), 'hood', mine, (_) => const _PlayerCharacterSection(view: CharacterView.sheet)),
      _Section(tr('Inventario'), 'backpack', mine, (_) => const _PlayerCharacterSection(view: CharacterView.inventory)),
      _Section(tr('Conjuros'), 'spell_book', mine, (_) => const _PlayerCharacterSection(view: CharacterView.spells)),
      _Section(tr('Chat'), 'conversation', table, (_) => const ChatScreen(), badge: true),
      _Section(tr('Artesanía'), 'anvil', mine, (_) => const _PlayerCharacterSection(view: CharacterView.crafting)),
      _Section(tr('Grupo'), 'party', table, (_) => const PartyScreen()),
      _Section(tr('Combate'), 'crossed_swords', table, (_) => const InitiativeScreen()),
      _Section(tr('Notas'), 'quill', lookup, (_) => const NotesScreen()),
      _Section(tr('Referencia'), 'book', lookup, (_) => const ReferenceScreen()),
    ];
  }

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: widget.session,
      child: Builder(
        builder: (context) {
          final s = SessionScope.of(context);
          final sections = _sections(s);
          if (_index >= sections.length) _index = 0;
          return isDesktopLayout(context) ? _desktop(context, s, sections) : _mobile(context, s, sections);
        },
      ),
    );
  }

  // ---------------------------------------------------------------- escritorio

  Widget _desktop(BuildContext context, GameSession s, List<_Section> sections) {
    final width = MediaQuery.sizeOf(context).width;
    final current = sections[_index];
    final panelFits = width >= 1240;
    final panelOpen = _panelOpen ?? width >= 1440;
    final showPanel = panelFits && panelOpen;
    final collapsed = _sidebarCollapsed || width < 1080;
    final shortcuts = <ShortcutActivator, VoidCallback>{
      for (var i = 0; i < sections.length && i < 9; i++)
        SingleActivator(LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i), control: true): () => _go(i),
      const SingleActivator(LogicalKeyboardKey.keyD, control: true): () => showDiceRoller(context),
      const SingleActivator(LogicalKeyboardKey.period, control: true): () => setState(() => _panelOpen = !panelOpen),
    };
    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Backdrop(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Sidebar(
                  key: const ValueKey('sidebar'),
                  sections: sections,
                  index: _index,
                  collapsed: collapsed,
                  onSelect: _go,
                  onToggle: width < 1080 ? null : () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                  onCharacter: () {
                    final i = sections.indexWhere((x) => x.icon == 'hood');
                    if (i >= 0) _go(i);
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DesktopTopBar(
                        section: current,
                        panelFits: panelFits,
                        panelOpen: panelOpen,
                        onTogglePanel: () => setState(() => _panelOpen = !panelOpen),
                      ),
                      const _ConnectionBanner(),
                      Expanded(
                        child: ShellPanels(
                          rollsInSidePanel: showPanel,
                          child: KeyedSubtree(key: ValueKey(current.label), child: current.builder(context)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (showPanel) ...[
                  VerticalDivider(width: 1, color: AppColors.outlineSoft),
                  const SizedBox(width: 340, child: _SidePanel()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- móvil

  Widget _mobile(BuildContext context, GameSession s, List<_Section> sections) {
    final current = sections[_index];
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
        child: Column(
          children: [
            const _ConnectionBanner(),
            Expanded(
              child: KeyedSubtree(key: ValueKey(current.label), child: current.builder(context)),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _bottomBar(context, sections),
    );
  }

  Widget _bottomBar(BuildContext context, List<_Section> sections) {
    const primary = 4;
    final inMore = _index >= primary;
    return NavigationBar(
      selectedIndex: inMore ? primary : _index,
      onDestinationSelected: (i) async {
        if (i < primary) {
          _go(i);
          return;
        }
        final chosen = await showModalBottomSheet<int>(
          context: context,
          builder: (ctx) => SessionScope(
            session: widget.session,
            child: _MoreSheet(sections: sections, from: primary, current: _index),
          ),
        );
        if (chosen != null) _go(chosen);
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

/// «Más» en el móvil: cuadrícula de iconos grandes, cómoda para el pulgar.
class _MoreSheet extends StatelessWidget {
  const _MoreSheet({required this.sections, required this.from, required this.current});
  final List<_Section> sections;
  final int from;
  final int current;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.15,
          children: [
            for (var j = from; j < sections.length; j++)
              Material(
                color: j == current ? AppColors.primaryContainer : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.pop(context, j),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _NavIcon(section: sections[j], selected: j == current, size: 34),
                      const SizedBox(height: 8),
                      Text(sections[j].label, style: t.labelLarge, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Barra lateral de escritorio: partida, personaje activo, secciones por grupo
/// y quién está conectado.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    super.key,
    required this.sections,
    required this.index,
    required this.collapsed,
    required this.onSelect,
    required this.onToggle,
    required this.onCharacter,
  });
  final List<_Section> sections;
  final int index;
  final bool collapsed;
  final ValueChanged<int> onSelect;
  final VoidCallback? onToggle;
  final VoidCallback onCharacter;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final t = Theme.of(context).textTheme;
    final groups = <String>[];
    for (final sec in sections) {
      if (!groups.contains(sec.group)) groups.add(sec.group);
    }
    final active = s.isDm ? null : s.activeCharacter;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: collapsed ? 76 : 256,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.97),
        border: Border(right: BorderSide(color: AppColors.outlineSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SidebarHeader(collapsed: collapsed),
          if (active != null) _ActiveCharacterCard(collapsed: collapsed, onTap: onCharacter),
          Expanded(
            // Todas las secciones se construyen (son pocas) para que los atajos y las pruebas las encuentren.
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final g in groups) ...[
                    if (!collapsed)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
                        child: Text(
                          g.toUpperCase(),
                          style: t.labelSmall?.copyWith(color: AppColors.muted, letterSpacing: 1.6),
                        ),
                      )
                    else
                      Divider(height: 14, indent: 18, endIndent: 18, color: AppColors.outlineSoft),
                    for (var i = 0; i < sections.length; i++)
                      if (sections[i].group == g)
                        _SidebarItem(
                          section: sections[i],
                          selected: i == index,
                          collapsed: collapsed,
                          shortcut: i < 9 ? 'Ctrl+${i + 1}' : null,
                          onTap: () => onSelect(i),
                        ),
                  ],
                ],
              ),
            ),
          ),
          _SidebarFooter(collapsed: collapsed, onToggle: onToggle),
        ],
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.collapsed});
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final t = Theme.of(context).textTheme;
    final emblem = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [AppColors.primaryContainer, AppColors.surfaceHighest]),
        border: Border.all(color: AppColors.gold, width: 2),
        boxShadow: [BoxShadow(color: AppColors.glow.withValues(alpha: 0.25), blurRadius: 12)],
      ),
      alignment: Alignment.center,
      child: GameIcon(s.isDm ? 'crowned_skull' : 'castle', size: 26, color: AppColors.gold),
    );
    return Container(
      padding: EdgeInsets.fromLTRB(collapsed ? 14 : 16, 16, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primaryContainer.withValues(alpha: 0.55), Colors.transparent],
        ),
        border: Border(bottom: BorderSide(color: AppColors.outlineSoft)),
      ),
      child: collapsed
          ? Tooltip(message: s.campaign.name, child: emblem)
          : Row(
              children: [
                emblem,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.campaign.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleMedium?.copyWith(
                          fontFamily: 'Cinzel',
                          fontVariations: const [FontVariation('wght', 700)],
                          color: AppColors.gold,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Pill(s.campaign.ruleset.short),
                          const SizedBox(width: 6),
                          Pill(
                            s.isDm ? tr('Máster') : tr('Jugador'),
                            color: s.isDm ? AppColors.crimson : AppColors.arcane,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.circle, size: 9, color: _statusColor(s.status)),
                          const SizedBox(width: 5),
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
                  ),
                ),
              ],
            ),
    );
  }
}

class _ActiveCharacterCard extends StatelessWidget {
  const _ActiveCharacterCard({required this.collapsed, required this.onTap});
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final c = s.activeCharacter!;
    final t = Theme.of(context).textTheme;
    final max = c.effectiveHpMax(s.campaign.ruleset);
    final ratio = max <= 0 ? 0.0 : (c.hpCurrent / max).clamp(0.0, 1.0);
    final portrait = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceHighest,
        border: Border.all(color: AppColors.hpColor(ratio), width: 2),
      ),
      alignment: Alignment.center,
      child: GameIcon(c.portrait, size: 24),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 2),
      child: Material(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(collapsed ? 6 : 10),
            child: collapsed
                ? Tooltip(message: '${c.name} · ${c.hpCurrent}/$max', child: portrait)
                : Row(
                    children: [
                      portrait,
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name, style: t.titleSmall, overflow: TextOverflow.ellipsis),
                            Text(c.classSummary, style: t.bodySmall, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 6,
                                color: AppColors.hpColor(ratio),
                                backgroundColor: AppColors.surfaceHighest,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(tr('PG {0}/{1}', [c.hpCurrent, max]), style: t.labelSmall),
                          ],
                        ),
                      ),
                      if (s.myCharacters.length > 1) const _CharacterSwitcher(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.section,
    required this.selected,
    required this.collapsed,
    required this.onTap,
    this.shortcut,
  });
  final _Section section;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;
  final String? shortcut;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final sel = widget.selected;
    final item = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
          padding: EdgeInsets.symmetric(horizontal: widget.collapsed ? 0 : 12, vertical: 9),
          decoration: BoxDecoration(
            color: sel ? AppColors.primaryContainer : (_hover ? AppColors.surfaceHigh : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? AppColors.gold.withValues(alpha: 0.5) : Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: widget.collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              _NavIcon(section: widget.section, selected: sel),
              if (!widget.collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.section.label,
                    style: t.labelLarge?.copyWith(
                      color: sel ? AppColors.gold : AppColors.parchment,
                      fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.shortcut != null && _hover)
                  Text(widget.shortcut!, style: t.labelSmall?.copyWith(color: AppColors.muted)),
              ],
            ],
          ),
        ),
      ),
    );
    return widget.collapsed ? Tooltip(message: widget.section.label, child: item) : item;
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({required this.collapsed, required this.onToggle});
  final bool collapsed;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final online = s.onlineIds;
    final players = s.campaign.members.where((m) => m.userId != s.campaign.dmUserId && !m.banned).toList();
    final t = Theme.of(context).textTheme;
    Widget avatar(String name, bool on) => Tooltip(
      message: '$name · ${on ? tr('conectado') : tr('desconectado')}',
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.only(right: 4, bottom: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? AppColors.primaryContainer : AppColors.surfaceHigh,
          border: Border.all(color: on ? AppColors.success : AppColors.outline, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: t.labelMedium?.copyWith(
            color: on ? AppColors.parchment : AppColors.muted,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.outlineSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!collapsed && players.isNotEmpty) ...[
            Text(tr('Mesa'), style: t.labelSmall?.copyWith(color: AppColors.muted, letterSpacing: 1.2)),
            const SizedBox(height: 6),
            Wrap(children: [for (final m in players) avatar(m.name, online.contains(m.userId))]),
          ],
          Row(
            mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
            children: [
              if (!collapsed)
                TextButton.icon(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.logout, size: 18),
                  label: Text(tr('Salir')),
                ),
              if (onToggle != null)
                IconButton(
                  tooltip: collapsed ? tr('Expandir') : tr('Contraer'),
                  icon: Icon(collapsed ? Icons.chevron_right : Icons.chevron_left),
                  onPressed: onToggle,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Cabecera de la sección en escritorio.
class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({
    required this.section,
    required this.panelFits,
    required this.panelOpen,
    required this.onTogglePanel,
  });
  final _Section section;
  final bool panelFits;
  final bool panelOpen;
  final VoidCallback onTogglePanel;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.88),
        border: Border(bottom: BorderSide(color: AppColors.outlineSoft)),
      ),
      child: Row(
        children: [
          GameIcon(section.icon, size: 26),
          const SizedBox(width: 12),
          Text(section.label, style: t.headlineSmall?.copyWith(color: AppColors.gold)),
          const Spacer(),
          FilledButton.tonalIcon(
            onPressed: () => showDiceRoller(context),
            icon: const GameIcon('d20', size: 20),
            label: Text(tr('Tirar dados')),
          ),
          const SizedBox(width: 6),
          Text('Ctrl+D', style: t.labelSmall?.copyWith(color: AppColors.muted)),
          if (panelFits) ...[
            const SizedBox(width: 10),
            IconButton(
              tooltip: panelOpen ? tr('Ocultar panel (Ctrl+.)') : tr('Mostrar panel (Ctrl+.)'),
              icon: Icon(panelOpen ? Icons.view_sidebar : Icons.view_sidebar_outlined),
              onPressed: onTogglePanel,
            ),
          ],
        ],
      ),
    );
  }
}

/// Panel derecho de escritorio: tiradas de la mesa y orden de turnos.
class _SidePanel extends StatelessWidget {
  const _SidePanel();

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Material(
      color: AppColors.surface.withValues(alpha: 0.9),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(
              tabs: [
                Tab(text: tr('Tiradas')),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(tr('Turnos')),
                      if (s.campaign.encounter.active) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.circle, size: 8, color: AppColors.crimson),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  Column(
                    children: [
                      if (s.isDm)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: Row(
                            children: [
                              Icon(Icons.visibility_off, size: 16, color: AppColors.muted),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  tr('Tus tiradas son secretas'),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const QuickDiceBar(),
                      const Divider(height: 1),
                      const Expanded(child: RollFeed()),
                    ],
                  ),
                  const _TurnOrderPanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Orden de iniciativa compacto para el panel derecho.
class _TurnOrderPanel extends StatelessWidget {
  const _TurnOrderPanel();

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final e = s.campaign.encounter;
    final t = Theme.of(context).textTheme;
    if (!e.active || e.combatants.isEmpty) {
      return EmptyState(icon: 'crossed_swords', title: tr('Sin combate'));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Text(tr('Ronda {0}', [e.round]), style: t.titleLarge),
              const Spacer(),
              if (s.isDm)
                FilledButton.tonalIcon(
                  onPressed: () => s.send(Command.putEncounter(e.copy()..next())),
                  icon: const Icon(Icons.skip_next),
                  label: Text(tr('Siguiente')),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            children: [
              for (var i = 0; i < e.combatants.length; i++)
                if (s.isDm || !e.combatants[i].hidden)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: i == e.turn ? AppColors.primaryContainer : AppColors.surfaceHigh.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: i == e.turn ? AppColors.gold : AppColors.outlineSoft),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 30,
                          child: Text(
                            '${e.combatants[i].initiative}',
                            style: t.titleMedium?.copyWith(color: AppColors.gold),
                          ),
                        ),
                        Expanded(child: Text(e.combatants[i].name, overflow: TextOverflow.ellipsis)),
                        if (e.combatants[i].hidden) Icon(Icons.visibility_off, size: 16, color: AppColors.muted),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.section, required this.selected, this.size = 24});
  final _Section section;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final icon = GameIcon(section.icon, size: size, color: selected ? AppColors.gold : AppColors.muted);
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
