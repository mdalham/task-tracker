import 'package:flutter/material.dart';

void customNoteMenuPopup({
  required BuildContext context,
  required Offset position,
  required Widget Function(void Function([String? result]) onClose) builder, // updated
  required ColorScheme colorScheme,
  required int left,
  required int top,
  void Function(String? result)? onDismiss,
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  final animationController = AnimationController(
    duration: const Duration(milliseconds: 200),
    vsync: Navigator.of(context),
  );

  final animation = CurvedAnimation(
    parent: animationController,
    curve: Curves.easeOutBack,
  );

  void closePopup([String? result]) {
    animationController.reverse().then((_) {
      entry.remove();
      if (onDismiss != null) onDismiss(result); // pass result back
    });
  }

  entry = OverlayEntry(
    builder: (context) => Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => closePopup(),
        ),
        Positioned(
          left: position.dx - left,
          top: position.dy + top,
          child: FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.2, 0),
                end: Offset.zero,
              ).animate(animationController),
              child: Material(
                borderRadius: BorderRadius.circular(18),
                child: builder(closePopup), // pass closePopup with optional result
              ),
            ),
          ),
        ),
      ],
    ),
  );

  overlay.insert(entry);
  animationController.forward();
}
