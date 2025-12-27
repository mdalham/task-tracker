// lib/provider/notification_provider.dart
import 'package:flutter/foundation.dart';

import '../db/notification_db_helper.dart';
import '../db/notification_models.dart';

class NotificationProvider extends ChangeNotifier {
  // -------------------------------------------------
  // Singleton
  // -------------------------------------------------
  static final NotificationProvider _instance = NotificationProvider._internal();
  factory NotificationProvider() => _instance;
  NotificationProvider._internal();

  final _db = NotificationHistoryDbHelper.instance;

  List<NotificationHistory> _notifications = [];
  List<NotificationHistory> get notifications => _notifications;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // -------------------------------------------------
  // NEW: FILTERED GETTERS (OPTIONAL)
  // -------------------------------------------------

  /// Get only task notifications
  List<NotificationHistory> get taskNotifications =>
      _notifications.where((n) => n.notificationType.contains('reminder') || n.notificationType.contains('5-minute')).toList();

  /// Get only note notifications
  List<NotificationHistory> get noteNotifications =>
      _notifications.where((n) => n.notificationType == 'note_reminder').toList();

  /// Get only todo notifications
  List<NotificationHistory> get todoNotifications =>
      _notifications.where((n) => n.notificationType == 'todo_reminder').toList();

  /// Get only unread notifications
  List<NotificationHistory> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();

  /// Get notifications count by type
  int get taskCount => taskNotifications.length;
  int get noteCount => noteNotifications.length;
  int get todoCount => todoNotifications.length;

  // -------------------------------------------------
  // LOAD
  // -------------------------------------------------
  Future<void> loadNotifications() async {
    _isLoading = true;
    notifyListeners();

    _notifications = await _db.getAllNotifications();
    _unreadCount = await _db.getUnreadCount();

    _isLoading = false;
    notifyListeners();
  }

  // -------------------------------------------------
  // ADD – PREVENT DUPLICATES
  // -------------------------------------------------
  Future<void> addNotification(NotificationHistory item) async {
    // Always insert — background handler may have saved it
    // But skip if already exists to avoid DB error
    final exists = await _db.exists(
      item.taskId,
      item.notificationType,
      item.sentAt.millisecondsSinceEpoch,
    );

    if (!exists) {
      await _db.insert(item);
      debugPrint('Notification added to DB: ${item.taskTitle}');
    } else {
      debugPrint('Notification already in DB: ${item.taskTitle}');
    }

    // Always refresh list from DB — ensures sync with background
    await _refresh();

    // Always notify UI — badge must update
    notifyListeners();
  }

  // -------------------------------------------------
  // MARK AS READ
  // -------------------------------------------------
  Future<void> markAsRead(int id) async {
    await _db.markAsRead(id);
    await _refresh();
  }

  // -------------------------------------------------
  // MARK ALL AS READ
  // -------------------------------------------------
  Future<void> markAllAsRead() async {
    await _db.markAllAsRead();
    await _refresh();
  }

  // -------------------------------------------------
  // DELETE SINGLE
  // -------------------------------------------------
  Future<void> delete(int id) async {
    await _db.delete(id);
    await _refresh();
  }

  // -------------------------------------------------
  // DELETE BY TASK + TYPE (for cancel)
  // -------------------------------------------------
  Future<void> deleteByTaskAndType(int taskId, String type) async {
    await _db.deleteByTaskIdAndType(taskId, type);
    await _refresh();
  }

  // -------------------------------------------------
  // DELETE ALL
  // -------------------------------------------------
  Future<void> deleteAll() async {
    await _db.deleteAll();
    await _refresh();
  }

  // -------------------------------------------------
  // NEW: DELETE BY TYPE (OPTIONAL)
  // -------------------------------------------------

  /// Delete all todo notifications
  Future<void> deleteAllTodoNotifications() async {
    final todoIds = todoNotifications.map((n) => n.id).whereType<int>().toList();
    for (final id in todoIds) {
      await _db.delete(id);
    }
    await _refresh();
  }

  /// Delete all task notifications
  Future<void> deleteAllTaskNotifications() async {
    final taskIds = taskNotifications.map((n) => n.id).whereType<int>().toList();
    for (final id in taskIds) {
      await _db.delete(id);
    }
    await _refresh();
  }

  /// Delete all note notifications
  Future<void> deleteAllNoteNotifications() async {
    final noteIds = noteNotifications.map((n) => n.id).whereType<int>().toList();
    for (final id in noteIds) {
      await _db.delete(id);
    }
    await _refresh();
  }

  // -------------------------------------------------
  // NEW: GET SPECIFIC NOTIFICATION (OPTIONAL)
  // -------------------------------------------------

  /// Get notification by ID
  NotificationHistory? getNotificationById(int id) {
    try {
      return _notifications.firstWhere((n) => n.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Check if notification exists in memory
  bool hasNotification(int taskId, String type) {
    return _notifications.any(
          (n) => n.taskId == taskId && n.notificationType == type,
    );
  }

  // -------------------------------------------------
  // NEW: STATISTICS (OPTIONAL)
  // -------------------------------------------------

  /// Get notification statistics
  Map<String, int> get statistics => {
    'total': _notifications.length,
    'unread': _unreadCount,
    'tasks': taskCount,
    'notes': noteCount,
    'todos': todoCount,
  };

  // -------------------------------------------------
  // INTERNAL REFRESH
  // -------------------------------------------------
  Future<void> _refresh() async {
    _notifications = await _db.getAllNotifications();
    _unreadCount = await _db.getUnreadCount();
    notifyListeners();
  }

  // -------------------------------------------------
  // CLEANUP
  // -------------------------------------------------
  @override
  void dispose() {
    _notifications.clear();
    super.dispose();
  }
}