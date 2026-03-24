import 'package:flutter/material.dart';

void showCustomDialog(BuildContext context, {required List<Widget> children}) {
  showGeneralDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    barrierDismissible: true,
    barrierLabel: 'Chiudi dialogo',
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.yellow.shade700, width: 2),
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
        ),
      );
    },
  );
}

// Creates a styled button for use inside custom dialogs.
Widget buildDialogButton({
  IconData? icon,
  required String label,
  required VoidCallback onPressed,
}) {
  return _AnimatedDialogButton(
    icon: icon,
    label: label,
    onPressed: onPressed,
  );
}

class _AnimatedDialogButton extends StatefulWidget {
  final IconData? icon;
  final String label;
  final VoidCallback onPressed;

  const _AnimatedDialogButton({
    this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  State<_AnimatedDialogButton> createState() => _AnimatedDialogButtonState();
}

class _AnimatedDialogButtonState extends State<_AnimatedDialogButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await _controller.reverse();
    await Future.delayed(const Duration(milliseconds: 50));
    await _controller.forward();
    await Future.delayed(const Duration(milliseconds: 50));
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.orange.shade400,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.yellow.shade700, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _handleTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
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
          ),
        ),
      ),
    );
  }
}
