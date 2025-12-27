// task_database_helper.dart – FINAL & PERFECT VERSION (Copy-Paste Ready)
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/material.dart';
import 'package:tasktracker/service/task/db/recurrence_models.dart';
import 'package:tasktracker/service/task/db/tasks_models.dart';
import 'dart:convert';

class TaskDbHelper {
  // -------------------------------------------------
  // SINGLETON
  // -------------------------------------------------
  static final TaskDbHelper instance = TaskDbHelper._internal();
  static Database? _database;
  TaskDbHelper._internal();

  // -------------------------------------------------
  // DB INFO
  // -------------------------------------------------
  static const String _dbName = 'tasks.db';
  static const int _dbVersion = 5;
  static const String tableTasks = 'tasks';

  // Columns
  static const String columnId = 'id';
  static const String columnTitle = 'title';
  static const String columnDescription = 'description';
  static const String columnCategory = 'category';
  static const String columnPriority = 'priority';
  static const String columnDate = 'date';
  static const String columnTime = 'time';
  static const String columnIsImportant = 'isImportant';
  static const String columnIsChecked = 'isChecked';
  static const String columnRecurrenceType = 'recurrenceType';
  static const String columnRecurrenceInterval = 'recurrenceInterval';
  static const String columnRecurrenceEndDate = 'recurrenceEndDate';
  static const String columnRecurrenceWeekdays = 'recurrenceWeekdays';
  static const String columnRecurrenceMonthlyDay = 'recurrenceMonthlyDay';
  static const String columnRecurrenceMonthlyLastDay = 'recurrenceMonthlyLastDay';
  static const String columnParentTaskId = 'parentTaskId';
  static const String columnIsRecurringInstance = 'isRecurringInstance';
  static const String columnOriginalDate = 'originalDate';
  static const String columnReminderEnabled = 'reminderEnabled';
  static const String columnReminderDateTime = 'reminderDateTime';
  static const String columnChecklist = 'checklist';
  static const String columnCreatedAt = 'createdAt';
  static const String columnUpdatedAt = 'updatedAt';
  static const String columnCompletedAt = 'completedAt';

  // -------------------------------------------------
  // DB ACCESS
  // -------------------------------------------------
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // -------------------------------------------------
  // CREATE TABLE
  // -------------------------------------------------
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableTasks (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnTitle TEXT NOT NULL,
        $columnDescription TEXT,
        $columnCategory TEXT,
        $columnPriority TEXT DEFAULT 'None',
        $columnDate TEXT,
        $columnTime TEXT,
        $columnIsImportant INTEGER DEFAULT 0,
        $columnIsChecked INTEGER DEFAULT 0,
        $columnRecurrenceType TEXT DEFAULT 'none',
        $columnRecurrenceInterval INTEGER DEFAULT 1,
        $columnRecurrenceEndDate TEXT,
        $columnRecurrenceWeekdays TEXT,
        $columnRecurrenceMonthlyDay INTEGER,
        $columnRecurrenceMonthlyLastDay INTEGER DEFAULT 0,
        $columnParentTaskId TEXT,
        $columnIsRecurringInstance INTEGER DEFAULT 0,
        $columnOriginalDate TEXT,
        $columnReminderEnabled INTEGER DEFAULT 0,
        $columnReminderDateTime TEXT,
        $columnChecklist TEXT,
        $columnCreatedAt TEXT NOT NULL,
        $columnUpdatedAt TEXT,
        $columnCompletedAt TEXT
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_date_time ON $tableTasks($columnDate, $columnTime)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_checked ON $tableTasks($columnIsChecked)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_parent ON $tableTasks($columnParentTaskId)');
  }

  // -------------------------------------------------
  // MIGRATION
  // -------------------------------------------------
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    final batch = db.batch();

    if (oldVersion < 2) {
      await _addColumnIfNotExists(db, tableTasks, columnRecurrenceMonthlyLastDay, 'INTEGER DEFAULT 0');
    }

    if (oldVersion < 3) {
      await _addColumnIfNotExists(db, tableTasks, columnCreatedAt, 'TEXT NOT NULL DEFAULT ""');
      await _addColumnIfNotExists(db, tableTasks, columnUpdatedAt, 'TEXT');
      await _addColumnIfNotExists(db, tableTasks, columnCompletedAt, 'TEXT');
    }

    if (oldVersion < 4) {
      await db.execute('DROP INDEX IF EXISTS idx_date');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_date_time ON $tableTasks($columnDate, $columnTime)');
    }

    if (oldVersion < 5) {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_parent ON $tableTasks($columnParentTaskId)');
    }

    await batch.commit(noResult: true);
  }

  Future<void> _addColumnIfNotExists(
      Database db,
      String table,
      String column,
      String definition,
      ) async {
    final cols = await db.rawQuery('PRAGMA table_info($table)');
    final exists = cols.any((c) => c['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  // ================================================
  // PUBLIC METHOD TO GET CORRECT DB MAP (MOST IMPORTANT FIX)
  // ================================================
  Map<String, dynamic> getTaskDbMap(TaskModel task) {
    return _taskToDbMap(task);
  }

  // ================================================
  // NEW SAFE INSERT METHODS (FOR RECURRING)
  // ================================================
  Future<int?> insertTaskFromMap(Map<String, dynamic> map) async {
    final db = await database;
    map['id'] = null;
    return await db.insert(tableTasks, map);
  }

  // -------------------------------------------------
  // ORIGINAL INSERT METHODS (kept 100%)
  // -------------------------------------------------
  Future<int> insertTask(TaskModel task) async {
    final db = await database;
    final map = getTaskDbMap(task);
    map['id'] = null;
    return await db.insert(tableTasks, map);
  }

  Future<List<int>> insertTasks(List<TaskModel> tasks) async {
    final db = await database;
    final batch = db.batch();
    for (final t in tasks) {
      final map = getTaskDbMap(t);
      map['id'] = null;
      batch.insert(tableTasks, map);
    }
    final results = await batch.commit();
    return results.cast<int>();
  }

  // -------------------------------------------------
  // UPDATE (100% unchanged)
  // -------------------------------------------------
  Future<int> updateTask(TaskModel task) async {
    if (task.id == null) return 0;
    final db = await database;
    return await db.update(
      tableTasks,
      getTaskDbMap(task),
      where: '$columnId = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> toggleTaskCompletion(int id, bool isChecked) async {
    final db = await database;
    return await db.update(
      tableTasks,
      {
        columnIsChecked: isChecked ? 1 : 0,
        columnCompletedAt: isChecked ? DateTime.now().toIso8601String() : null,
        columnUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateTaskPriority(int id, String priority) async {
    final db = await database;
    return await db.update(
      tableTasks,
      {columnPriority: priority, columnUpdatedAt: DateTime.now().toIso8601String()},
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateTaskCategory(int id, String category) async {
    final db = await database;
    return await db.update(
      tableTasks,
      {columnCategory: category, columnUpdatedAt: DateTime.now().toIso8601String()},
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // -------------------------------------------------
  // DELETE (100% unchanged)
  // -------------------------------------------------
  Future<int> deleteTask(int id) async {
    final db = await database;
    return await db.delete(tableTasks, where: '$columnId = ?', whereArgs: [id]);
  }

  Future<int> deleteTasks(List<int> ids) async {
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    return await db.delete(
      tableTasks,
      where: '$columnId IN ($placeholders)',
      whereArgs: ids,
    );
  }

  Future<int> deleteCompletedTasks() async {
    final db = await database;
    return await db.delete(tableTasks, where: '$columnIsChecked = ?', whereArgs: [1]);
  }

  Future<int> deleteAllTasks() async {
    final db = await database;
    return await db.delete(tableTasks);
  }

  Future<void> deleteRecurringTaskWithInstances(int parentTaskId) async {
    final db = await database;
    final batch = db.batch();
    batch.delete(tableTasks, where: '$columnId = ?', whereArgs: [parentTaskId]);
    batch.delete(tableTasks, where: '$columnParentTaskId = ?', whereArgs: [parentTaskId.toString()]);
    await batch.commit();
  }

  // -------------------------------------------------
  // ALL YOUR QUERY METHODS (100% unchanged)
  // -------------------------------------------------
  Future<TaskModel?> getTaskById(int id) async {
    final db = await database;
    final rows = await db.query(tableTasks, where: '$columnId = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _dbMapToTask(rows.first);
  }

  Future<List<TaskModel>> getAllTasks() async {
    final db = await database;
    final rows = await db.query(tableTasks, orderBy: '$columnCreatedAt DESC');
    return rows.map(_dbMapToTask).toList();
  }

  Future<List<TaskModel>> getTasksByCategory(String category) async {
    final db = await database;
    final rows = await db.query(
      tableTasks,
      where: '$columnCategory = ?',
      whereArgs: [category],
      orderBy: '$columnDate ASC, $columnTime ASC',
    );
    return rows.map(_dbMapToTask).toList();
  }

  Future<List<TaskModel>> getTasksByPriority(String priority) async {
    final db = await database;
    final rows = await db.query(
      tableTasks,
      where: '$columnPriority = ?',
      whereArgs: [priority],
      orderBy: '$columnDate ASC',
    );
    return rows.map(_dbMapToTask).toList();
  }

  Future<List<TaskModel>> _queryRange(
      DateTime start,
      DateTime? end, {
        required bool includeCompleted,
      }) async {
    final db = await database;
    final where = StringBuffer('$columnDate >= ?');
    final args = <dynamic>[start.toIso8601String()];

    if (end != null) {
      where.write(' AND $columnDate <= ?');
      args.add(end.toIso8601String());
    }
    if (!includeCompleted) {
      where.write(' AND $columnIsChecked = ?');
      args.add(0);
    }

    final rows = await db.query(
      tableTasks,
      where: where.toString(),
      whereArgs: args,
      orderBy: '$columnDate ASC, $columnTime ASC',
    );
    return rows.map(_dbMapToTask).toList();
  }


  Future<List<TaskModel>> getCompletedTasks() async {
    final db = await database;
    final rows = await db.query(
      tableTasks,
      where: '$columnIsChecked = ?',
      whereArgs: [1],
      orderBy: '$columnCompletedAt DESC',
    );
    return rows.map(_dbMapToTask).toList();
  }

  Future<List<TaskModel>> getOverdueTasks() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final rows = await db.query(
      tableTasks,
      where: '$columnDate < ? AND $columnIsChecked = ?',
      whereArgs: [now, 0],
      orderBy: '$columnDate DESC',
    );
    return rows.map(_dbMapToTask).toList();
  }

  Future<List<TaskModel>> getImportantTasks() async {
    final db = await database;
    final rows = await db.query(
      tableTasks,
      where: '$columnIsImportant = ?',
      whereArgs: [1],
      orderBy: '$columnDate ASC',
    );
    return rows.map(_dbMapToTask).toList();
  }

  Future<List<TaskModel>> getThisWeekTasks() async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    return _queryRange(
      DateTime(start.year, start.month, start.day),
      DateTime(end.year, end.month, end.day, 23, 59, 59),
      includeCompleted: false,
    );
  }

  Future<List<TaskModel>> getThisMonthTasks() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return _queryRange(start, end, includeCompleted: false);
  }

  Future<List<TaskModel>> getTasksWithReminders() async {
    final db = await database;
    final rows = await db.query(
      tableTasks,
      where: '$columnReminderEnabled = ? AND $columnReminderDateTime IS NOT NULL',
      whereArgs: [1],
      orderBy: '$columnReminderDateTime ASC',
    );
    return rows.map(_dbMapToTask).toList();
  }

  Future<List<TaskModel>> getRecurringTasks() async {
    final db = await database;
    final rows = await db.query(
      tableTasks,
      where: '$columnRecurrenceType != ? AND $columnIsRecurringInstance = ?',
      whereArgs: ['none', 0],
      orderBy: '$columnDate ASC',
    );
    return rows.map(_dbMapToTask).toList();
  }

  Future<List<TaskModel>> getRecurringInstances(int parentTaskId) async {
    final db = await database;
    final rows = await db.query(
      tableTasks,
      where: '$columnParentTaskId = ?',
      whereArgs: [parentTaskId.toString()],
      orderBy: '$columnDate ASC',
    );
    return rows.map(_dbMapToTask).toList();
  }

  Future<List<TaskModel>> searchTasks(String query) async {
    final db = await database;
    final q = '%$query%';
    final rows = await db.query(
      tableTasks,
      where: '$columnTitle LIKE ? OR $columnDescription LIKE ?',
      whereArgs: [q, q],
      orderBy: '$columnDate DESC',
    );
    return rows.map(_dbMapToTask).toList();
  }

  Future<int> getTaskCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM $tableTasks');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getCompletedTaskCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM $tableTasks WHERE $columnIsChecked = 1');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // -------------------------------------------------
  // MAP HELPERS (100% unchanged)
  // -------------------------------------------------
  Map<String, dynamic> _taskToDbMap(TaskModel t) {
    final r = t.recurrenceSettings;

    final timeStr = t.date != null
        ? '${t.date!.hour.toString().padLeft(2, '0')}:${t.date!.minute.toString().padLeft(2, '0')}'
        : null;

    return {
      if (t.id != null) columnId: t.id,
      columnTitle: t.title,
      columnDescription: t.description,
      columnCategory: t.category,
      columnPriority: t.priority,
      columnDate: t.date?.toIso8601String(),
      columnTime: timeStr,
      columnIsImportant: t.isImportant ? 1 : 0,
      columnIsChecked: t.isChecked ? 1 : 0,
      columnRecurrenceType: r.type.name,
      columnRecurrenceInterval: r.interval,
      columnRecurrenceEndDate: r.endDate?.toIso8601String(),
      columnRecurrenceWeekdays: r.selectedWeekdays.map((wd) => wd.value).join(','),
      columnRecurrenceMonthlyDay: r.monthlyDay,
      columnRecurrenceMonthlyLastDay: r.monthlyLastDay ? 1 : 0,
      columnParentTaskId: t.parentTaskId,
      columnIsRecurringInstance: t.isRecurringInstance ? 1 : 0,
      columnOriginalDate: t.originalDate?.toIso8601String(),
      columnReminderEnabled: t.reminderEnabled ? 1 : 0,
      columnReminderDateTime: t.reminderDateTime?.toIso8601String(),
      columnChecklist: t.checklistTask.isNotEmpty
          ? jsonEncode(t.checklistTask.map((e) => e.toMap()).toList())
          : null,
      columnCreatedAt: t.createdAt.toIso8601String(),
      columnUpdatedAt: t.updatedAt?.toIso8601String(),
      columnCompletedAt: t.completedAt?.toIso8601String(),
    };
  }

  TaskModel _dbMapToTask(Map<String, dynamic> map) {
    TimeOfDay? time;
    if (map[columnTime] != null && map[columnTime] is String) {
      final parts = (map[columnTime] as String).split(':');
      if (parts.length == 2) {
        time = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    DateTime? date;
    if (map[columnDate] != null) {
      date = DateTime.parse(map[columnDate] as String);
      if (time != null && date.hour == 0 && date.minute == 0) {
        date = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      }
    }

    final r = RecurrenceSettings(
      type: RecurrenceType.values.firstWhere(
            (e) => e.name == (map[columnRecurrenceType] ?? 'none'),
        orElse: () => RecurrenceType.none,
      ),
      interval: map[columnRecurrenceInterval] ?? 1,
      endDate: map[columnRecurrenceEndDate] != null ? DateTime.parse(map[columnRecurrenceEndDate]) : null,
      selectedWeekdays: _parseWeekdays(map[columnRecurrenceWeekdays]),
      monthlyDay: map[columnRecurrenceMonthlyDay],
      monthlyLastDay: (map[columnRecurrenceMonthlyLastDay] ?? 0) == 1,
    );

    final List<TaskModel> checklist = [];
    if (map[columnChecklist] != null && map[columnChecklist] is String) {
      try {
        final List<dynamic> raw = jsonDecode(map[columnChecklist] as String);
        checklist.addAll(raw.map((e) => TaskModel.fromMap(Map<String, dynamic>.from(e))));
      } catch (e) {
        debugPrint('Checklist parse error: $e');
      }
    }

    return TaskModel(
      id: map[columnId],
      title: map[columnTitle] ?? '',
      description: map[columnDescription] ?? '',
      category: map[columnCategory] ?? '',
      priority: map[columnPriority] ?? 'None',
      date: date,
      isImportant: (map[columnIsImportant] ?? 0) == 1,
      isChecked: (map[columnIsChecked] ?? 0) == 1,
      recurrenceSettings: r,
      parentTaskId: map[columnParentTaskId],
      isRecurringInstance: (map[columnIsRecurringInstance] ?? 0) == 1,
      originalDate: map[columnOriginalDate] != null ? DateTime.parse(map[columnOriginalDate]) : null,
      reminderEnabled: (map[columnReminderEnabled] ?? 0) == 1,
      reminderDateTime: map[columnReminderDateTime] != null ? DateTime.parse(map[columnReminderDateTime]) : null,
      checklistTask: checklist,
      createdAt: map[columnCreatedAt] != null ? DateTime.parse(map[columnCreatedAt]) : DateTime.now(),
      updatedAt: map[columnUpdatedAt] != null ? DateTime.parse(map[columnUpdatedAt]) : null,
      completedAt: map[columnCompletedAt] != null ? DateTime.parse(map[columnCompletedAt]) : null,
    );
  }

  List<WeekDay> _parseWeekdays(dynamic data) {
    if (data == null || data.toString().isEmpty) return [];
    try {
      return data
          .toString()
          .split(',')
          .where((v) => v.isNotEmpty)
          .map((v) => WeekDay.values.firstWhere(
            (wd) => wd.value == int.parse(v),
        orElse: () => WeekDay.monday,
      ))
          .toList();
    } catch (_) {
      return [];
    }
  }
}