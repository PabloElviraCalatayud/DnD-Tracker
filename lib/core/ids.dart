import 'dart:math';

final Random _rng = Random.secure();

const String _alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
const String _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// Identificador aleatorio corto, suficiente para objetos de una partida.
String newId([int length = 16]) => List.generate(length, (_) => _alphabet[_rng.nextInt(_alphabet.length)]).join();

/// Código de invitación legible (sin 0/O ni 1/I para evitar confusiones).
String newJoinCode([int length = 6]) =>
    List.generate(length, (_) => _codeAlphabet[_rng.nextInt(_codeAlphabet.length)]).join();

/// Secreto del dispositivo: identifica a un jugador ante el anfitrión.
String newSecret() => newId(32);
