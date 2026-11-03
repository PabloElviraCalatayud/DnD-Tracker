// Convierte los datos SRD de 5e-database (MIT, contenido SRD bajo CC-BY-4.0)
// al formato compacto que usa la app en assets/srd/<edicion>/.
//
// Uso:
//   git clone --depth 1 https://github.com/5e-bits/5e-srd-api /ruta/5e-srd-api
//   dart run tool/build_srd.dart /ruta/5e-srd-api/packages/5e-database/src
//
// Sólo usa dart:io y dart:convert para poder ejecutarse sin Flutter.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Uso: dart run tool/build_srd.dart <ruta a 5e-database/src>');
    exit(1);
  }
  final src = args.first;
  for (final edition in ['2014', '2024']) {
    final inDir = '$src/$edition/en';
    final outDir = Directory('assets/srd/$edition')..createSync(recursive: true);
    List<dynamic> load(String name) {
      final f = File('$inDir/5e-SRD-$name.json');
      if (!f.existsSync()) return const [];
      return jsonDecode(f.readAsStringSync()) as List<dynamic>;
    }

    void save(String name, Object data) {
      File('${outDir.path}/$name.json').writeAsStringSync(jsonEncode(data));
    }

    final monsters = load('Monsters').map((m) => _monster(m as Map<String, dynamic>)).toList();
    final spells = load('Spells').map((s) => _spell(s as Map<String, dynamic>)).toList();
    final items = [
      ...load('Equipment').map((e) => _equipment(e as Map<String, dynamic>)),
      ...load('Magic-Items').map((e) => _magicItem(e as Map<String, dynamic>)),
    ];
    final conditions = load('Conditions').map((c) {
      final m = c as Map<String, dynamic>;
      return {'id': m['index'], 'name': m['name'], 'desc': _text(m['desc'] ?? m['description'])};
    }).toList();
    final classes = _classes(load('Classes'), load('Levels'));
    final speciesFile = edition == '2014' ? 'Races' : 'Species';
    final lists = {
      'species': load(speciesFile).map((e) => (e as Map)['name']).toList(),
      'subspecies': load(edition == '2014' ? 'Subraces' : 'Subspecies').map((e) => (e as Map)['name']).toList(),
      'backgrounds': load('Backgrounds').map((e) => (e as Map)['name']).toList(),
      'languages': load('Languages').map((e) => (e as Map)['name']).toList(),
      'feats': load('Feats').map((e) {
        final m = e as Map<String, dynamic>;
        return {'name': m['name'], 'desc': _text(m['desc'] ?? m['description'])};
      }).toList(),
    };
    final craft = load('Equipment')
        .cast<Map<String, dynamic>>()
        .where((e) => e['craft'] is List && (e['craft'] as List).isNotEmpty)
        .map(
          (e) => {
            'tool': e['name'],
            'toolId': e['index'],
            'ability': (e['ability'] as Map?)?['name'],
            'items': (e['craft'] as List).map((c) => (c as Map)['index']).toList(),
          },
        )
        .toList();
    final rules = _rules(load('Rules'));

    save('monsters', monsters);
    save('spells', spells);
    save('items', items);
    save('conditions', conditions);
    save('classes', classes);
    save('lists', lists);
    save('craft', craft);
    save('rules', rules);
    stdout.writeln(
      '$edition: ${monsters.length} monstruos, ${spells.length} conjuros, '
      '${items.length} objetos, ${conditions.length} estados, ${classes.length} clases, '
      '${craft.length} herramientas de artesano, ${rules.length} capítulos de reglas',
    );
  }
}

String _text(Object? v) {
  if (v == null) return '';
  if (v is List) return v.map((e) => e.toString()).join('\n\n');
  return v.toString();
}

String _names(Object? list) {
  if (list is! List) return '';
  return list.map((e) => e is Map ? (e['name'] ?? e['index']) : e.toString()).join(', ');
}

String _cr(num cr) {
  if (cr == 0.125) return '1/8';
  if (cr == 0.25) return '1/4';
  if (cr == 0.5) return '1/2';
  return cr.toInt().toString();
}

String _speed(Object? s) {
  if (s is! Map) return '';
  final parts = <String>[];
  s.forEach((k, v) {
    if (k == 'hover') {
      if (v == true) parts.add('(hover)');
      return;
    }
    parts.add(k == 'walk' ? '$v' : '$k $v');
  });
  return parts.join(', ');
}

String _senses(Object? s) {
  if (s is! Map) return '';
  final parts = <String>[];
  s.forEach((k, v) {
    final label = k.toString().replaceAll('_', ' ');
    parts.add('$label $v');
  });
  return parts.join(', ');
}

List<Map<String, String>> _actions(Object? list) {
  if (list is! List) return const [];
  return list.map((a) {
    final m = a as Map<String, dynamic>;
    var name = m['name'].toString();
    final usage = m['usage'];
    if (usage is Map) {
      if (usage['type'] == 'per day') {
        name += ' (${usage['times']}/día)';
      } else if (usage['type'] == 'recharge on roll') {
        final min = usage['min_value'];
        name += min == 6 ? ' (Recarga 6)' : ' (Recarga $min-6)';
      } else if (usage['type'] == 'recharge after rest') {
        name += ' (se recarga tras descanso)';
      }
    }
    return {'n': name, 'd': _text(m['desc'])};
  }).toList();
}

Map<String, Object?> _monster(Map<String, dynamic> m) {
  final ac = (m['armor_class'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
  final acValue = ac.isEmpty ? 10 : (ac.first['value'] as num).toInt();
  final acNote = ac.isEmpty
      ? ''
      : [
          for (final a in ac)
            if (a['armor'] is List)
              _names(a['armor'])
            else if (a['type'] != null && a['type'] != 'dex')
              a['type'].toString(),
        ].where((e) => e.isNotEmpty).join(', ');
  final saves = <String>[];
  final skills = <String>[];
  for (final p in (m['proficiencies'] as List? ?? const [])) {
    final prof = (p as Map)['proficiency'] as Map;
    final name = prof['name'].toString();
    final value = (p['value'] as num).toInt();
    final sign = value >= 0 ? '+' : '';
    if (name.startsWith('Saving Throw: ')) {
      saves.add('${name.substring(14)} $sign$value');
    } else if (name.startsWith('Skill: ')) {
      skills.add('${name.substring(7)} $sign$value');
    }
  }
  final cr = (m['challenge_rating'] as num?) ?? 0;
  return {
    'id': m['index'],
    'name': m['name'],
    'size': m['size'],
    'type': [m['type'], if (m['subtype'] != null) '(${m['subtype']})'].join(' '),
    'alignment': m['alignment'],
    'ac': acValue,
    'acNote': acNote,
    'hp': m['hit_points'],
    'hitDice': m['hit_points_roll'] ?? m['hit_dice'],
    'speed': _speed(m['speed']),
    'abilities': [m['strength'], m['dexterity'], m['constitution'], m['intelligence'], m['wisdom'], m['charisma']],
    'saves': saves.join(', '),
    'skills': skills.join(', '),
    'vuln': (m['damage_vulnerabilities'] as List? ?? const []).join(', '),
    'res': (m['damage_resistances'] as List? ?? const []).join(', '),
    'imm': (m['damage_immunities'] as List? ?? const []).join(', '),
    'condImm': _names(m['condition_immunities']),
    'senses': _senses(m['senses']),
    'languages': m['languages'] ?? '',
    'cr': cr,
    'crText': _cr(cr),
    'xp': m['xp'] ?? 0,
    'pb': m['proficiency_bonus'],
    'traits': _actions(m['special_abilities']),
    'actions': _actions(m['actions']),
    'bonus': _actions(m['bonus_actions']),
    'reactions': _actions(m['reactions']),
    'legendary': _actions(m['legendary_actions']),
    if (m['desc'] != null) 'desc': _text(m['desc']),
  };
}

Map<String, Object?> _spell(Map<String, dynamic> s) {
  final comps = (s['components'] as List? ?? const []).join(', ');
  final dmg = s['damage'];
  String damageType = '';
  if (dmg is Map && dmg['damage_type'] is Map) damageType = dmg['damage_type']['name'].toString();
  return {
    'id': s['index'],
    'name': s['name'],
    'level': s['level'],
    'school': (s['school'] as Map?)?['name'] ?? '',
    'time': s['casting_time'] ?? '',
    'range': s['range'] ?? '',
    'components': comps,
    'material': s['material'] ?? '',
    'duration': s['duration'] ?? '',
    'conc': s['concentration'] ?? false,
    'ritual': s['ritual'] ?? false,
    'classes': (s['classes'] as List? ?? const []).map((c) => (c as Map)['name']).toList(),
    'desc': _text(s['desc'] ?? s['description']),
    'higher': _text(s['higher_level']),
    if (damageType.isNotEmpty) 'damageType': damageType,
    if (s['attack_type'] != null) 'attack': s['attack_type'],
    if (s['dc'] is Map) 'save': ((s['dc'] as Map)['dc_type'] as Map?)?['name'],
  };
}

int _costCp(Object? cost) {
  if (cost is! Map) return 0;
  final q = (cost['quantity'] as num?) ?? 0;
  const mult = {'cp': 1, 'sp': 10, 'ep': 50, 'gp': 100, 'pp': 1000};
  return (q * (mult[cost['unit']] ?? 100)).round();
}

String _equipmentCategory(Map<String, dynamic> e) {
  final ids = <String>{
    if (e['equipment_category'] is Map) (e['equipment_category'] as Map)['index'].toString(),
    for (final c in (e['equipment_categories'] as List? ?? const [])) (c as Map)['index'].toString(),
  };
  if (ids.contains('weapon') || ids.contains('weapons')) return 'weapon';
  if (ids.contains('armor') || ids.contains('shields')) return 'armor';
  if (ids.contains('ammunition')) return 'ammunition';
  if (ids.contains('tools') || ids.contains('artisans-tools')) return 'tool';
  if (ids.contains('mounts-and-vehicles')) return 'mount';
  if (ids.contains('equipment-packs')) return 'pack';
  if (ids.contains('arcane-foci') || ids.contains('druidic-foci') || ids.contains('holy-symbols')) {
    return 'focus';
  }
  return 'gear';
}

String _damage(Object? d) {
  if (d is! Map) return '';
  final type = (d['damage_type'] as Map?)?['name'] ?? '';
  return '${d['damage_dice']} $type'.trim();
}

Map<String, Object?> _equipment(Map<String, dynamic> e) {
  final ac = e['armor_class'];
  String acText = '';
  if (ac is Map) {
    acText = '${ac['base']}';
    if (ac['dex_bonus'] == true) {
      final max = ac['max_bonus'];
      acText += (max == null || max == 0) ? ' + DES' : ' + DES (máx. $max)';
    }
  }
  final sub = e['weapon_category'] != null
      ? '${e['weapon_category']} ${e['weapon_range'] ?? ''}'.trim()
      : (e['armor_category'] ?? (e['gear_category'] as Map?)?['name'] ?? (e['tool_category'] ?? ''));
  final range = e['range'];
  String rangeText = '';
  if (range is Map && range['long'] != null) rangeText = '${range['normal']}/${range['long']} ft.';
  return {
    'id': e['index'],
    'name': e['name'],
    'cat': _equipmentCategory(e),
    'sub': sub.toString(),
    'cost': _costCp(e['cost']),
    'weight': e['weight'] ?? 0,
    'desc': _text(e['desc'] ?? e['description']),
    if (_damage(e['damage']).isNotEmpty) 'damage': _damage(e['damage']),
    if (_damage(e['two_handed_damage']).isNotEmpty) 'damage2h': _damage(e['two_handed_damage']),
    if (rangeText.isNotEmpty) 'range': rangeText,
    if (e['properties'] is List && (e['properties'] as List).isNotEmpty)
      'props': (e['properties'] as List).map((p) => (p as Map)['name']).toList(),
    if (acText.isNotEmpty) 'ac': acText,
    if (e['mastery'] is Map) 'mastery': (e['mastery'] as Map)['name'],
    if (e['stealth_disadvantage'] == true) 'stealthDis': true,
    if ((e['str_minimum'] ?? 0) != 0) 'strMin': e['str_minimum'],
    if (e['quantity'] != null && e['quantity'] != 1) 'qty': e['quantity'],
  };
}

Map<String, Object?> _magicItem(Map<String, dynamic> e) {
  final desc = _text(e['desc']);
  final attune = e['attunement'] == true || desc.toLowerCase().contains('requires attunement');
  return {
    'id': 'magic-${e['index']}',
    'name': e['name'],
    'cat': 'magic',
    'sub': (e['equipment_category'] as Map?)?['name'] ?? '',
    'cost': 0,
    'weight': 0,
    'desc': desc,
    'rarity': (e['rarity'] as Map?)?['name'] ?? '',
    if (attune) 'attune': true,
  };
}

List<Map<String, Object?>> _classes(List<dynamic> classes, List<dynamic> levels) {
  return classes.cast<Map<String, dynamic>>().map((c) {
    final id = c['index'];
    final lv =
        levels
            .cast<Map<String, dynamic>>()
            .where((l) => (l['class'] as Map)['index'] == id && l['subclass'] == null)
            .toList()
          ..sort((a, b) => (a['level'] as int).compareTo(b['level'] as int));
    final spellAbility = ((c['spellcasting'] as Map?)?['spellcasting_ability'] as Map?)?['name'];
    return {
      'id': id,
      'name': c['name'],
      'hitDie': c['hit_die'],
      'saves': (c['saving_throws'] as List? ?? const []).map((s) => (s as Map)['name']).toList(),
      'spellAbility': ?spellAbility,
      'levels': lv.map((l) {
        final sc = l['spellcasting'] as Map<String, dynamic>?;
        return {
          'l': l['level'],
          'pb': l['prof_bonus'],
          'features': (l['features'] as List? ?? const []).map((f) => (f as Map)['name']).toList(),
          if (sc != null) ...{
            'cantrips': sc['cantrips_known'] ?? 0,
            if (sc['prepared_spells'] != null) 'prepared': sc['prepared_spells'],
            if (sc['spells_known'] != null) 'known': sc['spells_known'],
            'slots': [for (var i = 1; i <= 9; i++) sc['spell_slots_level_$i'] ?? 0],
          },
        };
      }).toList(),
    };
  }).toList();
}

List<Map<String, Object?>> _rules(List<dynamic> rules) {
  final all = rules.cast<Map<String, dynamic>>();
  final byIndex = {for (final r in all) r['index']: r};
  final parents = all.where((r) => r['children'] is List).toList();
  return parents.map((p) {
    final sections = (p['children'] as List).map((c) {
      final child = byIndex[(c as Map)['index']];
      return {'id': c['index'], 'name': c['name'], 'desc': child == null ? '' : _text(child['desc'])};
    }).toList();
    return {'id': p['index'], 'name': p['name'], 'sections': sections};
  }).toList();
}
