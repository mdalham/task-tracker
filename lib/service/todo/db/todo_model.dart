import 'package:uuid/uuid.dart';

class Todo {
  final String id;
  final String title;
  final String? description;
  final DateTime createdAt;
  final DateTime? dueDate;
  final DateTime? dueTime;
  final DateTime? reminderDateTime;
  final bool isCompleted;
  final DateTime? completedAt;
  final int? notificationId;
  final String? category;
  final int priority;
  final DateTime updatedAt;

  const Todo({
    required this.id,
    required this.title,
    this.description,
    required this.createdAt,
    this.dueDate,
    this.dueTime,
    this.reminderDateTime,
    this.isCompleted = false,
    this.completedAt,
    this.notificationId,
    this.category,
    this.priority = 0,
    required this.updatedAt,
  });

  factory Todo.create({
    required String title,
    String? description,
    DateTime? dueDate,
    DateTime? dueTime,
    DateTime? reminderDateTime,
    String? category,
    int priority = 0,
  }) {
    final now = DateTime.now();
    return Todo(
      id: const Uuid().v4(),
      title: title,
      description: description,
      createdAt: now,
      dueDate: dueDate,
      dueTime: dueTime,
      reminderDateTime: reminderDateTime,
      category: category,
      priority: priority,
      updatedAt: now,
    );
  }

  Todo copyWith({
    String? title,
    String? description,
    DateTime? dueDate,
    DateTime? dueTime,
    DateTime? reminderDateTime,
    bool? isCompleted,
    DateTime? completedAt,
    int? notificationId,
    String? category,
    int? priority,
  }) {
    return Todo(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      reminderDateTime: reminderDateTime ?? this.reminderDateTime,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      notificationId: notificationId ?? this.notificationId,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'due_time': dueTime?.toIso8601String(),
      'reminder_date_time': reminderDateTime?.toIso8601String(),
      'is_completed': isCompleted ? 1 : 0,
      'completed_at': completedAt?.toIso8601String(),
      'notification_id': notificationId,
      'category': category,
      'priority': priority,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Todo.fromMap(Map<String, dynamic> map) {
    return Todo(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date'] as String) : null,
      dueTime: map['due_time'] != null ? DateTime.parse(map['due_time'] as String) : null,
      reminderDateTime: map['reminder_date_time'] != null ? DateTime.parse(map['reminder_date_time'] as String) : null,
      isCompleted: (map['is_completed'] as int) == 1,
      completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at'] as String) : null,
      notificationId: map['notification_id'] as int?,
      category: map['category'] as String?,
      priority: map['priority'] as int? ?? 0,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  bool get isOverdue {
    if (isCompleted || dueDate == null) return false;
    final now = DateTime.now();
    final dueDateTime = _getCombinedDueDateTime();
    return dueDateTime.isBefore(now);
  }

  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    return dueDate!.year == now.year && dueDate!.month == now.month && dueDate!.day == now.day;
  }

  bool get isDueThisWeek {
    if (dueDate == null) return false;
    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));
    return dueDate!.isAfter(now) && dueDate!.isBefore(weekFromNow);
  }

  DateTime _getCombinedDueDateTime() {
    if (dueDate == null) return DateTime.now();
    if (dueTime == null) return dueDate!;
    return DateTime(dueDate!.year, dueDate!.month, dueDate!.day, dueTime!.hour, dueTime!.minute);
  }

  String get priorityName {
    switch (priority) {
      case 1: return 'Low';
      case 2: return 'Medium';
      case 3: return 'High';
      default: return 'None';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Todo && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class TodoStatistics {
  final int total;
  final int completed;
  final int pending;
  final int overdue;
  final int dueToday;
  final int dueThisWeek;

  const TodoStatistics({
    required this.total,
    required this.completed,
    required this.pending,
    required this.overdue,
    required this.dueToday,
    required this.dueThisWeek,
  });

  double get completionRate {
    if (total == 0) return 0.0;
    return (completed / total) * 100;
  }

  factory TodoStatistics.fromTodos(List<Todo> todos) {
    final completed = todos.where((t) => t.isCompleted).length;
    final pending = todos.where((t) => !t.isCompleted).length;
    final overdue = todos.where((t) => t.isOverdue).length;
    final dueToday = todos.where((t) => t.isDueToday && !t.isCompleted).length;
    final dueThisWeek = todos.where((t) => t.isDueThisWeek && !t.isCompleted).length;

    return TodoStatistics(
      total: todos.length,
      completed: completed,
      pending: pending,
      overdue: overdue,
      dueToday: dueToday,
      dueThisWeek: dueThisWeek,
    );
  }
}

enum TodoFilter { all, active, completed, overdue, today, week }
enum TodoSortBy { createdDate, dueDate, priority, title }
enum SortOrder { ascending, descending }