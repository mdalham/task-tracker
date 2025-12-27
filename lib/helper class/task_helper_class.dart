import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/dialog/delete_dialog.dart';
import '../screen/secondary/task_add_or_edit_screen.dart';
import '../screen/secondary/task_view_screen.dart';
import '../service/task/db/tasks_models.dart';
import '../service/task/provider/task_provider.dart';
import '../widget/custom_snack_bar.dart';

class TaskHelperClass {
  static void openTask(BuildContext context, TaskModel task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskViewScreen(task: task),
    );
  }

  // ACTIONS
  static Future<void> editTask(BuildContext context, TaskModel task) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskAddOrEditScreen(task: task)),
    );
    if (result == true && context.mounted) {
      Provider.of<TaskProvider>(context, listen: false).loadAllTasks();
    }
  }

  static Future<void> deleteTask(BuildContext context, TaskModel task) async {
    // 1. Confirm deletion

    final confirmed = await deleteDialog(
      context: context,
      title: "Delete Task?",
      message: task.title.isEmpty
          ? 'Delete this task permanently?\nThis action cannot be undone.'
          : 'Delete "${task.title}" permanently?\nThis action cannot be undone.',
      confirmText: "Delete",
    );

    if (confirmed != true) return;
    if (task.id == null) return;
    final provider = Provider.of<TaskProvider>(context, listen: false);
    final TaskModel deletedTask = task;
    provider.deleteTask(task.id!);

    if (!context.mounted) return;
    CustomSnackBar.show(
      context,
      message: 'Task deleted successfully!',
      type: SnackBarType.success,
      actionLabel: 'Undo',
      onAction: () async {
        await provider.addTask(deletedTask);
      },
    );

    try {
      await provider.deleteTask(task.id!);
    } catch (e) {
      debugPrint('Permanent task delete failed: $e');
    }
  }

  static Color priorityColor(String priority, ColorScheme cs) {
    return switch (priority) {
      'High' => Colors.redAccent,
      'Medium' => Colors.orangeAccent,
      'Low' => Colors.green,
      _ => cs.outline,
    };
  }

  static String formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(d.year, d.month, d.day);

    if (date == today) return 'Today';
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    if (date.difference(today).inDays > -7) {
      return '${date.difference(today).inDays.abs()}d ago';
    }
    return '${d.month}/${d.day}';
  }

  static Future<void> toggleComplete(
    BuildContext parentContext,
    TaskModel task,
  ) async {
    if (task.id == null) return;

    final willBeCompleted = !task.isChecked;

    // Haptic feedback
    if (willBeCompleted) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
    }

    // Show snackbar IMMEDIATELY (before state changes)
    CustomSnackBar.show(
      parentContext,
      message: willBeCompleted ? 'Task completed!' : 'Task marked incomplete',
      type: willBeCompleted ? SnackBarType.success : SnackBarType.warning,
    );

    // Then update state
    final success = await Provider.of<TaskProvider>(
      parentContext,
      listen: false,
    ).toggleTaskCompletion(task.id!);

    if (success && willBeCompleted) {
      HapticFeedback.selectionClick();
    }
  }
}
