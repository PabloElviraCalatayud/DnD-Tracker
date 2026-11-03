import 'dart:async';

import 'package:dnd_tracker/domain/campaign.dart';
import 'package:dnd_tracker/domain/character.dart';
import 'package:dnd_tracker/domain/profile.dart';
import 'package:dnd_tracker/net/invite.dart';
import 'package:dnd_tracker/net/transport.dart';
import 'package:dnd_tracker/state/client_session.dart';
import 'package:dnd_tracker/state/host_session.dart';
import 'package:dnd_tracker/state/session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../relay/bin/relay.dart' as relay;

Future<void> waitFor(bool Function() condition, {Duration timeout = const Duration(seconds: 10)}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) throw TimeoutException('condición no cumplida');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  test('máster y jugador conectados sólo a través del relay', () async {
    final server = await relay.Relay().serve(0);
    final relayUrl = 'ws://127.0.0.1:${server.port}';
    final dm = UserProfile(displayName: 'Máster');
    final player = UserProfile(displayName: 'Brom');
    final campaign = Campaign(name: 'Por datos móviles', dmUserId: dm.userId, dmName: 'Máster');
    final host = HostSession(
        campaign: campaign, profile: dm, storage: null, port: 0, relayUrl: relayUrl, enableLanBeacon: false);
    await host.start();
    await waitFor(() => host.relayState == RelayState.online);

    // La invitación no lleva IPs directas: sólo el relay.
    final invite = Invite(campaignId: campaign.id, campaignName: campaign.name, code: campaign.joinCode,
        relayUrl: relayUrl);
    final client = ClientSession(invite: invite, profile: player)..start();
    await waitFor(() => client.status == ConnectionStatus.online);
    expect(client.connectedVia!.path, endsWith('/join'));

    final pc = Character(ownerId: player.userId, name: 'Brom');
    expect((await client.saveCharacter(pc)).ok, isTrue);
    await waitFor(() => host.campaign.character(pc.id) != null);

    await client.close();
    await host.close();
    await server.close(force: true);
  });
}
