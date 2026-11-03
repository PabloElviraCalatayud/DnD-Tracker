import 'dart:async';

import 'package:dnd_tracker/domain/campaign.dart';
import 'package:dnd_tracker/domain/character.dart';
import 'package:dnd_tracker/domain/chat.dart';
import 'package:dnd_tracker/domain/item.dart';
import 'package:dnd_tracker/domain/profile.dart';
import 'package:dnd_tracker/engine/commands.dart';
import 'package:dnd_tracker/net/invite.dart';
import 'package:dnd_tracker/state/client_session.dart';
import 'package:dnd_tracker/state/host_session.dart';
import 'package:dnd_tracker/state/session.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> waitFor(bool Function() condition, {Duration timeout = const Duration(seconds: 10)}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) throw TimeoutException('condición no cumplida');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  late UserProfile dm;
  late UserProfile player;
  late HostSession host;
  late ClientSession client;

  setUp(() async {
    dm = UserProfile(displayName: 'Máster');
    player = UserProfile(displayName: 'Aria');
    final campaign = Campaign(name: 'La Cripta', dmUserId: dm.userId, dmName: dm.displayName);
    host = HostSession(campaign: campaign, profile: dm, storage: null, port: 0, enableLanBeacon: false);
    await host.start();
    expect(host.serverRunning, isTrue);
  });

  tearDown(() async {
    await client.close();
    await host.close();
  });

  Invite inviteFor({String? code}) => Invite(
        campaignId: host.campaign.id,
        campaignName: host.campaign.name,
        code: code ?? host.campaign.joinCode,
        hosts: ['127.0.0.1'],
        port: host.port,
      );

  test('un jugador se une, crea su personaje y recibe sólo su vista', () async {
    client = ClientSession(invite: inviteFor(), profile: player)..start();
    await waitFor(() => client.status == ConnectionStatus.online);
    expect(host.campaign.member(player.userId), isNotNull);
    expect(client.campaign.joinCode, isEmpty, reason: 'el código no se envía a los jugadores');

    final pc = Character(ownerId: player.userId, name: 'Aria', hpMax: 12, hpCurrent: 12);
    final r = await client.saveCharacter(pc);
    expect(r.ok, isTrue);
    await waitFor(() => host.campaign.character(pc.id) != null);
    expect(host.campaign.character(pc.id)!.ownerId, player.userId);

    // El máster le da un objeto con el peso y el valor ocultos.
    final gem = InventoryItem(name: 'Gema extraña', weight: 1, valueCp: 50000, hideWeight: true, hideValue: true,
        dmNote: 'Es una piedra de Ioun');
    await host.send(Command.giveItem(pc.id, gem));
    await waitFor(() => client.campaign.character(pc.id)!.inventory.isNotEmpty);
    final seen = client.campaign.character(pc.id)!.inventory.single;
    expect(seen.name, 'Gema extraña');
    expect(seen.weight, isNull);
    expect(seen.valueCp, isNull);
    expect(seen.dmNote, isEmpty);

    // El jugador edita su ficha (cantidad y visibilidad) sin destapar lo oculto.
    await client.editCharacter(pc.id, (c) {
      c.inventory.single.shared = true;
      c.hpCurrent = 7;
    });
    await waitFor(() => host.campaign.character(pc.id)!.hpCurrent == 7);
    final hostGem = host.campaign.character(pc.id)!.inventory.single;
    expect(hostGem.shared, isTrue);
    expect(hostGem.weight, 1);
    expect(hostGem.valueCp, 50000);
    expect(hostGem.dmNote, 'Es una piedra de Ioun');
  });

  test('código incorrecto => acceso denegado', () async {
    client = ClientSession(invite: inviteFor(code: 'XXXXXX'), profile: player)..start();
    await waitFor(() => client.status == ConnectionStatus.denied);
    expect(client.statusMessage, contains('Código'));
    expect(host.campaign.members, isEmpty);
  });

  test('el chat llega a los miembros del canal', () async {
    client = ClientSession(invite: inviteFor(), profile: player)..start();
    await waitFor(() => client.status == ConnectionStatus.online);
    await host.send(Command.sendChat(ChatChannel.generalId, '¡Tirad iniciativa!'));
    await waitFor(() => client.chat.messages.isNotEmpty);
    expect(client.chat.messages.single.text, '¡Tirad iniciativa!');

    final r = await client.send(Command.createChannel('Secreto', [player.userId, host.myUserId], direct: true));
    expect(r.ok, isTrue);
    await waitFor(() => client.chat.channels.length == 2);
  });

  test('reconexión automática tras caída del anfitrión', () async {
    client = ClientSession(invite: inviteFor(), profile: player)..start();
    await waitFor(() => client.status == ConnectionStatus.online);
    final port = host.port;
    await host.close();
    await waitFor(() => client.status != ConnectionStatus.online);
    host = HostSession(campaign: host.campaign, profile: dm, storage: null, port: port, enableLanBeacon: false);
    await host.start();
    client.retryNow();
    await waitFor(() => client.status == ConnectionStatus.online, timeout: const Duration(seconds: 20));
  });
}
