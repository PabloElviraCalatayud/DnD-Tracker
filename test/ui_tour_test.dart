// Recorre las pantallas principales con la partida de ejemplo, como máster y
// como jugador, en escritorio y en móvil. Falla si alguna pantalla lanza una
// excepción o se desborda. Con SCREENSHOT_DIR=/ruta guarda capturas PNG.
//
//   SCREENSHOT_DIR=/tmp/capturas flutter test test/ui_tour_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dnd_tracker/data/demo.dart';
import 'package:dnd_tracker/core/i18n.dart';
import 'package:dnd_tracker/data/storage.dart';
import 'package:dnd_tracker/domain/campaign.dart';
import 'package:dnd_tracker/domain/chat.dart';
import 'package:dnd_tracker/domain/profile.dart';
import 'package:dnd_tracker/domain/roll.dart';
import 'package:dnd_tracker/engine/commands.dart';
import 'package:dnd_tracker/engine/view_filter.dart';
import 'package:dnd_tracker/state/host_session.dart';
import 'package:dnd_tracker/state/providers.dart';
import 'package:dnd_tracker/state/session.dart';
import 'package:dnd_tracker/ui/screens/campaign_shell.dart';
import 'package:dnd_tracker/ui/screens/home_screen.dart';
import 'package:dnd_tracker/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Jugador simulado: ve la vista filtrada de la partida del máster.
class DemoPlayerSession extends GameSession {
  DemoPlayerSession(this.host, this.userId, this.name);
  final HostSession host;
  final String userId;
  final String name;

  @override
  Campaign get campaign => ViewFilter.forPlayer(host.campaign, userId, online: [userId]);
  @override
  ChatState get chat => host.campaign.chat.visibleTo(userId);
  @override
  bool get isDm => false;
  @override
  String get myUserId => userId;
  @override
  String get myName => name;
  @override
  ConnectionStatus get status => ConnectionStatus.online;
  @override
  String get statusMessage => '';
  @override
  Future<CommandResult> send(Command cmd) async {
    final r = host.engine.apply(cmd, Actor(userId: userId, name: name, isDm: false));
    notifyListeners();
    return CommandResult(r.ok, r.error, r.data);
  }

  @override
  Future<void> close() async {}

  @override
  List<RollEntry> get rolls => host.campaign.rolls.where((r) => !r.hidden).toList();

  @override
  Future<Uint8List?> loadAsset(String id) => host.loadAsset(id);

  @override
  Future<String?> uploadAsset(Uint8List bytes) => host.uploadAsset(bytes);
}

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
    }
    await loader.load();
  }

  await load('Cinzel', ['assets/fonts/Cinzel-Variable.ttf']);
  await load('CinzelDecorative', ['assets/fonts/CinzelDecorative-Bold.ttf']);
  await load('AlegreyaSans', [
    'assets/fonts/AlegreyaSans-Regular.ttf',
    'assets/fonts/AlegreyaSans-Bold.ttf',
    'assets/fonts/AlegreyaSans-Medium.ttf',
    'assets/fonts/AlegreyaSans-Italic.ttf',
  ]);
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter-sdk/flutter';
  final icons = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) await load('MaterialIcons', [icons.path]);
}

final _boundary = GlobalKey();
final String? _shotDir = Platform.environment['SCREENSHOT_DIR'];

Future<void> _settle(WidgetTester tester, {int ms = 250}) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms ~/ 4)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await _settle(tester);
  final dir = _shotDir;
  if (dir == null) return;
  await tester.runAsync(() async {
    final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(dir).createSync(recursive: true);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Widget _app(AppStorage storage, UserProfile profile, Widget home) => ProviderScope(
  overrides: [storageProvider.overrideWithValue(storage), initialProfileProvider.overrideWithValue(profile)],
  child: RepaintBoundary(
    key: _boundary,
    child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(), home: home),
  ),
);

Future<void> _tap(WidgetTester tester, String text) async {
  final f = find.text(text);
  expect(f, findsWidgets, reason: 'no encuentro "$text"');
  await tester.tap(f.first);
  await _settle(tester);
}

/// Va a una sección: la busca en la barra/raíl y si no está, en «Más».
Future<void> _goTo(WidgetTester tester, String section) async {
  for (final nav in [find.byType(NavigationRail), find.byType(NavigationBar)]) {
    final f = find.descendant(of: nav, matching: find.text(section));
    if (f.evaluate().isNotEmpty) {
      await tester.tap(f.first);
      await _settle(tester);
      return;
    }
  }
  await _openMore(tester);
  await _tap(tester, section);
}

Future<void> _openMore(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_horiz));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await _settle(tester);
}

void main() {
  late Directory tmp;
  late AppStorage storage;
  final dm = UserProfile(displayName: 'Pablo');

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('dndt_tour');
    storage = AppStorage(tmp);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  HostSession demoHost() => HostSession(
    campaign: buildDemoCampaign(dmUserId: dm.userId, dmName: dm.displayName),
    profile: dm,
    storage: storage,
    enableLanBeacon: false,
  );

  for (final (label, size) in [('escritorio', const Size(1280, 800)), ('movil', const Size(412, 892))]) {
    testWidgets('recorrido del máster ($label)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // Sombras reales para que las capturas se parezcan a la app (se restaura al final).
      debugDisableShadows = _shotDir == null;
      addTearDown(() => debugDisableShadows = true);
      final host = demoHost();
      await tester.pumpWidget(_app(storage, dm, CampaignShell(session: host)));
      await _shot(tester, 'dm_${label}_01_tablero');

      final sections = [
        'Resumen',
        'Combate',
        'Grimorio',
        'Chat',
        'Personajes',
        'Objetos',
        'Artesanía',
        'Notas',
        'Referencia',
        'Partida',
      ];
      var n = 2;
      for (final sec in sections) {
        await _goTo(tester, tr(sec));
        await _shot(tester, 'dm_${label}_${(n++).toString().padLeft(2, '0')}_${sec.toLowerCase()}');
      }

      // Ficha completa de un personaje desde «Personajes».
      if (label == 'escritorio') {
        await _goTo(tester, tr('Personajes'));
        await _tap(tester, 'Lyra Vientoalba');
        await _shot(tester, 'dm_${label}_20_ficha_lyra');
        await _tap(tester, 'Inventario');
        await _shot(tester, 'dm_${label}_21_inventario_lyra');
      }
      await tester.pumpWidget(const SizedBox());
      await _settle(tester);
      debugDisableShadows = true;
    });

    testWidgets('recorrido del jugador ($label)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // Sombras reales para que las capturas se parezcan a la app (se restaura al final).
      debugDisableShadows = _shotDir == null;
      addTearDown(() => debugDisableShadows = true);
      final host = demoHost();
      final player = DemoPlayerSession(host, 'demo-luis', 'Luis');
      final luis = UserProfile(userId: 'demo-luis', displayName: 'Luis');
      await tester.pumpWidget(_app(storage, luis, CampaignShell(session: player)));
      await _shot(tester, 'jugador_${label}_01_tablero');

      // Tirada desde el tablero: la genera el máster, se anima y queda registrada.
      final before = host.campaign.rolls.length;
      await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.byTooltip(tr('Tirar dados'))));
      await _settle(tester);
      await tester.tap(find.text('d20').last);
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await _shot(tester, 'jugador_${label}_01b_dados');
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(host.campaign.rolls.length, before + 1);
      expect(host.campaign.rolls.last.hidden, isFalse);

      final sections = ['Ficha', 'Inventario', 'Conjuros', 'Chat', 'Artesanía', 'Grupo', 'Combate', 'Notas', 'Referencia'];
      var n = 2;
      for (final sec in sections) {
        await _goTo(tester, tr(sec));
        await _shot(tester, 'jugador_${label}_${(n++).toString().padLeft(2, '0')}_${sec.toLowerCase()}');
      }
      // El jugador no debe ver datos ocultos por el máster.
      final ring = player.campaign.characters
          .firstWhere((c) => c.ownerId == 'demo-luis')
          .inventory
          .firstWhere((i) => i.name.startsWith('Anillo'));
      expect(ring.valueCp, isNull);
      expect(ring.dmNote, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await _settle(tester);
      debugDisableShadows = true;
    });
  }

  testWidgets('pantalla de inicio', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => storage.saveHosted(buildDemoCampaign(dmUserId: dm.userId, dmName: dm.displayName)));
    await tester.pumpWidget(_app(storage, dm, const HomeScreen()));
    await _settle(tester, ms: 600);
    await _shot(tester, 'inicio');
  });
}
