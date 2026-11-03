import 'dart:convert';
import 'dart:io';

import '../core/json.dart';
import '../domain/campaign.dart';
import '../domain/chat.dart';
import '../domain/player_note.dart';
import '../domain/profile.dart';
import '../net/invite.dart';

/// Partida a la que este dispositivo se ha unido como jugador: cómo conectar
/// y la última vista recibida (para poder consultarla sin conexión).
class JoinedCampaign {
  JoinedCampaign({required this.invite, this.lastView, this.chat, this.lastConnectedAt = 0});

  Invite invite;
  Campaign? lastView;
  ChatState? chat;
  int lastConnectedAt;

  String get campaignId => invite.campaignId;
  String get name => lastView?.name ?? invite.campaignName;

  Map<String, dynamic> toJson() => {
    'invite': invite.toJson(),
    if (lastView != null) 'lastView': lastView!.toJson(includeChat: false),
    if (chat != null) 'chat': chat!.toJson(),
    'lastConnectedAt': lastConnectedAt,
  };

  factory JoinedCampaign.fromJson(Map<String, dynamic> j) => JoinedCampaign(
    invite: Invite.fromJson(asMap(j['invite'])),
    lastView: j['lastView'] is Map ? Campaign.fromJson(asMap(j['lastView'])) : null,
    chat: j['chat'] is Map ? ChatState.fromJson(asMap(j['chat'])) : null,
    lastConnectedAt: asInt(j['lastConnectedAt']),
  );
}

/// Almacenamiento en ficheros JSON dentro de la carpeta de datos de la app.
///
/// - `profile.json`
/// - `hosted/{id}.json`: partidas en las que soy máster (fuente de verdad)
/// - `joined/{id}.json`: partidas en las que juego (caché + invitación)
/// - `notes/{id}.json`: cuaderno privado del jugador
class AppStorage {
  AppStorage(this.root);

  final Directory root;

  Directory _dir(String name) {
    final d = Directory('${root.path}${Platform.pathSeparator}$name');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  File _file(String dir, String name) => File('${_dir(dir).path}${Platform.pathSeparator}$name');

  static String _safe(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  /// Escritura atómica: primero a un temporal, después se renombra. Así un
  /// cierre inesperado no deja la partida a medias. Guarda además una copia .bak.
  Future<void> _writeJson(File file, Object data) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    if (await file.exists()) {
      try {
        await file.copy('${file.path}.bak');
      } on FileSystemException {
        // La copia de seguridad es opcional.
      }
    }
    try {
      await tmp.rename(file.path);
    } on FileSystemException {
      if (await file.exists()) await file.delete();
      await tmp.rename(file.path);
    }
  }

  Future<Map<String, dynamic>?> _readJson(File file) async {
    for (final f in [file, File('${file.path}.bak')]) {
      if (!await f.exists()) continue;
      try {
        final v = jsonDecode(await f.readAsString());
        if (v is Map) return asMap(v);
      } on FormatException {
        continue;
      }
    }
    return null;
  }

  // ------------------------------------------------------------ Perfil

  Future<UserProfile?> loadProfile() async {
    final j = await _readJson(File('${root.path}${Platform.pathSeparator}profile.json'));
    return j == null ? null : UserProfile.fromJson(j);
  }

  Future<void> saveProfile(UserProfile p) async {
    if (!root.existsSync()) root.createSync(recursive: true);
    await _writeJson(File('${root.path}${Platform.pathSeparator}profile.json'), p.toJson());
  }

  // ------------------------------------------------------------ Máster

  Future<List<Campaign>> listHosted() async {
    final out = <Campaign>[];
    await for (final f in _dir('hosted').list()) {
      if (f is File && f.path.endsWith('.json')) {
        final j = await _readJson(f);
        if (j != null) out.add(Campaign.fromJson(j));
      }
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  Future<Campaign?> loadHosted(String id) async {
    final j = await _readJson(_file('hosted', '${_safe(id)}.json'));
    return j == null ? null : Campaign.fromJson(j);
  }

  Future<void> saveHosted(Campaign c) => _writeJson(_file('hosted', '${_safe(c.id)}.json'), c.toJson());

  Future<void> deleteHosted(String id) async {
    for (final suffix in ['', '.bak', '.tmp']) {
      final f = File('${_file('hosted', '${_safe(id)}.json').path}$suffix');
      if (await f.exists()) await f.delete();
    }
  }

  // ------------------------------------------------------------ Jugador

  Future<List<JoinedCampaign>> listJoined() async {
    final out = <JoinedCampaign>[];
    await for (final f in _dir('joined').list()) {
      if (f is File && f.path.endsWith('.json')) {
        final j = await _readJson(f);
        if (j != null) out.add(JoinedCampaign.fromJson(j));
      }
    }
    out.sort((a, b) => b.lastConnectedAt.compareTo(a.lastConnectedAt));
    return out;
  }

  Future<JoinedCampaign?> loadJoined(String campaignId) async {
    final j = await _readJson(_file('joined', '${_safe(campaignId)}.json'));
    return j == null ? null : JoinedCampaign.fromJson(j);
  }

  Future<void> saveJoined(JoinedCampaign j) => _writeJson(_file('joined', '${_safe(j.campaignId)}.json'), j.toJson());

  Future<void> deleteJoined(String campaignId) async {
    for (final suffix in ['', '.bak', '.tmp']) {
      final f = File('${_file('joined', '${_safe(campaignId)}.json').path}$suffix');
      if (await f.exists()) await f.delete();
    }
  }

  // ------------------------------------------------------------ Cuaderno

  Future<List<PlayerNote>> loadNotes(String campaignId) async {
    final j = await _readJson(_file('notes', '${_safe(campaignId)}.json'));
    return j == null ? <PlayerNote>[] : asList(j['notes'], PlayerNote.fromJson);
  }

  Future<void> saveNotes(String campaignId, List<PlayerNote> notes) =>
      _writeJson(_file('notes', '${_safe(campaignId)}.json'), {'notes': notes.map((n) => n.toJson()).toList()});

  // ------------------------------------------------------------ Copias

  /// Exporta una partida a la carpeta "exports" y devuelve la ruta.
  Future<String> exportCampaign(Campaign c) async {
    final stamp = DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-');
    final f = _file('exports', '${_safe(c.name)}_$stamp.json');
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(c.toJson()));
    return f.path;
  }

  /// Importa una partida exportada (JSON). Si ya existe una con el mismo id
  /// se sobrescribe.
  Future<Campaign> importCampaign(String json) async {
    final c = Campaign.fromJson(asMap(jsonDecode(json)));
    await saveHosted(c);
    return c;
  }
}
