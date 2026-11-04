import 'dart:io';

import 'package:dnd_tracker/core/i18n.dart';
import 'package:dnd_tracker/core/i18n_en.dart';
import 'package:dnd_tracker/domain/currency.dart';
import 'package:flutter_test/flutter_test.dart';

/// Convierte el contenido de un literal Dart (sin comillas) a su valor.
String _unescape(String s) {
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == r'\' && i + 1 < s.length) {
      final n = s[++i];
      out.write(switch (n) {
        'n' => '\n',
        't' => '\t',
        _ => n,
      });
    } else {
      out.write(c);
    }
  }
  return out.toString();
}

void main() {
  tearDown(() => I18n.language = AppLanguage.es);

  test('todos los textos tr() tienen traducción al inglés', () {
    final single = RegExp(r"""\btr\(\s*'((?:[^'\\$]|\\.)*)'\s*[,)]""");
    final double = RegExp(r'''\btr\(\s*"((?:[^"\\$]|\\.)*)"\s*[,)]''');
    final missing = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('i18n_en.dart')) continue;
      final src = f.readAsStringSync();
      for (final m in [...single.allMatches(src), ...double.allMatches(src)]) {
        final key = _unescape(m.group(1)!);
        if (!englishStrings.containsKey(key)) missing.add('${f.path}: $key');
      }
    }
    expect(missing, isEmpty, reason: 'Faltan traducciones en lib/core/i18n_en.dart');
  });

  test('los marcadores {0}, {1}… coinciden en ambos idiomas', () {
    final ph = RegExp(r'\{\d\}');
    for (final e in englishStrings.entries) {
      final a = ph.allMatches(e.key).map((m) => m.group(0)).toList()..sort();
      final b = ph.allMatches(e.value).map((m) => m.group(0)).toList()..sort();
      expect(b, a, reason: e.key);
    }
  });

  test('tr traduce y sustituye argumentos', () {
    expect(tr('Daño a {0}', ['Brom']), 'Daño a Brom');
    I18n.language = AppLanguage.en;
    expect(tr('Daño a {0}', ['Brom']), 'Damage to Brom');
    expect(tr('Texto que no existe'), 'Texto que no existe');
    expect(formatCp(1250), '12 gp 5 sp');
    expect(parseCost('2 pp'), 2000, reason: 'en inglés pp es platino');
  });
}
