import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dice.dart';
import '../../../core/text.dart';
import '../../../domain/icons.dart';
import '../../../data/srd.dart';
import '../../../domain/abilities.dart';
import '../../../domain/character.dart';
import '../../../domain/ruleset.dart';
import '../../../state/providers.dart';
import '../../../state/session.dart';
import '../../layout.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../shared/dice_roller.dart';
import 'character_views.dart';
import '../../../core/i18n.dart';

String spellLevelLabel(int level) => level == 0 ? tr('Trucos') : tr('Nivel {0}', [level]);

/// Límite sugerido de conjuros preparados según edición y clases.
int? suggestedPreparedLimit(Character c, Ruleset rs, SrdData? srd) {
  var total = 0;
  var any = false;
  for (final cl in c.classes) {
    final srdClass = srd?.classByName(cl.srdId ?? cl.name);
    if (rs == Ruleset.v2024) {
      final p = srdClass?.level(cl.level)?.prepared;
      if (p != null && p > 0) {
        total += p;
        any = true;
      }
    } else {
      final ability = srdClass?.spellAbility != null ? Ability.byKey(srdClass!.spellAbility) : c.spellcasting.ability;
      final f = Rules(rs).preparedFormula2014(srdClass?.id ?? cl.name, cl.level, ability == null ? 0 : c.mod(ability));
      if (f != null) {
        total += f;
        any = true;
      } else {
        final k = srdClass?.level(cl.level)?.known;
        if (k != null && k > 0) {
          total += k;
          any = true;
        }
      }
    }
  }
  return any ? total : null;
}

class SpellsView extends ConsumerStatefulWidget {
  const SpellsView({super.key, required this.character});
  final Character character;

  @override
  ConsumerState<SpellsView> createState() => _SpellsViewState();
}

class _SpellsViewState extends ConsumerState<SpellsView> {
  bool _onlyReady = false;
  String? _selectedSpellId;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final c = widget.character;
    final editable = canEditCharacter(s, c);
    final rs = s.campaign.ruleset;
    final srd = ref.watch(srdProvider(rs)).value;
    final sc = c.spellcasting;
    final t = Theme.of(context).textTheme;
    final limit = sc.preparedLimit ?? suggestedPreparedLimit(c, rs, srd);
    final spells = sc.spells.map((x) => srd?.localizeSpell(x) ?? x).where((x) => !_onlyReady || x.isReady).toList()
      ..sort((a, b) => a.level != b.level ? a.level.compareTo(b.level) : a.name.compareTo(b.name));
    final levels = spells.map((x) => x.level).toSet().toList()..sort();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: editable
          ? FloatingActionButton.extended(
              onPressed: () => _addSpell(context, c, srd),
              icon: const Icon(Icons.add),
              label: Text(tr('Conjuro')),
            )
          : null,
      body: _withDetail(
        context,
        c,
        spells,
        editable,
        ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            SectionCard(
              title: tr('Lanzamiento de conjuros'),
              icon: 'magic_swirl',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (editable)
                        SizedBox(
                          width: 190,
                          child: DropdownButtonFormField<Ability?>(
                            initialValue: sc.ability,
                            decoration: InputDecoration(labelText: tr('Característica')),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('—')),
                              for (final a in [Ability.intl, Ability.wis, Ability.cha])
                                DropdownMenuItem(value: a, child: Text(a.label)),
                            ],
                            onChanged: (v) => editCharacter(context, c.id, (x) => x.spellcasting.ability = v),
                          ),
                        )
                      else if (sc.ability != null)
                        Text(sc.ability!.label, style: t.titleSmall),
                      StatBox(
                        label: tr('CD salvación'),
                        value: sc.ability == null ? '—' : '${c.spellSaveDc}',
                        width: 100,
                      ),
                      StatBox(
                        label: tr('Ataque'),
                        value: sc.ability == null ? '—' : signed(c.spellAttackBonus),
                        onTap: sc.ability == null
                            ? null
                            : () => showD20Roll(
                                context,
                                tr('Ataque de conjuro'),
                                c.spellAttackBonus + s.campaign.rules.exhaustionD20Penalty(c.exhaustion),
                              ),
                      ),
                      StatBox(
                        label: tr('Preparados'),
                        value: '${sc.preparedCount}${limit != null ? '/$limit' : ''}',
                        highlight: limit != null && sc.preparedCount > limit,
                        width: 100,
                        onTap: editable ? () => _editLimit(context, c, limit) : null,
                      ),
                    ],
                  ),
                  if (sc.concentratingOn.isNotEmpty) ...[
                    Gap.s,
                    InputChip(
                      avatar: GameIcon('brain', size: 18, color: AppColors.arcane),
                      label: Text(tr('Concentrado en: {0}', [sc.concentratingOn])),
                      onDeleted: editable
                          ? () => editCharacter(context, c.id, (x) => x.spellcasting.concentratingOn = '')
                          : null,
                    ),
                  ],
                ],
              ),
            ),
            SectionCard(
              title: tr('Espacios de conjuro'),
              icon: 'crystal_ball',
              trailing: editable
                  ? TextButton(onPressed: () => _autoSlots(context, c, rs, srd), child: Text(tr('Calcular por clase')))
                  : null,
              child: !sc.hasSlots
                  ? Text(tr('Sin espacios. Pulsa «Calcular por clase» o edítalos a mano.'), style: t.bodySmall)
                  : Column(
                      children: [
                        for (var i = 0; i < 9; i++)
                          if (sc.slots[i].max > 0) _SlotRow(character: c, level: i + 1, editable: editable),
                        if (sc.pactSlotsMax > 0)
                          _SlotRow(character: c, level: sc.pactSlotLevel, editable: editable, pact: true),
                      ],
                    ),
            ),
            Row(
              children: [
                Text(tr('Conjuros ({0})', [sc.spells.length]), style: t.titleLarge),
                const Spacer(),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(tr('Todos'))),
                    ButtonSegment(value: true, label: Text(tr('Preparados'))),
                  ],
                  selected: {_onlyReady},
                  onSelectionChanged: (v) => setState(() => _onlyReady = v.first),
                ),
              ],
            ),
            Gap.s,
            if (spells.isEmpty)
              EmptyState(
                icon: 'spell_book',
                title: _onlyReady ? tr('Nada preparado') : tr('Libro de conjuros vacío'),
                message: tr('Añade conjuros del SRD (filtrados por tu clase) o crea los tuyos.'),
              ),
            for (final lvl in levels)
              SectionCard(
                title: spellLevelLabel(lvl),
                child: Column(
                  children: [
                    for (final sp in spells.where((x) => x.level == lvl))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: sp.isCantrip
                            ? SizedBox(
                                width: 40,
                                child: Center(
                                  child: GameIcon(schoolIcon(sp.school), size: 24, color: AppColors.arcane),
                                ),
                              )
                            : Checkbox(
                                value: sp.prepared || sp.alwaysPrepared,
                                onChanged: editable && !sp.alwaysPrepared
                                    ? (v) => editCharacter(context, c.id, (x) {
                                        final y = x.spellcasting.spells.firstWhere((z) => z.id == sp.id);
                                        y.prepared = v ?? false;
                                      })
                                    : null,
                              ),
                        title: Row(
                          children: [
                            if (!sp.isCantrip) ...[
                              GameIcon(schoolIcon(sp.school), size: 18, color: AppColors.arcane),
                              const SizedBox(width: 6),
                            ],
                            Flexible(child: Text(sp.name)),
                            if (sp.concentration)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Pill(tr('C'), color: AppColors.arcane),
                              ),
                            if (sp.ritual) Padding(padding: const EdgeInsets.only(left: 4), child: Pill(tr('R'))),
                            if (sp.alwaysPrepared)
                              Padding(padding: const EdgeInsets.only(left: 4), child: Pill(tr('siempre'))),
                          ],
                        ),
                        subtitle: Text(
                          [sp.school, sp.castingTime, sp.range].where((e) => e.isNotEmpty).join(' · '),
                          style: t.bodySmall,
                        ),
                        selected: sp.id == _selectedSpellId,
                        onTap: () => _showSpell(context, c, sp, editable),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// En PC, el conjuro elegido se ve en un panel a la derecha de la lista.
  Widget _withDetail(BuildContext context, Character c, List<CharacterSpell> spells, bool editable, Widget list) {
    if (!isDesktopLayout(context)) return list;
    final sp = spells.where((x) => x.id == _selectedSpellId).firstOrNull;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: list),
        if (sp != null) ...[
          VerticalDivider(width: 1, color: AppColors.outlineSoft),
          SizedBox(
            width: 420,
            child: Material(
              color: AppColors.surface.withValues(alpha: 0.9),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 24),
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: tr('Cerrar'),
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _selectedSpellId = null),
                    ),
                  ),
                  ..._detail(context, c, sp, editable, () => setState(() => _selectedSpellId = null)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _editLimit(BuildContext context, Character c, int? suggested) async {
    final v = await promptNumber(
      context,
      tr('Límite de conjuros preparados'),
      initial: c.spellcasting.preparedLimit ?? suggested,
      hint: tr('Vacío = usar el sugerido por la edición ({0})', [suggested ?? '—']),
    );
    if (!context.mounted) return;
    await editCharacter(context, c.id, (x) => x.spellcasting.preparedLimit = v);
  }

  Future<void> _autoSlots(BuildContext context, Character c, Ruleset rs, SrdData? srd) async {
    List<int>? single;
    final casters = c.classes.where(
      (cl) =>
          Rules.casterType(cl.srdId ?? cl.name, cl.subclass) != CasterType.none &&
          Rules.casterType(cl.srdId ?? cl.name, cl.subclass) != CasterType.pact,
    );
    if (casters.length == 1) {
      final cl = casters.first;
      single = srd?.classByName(cl.srdId ?? cl.name)?.level(cl.level)?.slots;
    }
    await editCharacter(context, c.id, (x) {
      x.autoFillSlots(rs, singleClassSlots: single);
      if (x.spellcasting.ability == null && c.classes.isNotEmpty) {
        final ab = srd?.classByName(c.classes.first.srdId ?? c.classes.first.name)?.spellAbility;
        x.spellcasting.ability = Ability.byKey(ab);
      }
    });
  }

  /// Contenido del detalle de un conjuro (hoja inferior en móvil, panel en PC).
  List<Widget> _detail(BuildContext context, Character c, CharacterSpell sp, bool editable, VoidCallback close) {
    final s = SessionScope.read(context);
    final t = Theme.of(context).textTheme;
    return [
      Text(sp.name, style: t.headlineSmall),
      Text('${spellLevelLabel(sp.level)} · ${sp.school}${sp.ritual ? ' (ritual)' : ''}', style: t.bodySmall),
      Gap.m,
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (sp.castingTime.isNotEmpty) StatBox(label: tr('Tiempo'), value: sp.castingTime, width: 130),
          if (sp.range.isNotEmpty) StatBox(label: tr('Alcance'), value: sp.range, width: 130),
          if (sp.duration.isNotEmpty) StatBox(label: tr('Duración'), value: sp.duration, width: 150),
        ],
      ),
      if (sp.components.isNotEmpty) ...[
        Gap.s,
        Text(tr('Componentes: {0}', [sp.components]), style: t.bodySmall),
      ],
      Gap.m,
      if (sp.description.isNotEmpty) RichDescription(sp.description),
      if (sp.higherLevels.isNotEmpty) ...[
        Gap.s,
        Text(tr('A niveles superiores'), style: t.titleSmall?.copyWith(color: AppColors.gold)),
        RichDescription(sp.higherLevels),
      ],
      if (editable) ...[
        const Divider(height: 28),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              icon: GameIcon('fire_spell', size: 18, color: AppColors.onGold),
              label: Text(tr('Lanzar')),
              onPressed: () async {
                close();
                await _cast(context, c, sp);
              },
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
              icon: const Icon(Icons.delete_outline),
              label: Text(tr('Quitar')),
              onPressed: () async {
                close();
                await s.editCharacter(c.id, (x) => x.spellcasting.spells.removeWhere((y) => y.id == sp.id));
              },
            ),
          ],
        ),
      ],
    ];
  }

  Future<void> _showSpell(BuildContext context, Character c, CharacterSpell sp, bool editable) async {
    if (isDesktopLayout(context)) {
      setState(() => _selectedSpellId = _selectedSpellId == sp.id ? null : sp.id);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: _detail(context, c, sp, editable, () => Navigator.pop(ctx)),
        ),
      ),
    );
  }

  Future<void> _cast(BuildContext context, Character c, CharacterSpell sp) async {
    final sc = c.spellcasting;
    var slotLevel = 0;
    var usePact = false;
    if (!sp.isCantrip) {
      final options = <(int, bool)>[
        for (var l = sp.level; l <= 9; l++)
          if (sc.slots[l - 1].available > 0) (l, false),
        if (sc.pactSlotsMax - sc.pactSlotsUsed > 0 && sc.pactSlotLevel >= sp.level) (sc.pactSlotLevel, true),
      ];
      if (options.isEmpty) {
        final ok = await confirm(
          context,
          tr('Sin espacios'),
          tr('No te quedan espacios de nivel {0} o superior. ¿Lanzarlo igualmente (ritual, objeto…)?', [sp.level]),
          ok: tr('Lanzar'),
        );
        if (!ok) return;
      } else {
        final chosen = await showDialog<(int, bool)>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: Text(tr('Lanzar {0}', [sp.name])),
            children: [
              for (final o in options)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, o),
                  child: Text(o.$2 ? tr('Espacio de pacto (nivel {0})', [o.$1]) : tr('Espacio de nivel {0}', [o.$1])),
                ),
              if (sp.ritual)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, (0, false)),
                  child: Text(tr('Como ritual (sin espacio)')),
                ),
            ],
          ),
        );
        if (chosen == null) return;
        slotLevel = chosen.$1;
        usePact = chosen.$2;
      }
    }
    if (!context.mounted) return;
    if (sp.concentration && sc.concentratingOn.isNotEmpty && sc.concentratingOn != sp.name) {
      final ok = await confirm(
        context,
        tr('Concentración'),
        tr('Ya te estás concentrando en {0}. Si lanzas {1} perderás ese efecto.', [sc.concentratingOn, sp.name]),
        ok: tr('Lanzar'),
      );
      if (!ok || !context.mounted) return;
    }
    await editCharacter(context, c.id, (x) {
      if (usePact) {
        x.spellcasting.pactSlotsUsed++;
      } else if (slotLevel > 0) {
        x.spellcasting.slots[slotLevel - 1].used++;
      }
      if (sp.concentration) x.spellcasting.concentratingOn = sp.name;
    });
    if (context.mounted) {
      showSnack(
        context,
        slotLevel > 0
            ? tr('{0} lanzado con un espacio de nivel {1}', [sp.name, slotLevel])
            : tr('{0} lanzado', [sp.name]),
      );
    }
  }

  Future<void> _addSpell(BuildContext context, Character c, SrdData? srd) async {
    final s = SessionScope.read(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const GameIcon('spell_book', size: 26),
              title: Text(tr('Del {0}', [s.campaign.ruleset.srdName])),
              onTap: () => Navigator.pop(ctx, 'srd'),
            ),
            ListTile(
              leading: const GameIcon('quill', size: 26),
              title: Text(tr('Conjuro personalizado')),
              onTap: () => Navigator.pop(ctx, 'custom'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'srd') {
      if (srd == null) return;
      final picked = await Navigator.push<List<SrdSpell>>(
        context,
        MaterialPageRoute(
          builder: (_) => SpellBrowser(srd: srd, character: c, picking: true),
        ),
      );
      if (picked == null || picked.isEmpty || !context.mounted) return;
      await editCharacter(context, c.id, (x) {
        for (final p in picked) {
          if (x.spellcasting.spells.any((y) => y.srdId == p.id)) continue;
          x.spellcasting.spells.add(p.toCharacterSpell());
        }
      });
    } else {
      final sp = await _customSpellDialog(context);
      if (sp == null || !context.mounted) return;
      await editCharacter(context, c.id, (x) => x.spellcasting.spells.add(sp));
    }
  }

  Future<CharacterSpell?> _customSpellDialog(BuildContext context) async {
    final name = TextEditingController();
    final desc = TextEditingController();
    final time = TextEditingController(text: tr('1 acción'));
    final range = TextEditingController();
    final duration = TextEditingController(text: tr('Instantáneo'));
    var level = 1;
    var conc = false;
    return showDialog<CharacterSpell>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(tr('Conjuro personalizado')),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: InputDecoration(labelText: tr('Nombre')),
                  ),
                  Gap.s,
                  Row(
                    children: [
                      Text(tr('Nivel')),
                      const Spacer(),
                      NumberStepper(value: level, max: 9, onChanged: (v) => setState(() => level = v)),
                    ],
                  ),
                  TextField(
                    controller: time,
                    decoration: InputDecoration(labelText: tr('Tiempo de lanzamiento')),
                  ),
                  Gap.s,
                  TextField(
                    controller: range,
                    decoration: InputDecoration(labelText: tr('Alcance')),
                  ),
                  Gap.s,
                  TextField(
                    controller: duration,
                    decoration: InputDecoration(labelText: tr('Duración')),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: conc,
                    title: Text(tr('Concentración')),
                    onChanged: (v) => setState(() => conc = v ?? false),
                  ),
                  TextField(
                    controller: desc,
                    minLines: 3,
                    maxLines: 8,
                    decoration: InputDecoration(labelText: tr('Descripción')),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancelar'))),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(
                  ctx,
                  CharacterSpell(
                    name: name.text.trim(),
                    level: level,
                    castingTime: time.text.trim(),
                    range: range.text.trim(),
                    duration: duration.text.trim(),
                    concentration: conc,
                    description: desc.text.trim(),
                  ),
                );
              },
              child: Text(tr('Añadir')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.character, required this.level, required this.editable, this.pact = false});
  final Character character;
  final int level;
  final bool editable;
  final bool pact;

  @override
  Widget build(BuildContext context) {
    final sc = character.spellcasting;
    final max = pact ? sc.pactSlotsMax : sc.slots[level - 1].max;
    final used = pact ? sc.pactSlotsUsed : sc.slots[level - 1].used;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(pact ? tr('Pacto (niv. {0})', [level]) : tr('Nivel {0}', [level]))),
          Expanded(
            child: Wrap(
              children: [
                for (var i = 0; i < max; i++)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: i < max - used ? tr('Disponible (toca para gastar)') : tr('Gastado (toca para recuperar)'),
                    onPressed: editable
                        ? () => editCharacter(context, character.id, (x) {
                            final available = i < max - used;
                            if (pact) {
                              x.spellcasting.pactSlotsUsed = (used + (available ? 1 : -1)).clamp(0, max);
                            } else {
                              x.spellcasting.slots[level - 1].used = (used + (available ? 1 : -1)).clamp(0, max);
                            }
                          })
                        : null,
                    icon: Icon(
                      i < max - used ? Icons.circle : Icons.circle_outlined,
                      color: pact ? AppColors.crimson : AppColors.arcane,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
          Text('${max - used}/$max'),
        ],
      ),
    );
  }
}

/// Explorador de conjuros del SRD. Con [picking] permite seleccionar varios.
class SpellBrowser extends StatefulWidget {
  const SpellBrowser({super.key, required this.srd, this.character, this.picking = false});
  final SrdData srd;
  final Character? character;
  final bool picking;

  @override
  State<SpellBrowser> createState() => _SpellBrowserState();
}

class _SpellBrowserState extends State<SpellBrowser> {
  String _query = '';
  int? _level;
  String? _class;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    final c = widget.character;
    if (c != null && c.classes.isNotEmpty) {
      _class = widget.srd.classByName(c.classes.first.srdId ?? c.classes.first.name)?.nameEn;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final casterClasses = widget.srd.classes.where((c) => c.spellAbility != null).toList();
    final q = foldText(_query);
    final list = widget.srd.spells.where((sp) {
      if (_level != null && sp.level != _level) return false;
      if (_class != null && !sp.classes.contains(_class)) return false;
      return q.isEmpty || foldText(sp.name).contains(q) || foldText(sp.nameEn).contains(q);
    }).toList();
    return AppScaffold(
      title: widget.picking ? tr('Añadir conjuros') : tr('Conjuros ({0})', [widget.srd.ruleset.srdName]),
      actions: [
        if (widget.picking)
          TextButton(
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.pop(context, widget.srd.spells.where((s) => _selected.contains(s.id)).toList()),
            child: Text(tr('Añadir ({0})', [_selected.length])),
          ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: SearchField(onChanged: (v) => setState(() => _query = v), hint: tr('Buscar conjuro')),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _class,
                    decoration: InputDecoration(labelText: tr('Clase')),
                    items: [
                      DropdownMenuItem(value: null, child: Text(tr('Todas'))),
                      for (final c in casterClasses) DropdownMenuItem(value: c.nameEn, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _class = v),
                  ),
                ),
                Gap.s,
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    initialValue: _level,
                    decoration: InputDecoration(labelText: tr('Nivel')),
                    items: [
                      DropdownMenuItem(value: null, child: Text(tr('Todos'))),
                      for (var l = 0; l <= 9; l++) DropdownMenuItem(value: l, child: Text(spellLevelLabel(l))),
                    ],
                    onChanged: (v) => setState(() => _level = v),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, i) {
                final sp = list[i];
                final known = widget.character?.spellcasting.spells.any((x) => x.srdId == sp.id) ?? false;
                return ListTile(
                  leading: widget.picking
                      ? Checkbox(
                          value: known || _selected.contains(sp.id),
                          onChanged: known
                              ? null
                              : (v) => setState(() => v == true ? _selected.add(sp.id) : _selected.remove(sp.id)),
                        )
                      : Stack(
                          clipBehavior: Clip.none,
                          children: [
                            GameIcon(schoolIcon(sp.school), size: 30, color: AppColors.arcane),
                            Positioned(
                              right: -6,
                              bottom: -4,
                              child: CircleAvatar(
                                radius: 9,
                                backgroundColor: AppColors.surfaceHighest,
                                child: Text('${sp.level}', style: t.labelSmall?.copyWith(color: AppColors.gold)),
                              ),
                            ),
                          ],
                        ),
                  title: Text(sp.name),
                  subtitle: Text(
                    '${spellLevelLabel(sp.level)} · ${sp.school} · ${sp.time}'
                    '${sp.concentration ? ' · C' : ''}${sp.ritual ? ' · R' : ''}',
                  ),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(sp.name),
                      content: SizedBox(
                        width: 520,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${spellLevelLabel(sp.level)} · ${sp.school}', style: t.bodySmall),
                              Text('${sp.time} · ${sp.range} · ${sp.duration}', style: t.bodySmall),
                              Text(tr('Componentes: {0}', [sp.componentsFull]), style: t.bodySmall),
                              Text(tr('Clases: {0}', [sp.classesShown.join(', ')]), style: t.bodySmall),
                              Gap.s,
                              RichDescription(sp.description),
                              if (sp.higher.isNotEmpty) ...[
                                Gap.s,
                                RichDescription(tr('**A niveles superiores.** {0}', [sp.higher])),
                              ],
                            ],
                          ),
                        ),
                      ),
                      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cerrar')))],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
