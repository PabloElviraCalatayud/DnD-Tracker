import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dice.dart';
import '../../../core/ids.dart';
import '../../../domain/abilities.dart';
import '../../../domain/board.dart';
import '../../../domain/monster.dart';
import '../../../domain/ruleset.dart';
import '../../../engine/commands.dart';
import '../../../state/providers.dart';
import '../../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../shared/dice_roller.dart';
import '../shared/initiative_screen.dart';
import '../../../core/i18n.dart';

/// Grimorio del máster: monstruos del SRD de la edición y los personalizados.
class BestiaryScreen extends ConsumerStatefulWidget {
  const BestiaryScreen({super.key, this.picking = false});

  /// Si es true, al tocar un monstruo se devuelve en vez de abrir el detalle.
  final bool picking;

  @override
  ConsumerState<BestiaryScreen> createState() => _BestiaryScreenState();
}

class _BestiaryScreenState extends ConsumerState<BestiaryScreen> {
  String _query = '';
  String? _type;
  RangeValues _cr = const RangeValues(0, 30);
  bool _onlyCustom = false;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final srd = ref.watch(srdProvider(s.campaign.ruleset));
    final custom = s.campaign.monsters;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: widget.picking
          ? null
          : FloatingActionButton.extended(
              onPressed: () => openMonsterEditor(context, null),
              icon: const Icon(Icons.add),
              label: Text(tr('Criatura')),
            ),
      body: srd.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) {
          final all = [...custom, if (!_onlyCustom) ...data.monsters];
          final types = {for (final m in all) m.type.split(' ').first.toLowerCase()}.toList()..sort();
          final q = _query.toLowerCase();
          final list = all.where((m) {
            if (q.isNotEmpty && !m.name.toLowerCase().contains(q)) return false;
            if (_type != null && !m.type.toLowerCase().startsWith(_type!)) return false;
            return m.cr >= _cr.start && m.cr <= _cr.end;
          }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: SearchField(
                  onChanged: (v) => setState(() => _query = v),
                  hint: tr('Buscar criatura (goblin, dragon…)'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: _type,
                        hint: Text(tr('Tipo')),
                        items: [
                          DropdownMenuItem(value: null, child: Text(tr('Todos los tipos'))),
                          for (final ty in types) DropdownMenuItem(value: ty, child: Text(ty)),
                        ],
                        onChanged: (v) => setState(() => _type = v),
                      ),
                    ),
                    Gap.s,
                    FilterChip(
                      label: Text(tr('Mías ({0})', [custom.length])),
                      selected: _onlyCustom,
                      onSelected: (v) => setState(() => _onlyCustom = v),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Text(tr('VD {0}–{1}', [_crText(_cr.start), _crText(_cr.end)]), style: t.bodySmall),
                    Expanded(
                      child: RangeSlider(
                        values: _cr,
                        min: 0,
                        max: 30,
                        divisions: 30,
                        onChanged: (v) => setState(() => _cr = v),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? EmptyState(icon: 'dragon', title: tr('Ninguna criatura coincide'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 90),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final m = list[i];
                          return ListTile(
                            leading: GameIcon(
                              m.iconName,
                              size: 30,
                              color: m.custom ? AppColors.arcane : AppColors.gold,
                            ),
                            title: Text(m.name),
                            subtitle: Text(
                              tr('VD {0} · {1} {2} · CA {3} · PG {4}', [m.crText, m.size, m.type, m.ac, m.hp]),
                            ),
                            trailing: m.custom ? Pill(tr('propia'), color: AppColors.arcane) : null,
                            onTap: () {
                              if (widget.picking) {
                                Navigator.pop(context, m);
                              } else {
                                openMonsterDetail(context, m);
                              }
                            },
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  tr('{0} criaturas · {1} (CC-BY-4.0)', [list.length, s.campaign.ruleset.srdName]),
                  style: t.bodySmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _crText(double v) => v == 0 ? '0' : v.toInt().toString();
}

/// Abre el bestiario para elegir una criatura.
Future<Monster?> pickMonster(BuildContext context) {
  final s = SessionScope.read(context);
  return Navigator.push<Monster>(
    context,
    MaterialPageRoute(
      builder: (_) => SessionScope(
        session: s,
        child: AppScaffold(title: tr('Elegir criatura'), body: const BestiaryScreen(picking: true)),
      ),
    ),
  );
}

void openMonsterDetail(BuildContext context, Monster m) {
  final s = SessionScope.read(context);
  Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => SessionScope(
        session: s,
        child: MonsterDetailScreen(monster: m),
      ),
    ),
  );
}

class MonsterDetailScreen extends StatelessWidget {
  const MonsterDetailScreen({super.key, required this.monster});
  final Monster monster;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final m = monster.custom ? (s.campaign.monsters.where((x) => x.id == monster.id).firstOrNull ?? monster) : monster;
    return AppScaffold(
      title: m.name,
      actions: [
        IconButton(
          tooltip: tr('Añadir al combate'),
          icon: const GameIcon('crossed_swords', size: 24),
          onPressed: () => addMonsterDialog(context, m),
        ),
        PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'copy') {
              final copy = m.copy()
                ..id = newId()
                ..name = m.custom ? tr('{0} (copia)', [m.name]) : m.name
                ..custom = true;
              await openMonsterEditor(context, copy);
            } else if (v == 'edit') {
              await openMonsterEditor(context, m);
            } else if (v == 'delete') {
              final ok = await confirm(
                context,
                tr('Borrar'),
                tr('¿Borrar {0} de tu grimorio?', [m.name]),
                ok: tr('Borrar'),
                danger: true,
              );
              if (ok) {
                await s.send(Command.deleteMonster(m.id));
                if (context.mounted) Navigator.pop(context);
              }
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'copy', child: Text(m.custom ? tr('Duplicar') : tr('Copiar y personalizar'))),
            if (m.custom) PopupMenuItem(value: 'edit', child: Text(tr('Editar'))),
            if (m.custom) PopupMenuItem(value: 'delete', child: Text(tr('Borrar'))),
          ],
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: StatBlock(monster: m),
          ),
        ),
      ),
    );
  }
}

/// Bloque de estadísticas con tiradas al tocar.
class StatBlock extends StatelessWidget {
  const StatBlock({super.key, required this.monster});
  final Monster monster;

  static final _hit = RegExp(
    r'(?:Attack Roll|to hit|Tirada de ataque[^:]*)[: ]*\s*([+-]\d+)|([+-]\d+) (?:to hit|a impactar)',
    caseSensitive: false,
  );
  static final _dmg = RegExp(r'\((\d+d\d+(?:\s*[+−-]\s*\d+)?)\)');

  @override
  Widget build(BuildContext context) {
    final m = monster;
    final t = Theme.of(context).textTheme;
    Widget line(String label, String value) => value.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: RichText(
              text: TextSpan(
                style: t.bodyMedium,
                children: [
                  TextSpan(
                    text: '$label ',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.gold),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          );
    Widget section(String title, List<NamedText> entries) {
      if (entries.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Gap.m,
          Text(title, style: t.titleLarge?.copyWith(color: AppColors.crimson)),
          Divider(color: AppColors.crimson),
          for (final e in entries) _ActionEntry(entry: e, monsterName: m.name, hit: _hit, dmg: _dmg),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                GameIcon(m.iconName, size: 54, color: AppColors.crimson),
                Gap.m,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name, style: t.headlineSmall?.copyWith(color: AppColors.crimson)),
                      Text(
                        '${m.size} ${m.type}${m.alignment.isNotEmpty ? ', ${m.alignment}' : ''}',
                        style: t.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(color: AppColors.crimson, height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatBox(label: tr('CA'), value: '${m.ac}', sub: m.acNote.isEmpty ? null : m.acNote, width: 100),
                StatBox(
                  label: tr('PG'),
                  value: '${m.hp}',
                  sub: m.hitDice,
                  width: 110,
                  onTap: m.hitDice.isEmpty
                      ? null
                      : () => showExpressionRoll(context, tr('PG de {0}', [m.name]), m.hitDiceExpression),
                ),
                StatBox(label: tr('VD'), value: m.crText, sub: tr('{0} PX', [m.xp]), width: 90),
                StatBox(
                  label: tr('Iniciativa'),
                  value: signed(m.mod(Ability.dex)),
                  onTap: () => showD20Roll(context, tr('Iniciativa: {0}', [m.name]), m.mod(Ability.dex)),
                ),
              ],
            ),
            Gap.s,
            line(tr('Velocidad'), m.speed),
            Gap.s,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final a in Ability.values)
                  InkWell(
                    onTap: () => showD20Roll(context, '${a.label} (${m.name})', m.mod(a)),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        children: [
                          Text(a.abbr, style: t.labelLarge?.copyWith(color: AppColors.gold)),
                          Text('${m.score(a)}', style: t.titleMedium),
                          Text(signed(m.mod(a)), style: t.bodySmall),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Divider(color: AppColors.crimson, height: 20),
            line(tr('Salvaciones'), m.saves),
            line(tr('Habilidades'), m.skills),
            line(tr('Vulnerabilidades'), m.vulnerabilities),
            line(tr('Resistencias'), m.resistances),
            line(tr('Inmunidades'), m.immunities),
            line(tr('Inmune a estados'), m.conditionImmunities),
            line(tr('Sentidos'), m.senses),
            line(tr('Idiomas'), m.languages),
            section(tr('Rasgos'), m.traits),
            section(tr('Acciones'), m.actions),
            section(tr('Acciones adicionales'), m.bonusActions),
            section(tr('Reacciones'), m.reactions),
            section(tr('Acciones legendarias'), m.legendary),
            if (m.description.isNotEmpty) ...[Gap.m, RichDescription(m.description)],
          ],
        ),
      ),
    );
  }
}

class _ActionEntry extends StatelessWidget {
  const _ActionEntry({required this.entry, required this.monsterName, required this.hit, required this.dmg});
  final NamedText entry;
  final String monsterName;
  final RegExp hit;
  final RegExp dmg;

  @override
  Widget build(BuildContext context) {
    final h = hit.firstMatch(entry.text);
    final bonus = h == null ? null : int.tryParse((h.group(1) ?? h.group(2) ?? '').replaceAll('+', ''));
    final damages = dmg
        .allMatches(entry.text)
        .map((m) => m.group(1)!.replaceAll(' ', '').replaceAll('−', '-'))
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichDescription('***${entry.name}.*** ${entry.text}'),
          if (bonus != null || damages.isNotEmpty)
            Wrap(
              spacing: 6,
              children: [
                if (bonus != null)
                  ActionChip(
                    avatar: const GameIcon('d20', size: 16),
                    label: Text(tr('Atacar {0}', [signed(bonus)])),
                    onPressed: () => showD20Roll(context, '${entry.name} ($monsterName)', bonus),
                  ),
                for (final d in damages.take(2))
                  ActionChip(
                    avatar: const GameIcon('sword_wound', size: 16),
                    label: Text(d),
                    onPressed: () => showExpressionRoll(context, tr('Daño: {0}', [entry.name]), d),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Diálogo para añadir N copias de una criatura al combate.
/// Añade criaturas al combate. Si hay un mapa activo también salen como
/// fichas: con [onPlace] (desde el tablero) el máster elige dónde va cada una;
/// si no, se colocan solas en casillas libres.
Future<void> addMonsterDialog(
  BuildContext context,
  Monster m, {
  void Function(List<BoardToken> tokens)? onPlace,
}) async {
  final s = SessionScope.read(context);
  var count = 1;
  var rollHp = false;
  var hidden = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(tr('Añadir {0} al combate', [m.name])),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(tr('Cantidad')),
                const Spacer(),
                NumberStepper(value: count, min: 1, max: 30, onChanged: (v) => setState(() => count = v)),
              ],
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: rollHp,
              title: Text(tr('Tirar PG ({0})', [m.hitDice])),
              subtitle: Text(tr('Si no, {0} PG cada uno', [m.hp])),
              onChanged: m.hitDice.isEmpty ? null : (v) => setState(() => rollHp = v ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: hidden,
              title: Text(tr('Ocultos a los jugadores')),
              onChanged: (v) => setState(() => hidden = v ?? false),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancelar'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Añadir'))),
        ],
      ),
    ),
  );
  if (ok != true) return;
  final before = s.campaign.encounter.combatants.map((c) => c.id).toSet();
  final e = addMonstersToEncounter(s.campaign.encounter.copy(), m, count, rollHp: rollHp, hidden: hidden);
  await s.send(Command.putEncounter(e));
  // Si hay un mapa activo, las criaturas aparecen también como fichas.
  final map = s.campaign.board.activeMap;
  if (map != null) {
    final size = monsterTokenSize(m.size);
    final board = s.campaign.board.copy();
    final tokens = <BoardToken>[];
    for (final c in e.combatants.where((c) => !before.contains(c.id))) {
      final (x, y) = board.freeCell(map, startX: map.cols - 2, startY: 1);
      final token = BoardToken(
        mapId: map.id,
        kind: TokenKind.monster,
        combatantId: c.id,
        monsterId: m.id,
        icon: m.iconName,
        x: x,
        y: y,
        size: size,
        hidden: hidden,
      );
      board.tokens.add(token);
      tokens.add(token);
    }
    if (onPlace != null) {
      onPlace(tokens);
    } else {
      for (final t in tokens) {
        await s.send(Command.putToken(t));
      }
    }
  }
  if (context.mounted) showSnack(context, tr('{0}× {1} añadido(s) al combate', [count, m.name]));
}

// ------------------------------------------------------------------ Editor

Future<void> openMonsterEditor(BuildContext context, Monster? m) {
  final s = SessionScope.read(context);
  return Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => SessionScope(
        session: s,
        child: _MonsterEditor(initial: m),
      ),
    ),
  );
}

class _MonsterEditor extends StatefulWidget {
  const _MonsterEditor({this.initial});
  final Monster? initial;

  @override
  State<_MonsterEditor> createState() => _MonsterEditorState();
}

class _MonsterEditorState extends State<_MonsterEditor> {
  late Monster _m;
  final Map<String, TextEditingController> _c = {};

  TextEditingController _ctrl(String key, String value) =>
      _c.putIfAbsent(key, () => TextEditingController(text: value));

  static String _blocks(List<NamedText> list) => list.map((e) => '${e.name}. ${e.text}').join('\n\n');

  static List<NamedText> _parse(String text) {
    final out = <NamedText>[];
    for (final block in text.split(RegExp(r'\n\s*\n'))) {
      final b = block.trim();
      if (b.isEmpty) continue;
      final dot = b.indexOf('. ');
      out.add(dot > 0 && dot < 60 ? NamedText(b.substring(0, dot), b.substring(dot + 2)) : NamedText(b, ''));
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _m = widget.initial?.copy() ?? Monster(name: '', custom: true);
    _m.custom = true;
  }

  Future<void> _save() async {
    final s = SessionScope.read(context);
    String v(String k) => _c[k]?.text.trim() ?? '';
    _m
      ..name = v('name')
      ..size = v('size')
      ..type = v('type')
      ..alignment = v('alignment')
      ..ac = int.tryParse(v('ac')) ?? _m.ac
      ..acNote = v('acNote')
      ..hp = int.tryParse(v('hp')) ?? _m.hp
      ..hitDice = v('hitDice')
      ..speed = v('speed')
      ..saves = v('saves')
      ..skills = v('skills')
      ..resistances = v('res')
      ..immunities = v('imm')
      ..vulnerabilities = v('vuln')
      ..conditionImmunities = v('condImm')
      ..senses = v('senses')
      ..languages = v('languages')
      ..crText = v('cr').isEmpty ? '0' : v('cr')
      ..traits = _parse(v('traits'))
      ..actions = _parse(v('actions'))
      ..bonusActions = _parse(v('bonus'))
      ..reactions = _parse(v('reactions'))
      ..legendary = _parse(v('legendary'))
      ..description = v('desc');
    _m.cr = parseCr(_m.crText);
    _m.xp = Rules.xpByCr[_m.crText] ?? _m.xp;
    if (_m.name.isEmpty) {
      showSnack(context, tr('Ponle nombre a la criatura'), error: true);
      return;
    }
    if (_m.hitDice.isNotEmpty && int.tryParse(v('hp')) == null) _m.hp = averageOf(_m.hitDice);
    final r = await s.send(Command.putMonster(_m));
    if (!mounted) return;
    if (r.ok) {
      Navigator.pop(context);
    } else {
      showSnack(context, r.error ?? tr('Error'), error: true);
    }
  }

  Widget _f(String key, String label, String value, {int lines = 1, String? hint}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: _ctrl(key, value),
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 8,
      decoration: InputDecoration(labelText: label, hintText: hint, alignLabelWithHint: lines > 1),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppScaffold(
      title: widget.initial == null ? tr('Nueva criatura') : tr('Editar {0}', [_m.name]),
      actions: [TextButton(onPressed: _save, child: Text(tr('Guardar')))],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _f('name', tr('Nombre'), _m.name),
          Row(
            children: [
              Expanded(child: _f('size', tr('Tamaño'), _m.size, hint: 'Medium')),
              Gap.s,
              Expanded(child: _f('type', tr('Tipo'), _m.type, hint: 'humanoid')),
              Gap.s,
              Expanded(child: _f('alignment', tr('Alineamiento'), _m.alignment)),
            ],
          ),
          Row(
            children: [
              Expanded(child: _f('ac', tr('CA'), '${_m.ac}')),
              Gap.s,
              Expanded(child: _f('acNote', tr('Armadura'), _m.acNote)),
              Gap.s,
              Expanded(child: _f('hp', tr('PG'), '${_m.hp}')),
              Gap.s,
              Expanded(child: _f('hitDice', tr('Dados de golpe'), _m.hitDice, hint: '4d8+4')),
            ],
          ),
          Row(
            children: [
              Expanded(flex: 2, child: _f('speed', tr('Velocidad'), _m.speed, hint: '30 ft., fly 60 ft.')),
              Gap.s,
              Expanded(child: _f('cr', tr('VD'), _m.crText, hint: '1/4')),
            ],
          ),
          Text(tr('Características'), style: t.titleSmall),
          Wrap(
            spacing: 4,
            children: [
              for (final a in Ability.values)
                SizedBox(
                  width: 150,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(a.abbr),
                    trailing: NumberStepper(
                      compact: true,
                      value: _m.score(a),
                      min: 1,
                      max: 30,
                      onChanged: (v) => setState(() => _m.abilities[Ability.values.indexOf(a)] = v),
                    ),
                  ),
                ),
            ],
          ),
          Gap.s,
          _f('saves', tr('Salvaciones'), _m.saves, hint: 'DEX +4, WIS +2'),
          _f('skills', tr('Habilidades'), _m.skills, hint: 'Stealth +6'),
          _f('res', tr('Resistencias'), _m.resistances),
          _f('imm', tr('Inmunidades'), _m.immunities),
          _f('vuln', tr('Vulnerabilidades'), _m.vulnerabilities),
          _f('condImm', tr('Inmune a estados'), _m.conditionImmunities),
          _f('senses', tr('Sentidos'), _m.senses),
          _f('languages', tr('Idiomas'), _m.languages),
          Text(
            tr('Separa cada rasgo o acción con una línea en blanco. Formato: «Nombre. Descripción».'),
            style: t.bodySmall,
          ),
          Gap.s,
          _f('traits', tr('Rasgos'), _blocks(_m.traits), lines: 3),
          _f(
            'actions',
            tr('Acciones'),
            _blocks(_m.actions),
            lines: 4,
            hint: 'Mordisco. Melee Attack Roll: +5, reach 5 ft. Hit: 7 (1d10 + 2) Piercing damage.',
          ),
          _f('bonus', tr('Acciones adicionales'), _blocks(_m.bonusActions), lines: 2),
          _f('reactions', tr('Reacciones'), _blocks(_m.reactions), lines: 2),
          _f('legendary', tr('Acciones legendarias'), _blocks(_m.legendary), lines: 2),
          _f('desc', tr('Notas / descripción'), _m.description, lines: 3),
          FilledButton(onPressed: _save, child: Text(tr('Guardar en el grimorio'))),
        ],
      ),
    );
  }
}

/// Casillas que ocupa una criatura según su tamaño (en inglés o en castellano).
int monsterTokenSize(String size) {
  final v = size.toLowerCase();
  if (v.startsWith('gargant')) return 4;
  if (v.startsWith('huge') || v.startsWith('enorme')) return 3;
  if (v.startsWith('large') || v.startsWith('grande')) return 2;
  return 1;
}
