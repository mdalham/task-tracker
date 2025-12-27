import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tasktracker/service/task/db/recurrence_models.dart';

class TaskModel {
  // -----------------------------------------------------------------
  // Core fields
  // -----------------------------------------------------------------
  int? id;
  String title;
  String description;
  String category;
  String priority; // None, Low, Medium, High
  DateTime? date; // <-- **only one** date-time field
  bool isImportant;
  bool isChecked;

  // -----------------------------------------------------------------
  // Recurrence
  // -----------------------------------------------------------------
  RecurrenceSettings recurrenceSettings;
  String? parentTaskId;
  bool isRecurringInstance;
  DateTime? originalDate;

  // -----------------------------------------------------------------
  // Reminder
  // -----------------------------------------------------------------
  bool reminderEnabled;
  DateTime? reminderDateTime;

  // -----------------------------------------------------------------
  // Checklist (sub-tasks)
  // -----------------------------------------------------------------
  List<TaskModel> checklistTask;

  // -----------------------------------------------------------------
  // Timestamps
  // -----------------------------------------------------------------
  final DateTime createdAt;
  DateTime? updatedAt;
  DateTime? completedAt;

  // -----------------------------------------------------------------
  // Constructor
  // -----------------------------------------------------------------
  TaskModel({
    this.id,
    this.title = '',
    this.description = '',
    this.category = '',
    this.priority = 'None',
    this.date,
    this.isImportant = false,
    this.isChecked = false,
    RecurrenceSettings? recurrenceSettings,
    this.parentTaskId,
    this.isRecurringInstance = false,
    this.originalDate,
    this.reminderEnabled = false,
    this.reminderDateTime,
    List<TaskModel>? checklistTask,
    DateTime? createdAt,
    this.updatedAt,
    this.completedAt,
  }) : checklistTask = checklistTask ?? [],
        recurrenceSettings = recurrenceSettings ?? RecurrenceSettings(),
        createdAt = createdAt ?? DateTime.now();

  // -----------------------------------------------------------------
  // COPY WITH
  // -----------------------------------------------------------------
  TaskModel copyWith({
    int? id,
    String? title,
    String? description,
    String? category,
    String? priority,
    DateTime? date,
    bool? isImportant,
    bool? isChecked,
    RecurrenceSettings? recurrenceSettings,
    String? parentTaskId,
    bool? isRecurringInstance,
    DateTime? originalDate,
    bool? reminderEnabled,
    DateTime? reminderDateTime,
    List<TaskModel>? checklistTask,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      date: date ?? this.date,
      isImportant: isImportant ?? this.isImportant,
      isChecked: isChecked ?? this.isChecked,
      recurrenceSettings: recurrenceSettings ?? this.recurrenceSettings,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      isRecurringInstance: isRecurringInstance ?? this.isRecurringInstance,
      originalDate: originalDate ?? this.originalDate,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderDateTime: reminderDateTime ?? this.reminderDateTime,
      checklistTask: checklistTask ?? List.from(this.checklistTask),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  // -----------------------------------------------------------------
  // RECURRING HELPERS
  // -----------------------------------------------------------------
  bool shouldGenerateNextOccurrence() {
    return recurrenceSettings.type != RecurrenceType.none &&
        !isRecurringInstance &&
        date != null;
  }

  DateTime? getNextOccurrenceDate({DateTime? fromDate}) {
    if (!shouldGenerateNextOccurrence() || date == null) return null;
    return recurrenceSettings.getNextOccurrenceAfter(date!, fromDate: fromDate ?? DateTime.now());
  }

  TaskModel createRecurringInstance(DateTime newDate) {
    // Preserve the original time of day
    final newDateTime = DateTime(
      newDate.year,
      newDate.month,
      newDate.day,
      date!.hour,
      date!.minute,
    );

    return copyWith(
      id: null,
      date: newDateTime,
      parentTaskId: id?.toString(),
      isRecurringInstance: true,
      originalDate: date,
      isChecked: false,
      completedAt: null,
      createdAt: DateTime.now(),
      updatedAt: null,
    )..id = null;
  }

  // -----------------------------------------------------------------
  // MARK COMPLETE / INCOMPLETE
  // -----------------------------------------------------------------
  void markAsCompleted() {
    isChecked = true;
    completedAt = DateTime.now();
    updatedAt = DateTime.now();
  }

  void markAsIncomplete() {
    isChecked = false;
    completedAt = null;
    updatedAt = DateTime.now();
  }

  // -----------------------------------------------------------------
  // UI HELPERS (optional – you can keep them)
  // -----------------------------------------------------------------
  TimeOfDay? get timeOfDay =>
      date != null ? TimeOfDay.fromDateTime(date!) : null;

  String get formattedDate => date != null
      ? DateFormat('EEE, MMM d • h:mm a').format(date!)
      : 'No date';

  // -----------------------------------------------------------------
  // TIMESTAMP (relative)
  // -----------------------------------------------------------------
  String get timestamp {
    final now = DateTime.now();
    final updated = this.updatedAt;

    if (updated == null || updated.isAtSameMomentAs(createdAt)) {
      return _formatRelative(createdAt, now, prefix: 'Created');
    }

    final today = DateTime(now.year, now.month, now.day);
    final editDay = DateTime(updated.year, updated.month, updated.day);
    if (editDay == today) {
      return _formatRelative(updated, now, prefix: 'Edited');
    }

    return 'Edited ${DateFormat('MMM d, yyyy').format(updated)}';
  }

  String _formatRelative(
      DateTime date,
      DateTime now, {
        required String prefix,
      }) {
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return '$prefix just now';
    if (diff.inMinutes < 60) return '$prefix ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '$prefix ${diff.inHours}h ago';
    if (diff.inDays < 7) return '$prefix ${diff.inDays}d ago';
    return '$prefix ${DateFormat('MMM d').format(date)}';
  }

  // -----------------------------------------------------------------
  // TO / FROM MAP (SQLite)
  // -----------------------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'id': isRecurringInstance ? null : id,
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'date': date?.toIso8601String(), // <-- full datetime
      'isImportant': isImportant ? 1 : 0,
      'isChecked': isChecked ? 1 : 0,
      'recurrenceSettings': recurrenceSettings.toMap(),
      'parentTaskId': parentTaskId,
      'isRecurringInstance': isRecurringInstance ? 1 : 0,
      'originalDate': originalDate?.toIso8601String(),
      'reminderEnabled': reminderEnabled ? 1 : 0,
      'reminderDateTime': reminderDateTime?.toIso8601String(),
      'checklist': checklistTask.isNotEmpty
          ? jsonEncode(checklistTask.map((e) => e.toMap()).toList())
          : null,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    final List<TaskModel> checklist = [];
    if (map['checklist'] != null && map['checklist'] is String) {
      try {
        final List<dynamic> raw = jsonDecode(map['checklist'] as String);
        checklist.addAll(
          raw.map((e) => TaskModel.fromMap(Map<String, dynamic>.from(e))),
        );
      } catch (e) {
        debugPrint('Checklist parse error: $e');
      }
    }

    return TaskModel(
      id: map['id'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      priority: map['priority'] ?? 'None',
      date: map['date'] != null ? DateTime.parse(map['date']) : null,
      isImportant: (map['isImportant'] ?? 0) == 1,
      isChecked: (map['isChecked'] ?? 0) == 1,
      recurrenceSettings: map['recurrenceSettings'] != null
          ? RecurrenceSettings.fromMap(
        Map<String, dynamic>.from(map['recurrenceSettings']),
      )
          : RecurrenceSettings(),
      parentTaskId: map['parentTaskId'],
      isRecurringInstance: (map['isRecurringInstance'] ?? 0) == 1,
      originalDate: map['originalDate'] != null
          ? DateTime.parse(map['originalDate'])
          : null,
      reminderEnabled: (map['reminderEnabled'] ?? 0) == 1,
      reminderDateTime: map['reminderDateTime'] != null
          ? DateTime.parse(map['reminderDateTime'])
          : null,
      checklistTask: checklist,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : null,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'])
          : null,
    );
  }



  @override
  String toString() => 'TaskModel(id: $id, title: $title, date: $date)';
}
