// REPLACE YOUR ENTIRE TaskProvider WITH THIS (Copy-Paste Ready)
import 'dart:async';
import 'package:flutter/material.dart';
import '../../notification/db/notification_db_helper.dart';
import '../../notification/service/notification_service.dart';
import '../db/recurrence_models.dart';
import '../db/tasks_db_helper.dart';
import '../db/tasks_models.dart';

enum TaskFilterType {
  all,
  today,
  overdue,
  completed,
  important,
  inProgress,
  recurring,
  category,
  priority,
}

class TaskProvider extends ChangeNotifier {
  // ================================================
  // SINGLETON & DEPENDENCIES
  // ================================================
  static TaskProvider? _instance;
  static TaskProvider get instance => _instance ??= TaskProvider._internal();

  final TaskDbHelper _dbHelper = TaskDbHelper.instance;
  final NotificationService _notificationService = NotificationService.instance;
  final NotificationHistoryDbHelper _historyDb =
      NotificationHistoryDbHelper.instance;

  VoidCallback? onTasksChanged;

  Timer? _autoCompleteTimer;
  bool _autoCompleteRunning = false;
  bool _notificationCheckRunning = false;

  TaskProvider._internal();

  // ================================================
  // TASK LISTS (CACHED)
  // ================================================
  List<TaskModel> _allTasks = [];
  List<TaskModel> _todayTasks = [];
  List<TaskModel> _overdueTasks = [];
  List<TaskModel> _completedTasks = [];
  List<TaskModel> _importantTasks = [];
  List<TaskModel> _inProgressTasks = [];
  List<TaskModel> _recurringTasks = [];

  // ================================================
  // FILTERING & SEARCH
  // ================================================
  List<TaskModel> _filteredTasks = [];
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedPriority;
  TaskFilterType _currentFilter = TaskFilterType.all;

  // ================================================
  // STATUS & STATS
  // ================================================
  bool _isLoading = false;
  bool _isInitialized = false;
  int _totalTaskCount = 0;
  int _completedTaskCount = 0;

  // ================================================
  // GETTERS
  // ================================================
  List<TaskModel> get allTasks => _allTasks;
  List<TaskModel> get todayTasks => _todayTasks;
  List<TaskModel> get overdueTasks => _overdueTasks;
  List<TaskModel> get completedTasks => _completedTasks;
  List<TaskModel> get importantTasks => _importantTasks;
  List<TaskModel> get recurringTasks => _recurringTasks;
  List<TaskModel> get filteredTasks => _filteredTasks;

  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;
  String? get selectedPriority => _selectedPriority;
  TaskFilterType get currentFilter => _currentFilter;

  int get totalTaskCount => _totalTaskCount;
  int get completedTaskCount => _completedTaskCount;
  int get incompleteTaskCount => _totalTaskCount - _completedTaskCount;
  double get completionRate =>
      _totalTaskCount > 0 ? _completedTaskCount / _totalTaskCount : 0.0;

  // ================================================
  // INITIALIZATION
  // ================================================
  Future<void> initialize() async {
    if (_isInitialized) return;

    loadAllTasks();
    _isLoading = true;
    notifyListeners();

    try {
      await loadAllTasks();
      await checkAndAutoCompleteTasks();
      await _scheduleAllTaskNotifications();

      _autoCompleteTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        unawaited(checkAndAutoCompleteTasks());
        unawaited(_checkAndTriggerNotifications());
      });

      _isInitialized = true;
      debugPrint(
        'TaskProvider initialized + auto-complete + notifications active (every 10s)',
      );
    } catch (e, s) {
      debugPrint('Initialization error: $e\n$s');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _autoCompleteTimer?.cancel();
    super.dispose();
  }

  void _notifyAndTrigger() {
    notifyListeners();
    if (onTasksChanged != null) {
      onTasksChanged!();
    }
  }

  // ================================================
  // NOTIFICATIONS: HYBRID SYSTEM (100% unchanged)
  // ================================================
  Future<void> _scheduleAllTaskNotifications() async {
    debugPrint('Scheduling notifications for all pending tasks...');
    for (final task in _allTasks) {
      if (!task.isChecked && task.id != null) {
        await _notificationService.scheduleTaskNotifications(task);
      }
    }
  }

  Future<void> _checkAndTriggerNotifications() async {
    if (_notificationCheckRunning) return;
    _notificationCheckRunning = true;
    final now = DateTime.now();
    final pending = _allTasks
        .where((t) => !t.isChecked && t.id != null)
        .toList();

    for (final task in pending) {
      // Main Reminder
      if (task.reminderDateTime != null &&
          _isTimeMatch(task.reminderDateTime!, now)) {
        await _triggerImmediate(task, task.reminderDateTime!, 'reminder');
      }
      // 5-Minute Alert
      if (task.date != null) {
        final fiveMin = task.date!.subtract(const Duration(minutes: 5));
        if (_isTimeMatch(fiveMin, now)) {
          await _triggerImmediate(task, fiveMin, '5-minute');
        }
      }
    }
    _notificationCheckRunning = false;
  }

  bool _isTimeMatch(DateTime target, DateTime now) {
    final diff = target.difference(now).inSeconds.abs();
    return diff <= 10;
  }

  Future<void> _triggerImmediate(
    TaskModel task,
    DateTime when,
    String type,
  ) async {
    final sentAtMs = when.millisecondsSinceEpoch;
    final exists = await _historyDb.exists(task.id!, type, sentAtMs);
    if (exists) return;

    final title = type == '5-minute'
        ? 'Starting soon: ${task.title}'
        : 'Reminder: ${task.title}';
    final body = type == '5-minute'
        ? 'Task begins in 5 minutes'
        : (task.description.isEmpty
              ? 'Time to do this task!'
              : task.description);

    await NotificationService.instance.triggerRealNotificationNow(task);
    debugPrint('Triggered immediate: $title');
  }

  void setFiveMinuteReminderEnabled(bool enabled) {
    _notificationService.setFiveMinuteReminderEnabled(enabled);
    unawaited(_rescheduleAllPendingTasks());
    notifyListeners();
  }

  Future<void> _rescheduleAllPendingTasks() async {
    final pending = _allTasks
        .where((t) => !t.isChecked && t.id != null)
        .toList();
    debugPrint('Rescheduling ${pending.length} pending tasks…');
    for (final t in pending) {
      await _notificationService.scheduleTaskNotifications(t);
    }
  }

  // ================================================
  // LOAD TASKS & AUTO-COMPLETE (unchanged)
  // ================================================
  Future<void> loadAllTasks() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('Loading all tasks from DB...');
      final allTasks = await _dbHelper.getAllTasks();
      final total = await _dbHelper.getTaskCount();
      final completed = await _dbHelper.getCompletedTaskCount();

      _allTasks = allTasks;
      _totalTaskCount = total;
      _completedTaskCount = completed;

      // RECOMPUTE ALL LISTS FROM _allTasks (SINGLE SOURCE OF TRUTH)
      _todayTasks = _computeTodayTasks();
      _overdueTasks = _computeOverdueTasks();
      _completedTasks = _computeCompletedTasks();
      _importantTasks = _computeImportantTasks();
      _inProgressTasks = _computeInProgressTasks();
      _recurringTasks = _computeRecurringTasks();

      _applyCurrentFilter();
      debugPrint('Loaded ${_allTasks.length} tasks → ALL LISTS UPDATED');
    } catch (e, s) {
      debugPrint('Error loading tasks: $e\n$s');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> checkAndAutoCompleteTasks() async {
    if (_autoCompleteRunning) return;
    _autoCompleteRunning = true;
    final now = DateTime.now().toLocal();
    debugPrint('Auto-complete check at: $now');

    try {
      final tasksToComplete = _allTasks.where((task) {
        if (task.isChecked || task.date == null) return false;
        return task.date!.isBefore(now);
      }).toList();

      if (tasksToComplete.isEmpty) {
        debugPrint('No overdue tasks to complete');
        return;
      }

      debugPrint(
        'Auto-completing ${tasksToComplete.length} overdue task(s)...',
      );
      for (final task in tasksToComplete) {
        if (task.id == null) continue;

        // THIS IS THE FIX — CALL YOUR METHOD, NOT DB DIRECTLY
        await toggleTaskCompletion(task.id!);
      }
    } catch (e, s) {
      debugPrint('Auto-complete error: $e\n$s');
    } finally {
      _autoCompleteRunning = false;
    }
  }

  // ================================================
  // FILTERING (unchanged)
  // ================================================
  void setFilter(TaskFilterType filter) {
    if (_currentFilter == filter) return;
    _currentFilter = filter;
    _applyCurrentFilter();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim().toLowerCase();
    _applyCurrentFilter();
  }

  void setCategoryFilter(String? category) {
    _selectedCategory = category;
    if (_currentFilter == TaskFilterType.category) _applyCurrentFilter();
  }

  void setPriorityFilter(String? priority) {
    _selectedPriority = priority;
    if (_currentFilter == TaskFilterType.priority) _applyCurrentFilter();
  }

  void _applyCurrentFilter() {
    var base = _getBaseList();
    if (_searchQuery.isNotEmpty) {
      base = base.where((t) {
        final title = t.title.toLowerCase();
        final desc = t.description.toLowerCase();
        return title.contains(_searchQuery) || desc.contains(_searchQuery);
      }).toList();
    }
    _filteredTasks = base;
    notifyListeners();
  }

  List<TaskModel> _getBaseList() {
    return switch (_currentFilter) {
      TaskFilterType.all => _allTasks,
      TaskFilterType.today => _todayTasks,
      TaskFilterType.overdue => _overdueTasks,
      TaskFilterType.completed => _completedTasks,
      TaskFilterType.important => _importantTasks,
      TaskFilterType.inProgress => _inProgressTasks,
      TaskFilterType.recurring => _recurringTasks,
      TaskFilterType.category =>
        _selectedCategory != null
            ? _allTasks.where((t) => t.category == _selectedCategory).toList()
            : _allTasks,
      TaskFilterType.priority =>
        _selectedPriority != null
            ? _allTasks.where((t) => t.priority == _selectedPriority).toList()
            : _allTasks,
    };
  }

  List<TaskModel> _computeTodayTasks() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    return _allTasks.where((t) {
      return !t.isChecked &&
          t.date != null &&
          t.date!.isAfter(start.subtract(const Duration(seconds: 1))) &&
          t.date!.isBefore(end);
    }).toList();
  }

  List<TaskModel> _computeOverdueTasks() {
    final now = DateTime.now();
    return _allTasks
        .where((t) => !t.isChecked && t.date != null && t.date!.isBefore(now))
        .toList();
  }

  List<TaskModel> _computeCompletedTasks() {
    return _allTasks.where((t) => t.isChecked).toList();
  }

  List<TaskModel> get inProgressTasks {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final start = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);

    return _inProgressTasks
        .where(
          (t) =>
              t.date != null &&
              t.date!.isAfter(start.subtract(const Duration(seconds: 1))),
        )
        .toList();
  }

  List<TaskModel> _computeImportantTasks() {
    return _allTasks.where((t) => t.isImportant && !t.isChecked).toList();
  }

  List<TaskModel> _computeInProgressTasks() {
    return _allTasks.where((t) => !t.isChecked).toList();
  }

  List<TaskModel> _computeRecurringTasks() {
    return _allTasks
        .where(
          (t) =>
              t.recurrenceSettings.type != RecurrenceType.none &&
              !t.isRecurringInstance,
        )
        .toList();
  }

  // ================================================
  // UPGRADED & FIXED CRUD + RECURRING SYSTEM
  // ================================================

  Future<int?> addTask(TaskModel task) async {
    try {
      final map = TaskDbHelper.instance.getTaskDbMap(task)..['id'] = null;
      final int? newId = await _dbHelper.insertTaskFromMap(map);
      if (newId == null) return null;

      final savedTask = task.copyWith(id: newId);
      await _notificationService.scheduleTaskNotifications(savedTask);
      await loadAllTasks();
      _notifyAndTrigger();
      return newId;
    } catch (e, s) {
      debugPrint('addTask error: $e\n$s');
      return null;
    }
  }

  Future<bool> updateTask(TaskModel task) async {
    if (task.id == null) return false;

    try {
      await _dbHelper.updateTask(task);
      notifyListeners();
      await loadAllTasks();
      return true;
    } catch (e, s) {
      debugPrint('updateTask error: $e\n$s');
      return false;
    }
  }

  Future<bool> toggleTaskCompletion(int id) async {
    final task = await _dbHelper.getTaskById(id);
    if (task == null) return false;

    final becomingCompleted = !task.isChecked;
    await _dbHelper.toggleTaskCompletion(id, becomingCompleted);

    if (becomingCompleted) {
      await _notificationService.cancelTaskNotifications(id);

      // ONLY CREATE NEXT RECURRING INSTANCE
      if (task.recurrenceSettings.type != RecurrenceType.none) {
        // CRITICAL FIX: Always calculate next date starting from NOW
        final DateTime calculationBase = DateTime.now();
        final DateTime? nextDate = task.recurrenceSettings
            .getNextOccurrenceAfter(
              task.date ?? calculationBase,
              fromDate: calculationBase,
            );

        if (nextDate != null &&
            (task.recurrenceSettings.endDate == null ||
                nextDate.isBefore(task.recurrenceSettings.endDate!) ||
                nextDate.isAtSameMomentAs(task.recurrenceSettings.endDate!))) {
          final nextInstance = task.createRecurringInstance(nextDate);

          final map = TaskDbHelper.instance.getTaskDbMap(nextInstance);
          map['id'] = null;
          map['parentTaskId'] = task.id.toString();

          final nextId = await _dbHelper.insertTaskFromMap(map);
          if (nextId != null) {
            final instanceWithId = nextInstance.copyWith(id: nextId);
            await _notificationService.scheduleTaskNotifications(
              instanceWithId,
            );
            debugPrint(
              'Next recurring instance created: "${instanceWithId.title}" → ${nextDate.toString().substring(0, 10)}',
            );
          }
        }
      }
    } else {
      // Task unchecked → reschedule
      final updatedTask = task.copyWith(isChecked: false, completedAt: null);
      await _notificationService.scheduleTaskNotifications(updatedTask);
    }
    debugPrint(' Completed: "${task.title}" (ID: ${task.id})');
    await loadAllTasks();
    return true;
  }

  Future<bool> deleteTask(int id) async {
    await _notificationService.cancelTaskNotifications(id);
    await _dbHelper.deleteTask(id);
    await loadAllTasks();
    _notifyAndTrigger();
    return true;
  }

  Future<bool> deleteRecurringTask(int parentTaskId) async {
    await _notificationService.cancelTaskNotifications(parentTaskId);
    final instances = _allTasks
        .where((t) => t.parentTaskId == parentTaskId.toString())
        .toList();
    for (final instance in instances) {
      if (instance.id != null) {
        await _notificationService.cancelTaskNotifications(instance.id!);
      }
    }
    await _dbHelper.deleteRecurringTaskWithInstances(parentTaskId);
    await loadAllTasks();
    return true;
  }

  Future<bool> deleteCompletedTasks() async {
    final completed = await _dbHelper.getCompletedTasks();
    for (final task in completed) {
      if (task.id != null) {
        await _notificationService.cancelTaskNotifications(task.id!);
      }
    }
    await _dbHelper.deleteCompletedTasks();
    await loadAllTasks();
    return true;
  }

  Future<bool> deleteAllTasks() async {
    await _notificationService.cancelAllNotifications();
    await _dbHelper.deleteAllTasks();
    await loadAllTasks();
    _notifyAndTrigger();
    return true;
  }

  // ================================================
  // STATS (unchanged)
  // ================================================
  Map<String, int> getCategoryStatistics() {
    final map = <String, int>{};
    for (final t in _allTasks) {
      final cat = t.category;
      if (cat.isNotEmpty) {
        map[cat] = (map[cat] ?? 0) + 1;
      }
    }
    return map;
  }

  Map<String, int> getPriorityStatistics() {
    final map = <String, int>{};
    for (final t in _allTasks) {
      final pri = t.priority;
      map[pri] = (map[pri] ?? 0) + 1;
    }
    return map;
  }

  Map<String, dynamic> getCompletionStatistics() => {
    'total': _totalTaskCount,
    'completed': _completedTaskCount,
    'incomplete': incompleteTaskCount,
    'completionRate': completionRate,
    'today': _todayTasks.length,
    'overdue': _overdueTasks.length,
    'important': _importantTasks.length,
  };

  void unawaited(Future<void> future) => future.ignore();
}
