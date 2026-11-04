import 'i18n_en.dart';

/// Idiomas de la interfaz.
enum AppLanguage {
  es('Español'),
  en('English');

  const AppLanguage(this.nativeName);
  final String nativeName;

  static AppLanguage parse(Object? v) => v == 'en' ? AppLanguage.en : AppLanguage.es;
}

/// Traducción estilo gettext: el texto en castellano es la clave y
/// [englishStrings] da su traducción. Si falta una traducción se muestra el
/// castellano (el test `i18n_test.dart` avisa de las que faltan).
class I18n {
  static AppLanguage language = AppLanguage.es;

  static bool get isEnglish => language == AppLanguage.en;
}

/// Traduce [text] al idioma actual. Los marcadores `{0}`, `{1}`… se
/// sustituyen por [args] en orden.
String tr(String text, [List<Object?> args = const []]) {
  var s = I18n.language == AppLanguage.en ? (englishStrings[text] ?? text) : text;
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}
