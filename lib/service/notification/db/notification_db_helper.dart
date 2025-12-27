// lib/database/task/notification_db_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'notification_models.dart';

class NotificationHistoryDbHelper {
  // -------------------------------------------------
  // Singleton
  // -------------------------------------------------
  static final NotificationHistoryDbHelper instance = NotificationHistoryDbHelper._internal();
  NotificationHistoryDbHelper._internal();
  factory NotificationHistoryDbHelper() => instance;

  static Database? _db;
  final String tableName = "notification_history";

  // -------------------------------------------------
  // DB getter
  // -------------------------------------------------
  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, "notification_history.db");

    return await openDatabase(
      path,
      version: 3, // ← BUMP TO 3
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // -------------------------------------------------
  // CREATE TABLE WITH UNIQUE CONSTRAINT
  // -------------------------------------------------
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        taskId INTEGER NOT NULL,
        taskTitle TEXT NOT NULL,
        notificationType TEXT NOT NULL,
        sentAt INTEGER NOT NULL,
        taskDescription TEXT,
        taskCategory TEXT,
        taskPriority TEXT,
        taskDate INTEGER,
        isRead INTEGER NOT NULL DEFAULT 0,
        UNIQUE(taskId, notificationType, sentAt)
      )
    ''');
  }

  // -------------------------------------------------
  // UPGRADE: Recreate table with unique constraint
  // -------------------------------------------------
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('DROP TABLE IF EXISTS $tableName');
      await _onCreate(db, newVersion);
    }
  }

  // -------------------------------------------------
  // INSERT – IGNORE DUPLICATES
  // -------------------------------------------------
  Future<void> insert(NotificationHistory item) async {
    final db = await database;
    await db.insert(
      tableName,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // -------------------------------------------------
  // EXISTS – STRONG CHECK (taskId + type + sentAt)
  // -------------------------------------------------
  // In notification_db_helper.dart
  // lib/database/task/notification_db_helper.dart
  Future<bool> exists(int taskId, String type, [int? sentAt]) async {
    final db = await database;
    final where = sentAt != null
        ? 'taskId = ? AND notificationType = ? AND sentAt = ?'
        : 'taskId = ? AND notificationType = ?';
    final args = sentAt != null ? [taskId, type, sentAt] : [taskId, type];

    final result = await db.query(tableName, where: where, whereArgs: args);
    return result.isNotEmpty;
  }

  // -------------------------------------------------
  // DELETE BY TASK ID + TYPE
  // -------------------------------------------------
  Future<int> deleteByTaskIdAndType(int taskId, String type) async {
    final db = await database;
    return await db.delete(
      tableName,
      where: 'taskId = ? AND notificationType = ?',
      whereArgs: [taskId, type],
    );
  }

  // -------------------------------------------------
  // DELETE SINGLE
  // -------------------------------------------------
  Future<int> delete(int id) async {
    final db = await database;
    return await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // -------------------------------------------------
  // GET ALL (latest first)
  // -------------------------------------------------
  Future<List<NotificationHistory>> getAllNotifications() async {
    final db = await database;
    final maps = await db.query(tableName, orderBy: 'sentAt DESC');
    return maps.map(NotificationHistory.fromMap).toList();
  }

  // -------------------------------------------------
  // MARK AS READ
  // -------------------------------------------------
  Future<int> markAsRead(int id) async {
    final db = await database;
    return await db.update(
      tableName,
      {'isRead': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // -------------------------------------------------
  // MARK ALL AS READ
  // -------------------------------------------------
  Future<int> markAllAsRead() async {
    final db = await database;
    return await db.update(tableName, {'isRead': 1});
  }

  // -------------------------------------------------
  // UNREAD COUNT
  // -------------------------------------------------
  Future<int> getUnreadCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM $tableName WHERE isRead = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // -------------------------------------------------
  // DELETE ALL
  // -------------------------------------------------
  Future<int> deleteAll() async {
    final db = await database;
    return await db.delete(tableName);
  }
}