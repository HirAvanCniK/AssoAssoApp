import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import './deck_controller.dart';
import '../core/app_globals.dart';
import '../services/pocketbase_service.dart';
import '../widgets/painters/border_line_timer_painter.dart';
import '../widgets/universal_safearea.dart';
import '../widgets/tappable_card.dart';

enum GameAction { drawFromDeck, drawFromDiscard, discard, layOff }

enum CardDragType { deckToHand, handToDiscard, handToRun }

// Manages multiplayer game session state and synchronization.
//
// Handles game initialization, turn management, card animations, host/client
// coordination, and real-time backend synchronization.
class GameController {
  final PocketBaseService _pbService = PocketBaseService();
  final String sessionCode;
  final String currentUserNickname;
  final bool isHost;
  late final DeckController _deckController;

  final ValueNotifier<List<Widget>> movableWidgets = ValueNotifier([]);
  final ValueNotifier<double> progressNotifier = ValueNotifier<double>(1.0);
  final ValueNotifier<GameAction?> lastActionNotifier = ValueNotifier<GameAction?>(null);
  final ValueNotifier<CardDragType?> cardDragNotifier = ValueNotifier<CardDragType?>(null);

  Timer? _turnTimeoutTimer;
  Timer? _animationTimer;
  DateTime? _turnStartTime;
  int _turnDurationSeconds = 30;

  bool _isDisposed = false;

  bool _forceToFinishTurn = false;

  // Variables used for movable cards widgets
  List<Widget> _runs = [];
  List<Widget> _deck = [];
  List<Widget> _discard = [];
  List<Widget> _cards = [];

  final selectedCardNotifier = ValueNotifier<String?>(null);

  // Tracks active timer widgets currently displayed on screen.
  final List<Widget> _activeTimers = [];

  GameController(this.sessionCode, this.currentUserNickname, this.isHost) {
    _deckController = DeckController(sessionCode);
  }

  bool get isDisposed => _isDisposed;

  void clearSelectedCardNotifier() {
    selectedCardNotifier.value = null;
  }

  // Orchestrates the entire game initialization sequence.
  Future<void> startGame() async {
    AppGlobals.debugPrint('🎮 Starting game sequence (isHost: $isHost)...');
    final initialSession = await getSessionData();
    if (initialSession == null) {
      AppGlobals.debugPrint('❌ Could not start game: Session not found.');
      return;
    }

    if (isHost) {
      await _deckController.newDeck();
      await _deckController.shuffle();
      await Future.delayed(const Duration(milliseconds: 10000));
    } else {
      await _waitForHostToStart();
    }

    // Use a fresh session object after waiting period
    final session = await getSessionData();
    if (session == null) return;

    final players = session.data['players'] as List;
    await _distributeCardsSequentially(players);
    await Future.delayed(const Duration(seconds: 1));

    if (isHost) {
      AppGlobals.debugPrint('🎲 Starting first turn...');
      await _startFirstTurn(players);
    }
    AppGlobals.debugPrint('✅ Game start sequence complete!');
  }

  // --- Private Initialization Helpers ---

  // [Client-only] Polls until the host has started the game.
  Future<void> _waitForHostToStart() async {
    AppGlobals.debugPrint('🙋 Client: Waiting for host to start the game...');
    for (int i = 0; i < 40; i++) {
      final session = await getSessionData();
      if (session != null && session.data['playerShift'] != null) {
        AppGlobals.debugPrint('▶️ Host has started the game.');
        return;
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }
    AppGlobals.debugPrint('⚠️ Host start-check timed out.');
  }

  // [Host-only] Randomly selects the first player and updates the session.
  Future<void> _startFirstTurn(List players) async {
    final firstPlayerIndex = AppGlobals.randomNumber(0, players.length);
    await _updatePlayerShift(firstPlayerIndex);
  }

  // --- Turn Management ---

  // Requests to end the current turn in a non-blocking manner.
  Future<void> requestEndTurnFireAndForget() async {
    AppGlobals.debugPrint('🙋 $currentUserNickname requests to end turn.');
    try {
      final session = await getSessionData();
      if (session == null) return;

      final playerShift = session.data['playerShift'] as Map<String, dynamic>?;
      final players = session.data['players'] as List;
      if (playerShift == null) return;

      final currentTurnIndex = playerShift['iPlayer'] as int;
      final myIndex = players.indexWhere((p) => p['nickname'] == currentUserNickname);

      if (myIndex == currentTurnIndex) {
        final nextIndex = (currentTurnIndex + 1) % players.length;
        await _endTurnManager();
        await _updatePlayerShift(nextIndex);
        AppGlobals.debugPrint('✅ Turn advanced to player $nextIndex.');
      }
    } catch (e) {
      AppGlobals.debugPrint('❌ Error requesting end of turn: $e');
    }
  }

  // Updates the database to advance the turn to the specified player index.
  Future<void> _updatePlayerShift(int playerIndex, {bool resetTimestamp = true}) async {
    final session = await getSessionData();
    if (session == null) return;

    await _pbService.sessions.update(session.id, body: {
      'playerShift': {
        'iPlayer': playerIndex,
        'lastActionTimestamp': resetTimestamp
            ? DateTime.now().toIso8601String()
            : (session.data['playerShift'] as Map?)?['lastActionTimestamp'],
      },
      'lastAction':{
        'player': 'system',
        'action': 'switchTurn',
        'timestamp': DateTime.now().toIso8601String()
      }
    });
    await _initializeTurnTimerFromSession();
  }

  Future<void> _endTurnManager() async {
    final session = await getSessionData();
    if (session == null) return;
    
    // Find local player index and delegate to core logic
    final players = session.data['players'] as List;
    final myIndex = players.indexWhere((p) => p['nickname'] == currentUserNickname);
    if (myIndex == -1) return;
    
    await _enforceHandRulesForPlayerIndex(myIndex);
  }

  // --- Timer and Animation ---

  // Synchronizes the local timer state with the server's timestamp.
  void syncTurnTimer(RecordModel session) {
    final playerShift = session.data['playerShift'] as Map<String, dynamic>?;
    if (playerShift == null) return;

    final lastActionStr = playerShift['lastActionTimestamp'] as String?;
    if (lastActionStr == null) return;

    final lastAction = DateTime.parse(lastActionStr);
    if (_turnStartTime == null || _turnStartTime != lastAction) {
      _turnStartTime = lastAction;
      _turnDurationSeconds = _getTurnDurationFromSettings(session);
      _startAnimationTimer();
    }
  }

  // Initializes the local timer based on the current session state.
  Future<void> _initializeTurnTimerFromSession() async {
    final session = await getSessionData();
    if (session == null) return;

    _turnDurationSeconds = _getTurnDurationFromSettings(session);
    final playerShift = session.data['playerShift'] as Map<String, dynamic>?;
    _turnStartTime = playerShift?['lastActionTimestamp'] != null
        ? DateTime.parse(playerShift!['lastActionTimestamp'])
        : DateTime.now();

    _startAnimationTimer();
    if (isHost) {
      _startTurnTimeoutTimer();
    }
  }

  // Starts a high-frequency timer for smooth progress bar animation.
  void _startAnimationTimer() {
    _animationTimer?.cancel();
    _animationTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_turnStartTime == null) {
        timer.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(_turnStartTime!).inMilliseconds / 1000.0;
      final progress = (1.0 - elapsed / _turnDurationSeconds).clamp(0.0, 1.0);
      if (!_isDisposed && progressNotifier.value != progress) {
        progressNotifier.value = progress;
      }
      if (progress <= 0) timer.cancel();
    });
  }

  // [Host-only] Starts a polling timer to enforce turn timeouts.
  void _startTurnTimeoutTimer() {
    _turnTimeoutTimer?.cancel();
    AppGlobals.debugPrint('⏱️ Host turn timer started.');
    _turnTimeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!isHost || !timer.isActive) return;

      final session = await getSessionData();
      if (session == null) {
        timer.cancel();
        return;
      }

      if (getRemainingTimeFromSession(session) <= 0) {
        AppGlobals.debugPrint('⏰ Time expired! Forcing turn change.');
        timer.cancel();
        final players = session.data['players'] as List;
        final playerShift = session.data['playerShift'] as Map<String, dynamic>;
        final currentTurnIndex = playerShift['iPlayer'] as int;
        
        await _enforceHandRulesForPlayerIndex(currentTurnIndex);
        
        final nextIndex = (currentTurnIndex + 1) % players.length;
        await _updatePlayerShift(nextIndex);
      }
    });
  }


  // [Host-only] Enforces hand rules (6 cards) for a specific player by index.
  // Performs direct DB updates without UI interactions.
  Future<void> _enforceHandRulesForPlayerIndex(int playerIndex) async {
    final session = await getSessionData();
    if (session == null) return;

    final players = List<Map<String, dynamic>>.from(session.data['players'] as List);
    final player = players[playerIndex];
    var hand = List<String>.from(player['hand'] as List? ?? []);
    final nickname = player['nickname'] as String;

    if (hand.length == 7) {
      selectedCardNotifier.value = "hand_${AppGlobals.randomNumber(0, 7)}_XX";
      await discardPile(customNickname: nickname);
    } else if (hand.length < 6) {
      _forceToFinishTurn = true;
      await drawFromDeck(customNickname: nickname);
      _forceToFinishTurn = false;
    }  
  }

  // --- Card Distribution and Animation ---

  // Deals cards to all players with sequential animations.
  Future<void> _distributeCardsSequentially(List players) async {
    const cardsPerPlayer = 6;
    const cardDelay = Duration(milliseconds: 250);

    // [Host-only] Pre-draw all cards to avoid multiple DB reads.
    List<List<String>> playerCards = List.generate(players.length, (_) => []);
    if (isHost) {
      final totalCards = players.length * cardsPerPlayer;
      final drawnCards = await _deckController.getCardsFromDeck(totalCards);
      if (drawnCards != null) {
        for (int i = 0; i < totalCards; i++) {
          playerCards[i % players.length].add(drawnCards[i]);
        }
      }
    }

    // Animate and assign cards round-robin style.
    for (int round = 0; round < cardsPerPlayer; round++) {
      for (int i = 0; i < players.length; i++) {
        // await giveCardAnimation(targetPlayerIndex: i);
        if (isHost && playerCards[i].length > round) {
          await _giveSingleCard(i, playerCards[i][round]);
        }
        await Future.delayed(cardDelay);
      }
    }
  }

  // [Host-only] Assigns a single card to a player's hand in the database.
  Future<void> _giveSingleCard(int playerIndex, String card) async {
    final session = await getSessionData();
    if (session == null || _isDisposed) return;
    
    // Deep Copy
    var players = List<Map<String, dynamic>>.from(
      session.data['players'] as List,
      growable: false,
    );
    
    var playerData = Map<String, dynamic>.from(players[playerIndex]);
    
    var currentHand = List<String>.from(
      playerData['hand'] as List? ?? [],
      growable: true,
    );
    
    AppGlobals.debugPrint('🃏 Giving card "$card" to player $playerIndex (hand was: ${currentHand.length} cards)');
    
    currentHand.add(card);
    playerData['hand'] = currentHand;
    players[playerIndex] = playerData;
    
    await _pbService.sessions.update(session.id, body: {'players': players});
    
    AppGlobals.debugPrint('✅ Player $playerIndex now has ${currentHand.length} cards');
  }

  // --- UI and Widget Helpers ---

  Widget _buildStaticCardWidget({
    required String cardName,
    required bool isBack,
    required String uniqueId,
    double elevation = 1.1
  }) {
    return Container(
      width: 45,
      height: 65,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: (!isBack) ? [
          // Ambient shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15 * elevation),
            blurRadius: 20 * elevation,
            spreadRadius: 2 * elevation,
            offset: const Offset(0, 10),
          ),
          
          // Mid-tone shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2 * elevation),
            blurRadius: 10 * elevation,
            spreadRadius: 1 * elevation,
            offset: Offset(3 * elevation, 6 * elevation),
          ),
          
          // Contact shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35 * elevation),
            blurRadius: 4 * elevation,
            spreadRadius: 0.5 * elevation,
            offset: Offset(1 * elevation, 3 * elevation),
          ),
        ] : [],
      ),
      child: Image.asset(
        isBack 
          ? 'assets/images/cards/back.png'
          : 'assets/images/cards/$cardName.png',
        fit: BoxFit.cover,
      ),
    );
  }

  // Generates a list of the whole deck
  List<Widget> _buildDeckWidgets(List deck, {bool animate = true}) {
    final List<Widget> widgets = [];
    double offsetY = 0;
    
    for (int i = 0; i < deck.length; i++) {
      if (_isDisposed) break;
      
      final cardName = deck[i].toString();
      final uniqueId = 'deck_${i}_$cardName';
      
      widgets.add(
        MySafeArea(
          key: ValueKey('deck_$i'),
          child: Align(
            alignment: Alignment.center,
            child: Transform.translate(
              offset: Offset(-40, offsetY),
              child: animate 
                ? TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 100),
                    curve: Curves.easeOut,
                    builder: (context, value, child) => Opacity(opacity: value, child: child),
                    child: _buildStaticCardWidget(cardName: cardName, isBack: true, uniqueId: uniqueId),
                  )
                : _buildStaticCardWidget(cardName: cardName, isBack: true, uniqueId: uniqueId),
            ),
          )
        )
      );
      offsetY -= 0.08;
    }
    
    return widgets;
  }

  // Generates a list of the last discard pile card
  List<Widget> _buildDiscardWidgets(List discard, {bool animate = true}) {
    if (discard.isEmpty) return [];
    
    final List<Widget> widgets = [];
    
    final topDiscard = discard.last;
    final uniqueId = 'discard_${discard.length - 1}_$topDiscard';
    
    widgets.add(
      MySafeArea(
        key: ValueKey('discard_0'),
        child: Align(
          alignment: Alignment.center,
          child: Transform.translate(
            offset: const Offset(40, -1),
            child: animate
              ? TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOut,
                  builder: (context, value, child) => Opacity(opacity: value, child: child),
                  child: _buildStaticCardWidget(cardName: topDiscard.toString(), isBack: false, uniqueId: uniqueId),
                )
              : _buildStaticCardWidget(cardName: topDiscard.toString(), isBack: false, uniqueId: uniqueId),
          ),
        )
      )
    );
    
    return widgets;
  }

  // Displays the local player's hand with fanned card widgets.
  List<Widget> _buildPlayerCards(List playerHand, {bool animate = true}) {
    final List<Widget> widgets = [];
    double offsetX = -100;
    for (int i = 0; i < playerHand.length; i++) {
      final card = playerHand[i];
      final uniqueId = 'hand_${i}_$card';
      
      widgets.add(
        MySafeArea(
          key: ValueKey('hand_$i'),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Transform.translate(
              offset: Offset(offsetX, 0),
              child: animate
                ? TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 80 + (i * 20)),
                    curve: Curves.easeOut,
                    builder: (context, value, child) => Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: Opacity(opacity: value, child: child),
                    ),
                    child: TappableCard(
                      cardWidget: _buildStaticCardWidget(cardName: card, isBack: false, uniqueId: uniqueId, elevation: 1.0),
                      cardId: uniqueId,
                      selectedCardNotifier: selectedCardNotifier,
                    ),
                  )
                : TappableCard(
                    cardWidget: _buildStaticCardWidget(cardName: card, isBack: false, uniqueId: uniqueId, elevation: 1.0),
                    cardId: uniqueId,
                    selectedCardNotifier: selectedCardNotifier,
                  ),
            )
          )
        )
      );
      offsetX += 40;
    }
    
    return widgets;
  }
   
  Widget _createPlayerRun(List run, {bool animate = true}) {
    const double overlapAmount = 15.0;
    
    List<Widget> cards = [
      for (int i = 0; i < run.length; i++)
        Positioned(
          left: i * overlapAmount.toDouble(),
          child: _buildStaticCardWidget(
            cardName: run[i]['card'],
            isBack: false,
            uniqueId: 'run_${i}_XX',
            elevation: 1.0,
          ),
        ),
    ];
    
    if (animate) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.8 + (0.2 * value),
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: cards,
        ),
      );
    }
    
    return Stack(
      clipBehavior: Clip.none,
      children: cards,
    );
  }

  List<Widget> _buildPlayersRuns(List players, {bool animate = true}) {
    final widgets = <Widget>[];

    final myIndex = players.indexWhere((p) => p['nickname'] == currentUserNickname);
    final orderedPlayers = [...players.sublist(myIndex), ...players.sublist(0, myIndex)];

    Widget buildRun({
      required Alignment alignment,
      required Offset offset,
      required List run,
      double rotation = 0,
    }) {
      Widget child = Transform.translate(
        offset: offset,
        child: SizedBox(
          width: 240,
          height: 100,
          child: _createPlayerRun(run, animate: animate),
        ),
      );

      if (rotation != 0) {
        child = Transform.rotate(
          angle: rotation * pi / 180,
          child: child,
        );
      }

      return MySafeArea(
        child: Align(
          alignment: alignment,
          child: child,
        ),
      );
    }

    final myRuns = orderedPlayers[0]['completedScales'];

    if (myRuns.length == 1) {
      widgets.add(buildRun(
        alignment: Alignment.bottomCenter,
        offset: Offset(0, -40),
        run: myRuns[0],
      ));
    } else {
      widgets.addAll([
        buildRun(
          alignment: Alignment.bottomCenter,
          offset: Offset(-130, -40),
          run: myRuns[0],
        ),
        buildRun(
          alignment: Alignment.bottomCenter,
          offset: Offset(130, -40),
          run: myRuns[1],
        ),
      ]);
    }

    switch (players.length) {
      case 2:
        final runs = orderedPlayers[1]['completedScales'];

        if (runs.length == 1) {
          widgets.add(buildRun(
            alignment: Alignment.topCenter,
            offset: Offset(0, 70),
            run: runs[0],
          ));
        } else {
          widgets.addAll([
            buildRun(
              alignment: Alignment.topCenter,
              offset: Offset(-130, 70),
              run: runs[0],
            ),
            buildRun(
              alignment: Alignment.topCenter,
              offset: Offset(130, 70),
              run: runs[1],
            ),
          ]);
        }
        break;

      case 3:
        widgets.addAll([
          buildRun(
            alignment: Alignment.centerLeft,
            offset: Offset(0, 115),
            run: orderedPlayers[1]['completedScales'][0],
            rotation: -90,
          ),
          buildRun(
            alignment: Alignment.centerRight,
            offset: Offset(0, 115),
            run: orderedPlayers[2]['completedScales'][0],
            rotation: 90,
          ),
        ]);
        break;

      case 4:
        widgets.addAll([
          buildRun(
            alignment: Alignment.centerLeft,
            offset: Offset(0, 115),
            run: orderedPlayers[1]['completedScales'][0],
            rotation: -90,
          ),
          buildRun(
            alignment: Alignment.topCenter,
            offset: Offset(0, 70),
            run: orderedPlayers[2]['completedScales'][0],
          ),
          buildRun(
            alignment: Alignment.centerRight,
            offset: Offset(0, 115),
            run: orderedPlayers[3]['completedScales'][0],
            rotation: 90,
          ),
        ]);
        break;
    }

    return widgets;
  }

  Future<void> refreshAllCardsOnTable({
    bool? runs_change,
    bool? deck_change,
    bool? discard_change,
    bool? cards_change,
  }) async {
    if (_isDisposed) return;
    
    final session = await getSessionData();
    if (_isDisposed || session == null) return;
    
    // Extract data from session
    final deck = session.data['deck'] as List? ?? [];
    final discard = session.data['discardPile'] as List? ?? [];
    final players = session.data['players'] as List? ?? [];

    final playerHand = players.firstWhere(
      (p) => p['nickname'] == currentUserNickname, 
      orElse: () => null
      )['hand'] as List? ?? [];

    AppGlobals.debugPrint('🔄 Refreshing cards: deck=${deck.length}, discard=${discard.length}, playerHand=${playerHand.length}');
    
    // Reset card selection
    selectedCardNotifier.value = null;
    
    // Build a new list from scratch
    final List<Widget> runs_ = [];
    final List<Widget> deck_ = [];
    final List<Widget> discard_ = [];
    final List<Widget> cards_ = [];
        
    // Always rebuild with animations
    if (runs_change == true) runs_.addAll(_buildPlayersRuns(players, animate: true));
    if (deck_change == true) deck_.addAll(_buildDeckWidgets(deck, animate: true));
    if (discard_change == true) discard_.addAll(_buildDiscardWidgets(discard, animate: true));
    if (cards_change == true) cards_.addAll(_buildPlayerCards(playerHand, animate: true));
    
    // Update state
    if (!_isDisposed) {
      if (runs_change == true) {
        _runs.forEach(removeMovableWidget);
        runs_.forEach(addMovableWidget);
        _runs = runs_;
      }
      if (deck_change == true) {
        _deck.forEach(removeMovableWidget);
        deck_.forEach(addMovableWidget);
        _deck = deck_;
      }
      if (discard_change == true) {
        _discard.forEach(removeMovableWidget);
        discard_.forEach(addMovableWidget);
        _discard = discard_;
      }
      if (cards_change == true) {
        _cards.forEach(removeMovableWidget);
        cards_.forEach(addMovableWidget);
        _cards = cards_;
      }
      AppGlobals.debugPrint('✅ Widgets have been refreshed');
    }
  }

  // ------- Game Logic --------

  // Function that manages the Discard Pile, it allows the user to discard cards and draw cards from the Discard Pile
  Future<int> discardPile({
      String? customNickname
    }) async {
    if (_isDisposed) return 1;
    
    final session = await getSessionData();
    if (_isDisposed || session == null) return 1;

    final String nick = customNickname ?? currentUserNickname;

    final players = session.data['players'] as List? ?? [];

    if (selectedCardNotifier.value != null) {
      final uniqueId = selectedCardNotifier.value!.split("_");
      if (uniqueId.length == 3 && uniqueId[0] == "hand") {
        for (int i=0; i<players.length; i++) {
          if (players[i]['nickname'] == nick) {
            if (players[i]['hand'].length == 7) {
              final String cardToDiscard = players[i]['hand'].removeAt(int.parse(uniqueId[1]));
              await _pbService.sessions.update(session.id, body: {'players': players, 'lastAction': {
                'player': nick,
                'action': 'discardedCard',
                'timestamp': DateTime.now().toIso8601String()
              }});
              await _deckController.discardCard(cardToDiscard);
              cardDragNotifier.value = CardDragType.handToDiscard;
              lastActionNotifier.value = GameAction.discard;
              await requestEndTurnFireAndForget();
              return 0;
            }
            return 4;
          }
        }
        return 5;
      }
    } else {
      if (session.data['lastAction']['player'] == nick) return 6;
      final List discardPile = session.data['discardPile'];
      if (discardPile.isEmpty) return 7;
      final String drawedCard = discardPile.removeLast();
      for (int i=0; i<players.length; i++) {
        if (players[i]['nickname'] == nick) {
          players[i]['hand'].add(drawedCard);
          await _pbService.sessions.update(session.id, body: {'players': players, 'discardPile': discardPile, 
              'lastAction': {
                'player': nick,
                'action': 'drawFromDiscardPile',
                'timestamp': DateTime.now().toIso8601String()
              },
              'playerShift': {
                'iPlayer': i,
                'lastActionTimestamp': DateTime.now().toIso8601String()
              }});
          cardDragNotifier.value = CardDragType.deckToHand;
          lastActionNotifier.value = GameAction.drawFromDiscard;
          return 0;
        }
      }
      return 3;
    }
    return 5;
  }

  // Function that manages the Deck, it allows the user to draw cards from the Deck
  Future<int> drawFromDeck({
      String? customNickname
    }) async {
    if (_isDisposed) return 1;
    
    final session = await getSessionData();
    if (_isDisposed || session == null) return 1;

    final String nick = customNickname ?? currentUserNickname;

    final players = session.data['players'] as List? ?? [];

    // Variable used to determine whether the user must draw a card and the deck has exactly one card left. 
    // If so, after drawing it, it will be swapped with the discard pile.
    bool inverse = false;

    for (int i=0; i<players.length; i++) {
      if (players[i]['nickname'] == nick) {
        final num cardsToDraw = (_forceToFinishTurn ? 6 : 7) - players[i]['hand'].length;
        if(cardsToDraw == 0) return 3;
        if (cardsToDraw == 1) {
          if (session.data['lastAction']['player'] == nick && !_forceToFinishTurn) return 3;
          if (List<String>.from(session.data['deck'] ?? []).length == 1) {
            inverse = true;
          }
        }
        List<String>? cardsToAdd = await _deckController.getCardsFromDeck(cardsToDraw as int);
        if(cardsToAdd == null) {
          int maxNCards = List<String>.from(session.data['deck'] ?? []).length;
          cardsToAdd = await _deckController.getCardsFromDeck(maxNCards);
          if (cardsToAdd == null) return 1;
          await _deckController.invertDeckDiscard();
          cardsToAdd.addAll([...?(await _deckController.getCardsFromDeck(cardsToDraw-maxNCards))]);
        }
        if (inverse) await _deckController.invertDeckDiscard();
        players[i]['hand'].addAll(cardsToAdd);
        await _pbService.sessions.update(session.id, body: {'players': players, 
              'lastAction': {
                'player': nick,
                'action': 'drawFromDeck',
                'timestamp': DateTime.now().toIso8601String()
              },
              'playerShift': {
                'iPlayer': i,
                'lastActionTimestamp': DateTime.now().toIso8601String()
              }});
        cardDragNotifier.value = CardDragType.deckToHand;
        lastActionNotifier.value = GameAction.drawFromDeck;
        return 0;
      }
    }
    return 4;
  }

  Map<String, String> _parseCard({required String card, String? value, String? suit}) {
    return {"value": value ?? card[0], "suit": suit ?? card[1], "card": card};
  }

  bool _isCardMissing(List run, String card) {
    if (run.length == 14) return false;

    final parsed = card == "JOLLY" ? null : _parseCard(card: card);
    final value = parsed?['value'];
    final suit = parsed?['suit'];

    if (run.isEmpty) {
      return card == "JOLLY" || value == "A";
    }

    if (card != "JOLLY" && run.first['suit'] != suit) return false;

    if (run.length == 1) {
      return card == "JOLLY" || value == "2" || value == "K";
    }

    final asc = ["A","2","3","4","5","6","7","8","9","0","J","Q","K"];
    final desc = ["A","K","Q","J","0","9","8","7","6","5","4","3","2"];
    final order = run[1]['value'] == "2" ? asc : desc;

    final next = order[(order.indexOf(run.last['value']) + 1) % order.length];

    return card == "JOLLY" || value == next;
  }

  int _isAnyJollyReplaceable(List run, String card) {
    if (card == "JOLLY") return -1;
    for (int i=0; i<run.length; i++) {
      final c = run[i];
        if (
          c['card'].startsWith("JOLLY") &&
          c['value'] == _parseCard(card: card)['value'] &&
          c['suit'] == _parseCard(card: card)['suit']
          ) return i;
    }
    return -1;
  }

  Future<String?> _showChoiceDialog({
    required BuildContext context,
    required RecordModel session,
    required String title,
    required List<String> values,
    required Widget Function(String value) builder,
    int columns = 2,
  }) {
    final completer = Completer<String?>();

    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (getRemainingTimeFromSession(session) <= 1) {
        if (!completer.isCompleted) {
          completer.complete(null);
          Navigator.of(context, rootNavigator: true).pop();
        }
        timer.cancel();
      }
    });

    showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color.fromARGB(255, 59, 53, 22),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 20),
              ...List.generate((values.length / columns).ceil(), (row) {
                return Row(
                  children: List.generate(columns, (col) {
                    final index = row * columns + col;
                    if (index >= values.length) return const Expanded(child: SizedBox());

                    final value = values[index];

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: ElevatedButton(
                          onPressed: () {
                            if (!completer.isCompleted) {
                              completer.complete(value);
                              Navigator.pop(context, value);
                            }
                          },
                          child: builder(value),
                        ),
                      ),
                    );
                  }),
                );
              })
            ],
          ),
        );
      },
    );

    return completer.future;
  }

  Future<int> _layOffManager(BuildContext context, RecordModel session, int numberOfRun, String card, List players, int currentUserPos, String target, bool canLayOff) async {
    for (var p in players) {
      if (p['nickname'] == target) {
        int res = _isAnyJollyReplaceable(p['completedScales'][numberOfRun], card);
        if (res != -1) {
          p['completedScales'][numberOfRun][res]['card'] = card;
          players[currentUserPos]['hand'].add("JOLLY");
          return 0;
        }
        if (canLayOff && _isCardMissing(p['completedScales'][numberOfRun], card)) {
          var cardToAdd = _parseCard(card: card);
          // Check if is there any other run with the same suit
          if (p['completedScales'][numberOfRun].isEmpty) {
            for (var p_ in players) {
              if (p_['completedScales'].any((run) => run.isNotEmpty && run.first['suit'] == cardToAdd['suit'])) return 7;
            }
          }
          if (card != "JOLLY") {
            p['completedScales'][numberOfRun].add(cardToAdd);
            return 0;
          } else {
            if (p['completedScales'][numberOfRun].length >= 2) {
              // Take the suit of the run
              final suit = p['completedScales'][numberOfRun].first['suit'];

              // Take the value of next card needed
              final asc = ["A","2","3","4","5","6","7","8","9","0","J","Q","K"];
              final desc = ["A","K","Q","J","0","9","8","7","6","5","4","3","2"];
              final order = p['completedScales'][numberOfRun][1]['value'] == "2" ? asc : desc;

              final next = order[(order.indexOf(p['completedScales'][numberOfRun].last['value']) + 1) % order.length];

              cardToAdd = _parseCard(card: card, value: next, suit: suit);
              p['completedScales'][numberOfRun].add(cardToAdd);
              return 0;
            } else if (p['completedScales'][numberOfRun].isEmpty) {
              // Choose the joker's suit
              final selectedSuit = await _showChoiceDialog(
                context: context,
                session: session,
                title: "Che seme dovrà assumere il Jolly?",
                values: ["S", "H", "D", "C"],
                builder: (v) => Image.asset("assets/images/$v.png", height: 40),
              );
              if (selectedSuit == null) return 4;

              for (var p_ in players) {
                if (p_['completedScales'].any((run) => run.isNotEmpty && run.first['suit'] == selectedSuit)) return 7;
              }

              p['completedScales'][numberOfRun].add(_parseCard(card: "${card}_$selectedSuit", suit: selectedSuit, value: "A"));

              return 0;
            } else {
              // Choose whether the Joker will be 2 or K
              final String runSuit = p['completedScales'][numberOfRun].first['suit'];
              final selectedValue = await _showChoiceDialog(
                context: context,
                session: session,
                title: "Che valore dovrà assumere il Jolly?",
                values: ["2", "K"],
                builder: (v) => Image.asset("assets/images/cards/$v$runSuit.png", height: 65),
              );

              if (selectedValue == null) return 4;

              p['completedScales'][numberOfRun].add(_parseCard(card: "${card}_$selectedValue", suit: runSuit, value: selectedValue));

              return 0;
            }
          }
        }
        return 4;
      }
    }
    return 5;
  }

  // Function that manages all lay off
  Future<int> layOff(BuildContext context, String direction) async {
    if (_isDisposed) return 1;
    
    final session = await getSessionData();
    if (_isDisposed || session == null) return 1;

    final players = session.data['players'] as List? ?? [];

    if (selectedCardNotifier.value == null) return 3;

    int currentUserPosition = players.indexWhere((p) => p['nickname'] == currentUserNickname);

    int? nRun;

    if (direction.contains("|")) {
      nRun = int.parse(direction.split("|")[1]);
      direction = direction.split("|")[0];
    }

    String? nicknameTarget = direction == "bottom" ? currentUserNickname : null;

    if (nicknameTarget == null) {
      switch (session.data['nPlayers']) {
        case 2:
          nicknameTarget = players[(currentUserPosition - 1 + players.length) % players.length]['nickname'];
          break;
        case 3:
          switch (direction) {
            case "left":
              nicknameTarget = players[(currentUserPosition + 1 + players.length) % players.length]['nickname'];
              break;
            case "right":
              nicknameTarget = players[(currentUserPosition - 1 + players.length) % players.length]['nickname'];
              break;
          }
          break;
        case 4:
          switch (direction) {
            case "left":
              nicknameTarget = players[(currentUserPosition + 1 + players.length) % players.length]['nickname'];
              break;
            case "top":
              nicknameTarget = players[(currentUserPosition - 2 + players.length) % players.length]['nickname'];
              break;
            case "right":
              nicknameTarget = players[(currentUserPosition - 1 + players.length) % players.length]['nickname'];
              break;
          }
          break;
      }
    }

    if (nicknameTarget == null) return 1;

    int cardIndex = int.parse(selectedCardNotifier.value!.split("_")[1]);
    final String cardToLayOff = players[currentUserPosition]['hand'].removeAt(cardIndex);

    int res = await _layOffManager(
      context,
      session,
      nRun ?? 0,
      cardToLayOff, 
      players, 
      currentUserPosition,
      nicknameTarget, 
      direction == "bottom" || (session.data['gameSettings']['squads'] && (direction == "top"))
    );

    if (res == 0) {
      await _pbService.sessions.update(session.id, body: {'players': players, 
        'lastAction': {
          'player': currentUserNickname,
          'action': 'layedOff',
          'timestamp': DateTime.now().toIso8601String()
        },
        'playerShift': {
          'iPlayer': currentUserPosition,
          'lastActionTimestamp': DateTime.now().toIso8601String()
        }});
      cardDragNotifier.value = CardDragType.handToRun;
      lastActionNotifier.value = GameAction.layOff;
    }

    final res1 = await _checkWin();
    if (res1 != null) {
      for (var p in players) {
        if (res1['winners']!.contains(p['nickname'])) {
          p['won'] = true;
        } else {
          p['won'] = false;
        }
      }
      await _pbService.sessions.update(session.id, body: {'status': 'ended', 'players': players});
    }

    return res;
  }

  // Helper function that find winners if there are
  Future<Map<String, List<String>>?> _checkWin() async {
    if (_isDisposed) return null;

    final session = await getSessionData();
    if (_isDisposed || session == null) return null;

    final players = session.data['players'];
    final squads = session.data['gameSettings']['squads'] ?? false;

    bool hasCompletedScales(player) =>
        player['completedScales'].every((run) => run.length == 14);

    // Mode Squads (only with 4 players)
    if (players.length == 4 && squads) {
      for (int teamStart = 0; teamStart < 2; teamStart++) {
        final winners = <String>[];

        for (int i = teamStart; i < players.length; i += 2) {
          final player = players[i];
          if (hasCompletedScales(player)) {
            winners.add(player['nickname']);
          }
        }

        if (winners.length == 2) {
          return {"winners": winners};
        }
      }
      return null;
    }

    // Mode Normal
    for (final player in players) {
      if (hasCompletedScales(player)) {
        return {
          "winners": [player['nickname']]
        };
      }
    }

    return null;
  }

  // Creates and positions the visual turn timer for the active player.
  Widget? drawTimer(RecordModel session) {
    final playerShift = session.data['playerShift'] as Map<String, dynamic>?;
    if (playerShift == null) return null;

    final players = session.data['players'] as List;
    final currentTurnIndex = playerShift['iPlayer'] as int;
    final myIndex = players.indexWhere((p) => p['nickname'] == currentUserNickname);
    if (myIndex == -1) return null;

    final relativeIndex = (currentTurnIndex - myIndex + players.length) % players.length;

    final timerPositions = {
      2: {0: _bottomTimer, 1: _topTimer},
      3: {0: _bottomTimer, 1: _leftTimer, 2: _rightTimer},
      4: {0: _bottomTimer, 1: _leftTimer, 2: _topTimer, 3: _rightTimer},
    };

    return timerPositions[players.length]?[relativeIndex]?.call();
  }

  Widget _bottomTimer() => _buildTimerWidget(Alignment.bottomCenter, const Offset(-170, 0), 60, 60);
  Widget _leftTimer() => _buildTimerWidget(Alignment.centerLeft, const Offset(8, 0), 160, 60);
  Widget _topTimer() => _buildTimerWidget(Alignment.topCenter, const Offset(0, 0), 160, 60);
  Widget _rightTimer() => _buildTimerWidget(Alignment.centerRight, const Offset(-8, 0), 160, 60);

  Widget _buildTimerWidget(Alignment alignment, Offset offset, double w, double h) {
    return MySafeArea(
      child: Align(
        alignment: alignment,
        child: Transform.translate(
          offset: offset,
          child: SizedBox(
            width: w, height: h,
            child: ValueListenableBuilder<double>(
              valueListenable: progressNotifier,
              builder: (_, progress, __) => CustomPaint(painter: BorderLineTimerPainter(progress: progress)),
            ),
          ),
        ),
      )
    );
  }

  // --- Utility and State Management ---

  // Fetches the current session record from PocketBase.
  Future<RecordModel?> getSessionData() async {
    try {
      return await _pbService.getSessionByCode(sessionCode);
    } catch (e) {
      AppGlobals.debugPrint('Error in getSessionData: $e');
      return null;
    }
  }

  // Extracts the turn duration from session settings with safe fallbacks.
  int _getTurnDurationFromSettings(RecordModel session) {
    final settings = session.data['gameSettings'] as Map<String, dynamic>?;
    final duration = settings?['playerMoveDurationInSecs'];
    if (duration is int) return duration;
    if (duration is String) return int.tryParse(duration) ?? 30;
    return 30;
  }

  // Calculates the remaining time for the current turn.
  int getRemainingTimeFromSession(RecordModel session) {
    final moveDuration = _getTurnDurationFromSettings(session);
    final playerShift = session.data['playerShift'] as Map<String, dynamic>?;
    final lastActionStr = playerShift?['lastActionTimestamp'] as String?;
    if (lastActionStr == null) return moveDuration;

    try {
      final lastAction = DateTime.parse(lastActionStr);
      final elapsed = DateTime.now().difference(lastAction).inSeconds;
      return (moveDuration - elapsed).clamp(0, moveDuration);
    } catch (e) {
      return moveDuration;
    }
  }

  // Adds a movable widget to the screen.
  void addMovableWidget(Widget widget) {
    if (!_isDisposed) {
      movableWidgets.value = [...movableWidgets.value, widget];
    }
  }

  // Removes a movable widget from the screen.
  void removeMovableWidget(Widget widget) {
    if (!_isDisposed) {
      movableWidgets.value = List.from(movableWidgets.value)..remove(widget);
    }
  }

  // Adds a timer widget to the screen, clearing any existing ones.
  void addTimer(Widget timer) {
    clearTimers();
    _activeTimers.add(timer);
    addMovableWidget(timer);
  }

  // Clears all active timer widgets from the screen.
  void clearTimers() {
    _activeTimers.forEach(removeMovableWidget);
    _activeTimers.clear();
  }

  // Releases all resources used by the controller.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _turnTimeoutTimer?.cancel();
    _animationTimer?.cancel();
    progressNotifier.dispose();
    movableWidgets.dispose();
    selectedCardNotifier.dispose();
    lastActionNotifier.dispose();
    cardDragNotifier.dispose();
    AppGlobals.debugPrint('GameController disposed.');
  }
}
