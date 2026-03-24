import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_globals.dart';

// A service class for managing user preferences using SharedPreferences.
//
// This class provides a centralized way to access and modify user settings
// and statistics, ensuring consistency and reducing code duplication.
class SharedPreferencesService {
  // Loads all user preferences and statistics from SharedPreferences.
  //
  // Returns a map where keys are preference names and values are the stored
  // preferences. Provides default values if a preference is not set.
  static Future<Map<String, dynamic>> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      AppGlobals.keyNickname: prefs.getString(AppGlobals.keyNickname) ?? 'Giocatore',
      AppGlobals.keyAvatarPath: prefs.getString(AppGlobals.keyAvatarPath) ?? 'assets/images/avatars/avatar_0.png',
      AppGlobals.keyGamesPlayed: prefs.getInt(AppGlobals.keyGamesPlayed) ?? 0,
      AppGlobals.keyWins: prefs.getInt(AppGlobals.keyWins) ?? 0,
      AppGlobals.keyLosses: prefs.getInt(AppGlobals.keyLosses) ?? 0,
      AppGlobals.keySound: prefs.getBool(AppGlobals.keySound) ?? true,
      AppGlobals.keyShufflePlayers: prefs.getBool(AppGlobals.keyShufflePlayers) ?? AppGlobals.keyShufflePlayers_defaultValue,
      AppGlobals.keyReshuffleDeck: prefs.getBool(AppGlobals.keyReshuffleDeck) ?? AppGlobals.keyReshuffleDeck_defaultValue,
      AppGlobals.keySquads: prefs.getBool(AppGlobals.keySquads) ?? AppGlobals.keySquads_defaultValue,
      AppGlobals.keyTimePerTurn: prefs.getInt(AppGlobals.keyTimePerTurn) ?? AppGlobals.keyTimePerTurn_defaultValue,
      AppGlobals.keyMinScales: prefs.getInt(AppGlobals.keyMinScales) ?? AppGlobals.keyMinScales_defaultValue,
    };
  }

  // Saves a single preference value to SharedPreferences.
  //
  // The [key] must be one of the constants defined in this class.
  // The [value] can be a `bool`, `int`, or `String`.
  static Future<void> savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  // Updates player statistics and game settings in persistent storage.
  //
  // This method handles incremental updates for stats and direct updates for settings,
  // with validation to ensure data integrity.
  static Future<void> updateSettingsAndStats({
    int? gamesPlayedDelta,
    int? winsDelta,
    int? lossesDelta,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (gamesPlayedDelta != null && gamesPlayedDelta == 1) {
      await prefs.setInt(AppGlobals.keyGamesPlayed, (prefs.getInt(AppGlobals.keyGamesPlayed) ?? 0) + gamesPlayedDelta);
    }
    if (winsDelta != null && winsDelta == 1) {
      await prefs.setInt(AppGlobals.keyWins, (prefs.getInt(AppGlobals.keyWins) ?? 0) + winsDelta);
    }
    if (lossesDelta != null && lossesDelta == 1) {
      await prefs.setInt(AppGlobals.keyLosses, (prefs.getInt(AppGlobals.keyLosses) ?? 0) + lossesDelta);
    }
  }
}
