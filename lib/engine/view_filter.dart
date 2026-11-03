import '../domain/campaign.dart';
import '../domain/character.dart';
import '../domain/chat.dart';
import '../domain/currency.dart';
import '../domain/item.dart';

/// Construye lo que puede ver cada jugador. El anfitrión nunca envía datos
/// fuera de esta vista: si el máster oculta algo, no sale de su dispositivo.
class ViewFilter {
  /// Copia del objeto con el peso/valor ocultos si el máster lo ha decidido.
  static InventoryItem redactItem(InventoryItem item, CampaignSettings s) {
    final c = item.copy();
    if (s.hideItemWeights || item.hideWeight) c.weight = null;
    if (s.hideItemValues || item.hideValue) c.valueCp = null;
    c.dmNote = '';
    return c;
  }

  /// Ficha completa del propio jugador (sin las notas del máster).
  static Character ownCharacter(Character full, CampaignSettings s) {
    final c = full.copy();
    c.dmNotes = '';
    c.inventory = full.inventory.map((i) => redactItem(i, s)).toList();
    for (final p in c.projects) {
      p.result = redactItem(p.result, s);
    }
    return c;
  }

  /// Resumen que ven los compañeros de grupo.
  static Character partySummary(Character full, CampaignSettings s) {
    return Character(
      id: full.id,
      ownerId: full.ownerId,
      name: full.name,
      classes: full.classes.map((c) => ClassLevel.fromJson(c.toJson())).toList(),
      species: full.species,
      subspecies: full.subspecies,
      background: full.background,
      alignment: full.alignment,
      portrait: full.portrait,
      conditions: List.of(full.conditions),
      exhaustion: full.exhaustion,
      inspiration: full.inspiration,
      armorClass: full.armorClass,
      speed: full.speed,
      hpMax: s.showPartyHp ? full.hpMax : 0,
      hpCurrent: s.showPartyHp ? full.hpCurrent : 0,
      hpTemp: s.showPartyHp ? full.hpTemp : 0,
      hpHidden: !s.showPartyHp,
      inventory: full.inventory.where((i) => i.shared).map((i) => redactItem(i, s)).toList(),
      currency: full.shareCurrency ? full.currency.copy() : Currency(),
      shareCurrency: full.shareCurrency,
      isSummary: true,
      initiativeRoll: full.initiativeRoll,
    );
  }

  static Encounter encounterFor(Campaign full, String userId) {
    final e = full.encounter;
    if (!e.visibleToPlayers) return Encounter(visibleToPlayers: false);
    final currentId = e.current?.id;
    final visible = <Combatant>[];
    for (final c in e.combatants) {
      if (c.hidden) continue;
      final copy = Combatant.fromJson(c.toJson());
      copy.notes = '';
      if (copy.kind == CombatantKind.pc) {
        final ch = copy.characterId == null ? null : full.character(copy.characterId!);
        final own = ch != null && ch.ownerId == userId;
        if (ch != null) copy.conditions = List.of(ch.conditions);
        if (ch != null && (own || full.settings.showPartyHp)) {
          copy.hp = ch.hpCurrent;
          copy.hpMax = ch.hpMax;
          copy.ac = ch.armorClass;
        } else {
          copy.hp = null;
          copy.hpMax = null;
        }
      } else if (!full.settings.showMonsterHp) {
        copy.status = Combatant.healthStatus(c.hp ?? 0, c.hpMax ?? 0);
        copy.hp = null;
        copy.hpMax = null;
        copy.ac = null;
        copy.xp = 0;
      }
      visible.add(copy);
    }
    // El turno actual se mantiene en la misma criatura; si es oculta, en la
    // última visible anterior para no delatarla.
    var turn = 0;
    if (currentId != null) {
      final allIds = e.combatants.map((c) => c.id).toList();
      final start = allIds.indexOf(currentId);
      for (var i = start; i >= 0; i--) {
        final idx = visible.indexWhere((v) => v.id == allIds[i]);
        if (idx >= 0) {
          turn = idx;
          break;
        }
      }
    }
    return Encounter(active: e.active, round: e.round, turn: turn, combatants: visible, visibleToPlayers: true);
  }

  /// Vista de la partida para un jugador.
  static Campaign forPlayer(Campaign full, String userId, {Iterable<String> online = const []}) {
    final s = full.settings;
    final ownIds = full.characters.where((c) => c.ownerId == userId).map((c) => c.id).toSet();
    return Campaign(
      id: full.id,
      name: full.name,
      description: full.description,
      ruleset: full.ruleset,
      dmUserId: full.dmUserId,
      dmName: full.dmName,
      joinCode: '',
      settings: s.copy(),
      members: full.members
          .where((m) => !m.banned)
          .map(
            (m) => Member(userId: m.userId, name: m.name, role: m.role, joinedAt: m.joinedAt, lastSeenAt: m.lastSeenAt),
          )
          .toList(),
      characters: [for (final c in full.characters) ownIds.contains(c.id) ? ownCharacter(c, s) : partySummary(c, s)],
      recipes: full.recipes.where((r) => r.availableToAll || r.characterIds.any(ownIds.contains)).map((r) {
        final copy = r.copy();
        copy.result = redactItem(r.result, s);
        // Los jugadores no necesitan saber quién más conoce la receta.
        copy.characterIds = copy.characterIds.where(ownIds.contains).toList();
        return copy;
      }).toList(),
      encounter: encounterFor(full, userId),
      notes: full.notes.where((n) => n.shared).map((n) => CampaignNote.fromJson(n.toJson())).toList(),
      chat: ChatState(channels: [], messages: []),
      createdAt: full.createdAt,
      updatedAt: full.updatedAt,
      revision: full.revision,
      online: online.toList(),
      isView: true,
    );
  }
}
