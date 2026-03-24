import 'package:flutter/material.dart';

class TappableCard extends StatelessWidget {
  final Widget cardWidget;
  final String cardId;
  final ValueNotifier<String?> selectedCardNotifier;

  const TappableCard({
    required this.cardWidget,
    required this.cardId,
    required this.selectedCardNotifier,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: selectedCardNotifier,
      builder: (context, selectedId, child) {
        final isSelected = selectedId == cardId;
        
        return GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onTap: () {
            selectedCardNotifier.value = (selectedId == cardId) ? null : cardId;
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutQuad,
              transform: Matrix4.translationValues(0, isSelected ? -15 : 0, 0),
              child: cardWidget,
            ),
          ),
        );
      },
    );
  }
}