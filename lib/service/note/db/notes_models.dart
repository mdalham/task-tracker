// database/note/note_models.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// ---------------------------------------------------------------
/// CHECKLIST ITEM
/// ---------------------------------------------------------------
class ChecklistItem {
  final String title;
  final bool isChecked;

  const ChecklistItem({required this.title, this.isChecked = false});

  ChecklistItem copyWith({String? title, bool? isChecked}) {
    return ChecklistItem(
      title: title ?? this.title,
      isChecked: isChecked ?? this.isChecked,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'isChecked': isChecked ? 1 : 0,
  };

  factory ChecklistItem.fromMap(Map<String, dynamic> map) => ChecklistItem(
    title: map['title'] as String? ?? '',
    isChecked: (map['isChecked'] as int? ?? 0) == 1,
  );

  @override
  String toString() => 'ChecklistItem(title: $title, checked: $isChecked)';
}


/// ---------------------------------------------------------------
/// MAIN NOTE MODEL – UTC Storage, Local Display (No BD +6)
/// ---------------------------------------------------------------
class NoteModels {
  final int? id;
  final String title;
  final String content;
  final String category;
  final String priority;
  final String address;
  final DateTime? reminder; // UTC in DB
  final bool pinned;
  final List<String> images;
  final List<String> audios;
  final DateTime? noteDateTime; // UTC in DB
  final List<ChecklistItem> checklist;
  final String? createdAt; // UTC ISO string
  final String textAlign; // NEW: 'left', 'center', 'right', 'justify'
  final double fontSize; // NEW: Font size

  NoteModels({
    this.id,
    this.title = '',
    this.content = '',
    this.category = '',
    this.priority = 'None',
    this.address = '',
    this.reminder,
    this.pinned = false,
    List<String>? images,
    List<String>? audios,
    this.noteDateTime,
    List<ChecklistItem>? checklist,
    this.createdAt,
    this.textAlign = 'left', // DEFAULT
    this.fontSize = 18.0, // DEFAULT
  }) : images = images ?? [],
        audios = audios ?? [],
        checklist = checklist ?? [];

  // ──────────────────────────────────────────────────────────────────────
  // HELPER: Convert TextAlign enum to string
  // ──────────────────────────────────────────────────────────────────────
  static String textAlignToString(TextAlign align) {
    switch (align) {
      case TextAlign.left:
        return 'left';
      case TextAlign.center:
        return 'center';
      case TextAlign.right:
        return 'right';
      case TextAlign.justify:
        return 'justify';
      default:
        return 'left';
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // HELPER: Convert string to TextAlign enum
  // ──────────────────────────────────────────────────────────────────────
  static TextAlign stringToTextAlign(String align) {
    switch (align.toLowerCase()) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      case 'justify':
        return TextAlign.justify;
      case 'left':
      default:
        return TextAlign.left;
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // GETTER: Get TextAlign enum for UI
  // ──────────────────────────────────────────────────────────────────────
  TextAlign get textAlignEnum => stringToTextAlign(textAlign);

  // ──────────────────────────────────────────────────────────────────────
  // TO MAP – always store as UTC
  // ──────────────────────────────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category': category,
      'priority': priority,
      'address': address,
      'reminder': reminder?.toUtc().toIso8601String(),
      'pinned': pinned ? 1 : 0,
      'images': jsonEncode(images),
      'audios': jsonEncode(audios),
      'checklist': jsonEncode(checklist.map((i) => i.toMap()).toList()),
      'note_date_time': noteDateTime?.toUtc().toIso8601String(),
      'text_align': textAlign, // NEW
      'font_size': fontSize, // NEW
      // created_at set by DB
    };
  }

  // ──────────────────────────────────────────────────────────────────────
  // FROM MAP – parse UTC, keep UTC (local when displayed)
  // ──────────────────────────────────────────────────────────────────────
  factory NoteModels.fromMap(Map<String, dynamic> map) {
    return NoteModels(
      id: map['id'],
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      category: map['category'] ?? '',
      priority: map['priority'] ?? 'None',
      address: map['address'] ?? '',
      reminder: map['reminder'] != null
          ? DateTime.parse(map['reminder'])
          : null,
      pinned: (map['pinned'] as int? ?? 0) == 1,
      noteDateTime: map['note_date_time'] != null
          ? DateTime.parse(map['note_date_time'])
          : null,
      images: _decodeStringList(map['images']),
      audios: _decodeStringList(map['audios']),
      checklist: _decodeChecklist(map['checklist']),
      createdAt: map['created_at'],
      textAlign: map['text_align'] ?? 'left', // NEW
      fontSize: (map['font_size'] ?? 18.0).toDouble(), // NEW
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Safe JSON decode
  // ──────────────────────────────────────────────────────────────────────
  static List<String> _decodeStringList(dynamic raw) {
    if (raw == null) return [];
    if (raw is String) {
      try {
        final list = jsonDecode(raw);
        if (list is List) return list.cast<String>();
      } catch (e) {
        debugPrint('NoteModels: JSON decode error (images/audios): $e');
      }
    }
    if (raw is List) return raw.cast<String>();
    return [];
  }

  static List<ChecklistItem> _decodeChecklist(dynamic raw) {
    if (raw == null) return [];
    if (raw is String) {
      try {
        final list = jsonDecode(raw);
        if (list is List) {
          return list
              .map((e) => ChecklistItem.fromMap(Map<String, dynamic>.from(e)))
              .toList();
        }
      } catch (e) {
        debugPrint('NoteModels: JSON decode error (checklist): $e');
      }
    }
    if (raw is List) {
      return raw
          .map((e) => ChecklistItem.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  // ──────────────────────────────────────────────────────────────────────
  // copyWith
  // ──────────────────────────────────────────────────────────────────────
  NoteModels copyWith({
    int? id,
    String? title,
    String? content,
    String? category,
    String? priority,
    String? address,
    DateTime? reminder,
    bool? pinned,
    List<String>? images,
    List<String>? audios,
    DateTime? noteDateTime,
    List<ChecklistItem>? checklist,
    String? createdAt,
    String? textAlign, // NEW
    double? fontSize, // NEW
  }) {
    return NoteModels(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      address: address ?? this.address,
      reminder: reminder ?? this.reminder,
      pinned: pinned ?? this.pinned,
      images: images ?? this.images,
      audios: audios ?? this.audios,
      noteDateTime: noteDateTime ?? this.noteDateTime,
      checklist: checklist ?? this.checklist,
      createdAt: createdAt ?? this.createdAt,
      textAlign: textAlign ?? this.textAlign, // NEW
      fontSize: fontSize ?? this.fontSize, // NEW
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // DISPLAY HELPERS – Device Local Time
  // ──────────────────────────────────────────────────────────────────────
  DateTime get localNoteDateTime =>
      noteDateTime?.toLocal() ?? DateTime.now().toLocal();

  DateTime? get localReminder => reminder?.toLocal();

  DateTime? get localCreatedAt {
    if (createdAt == null) return null;
    try {
      return DateTime.parse(createdAt!).toLocal();
    } catch (e) {
      debugPrint('NoteModels: Invalid createdAt: $createdAt');
      return null;
    }
  }

  @override
  String toString() {
    return 'NoteModels(id: $id, title: $title, category: $category, '
        'pinned: $pinned, textAlign: $textAlign, fontSize: $fontSize)';
  }
}