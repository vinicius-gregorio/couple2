import 'package:flutter/material.dart';

import 'loading_button.dart';
import 'pop_guard.dart';

/// Asks before a destructive action. Confirm is the primary filled button.
/// Dismissing the dialog does not confirm.
///
/// Confirm and cancel share one [PopGuard], so a double tap closes the dialog
/// once and leaves the page underneath in place.
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
      return SinglePop(
        builder: (context, pop) {
          return AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              LoadingButton(
                variant: LoadingButtonVariant.text,
                onPressed: () => pop.pop(context, false),
                child: const Text('Cancelar'),
              ),
              LoadingButton(
                key: confirmKey,
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
