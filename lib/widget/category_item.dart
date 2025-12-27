import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screen/secondary/category_bottom_sheet.dart';
import '../helper class/size_helper_class.dart';
import '../models/add task/custom_menu.dart';
import '../service/category/provider/category_provider.dart';

class CategoryItem extends StatefulWidget {
  final String? selectedCategory;
  final void Function(String)? onCategoryChanged;

  const CategoryItem({
    super.key,
    this.selectedCategory,
    this.onCategoryChanged,
  });

  @override
  State<CategoryItem> createState() => _CategoryItemState();
}

class _CategoryItemState extends State<CategoryItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _iconController;
  String? _selectedCategory;
  bool _isPopupOpen = false;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _selectedCategory = widget.selectedCategory?.isNotEmpty == true
        ? widget.selectedCategory
        : null;
  }

  @override
  void didUpdateWidget(covariant CategoryItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCategory != oldWidget.selectedCategory) {
      _selectedCategory = widget.selectedCategory?.isNotEmpty == true
          ? widget.selectedCategory
          : null;
    }
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  void _openPopup() {
    setState(() {
      _isPopupOpen = true;
      _iconController.forward();
    });
  }

  void _closePopup([String? result]) {
    setState(() {
      _isPopupOpen = false;
      _iconController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Listen to provider for real-time updates
    final categories = context.watch<CategoryProvider>().categories;

    // Show message if no categories
    if (categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
          onTap: () {
            // Open category bottom sheet to create a new category
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const CategoryBottomSheet(),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  "No categories yet! Create new",
                  style: textTheme.bodyLarge?.copyWith(color: Colors.blue),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTapDown: (details) {
              if (!_isPopupOpen) {
                _openPopup();

                customMenu(
                  context: context,
                  position: details.globalPosition,
                  colorScheme: colorScheme,
                  left: 0,
                  top: 10,
                  onDismiss: _closePopup,
                  builder: (onClose) => Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.25, // Max 40% of screen height
                    ),
                    padding: const EdgeInsets.all(12),
                    width: MediaQuery.of(context).size.width * 0.5,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colorScheme.outline),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: categories.map((cat) {
                          final isSelected = cat.name == _selectedCategory;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedCategory = cat.name);
                              widget.onCategoryChanged?.call(cat.name);
                              onClose();
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                cat.name,
                                style: textTheme.bodyMedium!.copyWith(
                                  color: isSelected
                                      ? Colors.blue
                                      : colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              } else {
                _closePopup();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedCategory ?? "Select Category",
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 6),
                  AnimatedBuilder(
                    animation: _iconController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _iconController.value * 3.1416, // 180°
                        child: child,
                      );
                    },
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: colorScheme.onSurface,
                      size: SizeHelperClass.keyboardArrowDownIconSize(context) - 4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}