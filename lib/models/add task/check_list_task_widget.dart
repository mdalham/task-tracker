import 'package:flutter/material.dart';
import '../../service/task/db/tasks_models.dart';
import '../../widget/custom_container.dart';

class CheckListTaskWidget extends StatefulWidget {
  final List<TaskModel> initialItems;
  final ValueChanged<List<TaskModel>>? onChanged;

  const CheckListTaskWidget({
    super.key,
    this.initialItems = const [],
    this.onChanged,
  });

  @override
  State<CheckListTaskWidget> createState() => _CheckListTaskWidgetState();
}

class _CheckListTaskWidgetState extends State<CheckListTaskWidget> {
  late List<TaskModel> _items;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  @override
  void initState() {
    super.initState();
    _items = widget.initialItems.isNotEmpty
        ? List<TaskModel>.from(widget.initialItems)
        : [_createNewItem()];
    _initializeControllers();
  }

  TaskModel _createNewItem() {
    return TaskModel(
      title: '',
      isChecked: false,
    );
  }

  void _initializeControllers() {
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      final key = item.id?.toString() ?? 'temp_$i';
      if (!_controllers.containsKey(key)) {
        final controller = TextEditingController(text: item.title);
        final focusNode = FocusNode();
        controller.addListener(() {
          _updateItemTitle(key, controller.text);
        });
        _controllers[key] = controller;
        _focusNodes[key] = focusNode;
      }
    }
  }

  void _updateItemTitle(String key, String newTitle) {
    final index = _items.indexWhere(
          (item) => (item.id?.toString() ?? 'temp_${_items.indexOf(item)}') == key,
    );
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        title: newTitle,
        updatedAt: DateTime.now(),
      );
      _notifyParent();
    }
  }

  @override
  void didUpdateWidget(CheckListTaskWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialItems.length != widget.initialItems.length ||
        !_areItemsEqual(oldWidget.initialItems, widget.initialItems)) {
      _syncItemsWithWidget();
    }
  }

  bool _areItemsEqual(List<TaskModel> list1, List<TaskModel> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id ||
          list1[i].title != list2[i].title ||
          list1[i].isChecked != list2[i].isChecked) {
        return false;
      }
    }
    return true;
  }

  void _syncItemsWithWidget() {
    final newItems = widget.initialItems.isNotEmpty
        ? List<TaskModel>.from(widget.initialItems)
        : [_createNewItem()];
    _disposeUnusedControllers(newItems);
    _items = newItems;
    _initializeControllers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifyParent();
    });
  }

  void _disposeUnusedControllers(List<TaskModel> newItems) {
    final newKeys = newItems
        .asMap()
        .entries
        .map((e) => e.value.id?.toString() ?? 'temp_${e.key}')
        .toSet();
    final keysToRemove =
    _controllers.keys.where((k) => !newKeys.contains(k)).toList();
    for (var key in keysToRemove) {
      _controllers[key]?.dispose();
      _focusNodes[key]?.dispose();
      _controllers.remove(key);
      _focusNodes.remove(key);
    }
  }

  void _addItem() {
    setState(() {
      final newItem = _createNewItem();
      _items.add(newItem);
      final key = 'temp_${_items.length - 1}';
      final controller = TextEditingController();
      final focusNode = FocusNode();
      controller.addListener(() {
        _updateItemTitle(key, controller.text);
      });
      _controllers[key] = controller;
      _focusNodes[key] = focusNode;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        focusNode.requestFocus();
      });
      _notifyParent();
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) {
      setState(() {
        final key = _items[index].id?.toString() ?? 'temp_$index';
        _controllers[key]?.clear();
        _items[index] = _items[index].copyWith(
          title: '',
          isChecked: false,
          updatedAt: DateTime.now(),
        );
        _notifyParent();
      });
      return;
    }
    setState(() {
      final key = _items[index].id?.toString() ?? 'temp_$index';
      _controllers[key]?.dispose();
      _focusNodes[key]?.dispose();
      _controllers.remove(key);
      _focusNodes.remove(key);
      _items.removeAt(index);
      _rebuildControllerMap();
      _notifyParent();
    });
  }

  void _rebuildControllerMap() {
    final Map<String, TextEditingController> newControllers = {};
    final Map<String, FocusNode> newFocusNodes = {};
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      final oldKey = item.id?.toString() ?? 'temp_$i';
      final newKey = item.id?.toString() ?? 'temp_$i';
      if (_controllers.containsKey(oldKey)) {
        newControllers[newKey] = _controllers[oldKey]!;
        newFocusNodes[newKey] = _focusNodes[oldKey]!;
      }
    }
    _controllers
      ..clear()
      ..addAll(newControllers);
    _focusNodes
      ..clear()
      ..addAll(newFocusNodes);
  }

  void _toggleCheck(int index) {
    setState(() {
      _items[index] = _items[index].copyWith(
        isChecked: !_items[index].isChecked,
        completedAt: !_items[index].isChecked ? DateTime.now() : null,
        updatedAt: DateTime.now(),
      );
      _notifyParent();
    });
  }

  void _notifyParent() {
    final validItems =
    _items.where((item) => item.title.trim().isNotEmpty).toList();
    widget.onChanged?.call(List.from(validItems));
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    for (var f in _focusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return CustomContainer(
      padding: const EdgeInsets.all(12),
      color: colorScheme.primaryContainer,
      outlineColor: colorScheme.outline,
      circularRadius: 18,
      child: Column(
        children: List.generate(_items.length, (index) {
          final item = _items[index];
          final key = item.id?.toString() ?? 'temp_$index';
          final controller = _controllers[key]!;
          final focusNode = _focusNodes[key]!;
          final isLast = index == _items.length - 1;

          return Row(
            children: [
              Checkbox(
                value: item.isChecked,
                checkColor: Colors.white,
                activeColor: Colors.blue,
                onChanged: (_) => _toggleCheck(index),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Checklist item',
                    hintStyle: textTheme.bodyMedium,
                    border: InputBorder.none
                  ),
                  maxLines: 1,
                  textInputAction:
                  isLast ? TextInputAction.done : TextInputAction.next,
                  onSubmitted: (_) {
                    if (isLast && controller.text.trim().isNotEmpty) {
                      _addItem();
                    }
                  },
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                ),
              ),
              isLast
                  ? IconButton(
                icon: Icon(Icons.add, color: colorScheme.onSurface),
                onPressed: controller.text.trim().isNotEmpty
                    ? _addItem
                    : null,
              )
                  : IconButton(
                icon: Icon(Icons.close, color: colorScheme.onSurface),
                onPressed: () => _removeItem(index),
              ),
            ],
          );
        }),
      ),
    );
  }
}
