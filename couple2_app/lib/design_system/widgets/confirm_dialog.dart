import 'package:flutter/material.dart';

import 'pop_guard.dart';

/// Asks before a destructive action. The confirm control is a filled button
/// in the theme's primary style. Dismissing the dialog does not confirm.
///
/// Confirm and cancel share one [PopGuard], so a double tap closes the dialog
/// once and leaves the page underneath in place.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  Key? confirmKey,
  bool danger = false,
}) async {
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) {
      return SinglePop(
        builder: (context, pop) {
          return AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => pop.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                key: confirmKey,
                style: danger
                    ? FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      )
                    : null,
                onPressed: () => pop.pop(context, true),
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      );
    },
  );
  return accepted == true;
}
