// lib/provider/note_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../notification/service/notification_service.dart';
import '../db/notes_db_helper.dart';
import '../db/notes_models.dart';

/// ---------------------------------------------------------------
/// NOTE PROVIDER – UTC Storage, Local Display (Global-Ready)
/// Fully supports reliable reminders (killed app, reboot, doze-proof)
/// ---------------------------------------------------------------
class NoteProvider with ChangeNotifier {
  // ──────────────────────────────────────────────────────────────────────
  // Private state
  // ──────────────────────────────────────────────────────────────────────
  List<NoteModels> _notes = [];
  List<NoteModels> _filteredNotes = [];
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isLoading = false;

  // Reminder live checker (triggers notification when app is open)
  Timer? _noteReminderTimer;
  bool _reminderCheckRunning = false;

  // ──────────────────────────────────────────────────────────────────────
  // Getters
  // ──────────────────────────────────────────────────────────────────────
  List<NoteModels> get notes => _filteredNotes;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  int get totalNotes => _notes.length;
  // Inside NoteProvider class
  VoidCallback? onNotesChanged;




  // ──────────────────────────────────────────────────────────────────────
  // Constructor
  // ──────────────────────────────────────────────────────────────────────
  NoteProvider() {
    debugPrint('NoteProvider: Initializing...');
    loadNotes();
    startNoteReminderChecker();
  }

  @override
  void dispose() {
    stopNoteReminderChecker();
    super.dispose();
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    // Trigger external callback if set
    if (onNotesChanged != null) {
      onNotesChanged!.call();
      debugPrint('called onNoteC: $onNotesChanged');
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // LOAD ALL NOTES
  // ──────────────────────────────────────────────────────────────────────
  Future<void> loadNotes() async {
    _setLoading(true);
    try {
      debugPrint('NoteProvider: Loading notes from DB...');
      final List<Map<String, dynamic>> rawMaps = await NotesDatabaseHelper.instance.getAllNotes();

      _notes = rawMaps.map<NoteModels>((map) => NoteModels.fromMap(map)).toList();

      debugPrint('NoteProvider: Loaded ${_notes.length} notes');
      _applyFilters();
    } catch (e, st) {
      debugPrint('NoteProvider: ERROR loading notes: $e\n$st');
    } finally {
      _setLoading(false);
    }
  }


  // ──────────────────────────────────────────────────────────────────────
  // ADD NOTE
  // ──────────────────────────────────────────────────────────────────────
  Future<int> addNote(NoteModels note) async {
    try {
      debugPrint('NoteProvider: Adding note: "${note.title}"');
      final id = await NotesDatabaseHelper.instance.insertNote(note);
      final noteWithId = note.copyWith(id: id);

      // Schedule reliable notification (WorkManager + AlarmManager + Reboot-proof)
      await NotificationService.instance.scheduleNoteReminder(noteWithId);
      notifyListeners();
      await loadNotes();
      return id;
    } catch (e) {
      debugPrint('NoteProvider: ERROR adding note: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // UPDATE NOTE
  // ──────────────────────────────────────────────────────────────────────
  Future<void> updateNote(NoteModels note) async {
    try {
      debugPrint('NoteProvider: Updating note ID: ${note.id} | "${note.title}"');
      await NotesDatabaseHelper.instance.updateNote(note);

      // Re-schedule reminder (in case time or content changed)
      await NotificationService.instance.scheduleNoteReminder(note);
      notifyListeners();

      await loadNotes();
    } catch (e) {
      debugPrint('NoteProvider: ERROR updating note: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // DELETE NOTE
  // ──────────────────────────────────────────────────────────────────────
  Future<void> deleteNote(int id) async {
    try {
      debugPrint('NoteProvider: Deleting note ID: $id');

      // Cancel all scheduled notifications for this note
      await NotificationService.instance.cancelNoteReminder(id);

      await NotesDatabaseHelper.instance.deleteNote(id);
      notifyListeners();
      await loadNotes();
    } catch (e) {
      debugPrint('NoteProvider: ERROR deleting note: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // TOGGLE PIN
  // ──────────────────────────────────────────────────────────────────────
  Future<void> togglePin(NoteModels note) async {
    final updated = note.copyWith(pinned: !note.pinned);
    debugPrint('NoteProvider: Toggling pin for note ID: ${note.id} → ${updated.pinned}');
    await updateNote(updated);
  }

  // ──────────────────────────────────────────────────────────────────────
  // SEARCH & FILTER
  // ──────────────────────────────────────────────────────────────────────
  void search(String query) {
    _searchQuery = query.trim().toLowerCase();
    debugPrint('NoteProvider: Searching for: "$_searchQuery"');
    _applyFilters();
  }

  void filterByCategory(String category) {
    _selectedCategory = category;
    debugPrint('NoteProvider: Filtering by category: $category');
    _applyFilters();
  }

  List<String> get categories {
    final Set<String> cats = {'All'};
    for (final note in _notes) {
      final cat = note.category;
      if (cat.isNotEmpty && cat != 'Uncategorized') {
        cats.add(cat);
      }
    }
    final list = cats.toList()..sort();
    debugPrint('NoteProvider: Available categories: $list');
    return list;
  }

  DateTime? createdAtOf(NoteModels note) {
    final local = note.localCreatedAt;
    if (local != null) {
      debugPrint('NoteProvider: createdAt (local): $local');
    } else {
      debugPrint('NoteProvider: createdAt is null');
    }
    return local;
  }

  // ──────────────────────────────────────────────────────────────────────
  // PRIVATE: Apply filters + sort
  // ──────────────────────────────────────────────────────────────────────
  void _applyFilters() {
    List<NoteModels> filtered = List.from(_notes);

    if (_selectedCategory != 'All') {
      filtered = filtered.where((n) => n.category == _selectedCategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((n) {
        return n.title.toLowerCase().contains(_searchQuery) ||
            n.content.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // Sort: pinned first, then newest
    filtered.sort((a, b) {
      if (a.pinned && !b.pinned) return -1;
      if (!a.pinned && b.pinned) return 1;
      return b.localNoteDateTime.compareTo(a.localNoteDateTime);
    });

    _filteredNotes = filtered;
    debugPrint('NoteProvider: Showing ${_filteredNotes.length} notes after filter');
    notifyListeners();
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      debugPrint('NoteProvider: Loading state → $loading');
      notifyListeners();
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // LIVE REMINDER CHECKER – Triggers notification instantly when app is open
  // ──────────────────────────────────────────────────────────────────────
  void startNoteReminderChecker() {
    _noteReminderTimer?.cancel();
    _noteReminderTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(_checkAndTriggerNoteReminders());
    });
    debugPrint('NoteProvider: Live reminder checker STARTED (every 10s)');
  }

  void stopNoteReminderChecker() {
    _noteReminderTimer?.cancel();
    debugPrint('NoteProvider: Live reminder checker STOPPED');
  }

  Future<void> _checkAndTriggerNoteReminders() async {
    if (_reminderCheckRunning || _notes.isEmpty) return;
    _reminderCheckRunning = true;

    final now = DateTime.now();

    try {
      for (final note in _notes) {
        if (note.id == null || note.reminder == null) continue;

        final reminderTime = note.reminder!;
        final diffSeconds = reminderTime.difference(now).inSeconds.abs();

        // Trigger if within ±15 seconds (generous tolerance)
        if (diffSeconds <= 15) {
          await NotificationService.instance.triggerNoteReminderNow(note);
        }
      }
    } catch (e, s) {
      debugPrint('NoteProvider: Reminder check error → $e\n$s');
    } finally {
      _reminderCheckRunning = false;
    }
  }
}

// Helper to avoid "unawaited future" warnings
void unawaited(Future<void> future) {
  future.ignore();
}