import 'package:flutter/material.dart';

class ActionButton extends StatefulWidget {
  // The text label displayed on the button.
  final String label;

  // Callback executed when the button is tapped.
  final VoidCallback onPressed;

  // Background color of the button (default: dark red).
  final Color backgroundColor;

  // Creates a [ActionButton].
  //
  // [label] and [onPressed] are required. Background Color is optional with default.
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.backgroundColor = const Color(0xFFB71C1C),
  });

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton>
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
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            textStyle: const TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 16,
              fontFamily: 'Open Sans'
            ),
            backgroundColor: widget.backgroundColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: widget.backgroundColor.withValues(alpha: 0.8), width: 2)),
          ),
          onPressed: widget.onPressed,
          child: Text(widget.label),
        ),
      ),
    );
  }
}