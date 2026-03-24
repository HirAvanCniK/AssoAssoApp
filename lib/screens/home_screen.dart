import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_globals.dart';
import '../core/app_router.dart';
import '../core/formatters.dart';
import '../services/game_session_service.dart';
import '../services/shared_preferences_service.dart';
import '../widgets/bold_button.dart';
import '../widgets/dialogs.dart';
import '../widgets/universal_safearea.dart';

// Main entry screen for the application.
//
// Provides user profile display, animated decorations, and navigation to game modes.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final GameSessionService _gameSessionService = GameSessionService();
  late final List<AnimationController> _controllers;

  String _nickname = "Giocatore";
  String _avatarPath = 'assets/images/avatars/avatar_0.png';
  bool _didShowMessage = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _initAnimations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Display messages passed via arguments (e.g., after leaving a lobby)
    if (!_didShowMessage) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic> && args['message'] != null) {
        Future.microtask(() => _showSnackBar(args['message']));
      }
      _didShowMessage = true;
    }
  }

  // Loads user profile data from persistent storage.
  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferencesService.loadPreferences();
    if (mounted) {
      setState(() {
        _nickname = prefs[AppGlobals.keyNickname] ?? 'Giocatore';
        _avatarPath = prefs[AppGlobals.keyAvatarPath] ?? 'assets/images/avatars/avatar_0.png';
      });
    }
  }

  // Initializes the floating card animations.
  void _initAnimations() {
    _controllers = List.generate(4, (i) {
      return AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: MySafeArea(
          child: Stack(
            children: [
              ..._buildAnimatedAces(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  _buildProfileHeader(),
                  const Spacer(),
                  BoldButton(
                    label: "GIOCA",
                    onPressed: _showPlayDialog,
                    backgroundColor: const Color.fromARGB(255, 255, 178, 12),
                    borderColor: const Color.fromARGB(100, 255, 217, 0),
                  ),
                  const SizedBox(height: 20),
                  _buildFooterButtons(),
                  const SizedBox(height: 30),
                ],
              ),
            ]
          )
        ),
      ),
    );
  }

  // Builds the row of navigation buttons at the bottom of the screen.
  Widget _buildFooterButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildFooterButton("IMPOSTAZIONI", AppRouter.settings),
        const SizedBox(width: 10),
        _buildFooterButton("REGOLE", AppRouter.rules),
        const SizedBox(width: 10),
        _buildFooterButton("PROFILO", AppRouter.profile),
      ],
    );
  }

  // Builds a single styled footer navigation button.
  BoldButton _buildFooterButton(String label, String routeName) {
    return BoldButton(
      label: label,
      onPressed: () => Navigator.pushNamed(context, routeName).then((_) => _loadProfileData()),
      backgroundColor: const Color.fromARGB(255, 255, 178, 12),
      borderColor: const Color.fromARGB(100, 255, 217, 0),
    );
  }

  // Builds the header displaying the user's avatar and nickname.
  Widget _buildProfileHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.yellow.shade700.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundImage: AssetImage(_avatarPath),
            backgroundColor: Colors.white,
          ),
          const SizedBox(width: 16),
          Text(
            _nickname,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(blurRadius: 6, color: Colors.black)],
            ),
          ),
        ],
      ),
    );
  }

  // Builds the list of floating, animated ace cards for decoration.
  List<Widget> _buildAnimatedAces() {
    final cardPaths = ['AS', 'AH', 'AD', 'AC'].map((c) => 'assets/images/cards/$c.png').toList();
    final cardOffsets = [const Offset(40, 110), const Offset(170, 60), const Offset(170, 60), const Offset(40, 110)];
    final isLeft = [true, true, false, false];

    return List.generate(4, (i) {
      final animation = Tween<double>(
        begin: isLeft[i] ? -0.35 : 0.35,
        end: isLeft[i] ? -0.25 : 0.25,
      ).animate(CurvedAnimation(parent: _controllers[i], curve: Curves.easeInOut));

      return Positioned(
        top: cardOffsets[i].dy,
        left: isLeft[i] ? cardOffsets[i].dx : null,
        right: !isLeft[i] ? cardOffsets[i].dx : null,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Transform.rotate(
              angle: animation.value,
              child: child,
            );
          },
          child: Container(
            decoration: const BoxDecoration(
              boxShadow: [BoxShadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 10)],
            ),
            child: Image.asset(cardPaths[i], height: 150, fit: BoxFit.contain),
          ),
        ),
      );
    });
  }

  // --- Dialogs ---

  // Shows the main dialog to create or join a game lobby.
  void _showPlayDialog() {
    showCustomDialog(context,
      children: [
        Text('Cosa vuoi fare?', style: TextStyle(color: Colors.yellow.shade200, fontWeight: FontWeight.bold, fontSize: 20)),
        const SizedBox(height: 20),
        buildDialogButton(icon: Icons.add_box, label: "Crea Lobby", onPressed: () {
          Navigator.of(context).pop();
          _showPlayerCountDialog();
        }),
        const SizedBox(height: 12),
        buildDialogButton(icon: Icons.meeting_room, label: "Unisciti a Lobby", onPressed: () {
          Navigator.of(context).pop();
          _showJoinLobbyDialog();
        }),
      ],
    );
  }

  // Shows a dialog for selecting the player count when creating a new lobby.
  void _showPlayerCountDialog() {
    showCustomDialog(context,
      children: List.generate(3, (index) {
        final playerCount = index + 2;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: buildDialogButton(icon: Icons.group, label: '$playerCount giocatori', onPressed: () async {
            Navigator.of(context).pop();
            final sessionCode = await _gameSessionService.createGameSession(_nickname, playerCount);
            if (sessionCode != null) {
              _navigateToLobby(sessionCode);
            } else {
              _showSnackBar('Errore nella creazione della lobby');
            }
          }),
        );
      }),
    );
  }

  // Shows a dialog for entering a lobby code to join an existing game.
  void _showJoinLobbyDialog() {
    final codeController = TextEditingController();
    showCustomDialog(context,
      children: [
        TextField(
          controller: codeController,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [UpperCaseTextFormatter(), FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]'))],
          decoration: InputDecoration(
            hintText: "CODICE...",
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.yellow.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.yellow.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white, width: 2)),
          ),
        ),
        const SizedBox(height: 16),
        buildDialogButton(icon: Icons.login, label: "Entra", onPressed: () async {
          final code = codeController.text.trim();
          if (code.isEmpty) return;
          final success = await _gameSessionService.joinGameSession(code, _nickname, _showSnackBar);
          if (success) {
            _navigateToLobby(code);
          } else if (mounted) {
            Navigator.of(context).pop();
          }
        }),
      ],
    );
  }

  // --- Navigation & Feedback ---

  // Navigates to the lobby screen with the necessary arguments.
  void _navigateToLobby(String code) {
    if (mounted) {
      Navigator.pushNamed(
        context,
        AppRouter.lobby,
        arguments: {'code': code, 'currentUserNickname': _nickname},
      );
    }
  }

  // Displays a temporary feedback message to the user.
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.black87,
        ),
      );
    }
  }
}
