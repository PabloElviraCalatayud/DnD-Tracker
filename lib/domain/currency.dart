import '../core/i18n.dart';
import '../core/json.dart';

/// Monedas: pc (cobre), pp (plata), pe (electro), po (oro), ppt (platino).
class Currency {
  Currency({this.cp = 0, this.sp = 0, this.ep = 0, this.gp = 0, this.pp = 0});

  int cp;
  int sp;
  int ep;
  int gp;
  int pp;

  static const _labelsEs = ['pc', 'pp', 'pe', 'po', 'ppt'];
  static const _labelsEn = ['cp', 'sp', 'ep', 'gp', 'pp'];
  static const _namesEs = ['Cobre', 'Plata', 'Electro', 'Oro', 'Platino'];
  static const _namesEn = ['Copper', 'Silver', 'Electrum', 'Gold', 'Platinum'];

  /// Abreviaturas de las monedas en el idioma actual (de menor a mayor valor).
  static List<String> get coinLabels => I18n.isEnglish ? _labelsEn : _labelsEs;
  static List<String> get coinNames => I18n.isEnglish ? _namesEn : _namesEs;
  static const coinValuesCp = [1, 10, 50, 100, 1000];

  List<int> get asList => [cp, sp, ep, gp, pp];

  void setIndex(int i, int value) {
    switch (i) {
      case 0:
        cp = value;
      case 1:
        sp = value;
      case 2:
        ep = value;
      case 3:
        gp = value;
      case 4:
        pp = value;
    }
  }

  int get totalCp => cp + sp * 10 + ep * 50 + gp * 100 + pp * 1000;
  int get coinCount => cp + sp + ep + gp + pp;

  /// 50 monedas pesan 1 libra.
  double get weightLb => coinCount / 50;

  bool canAfford(int costCp) => totalCp >= costCp;

  /// Paga [costCp] usando primero las monedas pequeñas y devolviendo el cambio
  /// en las monedas más grandes posibles. Devuelve false si no alcanza.
  bool pay(int costCp) {
    if (costCp <= 0) return true;
    if (!canAfford(costCp)) return false;
    var remaining = totalCp - costCp;
    // Conservamos el platino y el electro que no sea necesario tocar.
    final original = asList;
    final result = List<int>.filled(5, 0);
    for (var i = 4; i >= 0; i--) {
      final value = coinValuesCp[i];
      final use = remaining ~/ value;
      final keep = use < original[i] ? use : original[i];
      result[i] = keep;
      remaining -= keep * value;
    }
    // Lo que no se pudo representar con las monedas originales se da en oro/plata/cobre.
    result[3] += remaining ~/ 100;
    remaining %= 100;
    result[1] += remaining ~/ 10;
    result[0] += remaining % 10;
    for (var i = 0; i < 5; i++) {
      setIndex(i, result[i]);
    }
    return true;
  }

  void add(Currency other) {
    cp += other.cp;
    sp += other.sp;
    ep += other.ep;
    gp += other.gp;
    pp += other.pp;
  }

  bool covers(Currency other) => cp >= other.cp && sp >= other.sp && ep >= other.ep && gp >= other.gp && pp >= other.pp;

  void subtract(Currency other) {
    cp -= other.cp;
    sp -= other.sp;
    ep -= other.ep;
    gp -= other.gp;
    pp -= other.pp;
  }

  bool get isZero => coinCount == 0;

  Map<String, dynamic> toJson() => {'cp': cp, 'sp': sp, 'ep': ep, 'gp': gp, 'pp': pp};

  factory Currency.fromJson(Map<String, dynamic> j) =>
      Currency(cp: asInt(j['cp']), sp: asInt(j['sp']), ep: asInt(j['ep']), gp: asInt(j['gp']), pp: asInt(j['pp']));

  Currency copy() => Currency(cp: cp, sp: sp, ep: ep, gp: gp, pp: pp);

  @override
  String toString() {
    final parts = <String>[];
    final l = asList;
    for (var i = 4; i >= 0; i--) {
      if (l[i] != 0) parts.add('${l[i]} ${coinLabels[i]}');
    }
    return parts.isEmpty ? '0 ${coinLabels[3]}' : parts.join(' · ');
  }
}

/// Formatea una cantidad en piezas de cobre como "12 po 5 pp 3 pc".
String formatCp(int? cp) {
  if (cp == null) return '?';
  final l = Currency.coinLabels;
  if (cp == 0) return '0 ${l[3]}';
  final neg = cp < 0;
  var v = cp.abs();
  final gp = v ~/ 100;
  v %= 100;
  final sp = v ~/ 10;
  final c = v % 10;
  final parts = <String>[if (gp > 0) '$gp ${l[3]}', if (sp > 0) '$sp ${l[1]}', if (c > 0) '$c ${l[0]}'];
  return (neg ? '−' : '') + parts.join(' ');
}

/// Interpreta textos como "15 po", "2 pp", "1.5 gp" o "30" (oro) a piezas de cobre.
int? parseCost(String text) {
  final t = text.trim().toLowerCase().replaceAll(',', '.');
  if (t.isEmpty) return 0;
  final match = RegExp(r'^(\d+(?:\.\d+)?)\s*([a-z]*)$').firstMatch(t);
  if (match == null) return null;
  final amount = double.parse(match.group(1)!);
  const mult = {
    '': 100,
    'po': 100,
    'gp': 100,
    'oro': 100,
    'pp': 10,
    'sp': 10,
    'plata': 10,
    'pc': 1,
    'cp': 1,
    'cobre': 1,
    'pe': 50,
    'ep': 50,
    'ppt': 1000,
    'pt': 1000,
    'platino': 1000,
  };
  // "pp" es plata en castellano y platino en inglés.
  final unit = match.group(2);
  final m = unit == 'pp' && I18n.isEnglish ? 1000 : mult[unit];
  if (m == null) return null;
  return (amount * m).round();
}
