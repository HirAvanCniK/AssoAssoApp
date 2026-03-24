import 'dart:math';
import 'package:flutter/foundation.dart';

// A utility class for global constants and helper functions.
class AppGlobals {
  // --- PocketBase Configuration ---
  static const String pocketbaseUrl = 'https://irvannitest.alwaysdata.net';
  
  static const String pocketbaseCollection = 'asso_asso_sessions';

  // --- SharedPreferences Keys ---
  static const String keyNickname = 'nickname';
  static const String keyAvatarPath = 'avatarPath';
  static const String keyGamesPlayed = 'partite';
  static const String keyWins = 'vittorie';
  static const String keyLosses = 'sconfitte';
  static const String keySound = 'sound';

  static const String keyShufflePlayers = 'shufflePlayers';
  static const bool keyShufflePlayers_defaultValue = true;

  static const String keyReshuffleDeck = 'reShuffleDeck';
  static const bool keyReshuffleDeck_defaultValue = true;

  static const String keySquads = 'squads';
  static const bool keySquads_defaultValue = true;

  static const String keyTimePerTurn = 'timePerTurn';
  static const int keyTimePerTurn_defaultValue = 20;

  static const String keyMinScales = 'minScales';
  static const int keyMinScales_defaultValue = 2;

  // Prints a debug message only when the app is in debug mode.
  static void debugPrint(Object? object) {
    if (kDebugMode) {
      print(object);
    }
  }

  // Generates a random integer within a given range [min, max).
  static int randomNumber(int min, int max) {
    return min + Random().nextInt(max - min);
  }

  // Generates a random alphanumeric session code.
  static String generateGameCode({int length = 6}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
