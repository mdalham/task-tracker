// model/note/note add/check_list_widget.dart
import 'package:flutter/material.dart';

import '../../service/note/db/notes_models.dart';
import '../../widget/custom_container.dart';

/// CHECKLIST WIDGET – ADD WORKS + NO EMPTY TITLES SAVED TO DB
class CheckListNoteWidget extends StatefulWidget {
  final List<ChecklistItem> initialItems;
  final ValueChanged<List<ChecklistItem>>? onChanged;

  const CheckListNoteWidget({
    super.key,
    this.initialItems = const [],
    this.onChanged,
  });

  @override
  State<CheckListNoteWidget> createState() => _CheckListNoteWidgetState();
}

class _CheckListNoteWidgetState extends State<CheckListNoteWidget> {
  late List<ChecklistItem> _items;
  final Map<int, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _items = widget.initialItems.isNotEmpty
        ? List.from(widget.initialItems)
        : [const ChecklistItem(title: '')];
    _rebuildControllers();
  }

  @override
  void didUpdateWidget(covariant CheckListNoteWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialItems != widget.initialItems) {
      _items = List.from(widget.initialItems);
      _rebuildControllers();
    }
  }

  void _rebuildControllers() {
    // Only create controllers for NEW items that don't have one
    for (int i = 0; i < _items.length; i++) {
      if (!_controllers.containsKey(i)) {
        _controllers[i] = TextEditingController(text: _items[i].title);
        // Add listener to update item when text changes
        final index = i;
        _controllers[i]!.addListener(() {
          if (_items[index].title != _controllers[index]!.text) {
            _items[index] = ChecklistItem(
              title: _controllers[index]!.text,
              isChecked: _items[index].isChecked,
            );
          }
        });
      } else {
        // Update existing controller text if item changed
        if (_controllers[i]!.text != _items[i].title) {
          _controllers[i]!.text = _items[i].title;
        }
      }
    }

    // Remove controllers for deleted items
    final keysToRemove =
    _controllers.keys.where((key) => key >= _items.length).toList();
    for (final key in keysToRemove) {
      _controllers[key]?.dispose();
      _controllers.remove(key);
    }
  }


  // DO NOT FILTER HERE — Let parent filter on save
  void _notifyParent() {
    if (mounted) {
      widget.onChanged?.call(List.from(_items));
    }
  }

  void _addItem() {
    setState(() {
      _items.add(const ChecklistItem(title: ''));
      _rebuildControllers();
      _notifyParent();
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);

      // Dispose the controller for removed item
      _controllers[index]?.dispose();

      // Reindex remaining controllers
      final Map<int, TextEditingController> newControllers = {};
      for (int i = 0; i < _items.length; i++) {
        if (i < index) {
          newControllers[i] = _controllers[i]!;
        } else {
          newControllers[i] = _controllers[i + 1]!;
        }
      }

      _controllers.clear();
      _controllers.addAll(newControllers);

      _notifyParent();
    });
  }

  void _toggleCheck(int index) {
    setState(() {
      final item = _items[index];
      _items[index] = ChecklistItem(
        title: item.title,
        isChecked: !item.isChecked,
      );
      _notifyParent();
    });
  }

  void _updateTitle(int index, String value) {
    _items[index] = ChecklistItem(
      title: value,
      isChecked: _items[index].isChecked,
    );
    _notifyParent();
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return CustomContainer(
      padding: const EdgeInsets.all(10),
      color: colorScheme.primaryContainer,
      outlineColor: colorScheme.outline,
      circularRadius: 18,
      child: Column(
        children: List.generate(_items.length, (index) {
          final item = _items[index];
          final controller = _controllers[index]!;

          return Row(
            children: [
              // Checkbox
              Checkbox(
                value: item.isChecked,
                checkColor: Colors.white,
                activeColor: Colors.blue,
                focusColor: colorScheme.onSurface,
                onChanged: (_) => _toggleCheck(index),
              ),

              // Text Field
              Expanded(
                child: TextField(
                  controller: controller,
                  style: textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Checklist item',
                    hintStyle: textTheme.bodySmall!.copyWith(fontSize: 16),
                    border: InputBorder.none,
                  ),
                  //onChanged: (value) => _updateTitle(index, value),
                  onSubmitted: (_) {
                    if (index == _items.length - 1) {
                      _addItem();
                    }
                  },
                  onTapOutside: (event) {
                    FocusScope.of(context).unfocus();
                  },
                ),
              ),

              // Add / Remove Button
              index == _items.length - 1
                  ? IconButton(
                icon: Icon(
                  Icons.add,
                  size: 20,
                  color: colorScheme.onSurface,
                ),
                onPressed: _addItem,
              )
                  : IconButton(
                icon: Icon(
                  Icons.close,
                  size: 20,
                  color: colorScheme.onSurface,
                ),
                onPressed: () => _removeItem(index),
              ),
              const SizedBox(width: 17),
            ],
          );
        }),
      ),
    );
  }
}