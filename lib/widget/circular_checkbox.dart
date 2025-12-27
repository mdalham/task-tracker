import 'package:flutter/material.dart';
import 'package:tasktracker/helper%20class/size_helper_class.dart';

class CircularCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?>? onChanged;
  final double size;

  const CircularCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 0,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidth = SizeHelperClass.circularCheckboxWidth(context);
    final iconHeight = SizeHelperClass.circularCheckboxHeight(context);

    return GestureDetector(
      onTap: () => onChanged?.call(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: iconWidth + size,
        height: iconHeight + size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: value
              ? Colors.blue
              : Colors.transparent,
          border: Border.all(
            color: value
                ? Colors.transparent
                : Theme.of(context).colorScheme.onSurface,
            width: 2,
          ),
          boxShadow: value
              ? [
            BoxShadow(
              color: Colors.blue.withOpacity(0.8),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ]
              : null,
        ),
        child: Center(
          child: AnimatedScale(
            scale: value ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            child: const Icon(
              Icons.check,
              size: 16,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}