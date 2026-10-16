import 'package:flutter/material.dart';

import 'app_ink_well.dart';

/// Modal sheet with its own scaffold, so a mutation SnackBar is visible
/// above the sheet and the sheet's content keeps its height.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (context) {
      return ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              Positioned.fill(
                child: isDismissible
                    ? Material(
                        color: Colors.transparent,
                        child: AppInkWell(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: const SizedBox.expand(),
                        ),
                      )
                    : const SizedBox.expand(),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 1,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: builder(context),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
