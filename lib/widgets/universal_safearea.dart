import 'package:flutter/material.dart';

class MySafeArea extends StatelessWidget {
  final Widget child;

  const MySafeArea({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: (!_hasSafeArea(context)) ? 
        Padding(
          padding: const EdgeInsets.all(15),
          child: child,
        ) :
        child
    );
  }

  bool _hasSafeArea(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    return padding.top > 0 ||
          padding.bottom > 0 ||
          padding.left > 0 ||
          padding.right > 0;
  }
}