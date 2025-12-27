// database/note/database_helper.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'notes_models.dart';

/// ---------------------------------------------------------------
/// DATABASE HELPER – UTC Storage, Global-Ready, No BD Hack
/// ---------------------------------------------------------------
class NotesDatabaseHelper {
  // ──────────────────────────────────────────────────────────────────────
  // DB Config
  // ──────────────────────────────────────────────────────────────────────
  static const String _databaseName = 'task_tracker_notes.db';
  static const int _databaseVersion = 3; // ← UPDATED to version 3

  // ──────────────────────────────────────────────────────────────────────
  // Singleton
  // ──────────────────────────────────────────────────────────────────────
  NotesDatabaseHelper._privateConstructor();
  static final NotesDatabaseHelper instance = NotesDatabaseHelper._privateConstructor();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      debugPrint('DB: Reusing existing database');
      return _database!;
    }
    debugPrint('DB: Initializing new database...');
    _database = await _initDatabase();
    debugPrint('DB: Database initialized at ${_database!.path}');
    return _database!;
  }

  // ──────────────────────────────────────────────────────────────────────
  // Initialize DB
  // ──────────────────────────────────────────────────────────────────────
  Future<Database> _initDatabase() async {
    final Directory docsDir = await getApplicationDocumentsDirectory();
    final String path = join(docsDir.path, _databaseName);
    debugPrint('DB: Opening database at $path');

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, version) async {
        debugPrint('DB: onCreate triggered (version $version)');
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        debugPrint('DB: onUpgrade from $oldVersion to $newVersion');
        await _onUpgrade(db, oldVersion, newVersion);
      },
      onOpen: (db) async {
        debugPrint('DB: Database opened successfully');
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // CREATE TABLE – UTC via SQLite + text_align + font_size
  // ──────────────────────────────────────────────────────────────────────
  Future<void> _createTables(Database db) async {
    debugPrint('DB: Creating table `notes`...');
    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL DEFAULT '',
        content TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL DEFAULT 'Uncategorized',
        priority TEXT NOT NULL DEFAULT 'None',
        address TEXT NOT NULL DEFAULT '',
        reminder TEXT,
        pinned INTEGER NOT NULL DEFAULT 0,
        images TEXT NOT NULL DEFAULT '[]',
        audios TEXT NOT NULL DEFAULT '[]',
        checklist TEXT NOT NULL DEFAULT '[]',
        note_date_time TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        text_align TEXT NOT NULL DEFAULT 'left',
        font_size REAL NOT NULL DEFAULT 16.0
      )
    ''');

    // Indexes for performance
    await db.execute('CREATE INDEX idx_notes_category ON notes(category)');
    await db.execute('CREATE INDEX idx_notes_pinned ON notes(pinned)');
    await db.execute('CREATE INDEX idx_notes_date ON notes(note_date_time)');
    await db.execute('CREATE INDEX idx_notes_created ON notes(created_at)');
    debugPrint('DB: Table and indexes created');
  }

  // ──────────────────────────────────────────────────────────────────────
  // FULL UPGRADE: v1 → v2 → v3
  // ──────────────────────────────────────────────────────────────────────
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('DB: Starting upgrade from v$oldVersion to v$newVersion');

    // ────────────────────────────────────────────────────────────────────
    // UPGRADE TO VERSION 2: Add created_at
    // ────────────────────────────────────────────────────────────────────
    if (oldVersion < 2) {
      debugPrint('DB: Upgrading to v2: Adding `created_at` column...');
      final columns = await db.rawQuery("PRAGMA table_info(notes)");
      final hasCreatedAt = columns.any((col) => col['name'] == 'created_at');

      if (!hasCreatedAt) {
        await db.execute('ALTER TABLE notes ADD COLUMN created_at TEXT');
        debugPrint('DB: `created_at` column added');
      } else {
        debugPrint('DB: `created_at` already exists – skipping ALTER');
      }

      // Backfill with UTC now
      final utcNow = DateTime.now().toUtc().toIso8601String();
      await db.rawUpdate(
        "UPDATE notes SET created_at = ? WHERE created_at IS NULL",
        [utcNow],
      );
      debugPrint('DB: Backfilled `created_at` with UTC time: $utcNow');
    }

    // ────────────────────────────────────────────────────────────────────
    // UPGRADE TO VERSION 3: Add text_align and font_size
    // ────────────────────────────────────────────────────────────────────
    if (oldVersion < 3) {
      debugPrint('DB: Upgrading to v3: Adding `text_align` and `font_size` columns...');
      final columns = await db.rawQuery("PRAGMA table_info(notes)");

      final hasTextAlign = columns.any((col) => col['name'] == 'text_align');
      final hasFontSize = columns.any((col) => col['name'] == 'font_size');

      // Add text_align column
      if (!hasTextAlign) {
        await db.execute('ALTER TABLE notes ADD COLUMN text_align TEXT DEFAULT "left"');
        debugPrint('DB: `text_align` column added');
      } else {
        debugPrint('DB: `text_align` already exists – skipping ALTER');
      }

      // Add font_size column
      if (!hasFontSize) {
        await db.execute('ALTER TABLE notes ADD COLUMN font_size REAL DEFAULT 18.0');
        debugPrint('DB: `font_size` column added');
      } else {
        debugPrint('DB: `font_size` already exists – skipping ALTER');
      }

      // Backfill defaults for existing notes
      await db.rawUpdate(
        "UPDATE notes SET text_align = 'left' WHERE text_align IS NULL OR text_align = ''",
      );
      await db.rawUpdate(
        "UPDATE notes SET font_size = 18.0 WHERE font_size IS NULL OR font_size = 0",
      );
      debugPrint('DB: Backfilled text_align="left" and font_size=18.0 for existing notes');
    }

    debugPrint('DB: Upgrade completed successfully!');
  }

  // ──────────────────────────────────────────────────────────────────────
  // INSERT – UTC timestamps
  // ──────────────────────────────────────────────────────────────────────
  Future<int> insertNote(NoteModels note) async {
    final db = await database;
    final nowUtc = DateTime.now().toUtc();

    final noteWithTime = note.copyWith(
      noteDateTime: note.noteDateTime ?? nowUtc,
    );

    final map = noteWithTime.toMap();
    map['created_at'] = nowUtc.toIso8601String();

    debugPrint(
      'DB: Inserting note: "${map['title']}" | text_align: ${map['text_align']} | font_size: ${map['font_size']}',
    );
    final id = await db.insert('notes', map);
    debugPrint('DB: Inserted note with ID: $id');
    return id;
  }

  // ──────────────────────────────────────────────────────────────────────
  // UPDATE – Preserve created_at
  // ──────────────────────────────────────────────────────────────────────
  Future<int> updateNote(NoteModels note) async {
    final db = await database;
    if (note.id == null) {
      debugPrint('DB: ERROR – Cannot update note without ID');
      throw Exception('Note ID required for update');
    }

    final existing = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [note.id],
    );

    final map = note.toMap();
    if (existing.isNotEmpty) {
      map['created_at'] = existing.first['created_at'];
    }

    debugPrint(
      'DB: Updating note ID: ${note.id} | Title: "${note.title}" | text_align: ${map['text_align']} | font_size: ${map['font_size']}',
    );
    final count = await db.update(
      'notes',
      map,
      where: 'id = ?',
      whereArgs: [note.id],
    );
    debugPrint('DB: Updated $count row(s)');
    return count;
  }

  // ──────────────────────────────────────────────────────────────────────
  // DELETE
  // ──────────────────────────────────────────────────────────────────────
  Future<int> deleteNote(int id) async {
    final db = await database;
    debugPrint('DB: Deleting note ID: $id');
    final count = await db.delete('notes', where: 'id = ?', whereArgs: [id]);
    debugPrint('DB: Deleted $count note(s)');
    return count;
  }

  // ──────────────────────────────────────────────────────────────────────
  // GET BY ID
  // ──────────────────────────────────────────────────────────────────────
  Future<NoteModels?> getNoteById(int id) async {
    final db = await database;
    final maps = await db.query('notes', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      final note = NoteModels.fromMap(maps.first);
      debugPrint('DB: Fetched note ID: $id | text_align: ${note.textAlign} | font_size: ${note.fontSize}');
      return note;
    }
    debugPrint('DB: No note found with ID: $id');
    return null;
  }

  // ──────────────────────────────────────────────────────────────────────
  // GET BY CATEGORY
  // ──────────────────────────────────────────────────────────────────────
  Future<List<NoteModels>> getNotesByCategory(String category) async {
    final db = await database;
    debugPrint('DB: Fetching notes in category: $category');
    final maps = await db.query(
      'notes',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'pinned DESC, note_date_time DESC',
    );
    final notes = maps.map((m) => NoteModels.fromMap(m)).toList();
    debugPrint('DB: Found ${notes.length} notes in $category');
    return notes;
  }

  // ──────────────────────────────────────────────────────────────────────
  // GET ALL – Raw maps (UTC)
  // ──────────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllNotes() async {
    final db = await database;
    debugPrint('DB: Fetching all notes...');
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      orderBy: 'pinned DESC, note_date_time DESC',
    );
    debugPrint('DB: Loaded ${maps.length} raw note maps');
    return maps;
  }

  // ──────────────────────────────────────────────────────────────────────
  // SEARCH
  // ──────────────────────────────────────────────────────────────────────
  Future<List<NoteModels>> searchNotes(String query) async {
    final db = await database;
    debugPrint('DB: Searching notes for: "$query"');
    final maps = await db.query(
      'notes',
      where: 'title LIKE ? OR content LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'pinned DESC, note_date_time DESC',
    );
    final notes = maps.map((m) => NoteModels.fromMap(m)).toList();
    debugPrint('DB: Search returned ${notes.length} results');
    return notes;
  }

  // ──────────────────────────────────────────────────────────────────────
  // CLOSE
  // ──────────────────────────────────────────────────────────────────────
  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      debugPrint('DB: Closing database...');
      await db.close();
      _database = null;
      debugPrint('DB: Database closed');
    }
  }
}