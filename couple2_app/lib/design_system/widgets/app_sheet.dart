import 'package:flutter/material.dart';

import 'app_ink_well.dart';
import 'mutation_scope.dart';

/// Modal sheet with its own scaffold, so a mutation SnackBar is visible
/// above the sheet and the sheet's content keeps its height.
///
/// The sheet is its own route, so it carries its own [MutationScope]. The
/// barrier still dismisses the sheet, and it stays out of the semantics tree.
/// The scrim inside the scope has no tap while a save is in flight.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  final navigator = Navigator.of(context);
  final localizations = MaterialLocalizations.of(context);
  // The route stays dismissible, but its barrier is kept out of the semantics
  // tree. A dismissible Material barrier is an enabled tap at the sheet origin.
  return navigator.push(
    _QuietBarrierSheetRoute<T>(
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      isScrollControlled: isScrollControlled,
      barrierLabel: localizations.scrimLabel,
      barrierOnTapHint: localizations.scrimOnTapHint(
        localizations.bottomSheetLabel,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      builder: (context) {
        // Fill the route so the scrim covers the sheet column, including the
        // origin the semantics harness was still finding enabled.
        return SizedBox.expand(
          child: MutationScope(
            child: ScaffoldMessenger(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                resizeToAvoidBottomInset: false,
                body: Stack(
                  children: [
                    Positioned.fill(
                      child: _SheetScrim(dismissible: isDismissible),
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
                        child: Builder(builder: builder),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Bottom sheet whose scrim still dismisses, without a semantics tap.
class _QuietBarrierSheetRoute<T> extends ModalBottomSheetRoute<T> {
  _QuietBarrierSheetRoute({
    required super.builder,
    super.capturedThemes,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.backgroundColor,
    super.elevation,
    super.isDismissible,
    super.enableDrag,
    required super.isScrollControlled,
  });

  @override
  bool get semanticsDismissible => false;
}

class _SheetScrim extends StatelessWidget {
  const _SheetScrim({required this.dismissible});

  final bool dismissible;

  @override
  Widget build(BuildContext context) {
    final busy = MutationScope.busyOf(context);
    // Absorb the tap so it does not fall through to the route barrier, which
    // would still pop the sheet while a save is in flight.
    if (!dismissible || busy) {
      return const AbsorbPointer(child: SizedBox.expand());
    }
    return Material(
      color: Colors.transparent,
      child: AppInkWell(
        onTap: () => Navigator.of(context).maybePop(),
        child: const SizedBox.expand(),
      ),
    );
  }
}
