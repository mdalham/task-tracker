// lib/model/notification/notification_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:workmanager/workmanager.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../../note/db/notes_models.dart';
import '../../task/db/tasks_models.dart';
import '../db/notification_db_helper.dart';
import '../db/notification_models.dart';
import '../provider/notification_provider.dart';

class NotificationService {
  // Singleton
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();
  factory NotificationService() => instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  bool fiveMinuteReminderEnabled = true;
  NotificationProvider? _provider;

  FlutterLocalNotificationsPlugin get plugin => _plugin;

  // ID HELPERS
  static int mainReminderId(int taskId) => taskId * 10;
  static int fiveMinuteReminderId(int taskId) => taskId * 10 + 1;
  static int noteReminderId(int noteId) => 500000 + noteId;

  // INITIALIZE
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('Initialising Reliable NotificationService…');

    tz_data.initializeTimeZones();
    _setLocalTz();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: android, iOS: ios);

    final bool? ok = await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleTap,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    if (ok != true) {
      debugPrint('Local notifications init failed or denied');
    } else {
      debugPrint('Local notifications initialized');
    }

    await _createChannel();

    if (Platform.isAndroid) {
      await AndroidAlarmManager.initialize();
      debugPrint('AndroidAlarmManager initialized');
    }

    _isInitialized = true;
    debugPrint(
      'Reliable NotificationService ready (Task + Note + Todo reminders)',
    );
  }

  void _setLocalTz() {
    try {
      final locationName = tz.local.name;
      tz.setLocalLocation(tz.getLocation(locationName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));
    }
  }

  Future<void> _createChannel() async {
    if (!Platform.isAndroid) return;
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        'task_reminders',
        'Tasks & Notes Reminders',
        description: 'Reminders for tasks and notes',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      ),
    );
  }

  // TASK NOTIFICATIONS
  Future<void> scheduleTaskNotifications(TaskModel task) async {
    if (!_isInitialized) await initialize();
    if (task.id == null || task.isChecked) return;

    await _cancelAllForTask(task.id!);

    if (task.reminderDateTime != null) {
      await _scheduleTask(task, task.reminderDateTime!, type: 'reminder');
      _scheduleTaskAlarm(task, task.reminderDateTime!, type: 'reminder');
    }
    if (fiveMinuteReminderEnabled && task.date != null) {
      final fiveMin = task.date!.subtract(const Duration(minutes: 5));
      if (fiveMin.isAfter(DateTime.now().add(const Duration(seconds: 5)))) {
        await _scheduleTask(task, fiveMin, type: '5-minute');
        _scheduleTaskAlarm(task, fiveMin, type: '5-minute');
      }
    }
  }

  // NOTE NOTIFICATIONS
  Future<void> scheduleNoteReminder(NoteModels note) async {
    if (!_isInitialized) await initialize();
    if (note.id == null || note.reminder == null) return;

    await cancelNoteReminder(note.id!);

    final when = note.reminder!;
    if (when.isBefore(DateTime.now().subtract(const Duration(seconds: 10))))
      return;

    await _scheduleNote(note, when);
    _scheduleNoteAlarm(note, when);
  }

  Future<void> cancelNoteReminder(int noteId) async {
    final id = noteReminderId(noteId);
    await _plugin.cancel(id);
    if (Platform.isAndroid) {
      await Workmanager().cancelByUniqueName(id.toString());
      await AndroidAlarmManager.cancel(id);
    }
  }

  // INTERNAL: Task Scheduling
  Future<void> _scheduleTask(
    TaskModel task,
    DateTime when, {
    required String type,
  }) async {
    final alarmId = type == '5-minute'
        ? fiveMinuteReminderId(task.id!)
        : mainReminderId(task.id!);
    final title = type == '5-minute'
        ? 'Starting soon: ${task.title}'
        : 'Reminder: ${task.title}';

    final payloadMap = {
      'kind': 'task',
      'taskId': task.id!,
      'taskTitle': task.title,
      'taskDescription': task.description,
      'taskCategory': task.category ?? '',
      'taskPriority': task.priority ?? '',
      'taskDate': task.date?.millisecondsSinceEpoch ?? 0,
      'type': type,
      'sentAt': when.millisecondsSinceEpoch,
    };

    await _scheduleUniversal(alarmId, payloadMap, when, title);
  }

  void _scheduleTaskAlarm(
    TaskModel task,
    DateTime when, {
    required String type,
  }) {
    if (!Platform.isAndroid) return;
    final alarmId = type == '5-minute'
        ? fiveMinuteReminderId(task.id!)
        : mainReminderId(task.id!);
    final payloadMap = {
      'kind': 'task',
      'taskId': task.id!,
      'taskTitle': task.title,
      'taskDescription': task.description,
      'taskCategory': task.category ?? '',
      'taskPriority': task.priority ?? '',
      'taskDate': task.date?.millisecondsSinceEpoch ?? 0,
      'type': type,
      'sentAt': when.millisecondsSinceEpoch,
    };
    _scheduleAlarmUniversal(alarmId, payloadMap, when);
  }

  // INTERNAL: Note Scheduling
  Future<void> _scheduleNote(NoteModels note, DateTime when) async {
    final alarmId = noteReminderId(note.id!);
    final title = note.title.isEmpty
        ? 'Note Reminder'
        : 'Reminder: ${note.title}';

    final payloadMap = {
      'kind': 'note',
      'noteId': note.id!,
      'noteTitle': note.title,
      'noteContent': note.content,
      'noteCategory': note.category,
      'sentAt': when.millisecondsSinceEpoch,
    };

    await _scheduleUniversal(alarmId, payloadMap, when, title);
  }

  void _scheduleNoteAlarm(NoteModels note, DateTime when) {
    if (!Platform.isAndroid) return;
    final alarmId = noteReminderId(note.id!);
    final payloadMap = {
      'kind': 'note',
      'noteId': note.id!,
      'noteTitle': note.title,
      'noteContent': note.content,
      'noteCategory': note.category,
      'sentAt': when.millisecondsSinceEpoch,
    };
    _scheduleAlarmUniversal(alarmId, payloadMap, when);
  }

  // UNIVERSAL SCHEDULERS (shared logic)
  Future<void> _scheduleUniversal(
    int id,
    Map<String, dynamic> payloadMap,
    DateTime when,
    String debugTitle,
  ) async {
    final payload = jsonEncode(payloadMap);
    final delay = when.difference(DateTime.now());

    if (delay.isNegative) {
      await _showFromPayload(payloadMap);
      return;
    }

    await Workmanager().registerOneOffTask(
      id.toString(),
      'universal_notification',
      inputData: {'payload': payload},
      initialDelay: delay,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.notRequired),
    );
    debugPrint('WorkManager → $debugTitle (ID: $id)');
  }

  void _scheduleAlarmUniversal(
    int id,
    Map<String, dynamic> payloadMap,
    DateTime when,
  ) {
    AndroidAlarmManager.oneShotAt(
      when,
      id,
      universalAlarmCallback,
      exact: true,
      wakeup: true,
      allowWhileIdle: true,
      alarmClock: true,
      rescheduleOnReboot: true,
      params: payloadMap,
    );
    debugPrint('AlarmManager → ID: $id @ $when');
  }

  // SHOW NOTIFICATION
  Future<void> _showFromPayload(Map<String, dynamic> data) async {
    final kind = data['kind'] as String?;

    if (kind == 'todo') {
      // TODO REMINDER ← ADDED THIS BLOCK
      final todoId = data['todoId'] as String?;
      if (todoId == null) return;

      final id = todoId.hashCode.abs();
      final title = 'Reminder: ${data['todoTitle'] as String? ?? 'Todo'}'
          .trim();
      final body = (data['todoDescription'] as String?)?.trim();
      final finalBody = body?.isNotEmpty == true
          ? body!
          : 'You have a todo reminder';

      await _showNotification(id, title, finalBody, jsonEncode(data));
      await _saveTodoHistory(data);
    } else if (kind == 'note') {
      // NOTE REMINDER
      final noteId = data['noteId'] as int?;
      if (noteId == null) return;

      final id = noteReminderId(noteId);
      final title = 'Reminder: ${data['noteTitle'] as String? ?? 'Note'}'
          .trim();
      final body = (data['noteContent'] as String?)?.trim();
      final finalBody = body?.isNotEmpty == true
          ? body!
          : 'You have a note reminder';

      await _showNotification(id, title, finalBody, jsonEncode(data));
      await _saveNoteHistory(data);
    } else if (kind == 'task' || kind == null) {
      // TASK REMINDER
      final taskId = data['taskId'] as int?;
      if (taskId == null) return;

      final type = data['type'] as String? ?? 'reminder';
      final id = type == '5-minute'
          ? fiveMinuteReminderId(taskId)
          : mainReminderId(taskId);

      final title = type == '5-minute'
          ? 'Starting soon: ${data['taskTitle'] as String? ?? 'Task'}'
          : 'Reminder: ${data['taskTitle'] as String? ?? 'Task'}';

      final bodyRaw = data['taskDescription'] as String?;
      final body = type == '5-minute'
          ? 'Task begins in 5 minutes'
          : (bodyRaw?.isNotEmpty == true ? bodyRaw! : 'Time to do this task!');

      await _showNotification(id, title.trim(), body, jsonEncode(data));
      await _saveTaskHistory(data);
    }
  }

  Future<void> showNotificationFromMap(Map<String, dynamic> data) async =>
      await _showFromPayload(data);

  Future<void> _showNotification(
    int id,
    String title,
    String body,
    String payload,
  ) async {
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Tasks & Notes Reminders',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          showWhen: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  Future<void> _saveTaskHistory(Map<String, dynamic> data) async =>
      await _saveHistory(data, isNote: false, isTodo: false);
  Future<void> _saveNoteHistory(Map<String, dynamic> data) async =>
      await _saveHistory(data, isNote: true, isTodo: false);
  Future<void> _saveTodoHistory(Map<String, dynamic> data) async =>
      await _saveHistory(data, isNote: false, isTodo: true);

  Future<void> _saveHistory(
    Map<String, dynamic> data, {
    required bool isNote,
    required bool isTodo,
  }) async {
    final history = NotificationHistory(
      taskId: isTodo
          ? (int.tryParse(data['todoId']?.toString() ?? '0') ?? 0)
          : (isNote ? data['noteId'] as int : data['taskId'] as int),
      taskTitle: isTodo
          ? (data['todoTitle'] as String? ?? '')
          : (isNote
                ? (data['noteTitle'] as String? ?? '')
                : (data['taskTitle'] as String? ?? '')),
      notificationType: isTodo
          ? 'todo_reminder'
          : (isNote ? 'note_reminder' : (data['type'] as String? ?? 'unknown')),
      sentAt: DateTime.fromMillisecondsSinceEpoch(data['sentAt'] as int),
      taskDescription: isTodo
          ? (data['todoDescription'] as String? ?? '')
          : (isNote
                ? (data['noteContent'] as String? ?? '')
                : (data['taskDescription'] as String? ?? '')),
      taskCategory: isTodo
          ? 'Todo'
          : (isNote
                ? (data['noteCategory'] as String? ?? '')
                : (data['taskCategory'] as String? ?? '')),
      taskPriority: data['taskPriority'] as String? ?? '',
      taskDate: data['taskDate'] != null && data['taskDate'] != 0
          ? DateTime.fromMillisecondsSinceEpoch(data['taskDate'] as int)
          : (data['reminderDateTime'] != null
                ? DateTime.parse(data['reminderDateTime'] as String)
                : null),
      isRead: false,
    );
    await NotificationHistoryDbHelper.instance.insert(history);
    _provider?.addNotification(history);
  }

  // CANCEL HELPERS
  Future<void> _cancelAllForTask(int taskId) async {
    final mainId = mainReminderId(taskId);
    final fiveId = fiveMinuteReminderId(taskId);
    await _plugin.cancel(mainId);
    await _plugin.cancel(fiveId);
    if (Platform.isAndroid) {
      await Workmanager().cancelByUniqueName(mainId.toString());
      await Workmanager().cancelByUniqueName(fiveId.toString());
      await AndroidAlarmManager.cancel(mainId);
      await AndroidAlarmManager.cancel(fiveId);
    }
  }

  Future<void> cancelTaskNotifications(int taskId) async =>
      await _cancelAllForTask(taskId);

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
    if (Platform.isAndroid) {
      for (int i = 0; i < 600000; i++) {
        await Workmanager().cancelByUniqueName(i.toString());
        await AndroidAlarmManager.cancel(i);
      }
    }
  }

  // TAP HANDLING
  Future<void> _handleTap(NotificationResponse resp) async =>
      await _processTap(resp);
  static Future<void> notificationTapBackground(
    NotificationResponse resp,
  ) async => await instance._processTap(resp);

  Future<void> _processTap(NotificationResponse resp) async {
    if (resp.payload == null) return;
    try {
      final data = jsonDecode(resp.payload!) as Map<String, dynamic>;
      final kind = data['kind'] as String?;

      final id = kind == 'todo'
          ? (int.tryParse(data['todoId']?.toString() ?? '0') ?? 0)
          : (kind == 'note' ? data['noteId'] as int : data['taskId'] as int);

      final type = kind == 'todo'
          ? 'todo_reminder'
          : (kind == 'note'
                ? 'note_reminder'
                : (data['type'] as String? ?? 'unknown'));

      final exists = await NotificationHistoryDbHelper.instance.exists(
        id,
        type,
        data['sentAt'] as int,
      );

      if (!exists) {
        final history = NotificationHistory(
          taskId: id,
          taskTitle: kind == 'todo'
              ? (data['todoTitle'] as String? ?? '')
              : (kind == 'note'
                    ? (data['noteTitle'] as String? ?? '')
                    : (data['taskTitle'] as String? ?? '')),
          notificationType: type,
          sentAt: DateTime.fromMillisecondsSinceEpoch(data['sentAt'] as int),
          taskDescription: kind == 'todo'
              ? (data['todoDescription'] as String? ?? '')
              : (kind == 'note'
                    ? (data['noteContent'] as String? ?? '')
                    : (data['taskDescription'] as String? ?? '')),
          isRead: true,
          taskCategory: data['taskCategory'] as String? ?? '',
          taskPriority: data['taskPriority'] as String? ?? '',
          taskDate: data['taskDate'] != null && data['taskDate'] != 0
              ? DateTime.fromMillisecondsSinceEpoch(data['taskDate'] as int)
              : null,
        );
        await NotificationHistoryDbHelper.instance.insert(history);
        instance._provider?.addNotification(history);
      }
    } catch (e) {
      debugPrint('Notification tap error: $e');
    }
  }

  // PUBLIC HELPERS
  void setProvider(NotificationProvider p) => _provider = p;
  void setFiveMinuteReminderEnabled(bool enabled) =>
      fiveMinuteReminderEnabled = enabled;
  bool get isFiveMinuteReminderEnabled => fiveMinuteReminderEnabled;

  Future<void> triggerRealNotificationNow(TaskModel task) async {
    if (task.id == null || task.isChecked) return;

    final now = DateTime.now();
    final type = task.reminderDateTime != null ? 'reminder' : '5-minute';
    final DateTime when =
        task.reminderDateTime ??
        (task.date?.subtract(const Duration(minutes: 5)) ?? now);

    if (when.isAfter(now.add(const Duration(seconds: 10)))) return;

    final sentAtMs = when.millisecondsSinceEpoch;
    final exists = await NotificationHistoryDbHelper.instance.exists(
      task.id!,
      type,
      sentAtMs,
    );
    if (exists) return;

    final payloadMap = {
      'kind': 'task',
      'taskId': task.id!,
      'taskTitle': task.title,
      'taskDescription': task.description,
      'taskCategory': task.category,
      'taskPriority': task.priority,
      'taskDate': task.date?.millisecondsSinceEpoch ?? 0,
      'type': type,
      'sentAt': sentAtMs,
    };

    await showNotificationFromMap(payloadMap);
  }

  Future<void> triggerNoteReminderNow(NoteModels note) async {
    if (note.id == null || note.reminder == null) return;

    final now = DateTime.now();
    final when = note.reminder!;

    if (when.isAfter(now.add(const Duration(seconds: 15))) ||
        when.isBefore(now.subtract(const Duration(seconds: 15)))) {
      return;
    }

    final sentAtMs = when.millisecondsSinceEpoch;

    final exists = await NotificationHistoryDbHelper.instance.exists(
      note.id!,
      'note_reminder',
      sentAtMs,
    );
    if (exists) return;

    final payloadMap = {
      'kind': 'note',
      'noteId': note.id!,
      'noteTitle': note.title,
      'noteContent': note.content,
      'noteCategory': note.category,
      'sentAt': sentAtMs,
    };

    await _showFromPayload(payloadMap);
  }

  Future<void> rescheduleAllOnStartup(List<TaskModel> tasks) async {
    debugPrint(
      'Rescheduling ${tasks.where((t) => t.id != null && !t.isChecked).length} tasks…',
    );
    for (final t in tasks.where((t) => t.id != null && !t.isChecked)) {
      await scheduleTaskNotifications(t);
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_isInitialized) await initialize();
    final pending = await _plugin.pendingNotificationRequests();
    debugPrint('=== Pending Local Notifications: ${pending.length} ===');
    for (var p in pending) {
      debugPrint('ID: ${p.id} | ${p.title}');
    }
    return pending;
  }

  // ========================================================================
  // TODO APP INTEGRATION METHODS
  // ========================================================================

  Future<int> scheduleTodoNotification(dynamic todo) async {
    if (!_isInitialized) await initialize();

    final String? todoId = todo.id?.toString();
    final DateTime? reminderDateTime = todo.reminderDateTime;
    final String title = todo.title ?? 'Todo Reminder';

    if (todoId == null || reminderDateTime == null) {
      throw Exception('Todo must have id and reminderDateTime');
    }

    if (reminderDateTime.isBefore(DateTime.now())) {
      throw Exception('Reminder time must be in the future');
    }

    final int notificationId = todoId.hashCode.abs();

    final payloadMap = {
      'kind': 'todo',
      'todoId': todoId,
      'todoTitle': title,
      'todoDescription': todo.description ?? '',
      'reminderDateTime': reminderDateTime.toIso8601String(),
      'sentAt': reminderDateTime.millisecondsSinceEpoch,
    };

    final payload = jsonEncode(payloadMap);
    final delay = reminderDateTime.difference(DateTime.now());

    if (delay.isNegative) {
      await _showFromPayload(payloadMap);
      return notificationId;
    }

    await Workmanager().registerOneOffTask(
      notificationId.toString(),
      'universal_notification',
      inputData: {'payload': payload},
      initialDelay: delay,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.notRequired),
    );

    if (Platform.isAndroid) {
      AndroidAlarmManager.oneShotAt(
        reminderDateTime,
        notificationId,
        todoAlarmCallback,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
        alarmClock: true,
        rescheduleOnReboot: true,
        params: payloadMap,
      );
    }

    debugPrint(
      '📅 Todo notification scheduled: $title (ID: $notificationId) at $reminderDateTime',
    );
    return notificationId;
  }

  Future<void> cancelNotification(int notificationId) async {
    await _plugin.cancel(notificationId);

    if (Platform.isAndroid) {
      await Workmanager().cancelByUniqueName(notificationId.toString());
      await AndroidAlarmManager.cancel(notificationId);
    }

    debugPrint('🚫 Cancelled notification: $notificationId');
  }

  Future<void> showTodoCompletedNotification(dynamic todo) async {
    if (!_isInitialized) await initialize();

    final String title = todo.title ?? 'Task';
    final int notificationId = DateTime.now().millisecondsSinceEpoch % 1000000;

    await _plugin.show(
      notificationId,
      'Task Completed! 🎉',
      title,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Tasks & Notes Reminders',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          showWhen: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );

    debugPrint('✅ Completion notification shown: $title');
  }
}

// ========================================================================
// UNIVERSAL CALLBACKS (TOP-LEVEL FUNCTIONS - OUTSIDE CLASS)
// ========================================================================

@pragma('vm:entry-point')
void universalCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('WorkManager fired: $taskName');
    WidgetsFlutterBinding.ensureInitialized();

    tz_data.initializeTimeZones();
    try {
      final dynamic tzResult = await FlutterTimezone.getLocalTimezone();
      final String location = tzResult is String
          ? tzResult
          : (tzResult?.location ?? 'UTC');
      tz.setLocalLocation(tz.getLocation(location));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    if (inputData?['payload'] != null) {
      final data =
          jsonDecode(inputData!['payload'] as String) as Map<String, dynamic>;
      await NotificationService.instance._showFromPayload(data);
    }
    return true;
  });
}

@pragma('vm:entry-point')
Future<void> universalAlarmCallback(
  int id,
  Map<String, dynamic> payloadMap,
) async {
  WidgetsFlutterBinding.ensureInitialized();

  tz_data.initializeTimeZones();
  try {
    final dynamic tzResult = await FlutterTimezone.getLocalTimezone();
    final String location = tzResult is String
        ? tzResult
        : (tzResult?.location ?? 'UTC');
    tz.setLocalLocation(tz.getLocation(location));
  } catch (_) {
    tz.setLocalLocation(tz.getLocation('UTC'));
  }

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  final androidImpl = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidImpl?.createNotificationChannel(
    const AndroidNotificationChannel(
      'task_reminders',
      'Tasks & Notes Reminders',
      importance: Importance.max,
    ),
  );

  await NotificationService.instance._showFromPayload(payloadMap);
}

@pragma('vm:entry-point')
Future<void> todoAlarmCallback(int id, Map<String, dynamic> params) async {
  WidgetsFlutterBinding.ensureInitialized();

  tz_data.initializeTimeZones();
  try {
    final dynamic tzResult = await FlutterTimezone.getLocalTimezone();
    final String location = tzResult is String
        ? tzResult
        : (tzResult?.location ?? 'UTC');
    tz.setLocalLocation(tz.getLocation(location));
  } catch (_) {
    tz.setLocalLocation(tz.getLocation('UTC'));
  }

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  await NotificationService.instance._showFromPayload(params);
}
