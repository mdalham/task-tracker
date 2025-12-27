import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'category_model.dart';

class CategoryDbHelper {
  static final CategoryDbHelper _instance = CategoryDbHelper._internal();
  factory CategoryDbHelper() => _instance;
  CategoryDbHelper._internal();

  static Database? _database;
  static const _dbName = 'categories.db';
  static const _table = 'categories';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await _createTable(db);
      },
      onOpen: (db) async {
        // Ensure table exists (defensive)
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          )
        ''');
      },
    );

    return db;
  }

  static Future<void> _createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');
  }

  Future<int> insert(CategoryModel category) async {
    final db = await database;
    final id = await db.insert(
      _table,
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  Future<List<CategoryModel>> fetchAll() async {
    final db = await database;
    final maps = await db.query(_table, orderBy: 'name ASC');
    return maps.map((m) => CategoryModel.fromMap(m)).toList();
  }

  Future<int> update(CategoryModel category) async {
    final db = await database;
    return db.update(_table, category.toMap(),
        where: 'id = ?', whereArgs: [category.id]);
  }

  Future<int> delete(int id) async {
    final db = await database;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /*/// For debugging: clear all categories (use only during dev)
  Future<void> debugClearAll() async {
    final db = await database;
    await db.delete(_table);
  }*/
}
