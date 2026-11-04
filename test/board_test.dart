// Interacción con el tablero: arrastrar fichas y colocarlas tocando el mapa.
import 'dart:io';

import 'package:dnd_tracker/data/demo.dart';
import 'package:dnd_tracker/data/storage.dart';
import 'package:dnd_tracker/domain/board.dart';
import 'package:dnd_tracker/domain/profile.dart';
import 'package:dnd_tracker/state/host_session.dart';
import 'package:dnd_tracker/state/providers.dart';
import 'package:dnd_tracker/ui/screens/board/map_view.dart';
import 'package:dnd_tracker/ui/screens/campaign_shell.dart';
import 'package:dnd_tracker/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  late AppStorage storage;
  final dm = UserProfile(displayName: 'Pablo');

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('dndt_board');
    storage = AppStorage(tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<HostSession> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final host = HostSession(
      campaign: buildDemoCampaign(dmUserId: dm.userId, dmName: dm.displayName),
      profile: dm,
      storage: storage,
      enableLanBeacon: false,
    );
    addTearDown(host.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storageProvider.overrideWithValue(storage), initialProfileProvider.overrideWithValue(dm)],
        child: MaterialApp(
          theme: buildTheme(),
          home: CampaignShell(session: host),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return host;
  }

  Finder tokenNamed(String name) => find.byWidgetPredicate((w) => w is TokenView && w.info.name == name && !w.lifted);

  BoardToken tokenOf(HostSession host, String characterName) {
    final c = host.campaign.characters.firstWhere((c) => c.name == characterName);
    return host.campaign.board.tokens.firstWhere((t) => t.characterId == c.id);
  }

  testWidgets('el máster arrastra una ficha a otra casilla', (tester) async {
    final host = await open(tester);
    final before = tokenOf(host, 'Kesh');
    final (x0, y0) = (before.x, before.y);
    final finder = tokenNamed('Kesh');
    expect(finder, findsOneWidget);
    final cell = tester.getRect(finder).width;
    await tester.timedDrag(finder, Offset(cell * 3, cell * 2), const Duration(milliseconds: 400));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final after = tokenOf(host, 'Kesh');
    // El arrastre pierde un poco por el umbral de inicio: acepta ±1 casilla.
    expect((after.x - (x0 + 3)).abs() <= 1, isTrue, reason: 'x ${after.x}');
    expect((after.y - (y0 + 2)).abs() <= 1, isTrue, reason: 'y ${after.y}');
    expect(after.x != x0 || after.y != y0, isTrue);
  });

  testWidgets('el máster coloca una ficha donde toca', (tester) async {
    final host = await open(tester);
    final map = host.campaign.board.activeMap!;
    final state = tester.state<MapViewState>(find.byType(MapView));
    final marker = BoardToken(mapId: map.id, kind: TokenKind.npc, label: 'Tabernero', icon: 'person');
    state.startPlacing([marker], 'Tabernero');
    await tester.pump();
    expect(find.textContaining('Tabernero'), findsWidgets);
    // Tocar dos casillas a la derecha de Kesh.
    final kesh = tokenNamed('Kesh');
    final cell = tester.getRect(kesh).width;
    await tester.tapAt(tester.getCenter(kesh) + Offset(cell * 2, 0));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final placed = host.campaign.board.tokens.where((t) => t.label == 'Tabernero').toList();
    expect(placed, hasLength(1));
    final k = tokenOf(host, 'Kesh');
    expect(placed.first.x, k.x + 2);
    expect(placed.first.y, k.y);
  });
}
