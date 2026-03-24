import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_router.dart';

// A cinematic splash screen with animated title and card fan effects.
//
// Displays a typewriter-style title animation followed by sequential card fan
// animations for each suit, then navigates to the [HomeScreen].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const String _fullTitle = 'ASSO ASSO';
  static const List<String> _ranks = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '0', 'J', 'Q', 'K', 'A'];
  static const List<String> _suits = ['C', 'H', 'D', 'S'];

  String _visibleTitle = '';
  final List<Widget> _fanCards = [];
  bool _showFan = false;

  @override
  void initState() {
    super.initState();
    _startAnimationSequence();
  }

  // Coordinates the entire animation sequence from title to navigation.
  Future<void> _startAnimationSequence() async {
    await _animateTitle();
    await _animateAllSuits();
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRouter.home);
    }
  }

  // Animates the title with a typewriter effect.
  Future<void> _animateTitle() async {
    for (int i = 0; i < _fullTitle.length; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() {
        _visibleTitle += _fullTitle[i];
      });
    }
    await Future.delayed(const Duration(milliseconds: 500)); // Pause after title
  }

  // Iterates through each suit and triggers its fan animation.
  Future<void> _animateAllSuits() async {
    for (final suit in _suits) {
      if (!mounted) return;
      await _animateCardFanForSuit(suit);
      await Future.delayed(const Duration(milliseconds: 100)); // Pause between suits
    }
  }

  // Animates a full fan of cards for a given suit.
  Future<void> _animateCardFanForSuit(String suit) async {
    final cardAssets = _ranks.map((r) => 'assets/images/cards/$r$suit.png').toList();
    
    setState(() {
      _showFan = true;
      _fanCards.clear();
    });

    // Animate cards appearing one by one
    for (int i = 0; i < cardAssets.length; i++) {
      await Future.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
      setState(() {
        _fanCards.add(_buildCurvedCard(i, cardAssets.length, cardAssets[i]));
      });
    }

    // Hold the fan, then clear it
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    setState(() {
      _showFan = false;
      _fanCards.clear();
    });
  }

  // Builds a single animated card widget positioned along a circular arc.
  Widget _buildCurvedCard(int index, int total, String assetPath) {
    const double radius = 130;
    const double angleStart = pi + pi / 8;
    const double angleEnd = 2 * pi - pi / 8;
    final double angle = angleStart + (angleEnd - angleStart) * index / (total - 1);

    final double x = radius * cos(angle);
    final double y = 30 + radius * sin(angle);
    final double rotation = angle + pi / 2;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(x * value, y * value),
            child: Transform.rotate(
              angle: rotation,
              child: child,
            ),
          ),
        );
      },
      child: Image.asset(assetPath, height: 90),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTitleComplete = _visibleTitle.length == _fullTitle.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          if (_showFan) Center(child: Stack(children: _fanCards)),
          Positioned(
            bottom: 70,
            left: 0,
            right: 0,
            child: AnimatedSlide(
              offset: isTitleComplete ? Offset.zero : const Offset(0, 0.2),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: isTitleComplete ? 1.0 : 0.8,
                duration: const Duration(milliseconds: 500),
                child: Text(
                  _visibleTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.anton(
                    textStyle: const TextStyle(
                      fontSize: 64,
                      color: Colors.white,
                      letterSpacing: 6,
                      shadows: [
                        Shadow(blurRadius: 18, color: Colors.black),
                        Shadow(blurRadius: 30, color: Colors.redAccent),
                        Shadow(offset: Offset(3, 3), blurRadius: 6, color: Colors.black87),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
