import 'package:assoasso_app/core/app_globals.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../controllers/game_controller.dart';
import '../core/app_router.dart';
import '../services/pocketbase_service.dart';
import '../widgets/action_button.dart';
import '../widgets/universal_safearea.dart';
import '../widgets/dialogs.dart';

// The main screen where the card game is played.
class GameScreen extends StatefulWidget {
  final String code;
  final String currentUserNickname;
  final String lobbyHostNickname;

  const GameScreen({
    super.key,
    required this.code,
    required this.currentUserNickname,
    required this.lobbyHostNickname,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final PocketBaseService _pbService = PocketBaseService();
  late final GameController _gameController;
  UnsubscribeFunc? _unsubscribeFn;
  RecordModel? _session;
  bool _isMyTurn = false;

  @override
  void initState() {
    super.initState();
    final isHost = widget.currentUserNickname == widget.lobbyHostNickname;
    _gameController = GameController(widget.code, widget.currentUserNickname, isHost);
    _initializeGame();
  }

  // Initializes the game state and subscribes to real-time updates.
  Future<void> _initializeGame() async {
    final initialSession = await _pbService.getSessionByCode(widget.code);
    if (initialSession == null) {
      _navigateHome('La partita non è più disponibile.');
      return;
    }

    _updateStateFromSession(initialSession);
    
    _gameController.startGame();

    _unsubscribeFn = await _pbService.sessions.subscribe(initialSession.id, (event) {
      if (!mounted) return;
      
      if (event.action == 'delete') {
        _navigateHome('La partita è terminata.');
        return;
      }
      
      if (event.record != null) {
        _onSessionUpdate(event.record);
      }
    });
  }

  // Callback for handling real-time session updates.
  void _onSessionUpdate(RecordModel? session) {
    if (session == null) {
      _navigateHome('La partita è terminata.');
      return;
    }

    if (session.data['status'] == 'ended') {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRouter.endgame,
          (route) => false,
          arguments: {'currentUserNickname': widget.currentUserNickname, 'players': session.data['players']},
        );
      }
      return;
    }

    // Detect any changes on Deck, Discard Pile and Player Hand
    final oldDeck = _session?.data['deck'];
    final oldDiscard = _session?.data['discardPile'];
    final oldPlayerHand = _session?.data['players'].firstWhere(
      (p) => p['nickname'] == widget.currentUserNickname, orElse: () => null
      )['hand'];

    final newDeck = session.data['deck'];
    final newDiscard = session.data['discardPile'];
    final newPlayerHand = session.data['players'].firstWhere(
      (p) => p['nickname'] == widget.currentUserNickname, orElse: () => null
      )['hand'];
    
    final deckChanged = oldDeck != newDeck;
    final discardChanged = oldDiscard != newDiscard;
    final playerHandChanged = oldPlayerHand != newPlayerHand;
    bool runsChanged = false;

    for (int i=0; i<session.data['nPlayers']; i++) {
      if (_session?.data['players'][i]['completedScales'].toString() != session.data['players'][i]['completedScales'].toString()){
        runsChanged = true;
        break;
      }
    }

    _updateStateFromSession(session);
    _gameController.syncTurnTimer(session);

    // Refresh Deck, Discard Pile and Player Hand
    if (deckChanged || discardChanged || playerHandChanged || runsChanged) {
      _gameController.refreshAllCardsOnTable(
        deck_change: deckChanged,
        runs_change: runsChanged,
        cards_change: playerHandChanged,
        discard_change: discardChanged
      );
    }

    final timerWidget = _gameController.drawTimer(session);
    if (timerWidget != null) {
      _gameController.addTimer(timerWidget);
    }
  }

  // Updates the local state based on the session data.
  void _updateStateFromSession(RecordModel session) {
    if (mounted) {
      setState(() {
        _session = session;
        _isMyTurn = _checkIfMyTurn(session);
      });
    }
  }

  bool _checkIfMyTurn(RecordModel session) {
    final playerShift = session.data['playerShift'] as Map<String, dynamic>?;
    if (playerShift == null) return false;

    final players = session.data['players'] as List;
    final currentTurnIndex = playerShift['iPlayer'] as int?;
    final myIndex = players.indexWhere((p) => p['nickname'] == widget.currentUserNickname);

    return currentTurnIndex != null && myIndex != -1 && currentTurnIndex == myIndex;
  }

  @override
  void dispose() {
    _unsubscribeFn?.call();
    _gameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          child: GestureDetector(
            onTap: () => _gameController.clearSelectedCardNotifier(),
            child: Stack(
              children: [
                if (_session != null) _buildGameUI(),
                ValueListenableBuilder<List<Widget>>(
                  valueListenable: _gameController.movableWidgets,
                  builder: (context, widgets, child) {
                    return Stack(children: widgets);
                  },
                ),
                if (_session != null) ..._buildInteractiveButtons(),
                if (_session != null) _buildActionFeedback(),
                if (_session == null) const Center(child: CircularProgressIndicator()),
              ],
            )
          ),
        ),
      )
    );
  }

  Widget _buildGameUI() {
    return MySafeArea(
      child: Stack(
        children: [
          ..._buildPlayerAvatars(),
          _buildTopBar(),
          _buildBottomBar(),
          ..._buildCardsSlots(),

          if (_isMyTurn)
            const Align(
              alignment: Alignment.topCenter,
              child: _PulsingTurnIndicator(),
            ),
          
          _buildCardDragAnimation(),
        ],
      )
    );
  }
  
  Widget _buildCardDragAnimation() {
    return ValueListenableBuilder<CardDragType?>(
      valueListenable: _gameController.cardDragNotifier,
      builder: (context, dragType, child) {
        if (dragType == null) return const SizedBox.shrink();
        
        return _CardDragAnimationWidget(
          dragType: dragType,
          onComplete: () {
            _gameController.cardDragNotifier.value = null;
          },
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ActionButton(label: 'Esci', onPressed: _leaveGameModal, backgroundColor: Colors.red.shade400),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ActionButton(label: 'Termina', onPressed: _isMyTurn ? () => _gameController.requestEndTurnFireAndForget() : () {}, 
          backgroundColor: !_isMyTurn ? Colors.grey : Color.fromARGB(199, 71, 255, 169)),
      ),
    );
  }

  Widget _buildActionFeedback() {
    return ValueListenableBuilder<GameAction?>(
      valueListenable: _gameController.lastActionNotifier,
      builder: (context, action, child) {
        if (action == null) return const SizedBox.shrink();
        
        String message;
        Color color;
        IconData icon;
        
        switch (action) {
          case GameAction.drawFromDeck:
            message = '+ Carta dal mazzo';
            color = Colors.blue;
            icon = Icons.add;
            break;
          case GameAction.drawFromDiscard:
            message = '+ Carta dagli scarti';
            color = Colors.purple;
            icon = Icons.add;
            break;
          case GameAction.discard:
            message = 'Carta scartata';
            color = Colors.red;
            icon = Icons.remove;
            break;
          case GameAction.layOff:
            message = 'Carta attaccata!';
            color = Colors.green;
            icon = Icons.check_circle;
            break;
        }
        
        return _ActionFeedbackWidget(
          message: message,
          color: color,
          icon: icon,
          onComplete: () {
            _gameController.lastActionNotifier.value = null;
          },
        );
      },
    );
  }

  List<Widget> _buildPlayerAvatars() {
    if (_session == null) return [];
    final players = List<Map<String, dynamic>>.from(_session!.data['players']);
    final myIndex = players.indexWhere((p) => p['nickname'] == widget.currentUserNickname);
    if (myIndex == -1) return [];

    // Reorder players so the current user is always at the bottom
    final orderedPlayers = [...players.sublist(myIndex), ...players.sublist(0, myIndex)];

    final positions = {
      2: [Alignment.bottomCenter, Alignment.topCenter],
      3: [Alignment.bottomCenter, Alignment.centerLeft, Alignment.centerRight],
      4: [Alignment.bottomCenter, Alignment.centerLeft, Alignment.topCenter, Alignment.centerRight],
    };

    return List.generate(orderedPlayers.length, (index) {
      final player = orderedPlayers[index];
      final alignment = positions[orderedPlayers.length]![index];
      return AnimatedPlayerEntry(
        index: index,
        child: Align(
          alignment: alignment,
          child: index == 0 ? 
            Transform.translate(
              offset: const Offset(-170, 0), 
              child: _buildPlayerWidget(player, alignment, index)) : 
            _buildPlayerWidget(player, alignment, index),
        ),
      );
    });
  }

  Widget _buildPlayerWidget(Map<String, dynamic> player, Alignment alignment, int index) {
    return Container(
      margin: const EdgeInsets.only(left: 8, right: 8),
      padding: const EdgeInsets.all(8),
      width: index == 0 ? 56 : 160,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: _playerContent(player, index)),
    );
  }

  List<Widget> _playerContent(Map<String, dynamic> player, int index) {
    return [
      CircleAvatar(backgroundImage: AssetImage(player['avatarPath'] ?? 'assets/images/avatars/avatar_0.png')),
      if(index!=0) Spacer(),
      if(index!=0) Text(player['nickname'], style: const TextStyle(color: Colors.white, fontFamily: 'Open Sans'))
    ];
  }

  // Creates an animated styled card slot placeholder widget with tap feedback.
  Widget _buildAnimatedCardSlot({
    required Alignment alignment,
    required Offset offset,
    required double w,
    required double h,
    VoidCallback? onTap,
    bool? isTransparent,
  }) {
    return _AnimatedCardSlot(
      alignment: alignment,
      offset: offset,
      width: w,
      height: h,
      onTap: onTap,
      isTransparent: isTransparent,
    );
  }

  // Creates a styled card slot placeholder widget.
  Widget _buildCardSlot({
    required Alignment alignment,
    required Offset offset,
    required double w,
    required double h,
    VoidCallback? onTap,
    bool? isTransparent,
  }) =>
      MySafeArea(
        child: Align(
          alignment: alignment,
          child: Transform.translate(
            offset: offset,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: onTap,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: w,
                  height: h,
                  decoration: BoxDecoration(
                    color: isTransparent == true ? Colors.transparent : Color.fromARGB(200, 78, 66, 49),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isTransparent == true ? Colors.transparent : Color.fromARGB(100, 255, 255, 255),
                      width: 2,
                    ),
                    boxShadow: isTransparent == true ? [] : [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                )
              ),
            ),
          ),
        )
      );

  List<Widget> _buildCardsSlots() {
    final widgets = <Widget>[];
    widgets.addAll([
      // Deck Slot
      _buildCardSlot(alignment: Alignment.center, offset: const Offset(-40, -1), w: 55, h: 77),

      // Discard Pile Slot
      _buildCardSlot(alignment: Alignment.center, offset: const Offset(40, -1), w: 55, h: 77),
    ]);

    final rows = <String, dynamic>{
      'top': _buildCardSlot(alignment: Alignment.topCenter, offset: const Offset(0, 51), w: 250, h: 75),
      'bottom': _buildCardSlot(alignment: Alignment.bottomCenter, offset: const Offset(0, -54), w: 250, h: 75),
      'left': _buildCardSlot(alignment: Alignment.centerLeft, offset: const Offset(166, 0), w: 75, h: 250),
      'right': _buildCardSlot(alignment: Alignment.centerRight, offset: const Offset(-166, 0), w: 75, h: 250),
      'bottom2': [
        _buildCardSlot(alignment: Alignment.bottomCenter, offset: const Offset(-130, -54), w: 250, h: 75),
        _buildCardSlot(alignment: Alignment.bottomCenter, offset: const Offset(130, -54), w: 250, h: 75)
      ],
      'top2': [
        _buildCardSlot(alignment: Alignment.topCenter, offset: const Offset(-130, 51), w: 250, h: 75),
        _buildCardSlot(alignment: Alignment.topCenter, offset: const Offset(130, 51), w: 250, h: 75)
      ]
    };
    if (_session != null) {
      final nPlayers = _session!.data['nPlayers'] as int;
      final minScales = _session!.data['gameSettings']['minScales'];
      if (minScales == 1){
        widgets.add(rows['bottom']!);
      }
      switch (nPlayers) {
        case 2:
          if (minScales == 1){
            widgets.add(rows['top']!);
          } else {
            widgets.addAll([
              ...rows['bottom2'],
              ...rows['top2']
            ]);
          }
          break;
        case 3:
          widgets.addAll([rows['left']!, rows['right']!]);
          break;
        case 4:
          widgets.addAll([rows['left']!, rows['right']!, rows['top']!]);
          break;
      }
    }
    return widgets;
  }

  List<Widget> _buildInteractiveButtons() {
    final widgets = <Widget>[];
    widgets.addAll([
      // Deck Slot
      _buildAnimatedCardSlot(alignment: Alignment.center, offset: const Offset(-40, -1), w: 55, h: 77, onTap: drawFromDeck, isTransparent: true),

      // Discard Pile Slot
      _buildAnimatedCardSlot(alignment: Alignment.center, offset: const Offset(40, -1), w: 55, h: 77, onTap: discardPile, isTransparent: true),
    ]);

    final rows = <String, dynamic>{
      'top': _buildAnimatedCardSlot(alignment: Alignment.topCenter, offset: const Offset(0, 65), w: 250, h: 75, onTap: () {_layOff('top');}, isTransparent: true),
      'bottom': _buildAnimatedCardSlot(alignment: Alignment.bottomCenter, offset: const Offset(0, -68), w: 250, h: 75, onTap: () {_layOff('bottom');}, isTransparent: true),
      'left': _buildAnimatedCardSlot(alignment: Alignment.centerLeft, offset: const Offset(180, 0), w: 75, h: 250, onTap: () {_layOff('left');}, isTransparent: true),
      'right': _buildAnimatedCardSlot(alignment: Alignment.centerRight, offset: const Offset(-180, 0), w: 75, h: 250, onTap: () {_layOff('right');}, isTransparent: true),
      'bottom2': [
        _buildAnimatedCardSlot(alignment: Alignment.bottomCenter, offset: const Offset(-130, -68), w: 250, h: 75, onTap: () {_layOff('bottom|0');}, isTransparent: true),
        _buildAnimatedCardSlot(alignment: Alignment.bottomCenter, offset: const Offset(130, -68), w: 250, h: 75, onTap: () {_layOff('bottom|1');}, isTransparent: true)
      ],
      'top2': [
        _buildAnimatedCardSlot(alignment: Alignment.topCenter, offset: const Offset(-130, 65), w: 250, h: 75, onTap: () {_layOff('top|0');}, isTransparent: true),
        _buildAnimatedCardSlot(alignment: Alignment.topCenter, offset: const Offset(130, 65), w: 250, h: 75, onTap: () {_layOff('top|1');}, isTransparent: true)
      ]
    };
    if (_session != null) {
      final nPlayers = _session!.data['nPlayers'] as int;
      final minScales = _session!.data['gameSettings']['minScales'];
      if (minScales == 1){
        widgets.add(rows['bottom']!);
      }
      switch (nPlayers) {
        case 2:
          if (minScales == 1){
            widgets.add(rows['top']!);
          } else {
            widgets.addAll([
              ...rows['bottom2'],
              ...rows['top2']
            ]);
          }
          break;
        case 3:
          widgets.addAll([rows['left']!, rows['right']!]);
          break;
        case 4:
          widgets.addAll([rows['left']!, rows['right']!, rows['top']!]);
          break;
      }
    }
    return widgets;
  }

  Future<void> drawFromDeck() async {
    if(_isMyTurn) {
      switch (await _gameController.drawFromDeck()) {
        case 1:
          _showSnackBar("Errore dell'applicazione");
          break;
        case 3:
          _showSnackBar("Non puoi pescare più carte");
          break;
        case 4:
          // Unreachable
          _showSnackBar("Giocatore non trovato");
          break;
        case 0:
          return;
        default:
          AppGlobals.debugPrint("Unchecked exception");
      }
    }
  }

  Future<void> discardPile() async {
    if(_isMyTurn) {
      switch (await _gameController.discardPile()) {
        case 1:
          _showSnackBar("Errore dell'applicazione");
          break;
        case 3:
          _showSnackBar("Nessuna carta selezionata");
          break;
        case 4:
          _showSnackBar("Non puoi scartare, non hai 7 carte");
          break;
        case 5:
          // Unreachable
          _showSnackBar("Giocatore non trovato");
          break;
        case 6:
          _showSnackBar("Hai già fatto la tua prima mossa");
          break;
        case 7:
          _showSnackBar("La pila degli scarti è vuota");
          break;
        case 0:
          return;
        default:
          AppGlobals.debugPrint("Unchecked exception");
      }
    }
  }

  Future<void> _layOff(String direction) async {
    if(_isMyTurn) {
      switch (await _gameController.layOff(context, direction)) {
        case 1:
          _showSnackBar("Errore dell'applicazione");
          break;
        case 3:
          _showSnackBar("Nessuna carta selezionata");
          break;
        case 4:
          _showSnackBar("Non puoi attaccare questa carta");
          break;
        case 5:
          // Unreachable
          _showSnackBar("Giocatore non trovato");
          break;
        case 6:
          _showSnackBar("Non puoi attaccare carte agli avversari");
          break;
        case 7:
          _showSnackBar("Non puoi creare altre scale di quel segno");
          break;
        case 0:
          return;
        default:
          AppGlobals.debugPrint("Unchecked exception");
      }
    }
  }

  Future<void> _leaveGameModal() async {
    showCustomDialog(context,
      children: [
        Text("Sei sicuro di voler uscire?", 
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Open Sans',
              fontWeight: FontWeight.bold,
              fontSize: 25
          ),
        ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            buildDialogButton(label: 'Si', onPressed: () async {
                Navigator.of(context).pop();
                _leaveGame();
            }),
            buildDialogButton(label: 'No', onPressed: () async {
                Navigator.of(context).pop();
            })
          ],
        )
      ],
    );
  }

  Future<void> _leaveGame() async {
    // Similar logic to leaving the lobby
    if (_session == null) {
      _navigateHome('Sei uscito dalla partita');
      return;
    }
    try {
        await _pbService.sessions.delete(_session!.id);
    } finally {
        _navigateHome('Sei uscito dalla partita');
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
  
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 500),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.black87,
        ),
      );
    }
  }
}

class _AnimatedCardSlot extends StatefulWidget {
  final Alignment alignment;
  final Offset offset;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final bool? isTransparent;

  const _AnimatedCardSlot({
    required this.alignment,
    required this.offset,
    required this.width,
    required this.height,
    this.onTap,
    this.isTransparent,
  });

  @override
  State<_AnimatedCardSlot> createState() => _AnimatedCardSlotState();
}

class _AnimatedCardSlotState extends State<_AnimatedCardSlot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return MySafeArea(
      child: Align(
        alignment: widget.alignment,
        child: Transform.translate(
          offset: widget.offset,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            onTap: widget.onTap,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: widget.width,
                      height: widget.height,
                      decoration: BoxDecoration(
                        color: widget.isTransparent == true 
                            ? Colors.transparent 
                            : Color.fromARGB(200, 78, 66, 49),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: widget.isTransparent == true 
                              ? Colors.transparent 
                              : Color.lerp(
                                  Color.fromARGB(100, 255, 255, 255),
                                  Colors.green.shade300,
                                  _glowAnimation.value,
                                )!,
                          width: 2,
                        ),
                        boxShadow: widget.isTransparent == true 
                            ? [] 
                            : [
                                BoxShadow(
                                  color: Color.lerp(
                                    Colors.black26,
                                    Colors.green.withValues(alpha: 0.5),
                                    _glowAnimation.value,
                                  )!,
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedPlayerEntry extends StatelessWidget {
  final Widget child;
  final int index;

  const AnimatedPlayerEntry({
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
          offset: Offset(0, 20 * (1 - value)),
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

class _PulsingTurnIndicator extends StatefulWidget {
  const _PulsingTurnIndicator();

  @override
  State<_PulsingTurnIndicator> createState() => _PulsingTurnIndicatorState();
}

class _PulsingTurnIndicatorState extends State<_PulsingTurnIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              margin: const EdgeInsets.only(top: 25),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.5),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Text('È il tuo turno!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }
}

class _ActionFeedbackWidget extends StatefulWidget {
  final String message;
  final Color color;
  final IconData icon;
  final VoidCallback onComplete;

  const _ActionFeedbackWidget({
    required this.message,
    required this.color,
    required this.icon,
    required this.onComplete,
  });

  @override
  State<_ActionFeedbackWidget> createState() => _ActionFeedbackWidgetState();
}

class _ActionFeedbackWidgetState extends State<_ActionFeedbackWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 10),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 80,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value.clamp(0.0, 1.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CardDragAnimationWidget extends StatefulWidget {
  final CardDragType dragType;
  final VoidCallback onComplete;

  const _CardDragAnimationWidget({
    required this.dragType,
    required this.onComplete,
  });

  @override
  State<_CardDragAnimationWidget> createState() => _CardDragAnimationWidgetState();
}

class _CardDragAnimationWidgetState extends State<_CardDragAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _positionAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    Offset startOffset;
    Offset endOffset;

    switch (widget.dragType) {
      case CardDragType.deckToHand:
        startOffset = const Offset(0, -150);
        endOffset = const Offset(0, 150);
        break;
      case CardDragType.handToDiscard:
        startOffset = const Offset(0, 150);
        endOffset = const Offset(80, 0);
        break;
      case CardDragType.handToRun:
        startOffset = const Offset(0, 150);
        endOffset = const Offset(0, -200);
        break;
    }

    _positionAnimation = Tween<Offset>(
      begin: startOffset,
      end: endOffset,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: widget.dragType == CardDragType.handToDiscard ? 0.1 : 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Center(
            child: Transform.translate(
              offset: _positionAnimation.value,
              child: Transform.rotate(
                angle: _rotationAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: 45,
                    height: 65,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/cards/back.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
