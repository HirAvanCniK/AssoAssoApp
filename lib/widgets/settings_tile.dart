import 'package:flutter/material.dart';

// A reusable widget for displaying a setting option.
//
// Typically used in settings screens, it provides a consistent layout for a
// title, a subtitle, and a trailing control widget (like a switch or slider).
class SettingsTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final Widget trailing;
  final bool isEnabled;

  const SettingsTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.isEnabled = true,
  });

  @override
  State<SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<SettingsTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.98,
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

  @override
  Widget build(BuildContext context) {
    final titleColor = widget.isEnabled ? Colors.white : Colors.grey[600];
    final subtitleColor = widget.isEnabled ? Colors.white70 : Colors.grey[700];

    return GestureDetector(
      onTapDown: widget.isEnabled ? (_) => _controller.reverse() : null,
      onTapUp: widget.isEnabled ? (_) => _controller.forward() : null,
      onTapCancel: widget.isEnabled ? () => _controller.forward() : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AbsorbPointer(
          absorbing: !widget.isEnabled,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.yellow.shade800.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                widget.trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
