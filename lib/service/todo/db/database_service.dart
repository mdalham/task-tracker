// lib/services/database_service.dart

import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tasktracker/service/todo/db/todo_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  static const String _databaseName = 'todos.db';
  static const int _databaseVersion = 1;
  static const String tableTodos = 'todos';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableTodos (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL,
        due_date TEXT,
        due_time TEXT,
        reminder_date_time TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT,
        notification_id INTEGER,
        category TEXT,
        priority INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_is_completed ON $tableTodos(is_completed)');
    await db.execute('CREATE INDEX idx_due_date ON $tableTodos(due_date)');
    await db.execute('CREATE INDEX idx_priority ON $tableTodos(priority)');
    await db.execute('CREATE INDEX idx_category ON $tableTodos(category)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future migrations here
  }

  Future<Todo> createTodo(Todo todo) async {
    try {
      final db = await database;
      await db.insert(tableTodos, todo.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      return todo;
    } catch (e) {
      throw DatabaseException('Failed to create todo: $e');
    }
  }

  Future<void> createTodos(List<Todo> todos) async {
    try {
      final db = await database;
      final batch = db.batch();
      for (final todo in todos) {
        batch.insert(tableTodos, todo.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } catch (e) {
      throw DatabaseException('Failed to create todos: $e');
    }
  }

  Future<List<Todo>> getAllTodos() async {
    try {
      final db = await database;
      final result = await db.query(tableTodos, orderBy: 'created_at DESC');
      return result.map((map) => Todo.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get all todos: $e');
    }
  }

  Future<Todo?> getTodoById(String id) async {
    try {
      final db = await database;
      final result = await db.query(tableTodos, where: 'id = ?', whereArgs: [id], limit: 1);
      if (result.isEmpty) return null;
      return Todo.fromMap(result.first);
    } catch (e) {
      throw DatabaseException('Failed to get todo: $e');
    }
  }

  Future<List<Todo>> getActiveTodos() async {
    try {
      final db = await database;
      final result = await db.query(
        tableTodos,
        where: 'is_completed = ?',
        whereArgs: [0],
        orderBy: 'due_date ASC, priority DESC, created_at DESC',
      );
      return result.map((map) => Todo.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get active todos: $e');
    }
  }

  Future<List<Todo>> getCompletedTodos() async {
    try {
      final db = await database;
      final result = await db.query(
        tableTodos,
        where: 'is_completed = ?',
        whereArgs: [1],
        orderBy: 'completed_at DESC',
      );
      return result.map((map) => Todo.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get completed todos: $e');
    }
  }

  Future<List<Todo>> getTodosByCategory(String category) async {
    try {
      final db = await database;
      final result = await db.query(
        tableTodos,
        where: 'category = ?',
        whereArgs: [category],
        orderBy: 'created_at DESC',
      );
      return result.map((map) => Todo.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get todos by category: $e');
    }
  }

  Future<List<Todo>> getTodosDueToday() async {
    try {
      final db = await database;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      final result = await db.query(
        tableTodos,
        where: 'due_date >= ? AND due_date < ? AND is_completed = ?',
        whereArgs: [today.toIso8601String(), tomorrow.toIso8601String(), 0],
        orderBy: 'due_time ASC, priority DESC',
      );
      return result.map((map) => Todo.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get todos due today: $e');
    }
  }

  Future<List<Todo>> getOverdueTodos() async {
    try {
      final db = await database;
      final now = DateTime.now();

      final result = await db.query(
        tableTodos,
        where: 'due_date < ? AND is_completed = ?',
        whereArgs: [now.toIso8601String(), 0],
        orderBy: 'due_date ASC',
      );
      return result.map((map) => Todo.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get overdue todos: $e');
    }
  }

  Future<List<Todo>> searchTodos(String query) async {
    try {
      final db = await database;
      final result = await db.query(
        tableTodos,
        where: 'title LIKE ? OR description LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'created_at DESC',
      );
      return result.map((map) => Todo.fromMap(map)).toList();
    } catch (e) {
      throw DatabaseException('Failed to search todos: $e');
    }
  }

  Future<int> updateTodo(Todo todo) async {
    try {
      final db = await database;
      return await db.update(tableTodos, todo.toMap(), where: 'id = ?', whereArgs: [todo.id]);
    } catch (e) {
      throw DatabaseException('Failed to update todo: $e');
    }
  }

  Future<Todo> toggleTodoCompletion(String id) async {
    try {
      final todo = await getTodoById(id);
      if (todo == null) {
        throw DatabaseException('Todo not found');
      }

      final updatedTodo = todo.copyWith(
        isCompleted: !todo.isCompleted,
        completedAt: !todo.isCompleted ? DateTime.now() : null,
      );

      await updateTodo(updatedTodo);
      return updatedTodo;
    } catch (e) {
      throw DatabaseException('Failed to toggle todo completion: $e');
    }
  }

  Future<int> deleteTodo(String id) async {
    try {
      final db = await database;
      return await db.delete(tableTodos, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw DatabaseException('Failed to delete todo: $e');
    }
  }

  Future<int> deleteCompletedTodos() async {
    try {
      final db = await database;
      return await db.delete(tableTodos, where: 'is_completed = ?', whereArgs: [1]);
    } catch (e) {
      throw DatabaseException('Failed to delete completed todos: $e');
    }
  }

  Future<int> deleteAllTodos() async {
    try {
      final db = await database;
      return await db.delete(tableTodos);
    } catch (e) {
      throw DatabaseException('Failed to delete all todos: $e');
    }
  }

  Future<int> getTodoCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM $tableTodos');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      throw DatabaseException('Failed to get todo count: $e');
    }
  }

  Future<int> getActiveTodoCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM $tableTodos WHERE is_completed = 0');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      throw DatabaseException('Failed to get active todo count: $e');
    }
  }

  Future<int> getCompletedTodoCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM $tableTodos WHERE is_completed = 1');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      throw DatabaseException('Failed to get completed todo count: $e');
    }
  }

  Future<List<String>> getAllCategories() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT DISTINCT category FROM $tableTodos WHERE category IS NOT NULL ORDER BY category',
      );
      return result.map((row) => row['category'] as String).where((category) => category.isNotEmpty).toList();
    } catch (e) {
      throw DatabaseException('Failed to get categories: $e');
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}

class DatabaseException implements Exception {
  final String message;
  DatabaseException(this.message);
  @override
  String toString() => 'DatabaseException: $message';
}