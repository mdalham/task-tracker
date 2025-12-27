import 'package:flutter/material.dart';
import 'package:tasktracker/widget/custom_container.dart';

import '../../service/todo/db/todo_model.dart';
import '../../widget/circular_checkbox.dart';

class TodoListItem extends StatelessWidget {
  final Todo todo;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const TodoListItem({
    super.key,
    required this.todo,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dismissible(
      key: Key(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete Todo'),
              content: const Text('Are you sure you want to delete this todo?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) => onDelete(),
      child: CustomContainer(
        color: colorScheme.primaryContainer,
        outlineColor: _getPriorityColor(todo.priority,colorScheme),
        circularRadius: 16,
        child: GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10,vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 10,left: 5),
                  child: CircularCheckbox(
                    value: todo.isCompleted,
                    onChanged: (_) => onToggle(),
                  )
                ),
                Expanded(
                  child: Text(
                    todo.title,
                    style: theme.textTheme.titleLarge!.copyWith(
                      fontSize: 24
                    )
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(int priority, ColorScheme colorscheme) {
    switch (priority) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.orangeAccent;
      case 3:
        return Colors.redAccent;
      default:
        return colorscheme.outline;
    }
  }

}