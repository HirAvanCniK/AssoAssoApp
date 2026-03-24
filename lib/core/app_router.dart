import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/rules_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/lobby_screen.dart';
import '../screens/game_screen.dart';
import '../screens/endgame_screen.dart';

// A class that handles the application's routing logic.
//
// It centralizes all route definitions and generation, making navigation
// management cleaner and more maintainable.
class AppRouter {
  static const String splash = '/';
  static const String home = '/home';
  static const String settings = '/settings';
  static const String rules = '/rules';
  static const String profile = '/profile';
  static const String lobby = '/lobby';
  static const String game = '/game';
  static const String endgame = '/endgame';

  // Generates routes based on the provided [RouteSettings].
  static Route<dynamic> onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case home:
        return MaterialPageRoute(settings: routeSettings, builder: (_) => const HomeScreen());
      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case rules:
        return MaterialPageRoute(builder: (_) => const RulesScreen());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case endgame:
        return MaterialPageRoute(settings: routeSettings, builder: (_) => const EndGameScreen());
      case lobby:
        final args = routeSettings.arguments as Map<String, dynamic>?;
        if (args != null && args.containsKey('code') && args.containsKey('currentUserNickname')) {
          return MaterialPageRoute(
            builder: (_) => LobbyScreen(
              code: args['code'] as String,
              currentUserNickname: args['currentUserNickname'] as String,
            ),
          );
        }
        return _errorRoute(routeSettings.name);
      case game:
        final args = routeSettings.arguments as Map<String, dynamic>?;
        if (args != null &&
            args.containsKey('code') &&
            args.containsKey('currentUserNickname') &&
            args.containsKey('lobbyHostNickname')) {
          return MaterialPageRoute(
            builder: (_) => GameScreen(
              code: args['code'] as String,
              currentUserNickname: args['currentUserNickname'] as String,
              lobbyHostNickname: args['lobbyHostNickname'] as String,
            ),
          );
        }
        return _errorRoute(routeSettings.name);
      default:
        return _errorRoute(routeSettings.name);
    }
  }

  // Returns a standardized error route for unknown or invalid paths.
  static Route<dynamic> _errorRoute(String? routeName) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        body: Center(
          child: Text('Errore: La rotta $routeName non è stata trovata.'),
        ),
      ),
    );
  }
}
