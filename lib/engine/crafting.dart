import 'dart:math';

import '../domain/character.dart';
import '../domain/item.dart';
import '../domain/recipe.dart';

class IngredientStatus {
  IngredientStatus(this.ingredient, this.have, this.need);
  final Ingredient ingredient;
  final int have;
  final int need;
  bool get ok => have >= need;
  int get missing => max(0, need - have);
}

/// Resultado de comprobar si un personaje puede fabricar una receta.
class CraftCheck {
  CraftCheck({
    required this.ingredients,
    required this.goldNeededCp,
    required this.goldOk,
    required this.toolOk,
    required this.maxTimes,
  });

  final List<IngredientStatus> ingredients;
  final int goldNeededCp;
  final bool goldOk;

  /// Sólo informativo: el máster decide si hace falta la herramienta.
  final bool toolOk;

  /// Cuántas veces se podría fabricar con lo que lleva encima.
  final int maxTimes;

  bool get canCraft => goldOk && ingredients.every((i) => i.ok);
  List<IngredientStatus> get missing => ingredients.where((i) => !i.ok).toList();
}

class Crafting {
  /// Unidades en el inventario que valen para el ingrediente [name].
  static int countMatching(Character c, String name) =>
      c.inventory.where((i) => i.matchesIngredient(name)).fold(0, (a, i) => a + i.quantity);

  static bool hasTool(Character c, String tool) {
    if (tool.trim().isEmpty) return true;
    final t = InventoryItem.normalize(tool);
    bool match(String s) {
      final n = InventoryItem.normalize(s);
      return n.isNotEmpty && (n.contains(t) || t.contains(n));
    }

    return c.toolProficiencies.any(match) || c.inventory.any((i) => match(i.name));
  }

  static CraftCheck check(Character c, Recipe r, {int times = 1}) {
    final statuses = <IngredientStatus>[];
    var maxTimes = 1 << 30;
    for (final ing in r.ingredients) {
      final have = countMatching(c, ing.name);
      final need = ing.consumed ? ing.quantity * times : ing.quantity;
      statuses.add(IngredientStatus(ing, have, need));
      if (ing.consumed && ing.quantity > 0) {
        maxTimes = min(maxTimes, have ~/ ing.quantity);
      } else if (have < ing.quantity) {
        maxTimes = 0;
      }
    }
    final gold = r.goldCostCp * times;
    if (r.goldCostCp > 0) maxTimes = min(maxTimes, c.currency.totalCp ~/ r.goldCostCp);
    if (maxTimes == 1 << 30) maxTimes = 99;
    return CraftCheck(
      ingredients: statuses,
      goldNeededCp: gold,
      goldOk: c.currency.canAfford(gold),
      toolOk: hasTool(c, r.tool),
      maxTimes: maxTimes,
    );
  }

  /// Gasta [quantity] unidades de objetos que valgan para [name]. Prefiere los
  /// objetos no equipados y que coinciden por nombre exacto.
  static void consume(Character c, String name, int quantity) {
    var left = quantity;
    final candidates = c.inventory.where((i) => i.matchesIngredient(name)).toList()
      ..sort((a, b) {
        if (a.equipped != b.equipped) return a.equipped ? 1 : -1;
        final an = InventoryItem.normalize(a.name) == InventoryItem.normalize(name);
        final bn = InventoryItem.normalize(b.name) == InventoryItem.normalize(name);
        if (an != bn) return an ? -1 : 1;
        return a.quantity.compareTo(b.quantity);
      });
    for (final item in candidates) {
      if (left <= 0) break;
      final take = min(left, item.quantity);
      item.quantity -= take;
      left -= take;
      if (item.quantity <= 0) c.inventory.remove(item);
    }
  }

  /// Añade un objeto al inventario apilándolo con uno idéntico si existe.
  static void addToInventory(Character c, InventoryItem item) {
    final stackable =
        item.charges == null &&
        !item.requiresAttunement &&
        item.category != ItemCategory.weapon &&
        item.category != ItemCategory.armor;
    if (stackable) {
      for (final existing in c.inventory) {
        if (existing.name == item.name &&
            existing.description == item.description &&
            existing.weight == item.weight &&
            existing.valueCp == item.valueCp &&
            existing.hideWeight == item.hideWeight &&
            existing.hideValue == item.hideValue &&
            existing.charges == null &&
            !existing.equipped) {
          existing.quantity += item.quantity;
          return;
        }
      }
    }
    c.inventory.add(item);
  }
}
