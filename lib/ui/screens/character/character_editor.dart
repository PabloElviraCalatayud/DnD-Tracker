import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dice.dart';
import '../../../data/srd.dart';
import '../../../domain/abilities.dart';
import '../../../domain/character.dart';
import '../../../domain/ruleset.dart';
import '../../../state/providers.dart';
import '../../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../../core/i18n.dart';

const portraitChoices = [
  'hood',
  'wizard_face',
  'elf_helmet',
  'helm',
  'person',
  'pointy_hat',
  'crowned_skull',
  'skull',
  'goblin',
  'orc',
  'troll',
  'wolf',
  'vampire',
  'ghost',
  'dragon',
  'minotaur',
  'spider',
  'fist',
  'crown',
  'feather',
  'leaf',
  'sun',
  'moon',
  'magic_swirl',
];

const alignments = [
  '',
  'Legal bueno',
  'Neutral bueno',
  'Caótico bueno',
  'Legal neutral',
  'Neutral',
  'Caótico neutral',
  'Legal malvado',
  'Neutral malvado',
  'Caótico malvado',
];

/// Herramientas habituales (en el idioma de la interfaz).
List<String> get artisanToolSuggestions => [for (final t in _artisanTools) tr(t)];

const _artisanTools = [
  'Útiles de alquimista',
  'Útiles de cervecero',
  'Útiles de calígrafo',
  'Herramientas de carpintero',
  'Herramientas de cartógrafo',
  'Herramientas de zapatero',
  'Utensilios de cocinero',
  'Herramientas de soplador de vidrio',
  'Herramientas de joyero',
  'Herramientas de peletero',
  'Herramientas de albañil',
  'Útiles de pintor',
  'Herramientas de alfarero',
  'Herramientas de herrero',
  'Herramientas de hojalatero',
  'Herramientas de tejedor',
  'Herramientas de tallador',
  'Útiles de herborista',
  'Útiles de envenenador',
  'Herramientas de ladrón',
  'Útiles para disfrazarse',
  'Útiles de falsificador',
  'Herramientas de navegante',
];

Future<void> openCharacterEditor(BuildContext context, Character? existing) {
  final s = SessionScope.read(context);
  return Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => SessionScope(
        session: s,
        child: CharacterEditor(initial: existing),
      ),
    ),
  );
}

class CharacterEditor extends ConsumerStatefulWidget {
  const CharacterEditor({super.key, this.initial});
  final Character? initial;

  @override
  ConsumerState<CharacterEditor> createState() => _CharacterEditorState();
}

class _CharacterEditorState extends ConsumerState<CharacterEditor> {
  late Character _c;
  bool _saving = false;
  bool get _isNew => widget.initial == null;

  @override
  void initState() {
    super.initState();
    final s = SessionScope.read(context);
    _c = widget.initial?.copy() ?? Character(ownerId: s.myUserId, name: '');
  }

  void _set(VoidCallback f) => setState(f);

  Future<void> _save() async {
    if (_c.name.trim().isEmpty) {
      showSnack(context, tr('El personaje necesita un nombre'), error: true);
      return;
    }
    setState(() => _saving = true);
    final s = SessionScope.read(context);
    if (_isNew) _c.hpCurrent = _c.hpMax;
    final r = await s.saveCharacter(_c);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!r.ok) {
      showSnack(context, r.error ?? tr('No se pudo guardar'), error: true);
      return;
    }
    if (_isNew) s.selectCharacter(_c.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final srd = ref.watch(srdProvider(s.campaign.ruleset)).value;
    return DefaultTabController(
      length: 5,
      child: AppScaffold(
        title: _isNew ? tr('Nuevo personaje') : tr('Editar {0}', [_c.name]),
        actions: [
          TextButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save), label: Text(tr('Guardar'))),
        ],
        bottom: TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: tr('Básico')),
            Tab(text: tr('Características')),
            Tab(text: tr('Competencias')),
            Tab(text: tr('Rasgos y ataques')),
            Tab(text: tr('Historia')),
          ],
        ),
        body: TabBarView(
          children: [
            _BasicTab(c: _c, set: _set, srd: srd, ruleset: s.campaign.ruleset),
            _AbilitiesTab(c: _c, set: _set),
            _ProficienciesTab(c: _c, set: _set, ruleset: s.campaign.ruleset),
            _FeaturesTab(c: _c, set: _set, srd: srd),
            _StoryTab(c: _c, set: _set),
          ],
        ),
      ),
    );
  }
}

/// Campo de texto ligado a una propiedad: no necesita controladores fuera.
class _Field extends StatefulWidget {
  const _Field({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.lines = 1,
    this.number = false,
    this.hint,
    this.suggestions = const [],
  });
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int lines;
  final bool number;
  final String? hint;
  final List<String> suggestions;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _Field old) {
    super.didUpdateWidget(old);
    if (widget.value != _ctrl.text && !FocusScope.of(context).hasFocus) _ctrl.text = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.suggestions.isNotEmpty) {
      return Autocomplete<String>(
        initialValue: TextEditingValue(text: widget.value),
        optionsBuilder: (v) {
          final q = v.text.toLowerCase();
          return widget.suggestions.where((s) => q.isEmpty || s.toLowerCase().contains(q));
        },
        onSelected: widget.onChanged,
        fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
          controller: controller,
          focusNode: focus,
          decoration: InputDecoration(labelText: widget.label, hintText: widget.hint),
          onChanged: widget.onChanged,
        ),
      );
    }
    return TextField(
      controller: _ctrl,
      minLines: widget.lines,
      maxLines: widget.lines == 1 ? 1 : widget.lines + 6,
      keyboardType: widget.number ? TextInputType.number : null,
      inputFormatters: widget.number ? [FilteringTextInputFormatter.allow(RegExp(r'[-0-9]'))] : null,
      decoration: InputDecoration(labelText: widget.label, hintText: widget.hint, alignLabelWithHint: widget.lines > 1),
      onChanged: widget.onChanged,
    );
  }
}

// ---------------------------------------------------------------- Básico

class _BasicTab extends StatelessWidget {
  const _BasicTab({required this.c, required this.set, required this.srd, required this.ruleset});
  final Character c;
  final void Function(VoidCallback) set;
  final SrdData? srd;
  final Ruleset ruleset;

  void _onClassChosen(ClassLevel cl, String name) {
    cl.name = name;
    final srdClass = srd?.classByName(name);
    if (srdClass != null) {
      cl.srdId = srdClass.id;
      cl.hitDie = srdClass.hitDie;
      if (c.saveProficiencies.isEmpty && c.classes.first == cl) {
        c.saveProficiencies = srdClass.saves.map(Ability.byKey).whereType<Ability>().toSet();
      }
      if (c.spellcasting.ability == null && srdClass.spellAbility != null) {
        c.spellcasting.ability = Ability.byKey(srdClass.spellAbility);
      }
    } else {
      cl.srdId = null;
    }
  }

  int _averageHp() {
    var hp = 0;
    var first = true;
    final con = c.mod(Ability.con);
    for (final cl in c.classes) {
      for (var i = 0; i < cl.level; i++) {
        hp += (first ? cl.hitDie : cl.hitDie ~/ 2 + 1) + con;
        first = false;
      }
    }
    return hp < 1 ? 1 : hp;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Field(label: tr('Nombre'), value: c.name, onChanged: (v) => c.name = v),
        Gap.m,
        Text(tr('Retrato'), style: t.titleSmall),
        Gap.s,
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in portraitChoices)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => set(() => c.portrait = p),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.portrait == p ? AppColors.gold : AppColors.outlineSoft),
                    color: c.portrait == p ? AppColors.primaryContainer : null,
                  ),
                  child: GameIcon(p, size: 30),
                ),
              ),
          ],
        ),
        Gap.m,
        Row(
          children: [
            Expanded(
              child: _Field(
                label: ruleset.speciesLabel,
                value: c.species,
                suggestions: srd?.species ?? [],
                onChanged: (v) => c.species = v,
              ),
            ),
            Gap.m,
            Expanded(
              child: _Field(
                label: ruleset.subspeciesLabel,
                value: c.subspecies,
                suggestions: srd?.subspecies ?? [],
                onChanged: (v) => c.subspecies = v,
              ),
            ),
          ],
        ),
        Gap.m,
        Row(
          children: [
            Expanded(
              child: _Field(
                label: tr('Trasfondo'),
                value: c.background,
                suggestions: srd?.backgrounds ?? [],
                onChanged: (v) => c.background = v,
              ),
            ),
            Gap.m,
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: alignments.contains(c.alignment) ? c.alignment : '',
                decoration: InputDecoration(labelText: tr('Alineamiento')),
                items: [for (final a in alignments) DropdownMenuItem(value: a, child: Text(a.isEmpty ? '—' : tr(a)))],
                onChanged: (v) => set(() => c.alignment = v ?? ''),
              ),
            ),
          ],
        ),
        Gap.m,
        _Field(
          label: tr('Puntos de experiencia'),
          value: '${c.xp}',
          number: true,
          onChanged: (v) => c.xp = int.tryParse(v) ?? 0,
        ),
        Gap.l,
        Row(
          children: [
            Text(tr('Clases (nivel total {0})', [c.level]), style: t.titleMedium),
            const Spacer(),
            TextButton.icon(
              onPressed: () => set(() => c.classes.add(ClassLevel(name: ''))),
              icon: const Icon(Icons.add),
              label: Text(c.classes.isEmpty ? tr('Añadir clase') : tr('Multiclase')),
            ),
          ],
        ),
        for (final cl in c.classes)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Field(
                          key: ValueKey('class-${c.classes.indexOf(cl)}'),
                          label: tr('Clase'),
                          value: cl.name,
                          suggestions: [
                            ...?srd?.classes.map((x) => x.name),
                            tr('Bárbaro'),
                            tr('Bardo'),
                            tr('Clérigo'),
                            tr('Druida'),
                            tr('Guerrero'),
                            tr('Monje'),
                            tr('Paladín'),
                            tr('Explorador'),
                            tr('Pícaro'),
                            tr('Hechicero'),
                            tr('Brujo'),
                            tr('Mago'),
                            tr('Artífice'),
                          ],
                          onChanged: (v) => set(() => _onClassChosen(cl, v)),
                        ),
                      ),
                      Gap.s,
                      Expanded(
                        child: _Field(label: tr('Subclase'), value: cl.subclass, onChanged: (v) => cl.subclass = v),
                      ),
                      IconButton(
                        tooltip: tr('Quitar clase'),
                        onPressed: () => set(() => c.classes.remove(cl)),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(tr('Nivel')),
                      NumberStepper(value: cl.level, min: 1, max: 20, onChanged: (v) => set(() => cl.level = v)),
                      const Spacer(),
                      Text(tr('Dado de golpe ')),
                      DropdownButton<int>(
                        value: cl.hitDie,
                        items: [
                          for (final d in [6, 8, 10, 12]) DropdownMenuItem(value: d, child: Text(tr('d{0}', [d]))),
                        ],
                        onChanged: (v) => set(() => cl.hitDie = v ?? cl.hitDie),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        Gap.l,
        Text(tr('Combate'), style: t.titleMedium),
        Gap.s,
        Row(
          children: [
            Expanded(
              child: _Field(
                key: ValueKey('hp-${c.hpMax}'),
                label: tr('PG máximos'),
                value: '${c.hpMax}',
                number: true,
                onChanged: (v) => c.hpMax = int.tryParse(v) ?? c.hpMax,
              ),
            ),
            TextButton(
              onPressed: c.classes.isEmpty ? null : () => set(() => c.hpMax = _averageHp()),
              child: Text(tr('Media por nivel')),
            ),
          ],
        ),
        Gap.m,
        Row(
          children: [
            Expanded(
              child: _Field(
                label: tr('CA'),
                value: '${c.armorClass}',
                number: true,
                onChanged: (v) => c.armorClass = int.tryParse(v) ?? 10,
              ),
            ),
            Gap.m,
            Expanded(
              child: _Field(
                label: tr('Velocidad (pies)'),
                value: '${c.speed}',
                number: true,
                onChanged: (v) => c.speed = int.tryParse(v) ?? 30,
              ),
            ),
          ],
        ),
        Gap.m,
        Row(
          children: [
            Expanded(
              child: _Field(
                label: tr('Bonif. extra iniciativa'),
                value: '${c.initiativeBonus}',
                number: true,
                hint: tr('Además de DES'),
                onChanged: (v) => c.initiativeBonus = int.tryParse(v) ?? 0,
              ),
            ),
            Gap.m,
            Expanded(
              child: _Field(
                label: tr('Bonif. extra Percepción pasiva'),
                value: '${c.passivePerceptionBonus}',
                number: true,
                onChanged: (v) => c.passivePerceptionBonus = int.tryParse(v) ?? 0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Características

class _AbilitiesTab extends StatelessWidget {
  const _AbilitiesTab({required this.c, required this.set});
  final Character c;
  final void Function(VoidCallback) set;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(tr('Puntuaciones'), style: t.titleMedium),
            const Spacer(),
            TextButton.icon(
              icon: const GameIcon('dice', size: 18),
              label: Text(tr('Tirar 4d6 ×6')),
              onPressed: () {
                final roller = DiceRoller();
                final values = [for (var i = 0; i < 6; i++) roller.roll('4d6kh3').total]
                  ..sort((a, b) => b.compareTo(a));
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(tr('Tus tiradas')),
                    content: Text(
                      tr('{0}\n\nAsígnalas como quieras a cada característica.', [values.join(' · ')]),
                      style: t.titleMedium,
                    ),
                    actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Vale')))],
                  ),
                );
              },
            ),
          ],
        ),
        for (final a in Ability.values)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(a.label),
            subtitle: Text(tr('Modificador {0}', [signed(c.mod(a))])),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                NumberStepper(value: c.score(a), min: 1, max: 30, onChanged: (v) => set(() => c.abilities[a] = v)),
                Gap.s,
                FilterChip(
                  label: Text(tr('Salv.')),
                  selected: c.saveProficiencies.contains(a),
                  onSelected: (v) => set(() => v ? c.saveProficiencies.add(a) : c.saveProficiencies.remove(a)),
                ),
              ],
            ),
          ),
        const Divider(height: 32),
        Text(tr('Habilidades'), style: t.titleMedium),
        Text(tr('Toca para cambiar: sin competencia → ½ → competente → pericia'), style: t.bodySmall),
        Gap.s,
        for (final sk in List.of(Skill.values)..sort((a, b) => a.label.compareTo(b.label)))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${sk.label} (${sk.ability.abbr})'),
            subtitle: Text(c.skillProficiency(sk).label),
            trailing: Text(signed(c.skillBonus(sk)), style: t.titleMedium),
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: c.skillProficiency(sk) == Proficiency.none
                  ? AppColors.surfaceHigh
                  : AppColors.primaryContainer,
              child: Text(c.skillProficiency(sk).badge, style: TextStyle(color: AppColors.gold, fontSize: 12)),
            ),
            onTap: () => set(() {
              final next = c.skillProficiency(sk).next;
              if (next == Proficiency.none) {
                c.skills.remove(sk);
              } else {
                c.skills[sk] = next;
              }
            }),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Competencias

class _ProficienciesTab extends StatelessWidget {
  const _ProficienciesTab({required this.c, required this.set, required this.ruleset});
  final Character c;
  final void Function(VoidCallback) set;
  final Ruleset ruleset;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Field(
          label: tr('Armaduras'),
          value: c.armorProficiencies,
          hint: tr('Ligeras, medias, escudos…'),
          onChanged: (v) => c.armorProficiencies = v,
        ),
        Gap.m,
        _Field(
          label: tr('Armas'),
          value: c.weaponProficiencies,
          hint: tr('Sencillas, marciales…'),
          onChanged: (v) => c.weaponProficiencies = v,
        ),
        Gap.m,
        _Field(label: tr('Idiomas'), value: c.languages, onChanged: (v) => c.languages = v),
        if (ruleset == Ruleset.v2024) ...[
          Gap.m,
          _Field(
            label: tr('Maestrías de armas'),
            value: c.weaponMasteries,
            hint: tr('Espada larga (Sap), Arco largo (Slow)…'),
            onChanged: (v) => c.weaponMasteries = v,
          ),
        ],
        Gap.l,
        Text(tr('Herramientas'), style: t.titleMedium),
        Text(tr('Se usan para la artesanía: escribe el nombre en castellano o en inglés.'), style: t.bodySmall),
        Gap.s,
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final tool in c.toolProficiencies)
              InputChip(label: Text(tool), onDeleted: () => set(() => c.toolProficiencies.remove(tool))),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: Text(tr('Añadir')),
              onPressed: () async {
                final chosen = await showDialog<String>(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    title: Text(tr('Herramienta')),
                    children: [
                      SimpleDialogOption(
                        onPressed: () async {
                          final v = await promptText(ctx, tr('Otra herramienta'));
                          if (ctx.mounted) Navigator.pop(ctx, v);
                        },
                        child: Text(tr('Escribir otra…')),
                      ),
                      for (final s in artisanToolSuggestions)
                        SimpleDialogOption(onPressed: () => Navigator.pop(ctx, s), child: Text(s)),
                    ],
                  ),
                );
                if (chosen != null && chosen.trim().isNotEmpty) set(() => c.toolProficiencies.add(chosen.trim()));
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Rasgos

class _FeaturesTab extends StatelessWidget {
  const _FeaturesTab({required this.c, required this.set, required this.srd});
  final Character c;
  final void Function(VoidCallback) set;
  final SrdData? srd;

  Future<Feature?> _featureDialog(BuildContext context, Feature? initial) {
    final f = initial == null ? Feature(name: '') : Feature.fromJson(initial.toJson());
    final name = TextEditingController(text: f.name);
    final desc = TextEditingController(text: f.description);
    final uses = TextEditingController(text: f.maxUses?.toString() ?? '');
    final source = TextEditingController(text: f.source);
    var recharge = f.recharge;
    return showDialog<Feature>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(initial == null ? tr('Nuevo rasgo') : tr('Editar rasgo')),
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
                  TextField(
                    controller: source,
                    decoration: InputDecoration(labelText: tr('Origen (clase, dote, especie…)')),
                  ),
                  Gap.s,
                  TextField(
                    controller: uses,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: tr('Usos máximos (vacío = sin límite)')),
                  ),
                  Gap.s,
                  DropdownButtonFormField<Recharge>(
                    initialValue: recharge,
                    decoration: InputDecoration(labelText: tr('Se recupera con')),
                    items: [for (final r in Recharge.values) DropdownMenuItem(value: r, child: Text(r.label))],
                    onChanged: (v) => setState(() => recharge = v ?? recharge),
                  ),
                  Gap.s,
                  TextField(
                    controller: desc,
                    minLines: 3,
                    maxLines: 10,
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
                f
                  ..name = name.text.trim()
                  ..description = desc.text.trim()
                  ..maxUses = int.tryParse(uses.text)
                  ..recharge = recharge
                  ..source = source.text.trim();
                if (f.maxUses != null && f.used > f.maxUses!) f.used = f.maxUses!;
                Navigator.pop(ctx, f);
              },
              child: Text(tr('Guardar')),
            ),
          ],
        ),
      ),
    );
  }

  Future<Attack?> _attackDialog(BuildContext context, Attack? initial) {
    final a = initial == null ? Attack(name: '') : Attack.fromJson(initial.toJson());
    final name = TextEditingController(text: a.name);
    final bonus = TextEditingController(text: a.bonus);
    final damage = TextEditingController(text: a.damage);
    final notes = TextEditingController(text: a.notes);
    return showDialog<Attack>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Ataque')),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: InputDecoration(labelText: tr('Nombre')),
              ),
              Gap.s,
              TextField(
                controller: bonus,
                decoration: InputDecoration(labelText: tr('Bonificador de ataque'), hintText: '+5'),
              ),
              Gap.s,
              TextField(
                controller: damage,
                decoration: InputDecoration(labelText: tr('Daño'), hintText: tr('1d8+3 cortante')),
              ),
              Gap.s,
              TextField(
                controller: notes,
                decoration: InputDecoration(labelText: tr('Notas')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancelar'))),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              a
                ..name = name.text.trim()
                ..bonus = bonus.text.trim()
                ..damage = damage.text.trim()
                ..notes = notes.text.trim();
              Navigator.pop(ctx, a);
            },
            child: Text(tr('Guardar')),
          ),
        ],
      ),
    );
  }

  Future<void> _addFeat(BuildContext context) async {
    final feats = srd?.feats ?? <Feat>[];
    if (feats.isEmpty) return;
    final chosen = await showDialog<Feat>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(tr('Dotes del SRD')),
        children: [
          for (final f in feats) SimpleDialogOption(onPressed: () => Navigator.pop(ctx, f), child: Text(f.name)),
        ],
      ),
    );
    if (chosen != null) {
      set(
        () => c.features.add(
          Feature(name: chosen.name, description: chosen.description, source: tr('Dote'), recharge: Recharge.none),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(tr('Rasgos, dotes y recursos'), style: t.titleMedium),
            const Spacer(),
            if ((srd?.feats ?? []).isNotEmpty)
              TextButton(onPressed: () => _addFeat(context), child: Text(tr('Dote SRD'))),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final f = await _featureDialog(context, null);
                if (f != null) set(() => c.features.add(f));
              },
            ),
          ],
        ),
        for (final f in c.features)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(f.name),
            subtitle: Text(
              [
                f.source,
                if (f.maxUses != null) tr('{0} usos · {1}', [f.maxUses, f.recharge.label]),
              ].where((x) => x.isNotEmpty).join(' · '),
            ),
            onTap: () async {
              final edited = await _featureDialog(context, f);
              if (edited != null) set(() => c.features[c.features.indexOf(f)] = edited);
            },
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => set(() => c.features.remove(f)),
            ),
          ),
        const Divider(height: 32),
        Row(
          children: [
            Text(tr('Ataques'), style: t.titleMedium),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final a = await _attackDialog(context, null);
                if (a != null) set(() => c.attacks.add(a));
              },
            ),
          ],
        ),
        Text(tr('Las armas equipadas con daño también aparecen en la ficha.'), style: t.bodySmall),
        for (final a in c.attacks)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(a.name),
            subtitle: Text('${a.bonus} · ${a.damage}'),
            onTap: () async {
              final edited = await _attackDialog(context, a);
              if (edited != null) set(() => c.attacks[c.attacks.indexOf(a)] = edited);
            },
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => set(() => c.attacks.remove(a)),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Historia

class _StoryTab extends StatelessWidget {
  const _StoryTab({required this.c, required this.set});
  final Character c;
  final void Function(VoidCallback) set;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Field(
          label: tr('Rasgos de personalidad'),
          value: c.personality,
          lines: 2,
          onChanged: (v) => c.personality = v,
        ),
        Gap.m,
        _Field(label: tr('Ideales'), value: c.ideals, lines: 2, onChanged: (v) => c.ideals = v),
        Gap.m,
        _Field(label: tr('Vínculos'), value: c.bonds, lines: 2, onChanged: (v) => c.bonds = v),
        Gap.m,
        _Field(label: tr('Defectos'), value: c.flaws, lines: 2, onChanged: (v) => c.flaws = v),
        Gap.m,
        _Field(label: tr('Apariencia'), value: c.appearance, lines: 2, onChanged: (v) => c.appearance = v),
        Gap.m,
        _Field(label: tr('Historia'), value: c.backstory, lines: 6, onChanged: (v) => c.backstory = v),
      ],
    );
  }
}
