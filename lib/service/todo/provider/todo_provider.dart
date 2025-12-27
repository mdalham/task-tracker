// lib/providers/todo_provider.dart

import 'package:flutter/foundation.dart';
import '../../notification/service/notification_service.dart';
import '../db/database_service.dart';
import '../db/todo_model.dart';

class TodoProvider with ChangeNotifier {
  final DatabaseService _databaseService;
  final NotificationService _notificationService;

  List<Todo> _todos = [];
  bool _isLoading = false;
  String? _errorMessage;
  TodoFilter _currentFilter = TodoFilter.all;
  TodoSortBy _sortBy = TodoSortBy.createdDate;
  SortOrder _sortOrder = SortOrder.descending;
  String _searchQuery = '';

  TodoProvider({
    DatabaseService? databaseService,
    NotificationService? notificationService,
  })  : _databaseService = databaseService ?? DatabaseService.instance,
        _notificationService = notificationService ?? NotificationService.instance {
    _initialize();
  }

  List<Todo> get todos => _getFilteredAndSortedTodos();
  List<Todo> get allTodos => List.unmodifiable(_todos);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  TodoFilter get currentFilter => _currentFilter;
  TodoSortBy get sortBy => _sortBy;
  SortOrder get sortOrder => _sortOrder;
  String get searchQuery => _searchQuery;

  int get totalCount => _todos.length;
  int get activeCount => _todos.where((t) => !t.isCompleted).length;
  int get completedCount => _todos.where((t) => t.isCompleted).length;
  int get overdueCount => _todos.where((t) => t.isOverdue).length;
  int get dueTodayCount => _todos.where((t) => t.isDueToday && !t.isCompleted).length;

  TodoStatistics get statistics => TodoStatistics.fromTodos(_todos);

  Future<void> _initialize() async {
    await _notificationService.initialize();
    await loadTodos();
  }

  Future<void> loadTodos() async {
    _setLoading(true);
    _clearError();

    try {
      _todos = await _databaseService.getAllTodos();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load todos: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshTodos() async {
    await loadTodos();
  }

  Future<bool> addTodo({
    required String title,
    String? description,
    DateTime? dueDate,
    DateTime? dueTime,
    DateTime? reminderDateTime,
    String? category,
    int priority = 0,
  }) async {
    _clearError();

    try {
      if (title.trim().isEmpty) {
        _setError('Title cannot be empty');
        return false;
      }

      final todo = Todo.create(
        title: title.trim(),
        description: description?.trim(),
        dueDate: dueDate,
        dueTime: dueTime,
        reminderDateTime: reminderDateTime,
        category: category?.trim(),
        priority: priority,
      );

      await _databaseService.createTodo(todo);

      int? notificationId;
      if (reminderDateTime != null && reminderDateTime.isAfter(DateTime.now())) {
        try {
          notificationId = await _notificationService.scheduleTodoNotification(todo);
          final updatedTodo = todo.copyWith(notificationId: notificationId);
          await _databaseService.updateTodo(updatedTodo);
          _todos.add(updatedTodo);
        } catch (e) {
          debugPrint('Failed to schedule notification: $e');
          _todos.add(todo);
        }
      } else {
        _todos.add(todo);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to add todo: $e');
      return false;
    }
  }

  Future<bool> updateTodo({
    required String id,
    String? title,
    String? description,
    DateTime? dueDate,
    DateTime? dueTime,
    DateTime? reminderDateTime,
    String? category,
    int? priority,
  }) async {
    _clearError();

    try {
      final index = _todos.indexWhere((t) => t.id == id);
      if (index == -1) {
        _setError('Todo not found');
        return false;
      }

      final oldTodo = _todos[index];

      if (oldTodo.notificationId != null) {
        await _notificationService.cancelNotification(oldTodo.notificationId!);
      }

      final updatedTodo = oldTodo.copyWith(
        title: title,
        description: description,
        dueDate: dueDate,
        dueTime: dueTime,
        reminderDateTime: reminderDateTime,
        category: category,
        priority: priority,
      );

      await _databaseService.updateTodo(updatedTodo);

      int? notificationId;
      if (reminderDateTime != null && reminderDateTime.isAfter(DateTime.now())) {
        try {
          notificationId = await _notificationService.scheduleTodoNotification(updatedTodo);
          final todoWithNotification = updatedTodo.copyWith(notificationId: notificationId);
          await _databaseService.updateTodo(todoWithNotification);
          _todos[index] = todoWithNotification;
        } catch (e) {
          debugPrint('Failed to schedule notification: $e');
          _todos[index] = updatedTodo;
        }
      } else {
        _todos[index] = updatedTodo;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update todo: $e');
      return false;
    }
  }
  // In todo_provider.dart - ADD THIS METHOD

  Future<bool> restoreTodo(Todo todo) async {
    _clearError();

    try {
      // Create todo with exact same data (including ID)
      await _databaseService.createTodo(todo);

      // Reschedule notification if it had one
      if (todo.reminderDateTime != null &&
          todo.reminderDateTime!.isAfter(DateTime.now())) {
        try {
          final notificationId = await _notificationService
              .scheduleTodoNotification(todo);
          final updatedTodo = todo.copyWith(notificationId: notificationId);
          await _databaseService.updateTodo(updatedTodo);
          _todos.add(updatedTodo);
        } catch (e) {
          debugPrint('Failed to schedule notification: $e');
          _todos.add(todo);
        }
      } else {
        _todos.add(todo);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to restore todo: $e');
      return false;
    }
  }

  Future<bool> toggleTodoCompletion(String id) async {
    _clearError();

    try {
      final index = _todos.indexWhere((t) => t.id == id);
      if (index == -1) {
        _setError('Todo not found');
        return false;
      }

      final oldTodo = _todos[index];
      final updatedTodo = oldTodo.copyWith(
        isCompleted: !oldTodo.isCompleted,
        completedAt: !oldTodo.isCompleted ? DateTime.now() : null,
      );

      await _databaseService.updateTodo(updatedTodo);

      if (updatedTodo.isCompleted && oldTodo.notificationId != null) {
        await _notificationService.cancelNotification(oldTodo.notificationId!);
      }

      if (updatedTodo.isCompleted) {
        await _notificationService.showTodoCompletedNotification(updatedTodo);
      }

      _todos[index] = updatedTodo;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to toggle todo: $e');
      return false;
    }
  }

  Future<bool> deleteTodo(String id) async {
    _clearError();

    try {
      final index = _todos.indexWhere((t) => t.id == id);
      if (index == -1) {
        _setError('Todo not found');
        return false;
      }

      final todo = _todos[index];

      if (todo.notificationId != null) {
        await _notificationService.cancelNotification(todo.notificationId!);
      }

      await _databaseService.deleteTodo(id);

      _todos.removeAt(index);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to delete todo: $e');
      return false;
    }
  }

  Future<bool> deleteCompletedTodos() async {
    _clearError();

    try {
      await _databaseService.deleteCompletedTodos();
      _todos.removeWhere((t) => t.isCompleted);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to delete completed todos: $e');
      return false;
    }
  }

  Future<bool> deleteAllTodos() async {
    _clearError();

    try {
      await _notificationService.cancelAllNotifications();
      await _databaseService.deleteAllTodos();
      _todos.clear();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to delete all todos: $e');
      return false;
    }
  }

  void setFilter(TodoFilter filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  void setSortBy(TodoSortBy sortBy) {
    if (_sortBy == sortBy) {
      _sortOrder = _sortOrder == SortOrder.ascending ? SortOrder.descending : SortOrder.ascending;
    } else {
      _sortBy = sortBy;
      _sortOrder = SortOrder.descending;
    }
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  List<Todo> _getFilteredAndSortedTodos() {
    var filtered = _todos;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((todo) {
        return todo.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (todo.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      }).toList();
    }

    switch (_currentFilter) {
      case TodoFilter.active:
        filtered = filtered.where((t) => !t.isCompleted).toList();
        break;
      case TodoFilter.completed:
        filtered = filtered.where((t) => t.isCompleted).toList();
        break;
      case TodoFilter.overdue:
        filtered = filtered.where((t) => t.isOverdue).toList();
        break;
      case TodoFilter.today:
        filtered = filtered.where((t) => t.isDueToday && !t.isCompleted).toList();
        break;
      case TodoFilter.week:
        filtered = filtered.where((t) => t.isDueThisWeek && !t.isCompleted).toList();
        break;
      case TodoFilter.all:
      default:
        break;
    }

    filtered.sort((a, b) {
      int comparison = 0;

      switch (_sortBy) {
        case TodoSortBy.title:
          comparison = a.title.compareTo(b.title);
          break;
        case TodoSortBy.dueDate:
          if (a.dueDate == null && b.dueDate == null) {
            comparison = 0;
          } else if (a.dueDate == null) {
            comparison = 1;
          } else if (b.dueDate == null) {
            comparison = -1;
          } else {
            comparison = a.dueDate!.compareTo(b.dueDate!);
          }
          break;
        case TodoSortBy.priority:
          comparison = b.priority.compareTo(a.priority);
          break;
        case TodoSortBy.createdDate:
        default:
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
      }

      return _sortOrder == SortOrder.ascending ? comparison : -comparison;
    });

    return filtered;
  }

  Future<List<String>> getCategories() async {
    try {
      return await _databaseService.getAllCategories();
    } catch (e) {
      debugPrint('Failed to get categories: $e');
      return [];
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  Todo? getTodoById(String id) {
    try {
      return _todos.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }


  @override
  void dispose() {
    _todos.clear();
    super.dispose();
  }
}