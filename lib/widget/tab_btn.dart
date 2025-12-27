import 'package:flutter/material.dart';

class TabButtonDesign extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final Function(int) selectTab;

  const TabButtonDesign({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.selectTab,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final bool isSelected = selectedIndex == index;

          return GestureDetector(
            onTap: () => selectTab(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue.withOpacity(0.1) : colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? Colors.blue : colorScheme.onSurface,
                  width: 1.5,
                ),
              ),
              child: Text(
                tabs[index],
                style: textTheme.labelLarge!.copyWith(
                  color: isSelected ? Colors.blue : colorScheme.primary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                )
              ),
            ),
          );
        }),
      ),
    );
  }
}
