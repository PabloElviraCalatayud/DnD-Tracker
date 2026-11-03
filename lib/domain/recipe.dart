import '../core/ids.dart';
import '../core/json.dart';
import 'item.dart';

class Ingredient {
  Ingredient({required this.name, this.quantity = 1, this.consumed = true});

  /// Nombre del objeto o etiqueta (p. ej. "Hierba de sangre" o "metal").
  String name;
  int quantity;

  /// false = hace falta tenerlo pero no se gasta (un molde, un catalizador...).
  bool consumed;

  Map<String, dynamic> toJson() => {'name': name, 'quantity': quantity, if (!consumed) 'consumed': false};

  factory Ingredient.fromJson(Map<String, dynamic> j) =>
      Ingredient(name: asString(j['name']), quantity: asInt(j['quantity'], 1), consumed: asBool(j['consumed'], true));
}

/// Receta de fabricación definida por el máster (o por el jugador si el
/// máster lo permite).
class Recipe {
  Recipe({
    String? id,
    required this.name,
    this.description = '',
    required this.result,
    this.resultQuantity = 1,
    List<Ingredient>? ingredients,
    this.goldCostCp = 0,
    this.tool = '',
    this.days = 0,
    this.check = '',
    this.availableToAll = false,
    List<String>? characterIds,
    this.createdBy = '',
  }) : id = id ?? newId(),
       ingredients = ingredients ?? <Ingredient>[],
       characterIds = characterIds ?? <String>[];

  String id;
  String name;
  String description;
  InventoryItem result;
  int resultQuantity;
  List<Ingredient> ingredients;
  int goldCostCp;

  /// Herramienta necesaria (texto libre: "Útiles de alquimista").
  String tool;

  /// Días de trabajo. 0 = se fabrica al momento.
  int days;

  /// Prueba necesaria, texto libre ("CD 15 Inteligencia (Útiles de alquimista)").
  String check;
  bool availableToAll;

  /// Personajes que conocen la receta (si no es para todos).
  List<String> characterIds;
  String createdBy;

  bool isAvailableTo(String characterId) => availableToAll || characterIds.contains(characterId);

  Recipe copy() => Recipe.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (description.isNotEmpty) 'description': description,
    'result': result.toJson(),
    'resultQuantity': resultQuantity,
    'ingredients': ingredients.map((i) => i.toJson()).toList(),
    'goldCostCp': goldCostCp,
    if (tool.isNotEmpty) 'tool': tool,
    'days': days,
    if (check.isNotEmpty) 'check': check,
    'availableToAll': availableToAll,
    'characterIds': characterIds,
    if (createdBy.isNotEmpty) 'createdBy': createdBy,
  };

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
    id: asString(j['id'], newId()),
    name: asString(j['name'], 'Receta'),
    description: asString(j['description']),
    result: InventoryItem.fromJson(asMap(j['result'])),
    resultQuantity: asInt(j['resultQuantity'], 1),
    ingredients: asList(j['ingredients'], Ingredient.fromJson),
    goldCostCp: asInt(j['goldCostCp']),
    tool: asString(j['tool']),
    days: asInt(j['days']),
    check: asString(j['check']),
    availableToAll: asBool(j['availableToAll']),
    characterIds: asStringList(j['characterIds']),
    createdBy: asString(j['createdBy']),
  );
}
