import '../core/i18n.dart';
import '../core/ids.dart';
import '../core/json.dart';

enum ItemCategory {
  weapon('Arma', 'broadsword'),
  armor('Armadura', 'breastplate'),
  ammunition('Munición', 'arrows'),
  gear('Equipo', 'backpack'),
  tool('Herramienta', 'hammer'),
  consumable('Consumible', 'potion'),
  material('Material', 'ore'),
  treasure('Tesoro', 'gem'),
  magic('Objeto mágico', 'sparkles'),
  other('Otro', 'swap_bag');

  const ItemCategory(this._label, this.icon);
  final String _label;
  final String icon;

  String get label => tr(_label);

  static ItemCategory fromSrd(String cat) => switch (cat) {
    'weapon' => ItemCategory.weapon,
    'armor' => ItemCategory.armor,
    'ammunition' => ItemCategory.ammunition,
    'tool' => ItemCategory.tool,
    'magic' => ItemCategory.magic,
    'focus' || 'pack' || 'gear' || 'mount' => ItemCategory.gear,
    _ => ItemCategory.other,
  };
}

/// Quién puede ver un objeto del inventario (además de su dueño y del máster).
enum ItemVisibility {
  /// Sólo el dueño (y el máster, que lo ve todo).
  private,

  /// Todos los jugadores de la partida.
  party,

  /// Sólo los jugadores elegidos en [InventoryItem.visibleTo].
  some,
}

/// Objeto en un inventario (o plantilla de la biblioteca del máster).
///
/// [weight] y [valueCp] son por unidad. Cuando el máster los oculta, la vista
/// que recibe el jugador los trae a `null` y la interfaz muestra "?".
class InventoryItem {
  InventoryItem({
    String? id,
    required this.name,
    this.description = '',
    this.category = ItemCategory.gear,
    this.quantity = 1,
    this.weight = 0,
    this.valueCp = 0,
    this.rarity = '',
    this.requiresAttunement = false,
    this.attuned = false,
    this.equipped = false,
    this.visibility = ItemVisibility.private,
    List<String>? visibleTo,
    this.hideWeight = false,
    this.hideValue = false,
    this.dmNote = '',
    List<String>? tags,
    this.srdId,
    this.templateId,
    this.icon = '',
    this.custom = false,
    this.damage = '',
    this.armorClass = '',
    this.properties = '',
    this.charges,
    this.maxCharges,
    this.notes = '',
  }) : id = id ?? newId(),
       tags = tags ?? <String>[],
       visibleTo = visibleTo ?? <String>[];

  String id;
  String name;
  String description;
  ItemCategory category;
  int quantity;

  /// Peso por unidad en libras (null = oculto por el máster).
  double? weight;

  /// Valor por unidad en piezas de cobre (null = oculto por el máster).
  int? valueCp;

  String rarity;
  bool requiresAttunement;
  bool attuned;
  bool equipped;

  /// El jugador decide quién del grupo puede ver este objeto.
  ItemVisibility visibility;

  /// Jugadores (userId) que lo ven cuando [visibility] es [ItemVisibility.some].
  List<String> visibleTo;

  /// ¿Lo ve alguien más aparte del dueño?
  bool get shared => visibility == ItemVisibility.party || (visibility == ItemVisibility.some && visibleTo.isNotEmpty);

  /// ¿Puede verlo el jugador [userId] (que no es el dueño)?
  bool isVisibleTo(String userId) =>
      visibility == ItemVisibility.party || (visibility == ItemVisibility.some && visibleTo.contains(userId));

  void hideFromEveryone() {
    visibility = ItemVisibility.private;
    visibleTo = [];
  }

  /// Controlados por el máster.
  bool hideWeight;
  bool hideValue;
  String dmNote;

  /// Etiquetas para recetas (p. ej. "hierba", "metal"). Un ingrediente de
  /// receta coincide con el nombre del objeto o con alguna de sus etiquetas.
  List<String> tags;
  String? srdId;
  String? templateId;
  String icon;
  bool custom;
  String damage;
  String armorClass;
  String properties;
  int? charges;
  int? maxCharges;
  String notes;

  String get iconName => icon.isNotEmpty ? icon : category.icon;

  double? get totalWeight => weight == null ? null : weight! * quantity;
  int? get totalValueCp => valueCp == null ? null : valueCp! * quantity;

  bool get isMagic => category == ItemCategory.magic || rarity.isNotEmpty;

  /// ¿Encaja con el ingrediente [name]? (nombre o etiqueta, sin distinguir mayúsculas).
  bool matchesIngredient(String name) {
    final n = normalize(name);
    if (normalize(this.name) == n) return true;
    return tags.any((t) => normalize(t) == n);
  }

  static String normalize(String s) => s.trim().toLowerCase();

  InventoryItem copy({String? newIdValue, int? quantity}) {
    final c = InventoryItem.fromJson(toJson());
    if (newIdValue != null) c.id = newIdValue;
    if (quantity != null) c.quantity = quantity;
    return c;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (description.isNotEmpty) 'description': description,
    'category': category.name,
    'quantity': quantity,
    'weight': weight,
    'valueCp': valueCp,
    if (rarity.isNotEmpty) 'rarity': rarity,
    if (requiresAttunement) 'requiresAttunement': true,
    if (attuned) 'attuned': true,
    if (equipped) 'equipped': true,
    if (visibility != ItemVisibility.private) 'visibility': visibility.name,
    if (visibleTo.isNotEmpty) 'visibleTo': visibleTo,
    if (hideWeight) 'hideWeight': true,
    if (hideValue) 'hideValue': true,
    if (dmNote.isNotEmpty) 'dmNote': dmNote,
    if (tags.isNotEmpty) 'tags': tags,
    if (srdId != null) 'srdId': srdId,
    if (templateId != null) 'templateId': templateId,
    if (icon.isNotEmpty) 'icon': icon,
    if (custom) 'custom': true,
    if (damage.isNotEmpty) 'damage': damage,
    if (armorClass.isNotEmpty) 'armorClass': armorClass,
    if (properties.isNotEmpty) 'properties': properties,
    if (charges != null) 'charges': charges,
    if (maxCharges != null) 'maxCharges': maxCharges,
    if (notes.isNotEmpty) 'notes': notes,
  };

  factory InventoryItem.fromJson(Map<String, dynamic> j) => InventoryItem(
    id: asString(j['id'], newId()),
    name: asString(j['name'], 'Objeto'),
    description: asString(j['description']),
    category: enumByName(ItemCategory.values, j['category'], ItemCategory.gear),
    quantity: asInt(j['quantity'], 1),
    weight: asDoubleOrNull(j['weight']),
    valueCp: asIntOrNull(j['valueCp']),
    rarity: asString(j['rarity']),
    requiresAttunement: asBool(j['requiresAttunement']),
    attuned: asBool(j['attuned']),
    equipped: asBool(j['equipped']),
    // Las versiones anteriores sólo tenían "shared" (todo el grupo o nadie).
    visibility: j['visibility'] != null
        ? enumByName(ItemVisibility.values, j['visibility'], ItemVisibility.private)
        : (asBool(j['shared']) ? ItemVisibility.party : ItemVisibility.private),
    visibleTo: asStringList(j['visibleTo']),
    hideWeight: asBool(j['hideWeight']),
    hideValue: asBool(j['hideValue']),
    dmNote: asString(j['dmNote']),
    tags: asStringList(j['tags']),
    srdId: asStringOrNull(j['srdId']),
    templateId: asStringOrNull(j['templateId']),
    icon: asString(j['icon']),
    custom: asBool(j['custom']),
    damage: asString(j['damage']),
    armorClass: asString(j['armorClass']),
    properties: asString(j['properties']),
    charges: asIntOrNull(j['charges']),
    maxCharges: asIntOrNull(j['maxCharges']),
    notes: asString(j['notes']),
  );
}

/// Rarezas habituales, para los selectores.
const List<String> rarities = ['', 'Common', 'Uncommon', 'Rare', 'Very Rare', 'Legendary', 'Artifact'];

String rarityLabel(String r) => switch (r.toLowerCase()) {
  '' => tr('Sin rareza'),
  'common' => tr('Común'),
  'uncommon' => tr('Poco común'),
  'rare' => tr('Raro'),
  'very rare' => tr('Muy raro'),
  'legendary' => tr('Legendario'),
  'artifact' => tr('Artefacto'),
  _ => r,
};
