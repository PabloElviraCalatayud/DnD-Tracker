// Pequeños ayudantes para leer JSON sin reventar si falta un campo.
// Todas las clases del dominio guardan/leen JSON a mano para no depender
// de generación de código.

int asInt(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

int? asIntOrNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double asDouble(Object? v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

double? asDoubleOrNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

String asString(Object? v, [String fallback = '']) => v == null ? fallback : v.toString();

String? asStringOrNull(Object? v) => v?.toString();

bool asBool(Object? v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == 'true';
  return fallback;
}

Map<String, dynamic> asMap(Object? v) =>
    v is Map ? v.map((k, val) => MapEntry(k.toString(), val)) : <String, dynamic>{};

List<T> asList<T>(Object? v, T Function(Map<String, dynamic>) fromJson) {
  if (v is! List) return <T>[];
  return v.whereType<Map>().map((e) => fromJson(asMap(e))).toList();
}

List<String> asStringList(Object? v) {
  if (v is! List) return <String>[];
  return v.where((e) => e != null).map((e) => e.toString()).toList();
}

T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
