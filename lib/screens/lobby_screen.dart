import 'package:assoasso_app/core/app_globals.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../core/app_router.dart';
import '../services/pocketbase_service.dart';
import '../widgets/action_button.dart';
import '../widgets/settings_tile.dart';
import '../widgets/universal_safearea.dart';

// A screen for the game lobby, where players wait before a match starts.
class LobbyScreen extends StatefulWidget {
  final String code;
  final String currentUserNickname;

  const LobbyScreen({super.key, required this.code, required this.currentUserNickname});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final PocketBaseService _pbService = PocketBaseService();
  UnsubscribeFunc? _unsubscribeFn;
  RecordModel? _session;
  bool _isHost = false;

  // Game settings state, mirrored from the session for the UI
  bool _shufflePlayers = AppGlobals.keyShufflePlayers_defaultValue;
  bool _reShuffleDeck = AppGlobals.keyReshuffleDeck_defaultValue;
  bool _squads = AppGlobals.keySquads_defaultValue;
  int _timePerTurn = AppGlobals.keyTimePerTurn_defaultValue;
  int _minScales = AppGlobals.keyMinScales_defaultValue;

  bool _hasNavigatedToGame = false;

  @override
  void initState() {
    super.initState();
    _initializeLobby();
  }

  // Initializes lobby state and subscribes to real-time session updates.
  Future<void> _initializeLobby() async {
    final initialSession = await _pbService.getSessionByCode(widget.code);
    if (!mounted) return;

    if (initialSession == null) {
      _navigateHome('Lobby non trovata');
      return;
    }

    _updateStateFromSession(initialSession);

    // Subscribe to real-time updates via PocketBase realtime
    _unsubscribeFn = await _pbService.sessions.subscribe(initialSession.id, (event) {
      if (mounted) {
        _onSessionUpdate(event.record);
      }
    });
  }

  // Callback for handling real-time session updates from PocketBase.
  void _onSessionUpdate(RecordModel? session) {
    if (session == null) {
        _navigateHome('La lobby è stata chiusa');
        return;
    }

    // Check if the game has started
    if (session.data['status'] == 'started') {
      _navigateToGame(session);
      return;
    }

    // Check if the current user is still in the lobby
    final players = List<Map<String, dynamic>>.from(session.data['players'] ?? []);
    if (!players.any((p) => p['nickname'] == widget.currentUserNickname)) {
        _navigateHome('Sei stato rimosso dalla lobby');
        return;
    }

    _updateStateFromSession(session);
  }

  // Updates the local state from a session record.
  void _updateStateFromSession(RecordModel session) {
    if (!mounted) return;
    setState(() {
      _session = session;
      _isHost = _checkIfHost(session);
      _loadSettingsFromSession(session);
    });
  }

  // Checks if the current user is the host of the lobby.
  bool _checkIfHost(RecordModel? session) {
    if (session == null) return false;
    final players = List<Map<String, dynamic>>.from(session.data['players'] ?? []);
    final host = players.firstWhere((p) => p['isHost'] == true, orElse: () => {});
    return host['nickname'] == widget.currentUserNickname;
  }

  // Loads game settings from the session data into the local state.
  void _loadSettingsFromSession(RecordModel session) {
    final settings = session.data['gameSettings'] as Map<String, dynamic>? ?? {};
    _shufflePlayers = settings['playersShuffle'] ?? AppGlobals.keyShufflePlayers_defaultValue;
    _reShuffleDeck = settings['shuffleCardsWhenFinishDeck'] ?? AppGlobals.keyReshuffleDeck_defaultValue;
    _squads = session.data['nPlayers'] == 4 ? (settings['squads'] ?? AppGlobals.keySquads_defaultValue) : false;
    _timePerTurn = settings['playerMoveDurationInSecs'] ?? AppGlobals.keyTimePerTurn_defaultValue;
    _minScales = session.data['nPlayers'] == 2 ? (settings['minScales'] ?? AppGlobals.keyMinScales_defaultValue): 1;
  }

  @override
  void dispose() {
    _unsubscribeFn?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Prevent navigating back with the system button
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: MySafeArea(
            child: _session == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      _buildHeader(),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: _buildPlayerList()),
                            Expanded(flex: 3, child: _buildSettingsPanel()),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // --- UI Builder Methods ---

  Widget _buildHeader() {
    final players = List<Map<String, dynamic>>.from(_session?.data['players'] ?? []);
    final requiredPlayers = _session?.data['nPlayers'] ?? 0;
    final canStart = _isHost && players.length == requiredPlayers;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ActionButton(label: 'ESCI', onPressed: _leaveLobby, backgroundColor: Colors.red.shade600),
          Row(children: [
            Text('LOBBY: ', style: TextStyle(fontSize: 28, color: Colors.yellow[100], fontWeight: FontWeight.bold)),
            SelectableText(
              widget.code,
              style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ]),
          if (_isHost)
            Opacity(
              opacity: canStart ? 1.0 : 0.5,
              child: ActionButton(
                label: 'AVVIA PARTITA',
                onPressed: canStart ? _startGame : () => _showSnackBar('Numero di giocatori insufficiente per iniziare'),
                backgroundColor: Colors.green.shade600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayerList() {
    final players = List<Map<String, dynamic>>.from(_session!.data['players'] ?? []);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Giocatori (${players.length}/${_session!.data['nPlayers']})', style: _sectionTitleStyle()),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: players.length,
              itemBuilder: (context, index) {
                final player = players[index];
                return AnimatedPlayerCard(
                  index: index,
                  child: Card(
                    color: Colors.black.withValues(alpha: 0.5),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(backgroundImage: AssetImage(player['avatarPath'] ?? 'assets/images/avatars/avatar_0.png')),
                      title: Text(player['nickname'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      trailing: player['isHost'] == true ? const Icon(Icons.star, color: Colors.yellow) : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel() {
    final nPlayers = _session?.data['nPlayers'] ?? 2;
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Impostazioni Partita', style: _sectionTitleStyle()),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: [
                _buildSwitchSetting('Mescola giocatori', 'Determina l\'ordine di gioco casualmente', _shufflePlayers, 'playersShuffle'),
                _buildSwitchSetting('Rimescola mazzo', 'Se il mazzo finisce, rimescola gli scarti prima di riutilizzarli', _reShuffleDeck, 'shuffleCardsWhenFinishDeck'),
                if (nPlayers == 4) _buildSwitchSetting('Squadre', 'Abilita la modalità a squadre', _squads, 'squads'),
                _buildDropdownSetting<int>('Tempo per mossa', 'Durata massima di ogni mossa', _timePerTurn, [10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60], 'playerMoveDurationInSecs', (v) => '$v sec'),
                if (nPlayers == 2) _buildDropdownSetting<int>('Scale minime', 'Numero di scale per vincere', _minScales, [1, 2], 'minScales', (v) => '$v'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Settings Widgets ---

  Widget _buildSwitchSetting(String title, String subtitle, bool value, String key) {
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      isEnabled: _isHost,
      trailing: Switch(
        value: value,
        onChanged: _isHost ? (newValue) => _updateGameSetting(key, newValue) : null,
        activeColor: Colors.green.shade400,
        inactiveThumbColor: Colors.grey.shade700,
        activeTrackColor: Colors.green.withValues(alpha: 0.5),
        inactiveTrackColor: Colors.grey.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildDropdownSetting<T>(
    String title, String subtitle, T value, List<T> items, String key, String Function(T) valueBuilder) {
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      isEnabled: _isHost,
      trailing: _isHost ? DropdownButton<T>(
        value: value,
        items: items.map((item) => DropdownMenuItem<T>(value: item, child: Text(valueBuilder(item)))).toList(),
        onChanged: _isHost ? (newValue) => _updateGameSetting(key, newValue) : null,
        dropdownColor: Colors.black87,
        style: const TextStyle(color: Colors.white),
        underline: Container(),
      ) :
      Text(value.toString()),
    );
  }

  // --- Actions & Navigation ---

  Future<void> _updateGameSetting(String key, dynamic value) async {
    if (_session == null || !_isHost) return;
    final newSettings = Map<String, dynamic>.from(_session!.data['gameSettings'] ?? {});
    newSettings[key] = value;
    try {
      await _pbService.sessions.update(_session!.id, body: {'gameSettings': newSettings});
    } catch (e) {
      _showSnackBar('Errore nell\'aggiornamento delle impostazioni');
    }
  }

  Future<void> _leaveLobby() async {
    if (_session == null) {
      _navigateHome('Sei uscito dalla lobby');
      return;
    }

    var players = List<Map<String, dynamic>>.from(_session!.data['players'] ?? []);
    players.removeWhere((p) => p['nickname'] == widget.currentUserNickname);

    try {
      if (players.isEmpty) {
        await _pbService.sessions.delete(_session!.id);
      } else {
        if (_isHost && players.isNotEmpty) {
          players[0]['isHost'] = true;
        }
        await _pbService.sessions.update(_session!.id, body: {'players': players});
      }
    } finally {
      _navigateHome('Sei uscito dalla lobby');
    }
  }

  Future<void> _startGame() async {
    if (_session == null || !_isHost) return;
    try {
        var players = List<Map<String, dynamic>>.from(_session!.data['players'] ?? []);
        if (_shufflePlayers) {
            players.shuffle();
        }
        if (_session!.data['nPlayers'] == 2 && _minScales == 2) {
          for (int i=0; i<players.length; i++) {
            players[i]['completedScales'] = [[], []];
          }
        }
        await _pbService.sessions.update(_session!.id, body: {
            'status': 'started',
            'startedAt': DateTime.now().toIso8601String(),
            'players': players,
        });
    } catch (e) {
        _showSnackBar('Errore nell\'avvio della partita');
    }
  }

  void _navigateHome(String message) {
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRouter.home,
        (route) => false,
        arguments: {'message': message},
      );
    }
  }

  void _navigateToGame(RecordModel session) {
    if (!mounted || _hasNavigatedToGame) return;
    final players = List<Map<String, dynamic>>.from(session.data['players'] ?? []);
    final host = players.firstWhere((p) => p['isHost'] == true, orElse: () => {});
    final hostNickname = host['nickname'] ?? '';

    _hasNavigatedToGame = true;

    Navigator.pushReplacementNamed(
      context,
      AppRouter.game,
      arguments: {
        'code': widget.code,
        'currentUserNickname': widget.currentUserNickname,
        'lobbyHostNickname': hostNickname,
      },
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black87,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // --- Style Helpers ---

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Colors.black.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.yellow.shade800.withValues(alpha: 0.6)),
    );
  }

  TextStyle _sectionTitleStyle() {
    return TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.yellow[200]);
  }
}

class AnimatedPlayerCard extends StatelessWidget {
  final Widget child;
  final int index;

  const AnimatedPlayerCard({
    super.key,
    required this.child,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 200 + (index * 50)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(30 * (1 - value), 0),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
