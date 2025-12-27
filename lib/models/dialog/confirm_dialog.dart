import 'package:flutter/material.dart';

Future<bool?> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String cancelText = "Cancel",
  String confirmText = "Confirm",
  Color confirmColor = Colors.blue,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Text(title,style: Theme.of(context).textTheme.titleLarge,),
      content: Text(message,style: Theme.of(context).textTheme.bodyMedium,),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelText,style: Theme.of(context).textTheme.titleMedium,),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: confirmColor),
          child: Text(confirmText,style: Theme.of(context).textTheme.titleMedium!.copyWith(
            color: Colors.white
          )),
        ),
      ],
    ),
  );
}
