import '../core/app_globals.dart';
import 'pocketbase_service.dart';
import 'shared_preferences_service.dart';

// A service class to manage game session logic like creating and joining lobbies.
class GameSessionService {
  final PocketBaseService _pbService = PocketBaseService();

  // Creates a new game session in the backend.
  //
  // Returns the unique session code if successful, otherwise returns null.
  Future<String?> createGameSession(String nickname, int nPlayers) async {
    try {
      final prefs = await SharedPreferencesService.loadPreferences();
      final code = AppGlobals.generateGameCode();

      await _pbService.sessions.create(
        body: {
          'code': code,
          'createdAt': DateTime.now().toIso8601String(),
          'status': 'waiting',
          'nPlayers': nPlayers,
          'lastAction': {},
          'gameSettings': {
            'playerMoveDurationInSecs': prefs[AppGlobals.keyTimePerTurn],
            'shuffleCardsWhenFinishDeck': prefs[AppGlobals.keyReshuffleDeck],
            'squads': nPlayers == 4 ? prefs[AppGlobals.keySquads] : false,
            'minScales': nPlayers == 2 ? prefs[AppGlobals.keyMinScales]: 1,
            'playersShuffle': prefs[AppGlobals.keyShufflePlayers],
          },
          'players': [
            {
              'nickname': nickname,
              'avatarPath': prefs[AppGlobals.keyAvatarPath],
              'joinedAt': DateTime.now().toIso8601String(),
              'isHost': true,
              'hand': [],
              'completedScales': [[]],
            },
          ],
        },
      );
      return code;
    } catch (e) {
      AppGlobals.debugPrint('Error in createGameSession: $e');
      return null;
    }
  }

  // Attempts to join an existing game session using a lobby code.
  //
  // Returns `true` if successful, otherwise `false`.
  // The [onShowMessage] callback is used to display feedback to the user.
  Future<bool> joinGameSession(String code, String nickname, Function(String) onShowMessage) async {
    try {
      final session = await _pbService.getSessionByCode(code);

      if (session == null) {
        onShowMessage('Lobby non trovata');
        return false;
      }

      final players = List<Map<String, dynamic>>.from(session.data['players'] ?? []);

      if (players.any((p) => p['nickname'] == nickname)) {
        onShowMessage('Esiste già un giocatore con quel nickname nella lobby');
        return false;
      }

      if (players.length >= session.data['nPlayers']) {
        onShowMessage('Lobby piena');
        return false;
      }

      final prefs = await SharedPreferencesService.loadPreferences();
      players.add({
        'nickname': nickname,
        'avatarPath': prefs[AppGlobals.keyAvatarPath],
        'joinedAt': DateTime.now().toIso8601String(),
        'isHost': false,
        'hand': [],
        'completedScales': [[]],
      });

      await _pbService.sessions.update(session.id, body: {'players': players});
      return true;
    } catch (e) {
      AppGlobals.debugPrint('Error in joinGameSession: $e');
      onShowMessage('Errore durante l\'accesso alla lobby');
      return false;
    }
  }
}
