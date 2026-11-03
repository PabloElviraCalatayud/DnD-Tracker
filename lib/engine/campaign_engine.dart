import 'dart:math';

import '../core/ids.dart';
import '../core/json.dart';
import '../domain/campaign.dart';
import '../domain/character.dart';
import '../domain/chat.dart';
import '../domain/currency.dart';
import '../domain/item.dart';
import '../domain/monster.dart';
import '../domain/recipe.dart';
import '../domain/ruleset.dart';
import 'commands.dart';
import 'crafting.dart';

class EngineError implements Exception {
  EngineError(this.message);
  final String message;
  @override
  String toString() => message;
}

class EngineResult {
  EngineResult({
    this.ok = true,
    this.error,
    this.changed = false,
    List<ChatMessage>? messages,
    List<ChatChannel>? channels,
    this.kickedUserId,
  }) : messages = messages ?? const [],
       channels = channels ?? const [];

  factory EngineResult.failure(String error) => EngineResult(ok: false, error: error);

  final bool ok;
  final String? error;

  /// Ha cambiado el estado de la partida (hay que guardar y difundir vistas).
  final bool changed;
  final List<ChatMessage> messages;
  final List<ChatChannel> channels;
  final String? kickedUserId;
}

/// Aplica comandos sobre una partida comprobando permisos. Es Dart puro: lo
/// usa el anfitrión y también los tests.
class CampaignEngine {
  CampaignEngine(this.campaign);

  final Campaign campaign;

  CampaignSettings get _settings => campaign.settings;

  EngineResult apply(Command cmd, Actor actor) {
    try {
      final result = _dispatch(cmd, actor);
      if (result.changed) {
        campaign.revision++;
        campaign.updatedAt = DateTime.now().millisecondsSinceEpoch;
      }
      return result;
    } on EngineError catch (e) {
      return EngineResult.failure(e.message);
    } on Object catch (e) {
      return EngineResult.failure('Comando no válido: $e');
    }
  }

  EngineResult _dispatch(Command cmd, Actor actor) {
    final d = cmd.data;
    switch (cmd.type) {
      case 'character.put':
        return _putCharacter(Character.fromJson(asMap(d['character'])), actor);
      case 'character.delete':
        final c = _ownedCharacter(actor, asString(d['characterId']));
        campaign.characters.remove(c);
        campaign.encounter.combatants.removeWhere((x) => x.characterId == c.id);
        for (final r in campaign.recipes) {
          r.characterIds.remove(c.id);
        }
        campaign.addLog('${actor.name} eliminó a ${c.name}', actor: actor.name);
        return EngineResult(changed: true);
      case 'character.assign':
        _requireDm(actor);
        final c = _character(asString(d['characterId']));
        final owner = asString(d['ownerId']);
        c.ownerId = owner;
        campaign.addLog('${c.name} ahora pertenece a ${campaign.memberName(owner)}', actor: actor.name);
        return EngineResult(changed: true);

      case 'item.give':
        _requireDm(actor);
        final c = _character(asString(d['characterId']));
        final item = InventoryItem.fromJson(asMap(d['item']));
        item.id = newId();
        item.equipped = false;
        item.attuned = false;
        item.quantity = max(1, item.quantity);
        Crafting.addToInventory(c, item);
        campaign.addLog(
          '${actor.name} entregó ${item.quantity}× ${item.name} a ${c.name}',
          actor: actor.name,
          characterId: c.id,
        );
        return EngineResult(changed: true);
      case 'item.transfer':
        return _transferItem(d, actor);
      case 'currency.transfer':
        return _transferCurrency(d, actor);
      case 'library.put':
        _requireDm(actor);
        final item = InventoryItem.fromJson(asMap(d['item']));
        item.custom = true;
        _upsert(campaign.itemLibrary, item, (x) => x.id);
        return EngineResult(changed: true);
      case 'library.delete':
        _requireDm(actor);
        campaign.itemLibrary.removeWhere((x) => x.id == asString(d['id']));
        return EngineResult(changed: true);

      case 'recipe.put':
        return _putRecipe(Recipe.fromJson(asMap(d['recipe'])), actor);
      case 'recipe.delete':
        final r = campaign.recipe(asString(d['id']));
        if (r == null) throw EngineError('La receta no existe');
        if (!actor.isDm && r.createdBy != actor.userId) throw EngineError('Sólo el máster puede borrarla');
        campaign.recipes.remove(r);
        return EngineResult(changed: true);
      case 'craft.recipe':
        return _craftRecipe(d, actor);
      case 'craft.standard':
        return _craftStandard(d, actor);
      case 'craft.progress':
        return _craftProgress(d, actor);
      case 'craft.cancel':
        final c = _ownedCharacter(actor, asString(d['characterId']));
        final p = c.projects.where((x) => x.id == asString(d['projectId'])).firstOrNull;
        if (p == null) throw EngineError('El proyecto no existe');
        c.projects.remove(p);
        campaign.addLog('${c.name} abandonó la fabricación de ${p.result.name}', actor: actor.name, characterId: c.id);
        return EngineResult(changed: true);

      case 'monster.put':
        _requireDm(actor);
        final m = Monster.fromJson(asMap(d['monster']))..custom = true;
        _upsert(campaign.monsters, m, (x) => x.id);
        return EngineResult(changed: true);
      case 'monster.delete':
        _requireDm(actor);
        campaign.monsters.removeWhere((x) => x.id == asString(d['id']));
        return EngineResult(changed: true);
      case 'encounter.put':
        _requireDm(actor);
        campaign.encounter = Encounter.fromJson(asMap(d['encounter']));
        return EngineResult(changed: true);
      case 'encounter.initiative':
        final c = _ownedCharacter(actor, asString(d['characterId']));
        final value = asInt(d['value']);
        c.initiativeRoll = value;
        for (final x in campaign.encounter.combatants) {
          if (x.characterId == c.id) x.initiative = value;
        }
        campaign.encounter.sort();
        return EngineResult(changed: true);
      case 'note.put':
        _requireDm(actor);
        final n = CampaignNote.fromJson(asMap(d['note']));
        n.updatedAt = DateTime.now().millisecondsSinceEpoch;
        _upsert(campaign.notes, n, (x) => x.id);
        return EngineResult(changed: true);
      case 'note.delete':
        _requireDm(actor);
        campaign.notes.removeWhere((x) => x.id == asString(d['id']));
        return EngineResult(changed: true);
      case 'settings.put':
        _requireDm(actor);
        campaign.settings = CampaignSettings.fromJson(asMap(d['settings']));
        if (d['name'] != null && asString(d['name']).trim().isNotEmpty) campaign.name = asString(d['name']).trim();
        if (d['description'] != null) campaign.description = asString(d['description']);
        if (d['ruleset'] != null) {
          final r = Ruleset.parse(d['ruleset']);
          if (r != campaign.ruleset) {
            campaign.ruleset = r;
            campaign.addLog('Edición cambiada a ${r.label}', actor: actor.name);
          }
        }
        return EngineResult(changed: true);
      case 'campaign.newJoinCode':
        _requireDm(actor);
        campaign.joinCode = newJoinCode();
        return EngineResult(changed: true);
      case 'member.kick':
        _requireDm(actor);
        final userId = asString(d['userId']);
        final m = campaign.member(userId);
        if (m == null) throw EngineError('Ese jugador no está en la partida');
        if (asBool(d['ban'], true)) m.banned = true;
        campaign.addLog('${m.name} ha sido expulsado', actor: actor.name);
        return EngineResult(changed: true, kickedUserId: userId);
      case 'member.unban':
        _requireDm(actor);
        campaign.member(asString(d['userId']))?.banned = false;
        return EngineResult(changed: true);

      case 'chat.send':
        return _sendChat(d, actor);
      case 'chat.createChannel':
        return _createChannel(d, actor);
    }
    throw EngineError('Comando desconocido: ${cmd.type}');
  }

  // ------------------------------------------------------------ Permisos

  void _requireDm(Actor actor) {
    if (!actor.isDm) throw EngineError('Sólo el máster puede hacer esto');
  }

  Character _character(String id) {
    final c = campaign.character(id);
    if (c == null) throw EngineError('El personaje no existe');
    return c;
  }

  Character _ownedCharacter(Actor actor, String id) {
    final c = _character(id);
    if (!actor.isDm && c.ownerId != actor.userId) throw EngineError('Ese personaje no es tuyo');
    return c;
  }

  static void _upsert<T>(List<T> list, T value, String Function(T) idOf) {
    final i = list.indexWhere((x) => idOf(x) == idOf(value));
    if (i >= 0) {
      list[i] = value;
    } else {
      list.add(value);
    }
  }

  // ------------------------------------------------------------ Personajes

  EngineResult _putCharacter(Character incoming, Actor actor) {
    final existing = campaign.character(incoming.id);
    incoming.isSummary = false;
    incoming.hpHidden = false;
    if (actor.isDm) {
      if (incoming.ownerId.isEmpty) incoming.ownerId = actor.userId;
      if (existing == null) {
        campaign.characters.add(incoming);
        campaign.addLog('${actor.name} creó a ${incoming.name}', actor: actor.name, characterId: incoming.id);
      } else {
        _logChanges(existing, incoming, actor);
        campaign.characters[campaign.characters.indexOf(existing)] = incoming;
      }
      return EngineResult(changed: true);
    }

    if (existing == null) {
      incoming.ownerId = actor.userId;
      incoming.dmNotes = '';
      incoming.projects = [];
      for (final i in incoming.inventory) {
        _sanitizeNewPlayerItem(i);
      }
      campaign.characters.add(incoming);
      campaign.addLog('${actor.name} creó a ${incoming.name}', actor: actor.name, characterId: incoming.id);
      return EngineResult(changed: true);
    }
    if (existing.ownerId != actor.userId) throw EngineError('Ese personaje no es tuyo');
    final merged = mergePlayerEdit(existing, incoming, _settings);
    _logChanges(existing, merged, actor);
    campaign.characters[campaign.characters.indexOf(existing)] = merged;
    return EngineResult(changed: true);
  }

  static void _sanitizeNewPlayerItem(InventoryItem i) {
    i.hideWeight = false;
    i.hideValue = false;
    i.dmNote = '';
    i.weight ??= 0;
    i.valueCp ??= 0;
  }

  /// Fusiona la ficha que envía un jugador con la que guarda el anfitrión,
  /// conservando lo que sólo controla el máster (notas, datos ocultos...).
  static Character mergePlayerEdit(Character existing, Character incoming, CampaignSettings s) {
    final merged = incoming.copy();
    merged.ownerId = existing.ownerId;
    merged.dmNotes = existing.dmNotes;
    merged.isSummary = false;
    merged.hpHidden = false;
    // Los proyectos sólo cambian mediante comandos de artesanía.
    merged.projects = existing.projects.map((p) => CraftingProject.fromJson(p.toJson())).toList();
    for (final item in merged.inventory) {
      final old = existing.itemById(item.id);
      if (old == null) {
        _sanitizeNewPlayerItem(item);
        continue;
      }
      item.hideWeight = old.hideWeight;
      item.hideValue = old.hideValue;
      item.dmNote = old.dmNote;
      if (s.hideItemWeights || old.hideWeight) item.weight = old.weight;
      if (s.hideItemValues || old.hideValue) item.valueCp = old.valueCp;
      item.weight ??= old.weight ?? 0;
      item.valueCp ??= old.valueCp ?? 0;
    }
    return merged;
  }

  void _logChanges(Character before, Character after, Actor actor) {
    final changes = <String>[];
    if (before.hpCurrent != after.hpCurrent) changes.add('PG ${before.hpCurrent} → ${after.hpCurrent}');
    if (before.currency.totalCp != after.currency.totalCp) {
      changes.add('dinero ${before.currency} → ${after.currency}');
    }
    final beforeItems = {for (final i in before.inventory) i.id: i};
    final afterItems = {for (final i in after.inventory) i.id: i};
    for (final i in after.inventory) {
      final old = beforeItems[i.id];
      if (old == null) {
        changes.add('+${i.quantity} ${i.name}');
      } else if (old.quantity != i.quantity) {
        final diff = i.quantity - old.quantity;
        changes.add('${diff > 0 ? '+' : ''}$diff ${i.name}');
      }
    }
    for (final i in before.inventory) {
      if (!afterItems.containsKey(i.id)) changes.add('−${i.quantity} ${i.name}');
    }
    if (before.level != after.level) changes.add('nivel ${before.level} → ${after.level}');
    if (changes.isEmpty) return;
    campaign.addLog('${after.name}: ${changes.join(', ')}', actor: actor.name, characterId: after.id);
  }

  // ------------------------------------------------------------ Intercambios

  EngineResult _transferItem(Map<String, dynamic> d, Actor actor) {
    if (!actor.isDm && !_settings.playersCanTrade) throw EngineError('El máster ha desactivado los intercambios');
    final from = _ownedCharacter(actor, asString(d['fromCharacterId']));
    final to = _character(asString(d['toCharacterId']));
    if (from.id == to.id) throw EngineError('Origen y destino son el mismo personaje');
    final item = from.itemById(asString(d['itemId']));
    if (item == null) throw EngineError('El objeto no existe');
    final qty = asInt(d['quantity'], item.quantity).clamp(1, item.quantity);
    InventoryItem moved;
    if (qty >= item.quantity) {
      from.inventory.remove(item);
      moved = item;
    } else {
      item.quantity -= qty;
      moved = item.copy(newIdValue: newId(), quantity: qty);
    }
    moved.equipped = false;
    moved.attuned = false;
    moved.shared = false;
    Crafting.addToInventory(to, moved);
    campaign.addLog('${from.name} dio $qty× ${moved.name} a ${to.name}', actor: actor.name, characterId: from.id);
    return EngineResult(changed: true);
  }

  EngineResult _transferCurrency(Map<String, dynamic> d, Actor actor) {
    if (!actor.isDm && !_settings.playersCanTrade) throw EngineError('El máster ha desactivado los intercambios');
    final from = _ownedCharacter(actor, asString(d['fromCharacterId']));
    final to = _character(asString(d['toCharacterId']));
    final amount = Currency.fromJson(asMap(d['currency']));
    if (amount.asList.any((v) => v < 0) || amount.isZero) throw EngineError('Cantidad no válida');
    if (!from.currency.covers(amount)) throw EngineError('${from.name} no tiene esas monedas');
    from.currency.subtract(amount);
    to.currency.add(amount);
    campaign.addLog('${from.name} dio $amount a ${to.name}', actor: actor.name, characterId: from.id);
    return EngineResult(changed: true);
  }

  // ------------------------------------------------------------ Artesanía

  EngineResult _putRecipe(Recipe r, Actor actor) {
    final existing = campaign.recipe(r.id);
    if (!actor.isDm) {
      if (!_settings.playersCanCreateRecipes) throw EngineError('Sólo el máster puede crear recetas');
      if (existing != null && existing.createdBy != actor.userId) {
        throw EngineError('Sólo puedes editar tus propias recetas');
      }
      final own = campaign.charactersOf(actor.userId).map((c) => c.id).toSet();
      r.availableToAll = false;
      r.characterIds = r.characterIds.where(own.contains).toList();
      if (r.characterIds.isEmpty) throw EngineError('Elige al menos uno de tus personajes');
      r.createdBy = actor.userId;
    } else if (r.createdBy.isEmpty) {
      r.createdBy = actor.userId;
    }
    _upsert(campaign.recipes, r, (x) => x.id);
    return EngineResult(changed: true);
  }

  EngineResult _craftRecipe(Map<String, dynamic> d, Actor actor) {
    final c = _ownedCharacter(actor, asString(d['characterId']));
    final r = campaign.recipe(asString(d['recipeId']));
    if (r == null) throw EngineError('La receta no existe');
    if (!r.isAvailableTo(c.id)) throw EngineError('${c.name} no conoce esa receta');
    final times = asInt(d['times'], 1).clamp(1, 99);
    final check = Crafting.check(c, r, times: times);
    if (!check.canCraft) {
      final missing = [
        for (final m in check.missing) '${m.missing}× ${m.ingredient.name}',
        if (!check.goldOk) 'dinero',
      ];
      throw EngineError('Faltan materiales: ${missing.join(', ')}');
    }
    for (final ing in r.ingredients) {
      if (ing.consumed) Crafting.consume(c, ing.name, ing.quantity * times);
    }
    c.currency.pay(r.goldCostCp * times);
    final result = r.result.copy(newIdValue: newId(), quantity: r.resultQuantity * times);
    result.custom = true;
    if (r.days <= 0) {
      Crafting.addToInventory(c, result);
      campaign.addLog('${c.name} fabricó ${result.quantity}× ${result.name}', actor: actor.name, characterId: c.id);
    } else {
      c.projects.add(CraftingProject(result: result, recipeId: r.id, daysRequired: r.days * times));
      campaign.addLog(
        '${c.name} empezó a fabricar ${result.quantity}× ${result.name} (${r.days * times} días)',
        actor: actor.name,
        characterId: c.id,
      );
    }
    return EngineResult(changed: true);
  }

  EngineResult _craftStandard(Map<String, dynamic> d, Actor actor) {
    final c = _ownedCharacter(actor, asString(d['characterId']));
    final item = InventoryItem.fromJson(asMap(d['item']));
    item.id = newId();
    item.hideWeight = false;
    item.hideValue = false;
    item.dmNote = '';
    item.weight ??= 0;
    item.valueCp ??= 0;
    final cost = max(0, asInt(d['costCp']));
    final days = max(0, asInt(d['days']));
    if (!c.currency.canAfford(cost)) throw EngineError('${c.name} no puede pagar los materiales (${formatCp(cost)})');
    c.currency.pay(cost);
    if (days == 0) {
      Crafting.addToInventory(c, item);
      campaign.addLog(
        '${c.name} fabricó ${item.quantity}× ${item.name} (${formatCp(cost)})',
        actor: actor.name,
        characterId: c.id,
      );
    } else {
      c.projects.add(CraftingProject(result: item, daysRequired: days));
      campaign.addLog(
        '${c.name} empezó a fabricar ${item.name}: $days días, materiales ${formatCp(cost)}',
        actor: actor.name,
        characterId: c.id,
      );
    }
    return EngineResult(changed: true);
  }

  EngineResult _craftProgress(Map<String, dynamic> d, Actor actor) {
    final c = _ownedCharacter(actor, asString(d['characterId']));
    final p = c.projects.where((x) => x.id == asString(d['projectId'])).firstOrNull;
    if (p == null) throw EngineError('El proyecto no existe');
    p.daysDone = max(0, p.daysDone + asInt(d['days'], 1));
    if (p.done) {
      c.projects.remove(p);
      Crafting.addToInventory(c, p.result.copy(newIdValue: newId()));
      campaign.addLog(
        '${c.name} terminó de fabricar ${p.result.quantity}× ${p.result.name}',
        actor: actor.name,
        characterId: c.id,
      );
    }
    return EngineResult(changed: true);
  }

  // ------------------------------------------------------------ Chat

  EngineResult _sendChat(Map<String, dynamic> d, Actor actor) {
    final channel = campaign.chat.channel(asString(d['channelId'], ChatChannel.generalId));
    if (channel == null) throw EngineError('El canal no existe');
    if (!channel.includes(actor.userId) && !(actor.isDm && channel.kind == ChannelKind.general)) {
      throw EngineError('No estás en ese canal');
    }
    final text = asString(d['text']).trim();
    if (text.isEmpty) throw EngineError('Mensaje vacío');
    final msg = ChatMessage(
      channelId: channel.id,
      authorId: actor.userId,
      authorName: actor.name,
      text: text.length > 4000 ? text.substring(0, 4000) : text,
      kind: enumByName(MessageKind.values, d['kind'], MessageKind.text),
    );
    campaign.chat.add(msg);
    return EngineResult(changed: false, messages: [msg]);
  }

  EngineResult _createChannel(Map<String, dynamic> d, Actor actor) {
    final members = {...asStringList(d['memberIds']), actor.userId}.toList()..sort();
    final valid = members.every((id) => id == campaign.dmUserId || campaign.member(id) != null);
    if (!valid || members.length < 2) throw EngineError('Miembros no válidos');
    final direct = asBool(d['direct']);
    if (direct) {
      for (final c in campaign.chat.channels) {
        final cm = List.of(c.memberIds)..sort();
        if (c.kind == ChannelKind.direct && cm.join(',') == members.join(',')) {
          return EngineResult(channels: [c]);
        }
      }
    }
    final name = asString(d['name']).trim();
    final channel = ChatChannel(
      name: name.isEmpty ? members.map(campaign.memberName).join(', ') : name,
      kind: direct ? ChannelKind.direct : ChannelKind.group,
      memberIds: members,
      createdBy: actor.userId,
    );
    campaign.chat.upsertChannel(channel);
    return EngineResult(changed: false, channels: [channel]);
  }
}
