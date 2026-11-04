import '../core/i18n.dart';
import '../core/ids.dart';
import '../core/json.dart';

enum UnitSystem {
  imperial('Imperial (libras, pies)'),
  metric('Métrico (kg, metros, como los manuales en castellano)');

  const UnitSystem(this._label);
  final String _label;
  String get label => tr(_label);
}

/// Perfil local del usuario de este dispositivo. El mismo perfil puede ser
/// máster en unas partidas y jugador en otras.
class UserProfile {
  UserProfile({
    String? userId,
    String? secret,
    this.displayName = '',
    this.units = UnitSystem.metric,
    this.hostPort = 4040,
    this.relayUrl = '',
    this.language = AppLanguage.es,
  }) : userId = userId ?? newId(),
       secret = secret ?? newSecret();

  String userId;
  String secret;
  String displayName;
  UnitSystem units;
  int hostPort;
  String relayUrl;
  AppLanguage language;

  bool get isComplete => displayName.trim().isNotEmpty;

  UserProfile copy() => UserProfile.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'secret': secret,
    'displayName': displayName,
    'units': units.name,
    'hostPort': hostPort,
    'relayUrl': relayUrl,
    'language': language.name,
  };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    userId: asStringOrNull(j['userId']),
    secret: asStringOrNull(j['secret']),
    displayName: asString(j['displayName']),
    units: enumByName(UnitSystem.values, j['units'], UnitSystem.metric),
    hostPort: asInt(j['hostPort'], 4040),
    relayUrl: asString(j['relayUrl']),
    language: AppLanguage.parse(j['language']),
  );
}

/// Conversión de unidades para mostrar. Los datos se guardan siempre en libras
/// y pies (como el SRD); los manuales en castellano usan 1 lb ≈ 0,5 kg y
/// 5 pies = 1,5 m.
class Units {
  const Units(this.system);
  final UnitSystem system;

  String weight(double? lb, {int decimals = 1}) {
    if (lb == null) return '?';
    if (system == UnitSystem.metric) return '${_fmt(lb / 2, decimals)} kg';
    return '${_fmt(lb, decimals)} lb';
  }

  String distance(int feet) {
    if (system == UnitSystem.metric) return '${_fmt(feet * 0.3, 1)} m';
    return I18n.isEnglish ? '$feet ft' : '$feet pies';
  }

  /// Convierte un peso introducido por el usuario a libras.
  double toLb(double value) => system == UnitSystem.metric ? value * 2 : value;
  double fromLb(double lb) => system == UnitSystem.metric ? lb / 2 : lb;
  String get weightUnit => system == UnitSystem.metric ? 'kg' : 'lb';

  static String _fmt(double v, int decimals) {
    final s = v.toStringAsFixed(decimals);
    final trimmed = s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
    return trimmed.replaceAll('.', ',');
  }
}
