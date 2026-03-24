import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// A custom button widget with press animation and comic-book styling.
//
// Features scale animation on tap, customizable colors, Google Fonts "Bangers"
// typography, and layered shadows for depth.
class BoldButton extends StatefulWidget {
  // The text label displayed on the button.
  final String label;

  // Callback executed when the button is tapped.
  final VoidCallback onPressed;

  // Background color of the button (default: dark red).
  final Color backgroundColor;

  // Border color for the button outline (default: golden yellow).
  final Color borderColor;

  // Creates a [BoldButton].
  //
  // [label] and [onPressed] are required. Colors are optional with defaults.
  const BoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.backgroundColor = const Color(0xFFB71C1C),
    this.borderColor = const Color(0xFFFFD700),
  });

  @override
  State<BoldButton> createState() => _BoldButtonState();
}

class _BoldButtonState extends State<BoldButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Handles tap interaction with press animation sequence.
  Future<void> _handleTap() async {
    await _controller.reverse();
    await Future.delayed(const Duration(milliseconds: 10));
    await _controller.forward();
    await Future.delayed(const Duration(milliseconds: 30));
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _controller.value,
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 40),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.borderColor, width: 0),
            boxShadow: [
              BoxShadow(
                color: widget.backgroundColor.withAlpha(130),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withAlpha(200),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.bangers(
              textStyle: TextStyle(
                fontSize: 32,
                color: Colors.white,
                letterSpacing: 2,
                shadows: [
                  Shadow(
                    blurRadius: 6,
                    color: Colors.black.withAlpha(180),
                    offset: const Offset(1, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}