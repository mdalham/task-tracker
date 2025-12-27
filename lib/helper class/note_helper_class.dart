import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tasktracker/service/note/provider/notes_provider.dart';
import 'package:tasktracker/widget/custom_snack_bar.dart';
import '../models/dialog/delete_dialog.dart';
import '../service/note/db/notes_models.dart';

class NoteHelperClass {
  static Color priorityColor(NoteModels note, ColorScheme cs) {
    switch (note.priority) {
      case 'High':
        return Colors.redAccent;
      case 'Medium':
        return Colors.orangeAccent;
      case 'Low':
        return Colors.green;
      default:
        return cs.outline;
    }
  }

  static WrapAlignment convertTextAlignToWrapAlignment(TextAlign textAlign) {
    switch (textAlign) {
      case TextAlign.left:
        return WrapAlignment.start;
      case TextAlign.center:
        return WrapAlignment.center;
      case TextAlign.right:
        return WrapAlignment.end;
      case TextAlign.justify:
        return WrapAlignment.start;
      default:
        return WrapAlignment.start;
    }
  }

  static Future<bool> deleteNote(BuildContext context, NoteModels note) async {
    final TextTheme textTheme = Theme.of(context).textTheme;
    // 1. Show confirmation dialog
    final confirm = await deleteDialog(
      context: context,
      title: "Delete Note?",
      message: "Delete this note? This action cannot be undone.",
      confirmText: "Delete",
    );

    if (confirm != true) return false;
    if (note.id == null) return false;

    final provider = Provider.of<NoteProvider>(context, listen: false);

    final NoteModels deletedNote = note;
    provider.deleteNote(note.id!);

    // 3. Show SnackBar with UNDO
    if (!context.mounted) return true;

    CustomSnackBar.show(
      context,
      message: 'Note deleted successfully!',
      type: SnackBarType.success,
      actionLabel: 'Undo',
      onAction: () async {
        await provider.addNote(deletedNote);
      },
    );

    try {
      await provider.deleteNote(deletedNote.id!);
    } catch (e) {
      debugPrint('Permanent delete failed (but already removed from UI): $e');
    }

    return true;
  }
}
