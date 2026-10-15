import 'package:flutter/material.dart';

/// Asks before a destructive action. The confirm control is a filled button
/// in the theme's primary style. Dismissing the dialog does not confirm.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  Key? confirmKey,
}) async {
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: confirmKey,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return accepted == true;
}
