import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'mutation_scope.dart';

/// Modal sheet with its own scaffold, so a mutation SnackBar is visible
/// above the sheet and the sheet's content keeps its height.
///
/// The sheet is its own route and its own [MutationScope]. While that scope
/// is busy, the barrier, Escape, system back, and drag cannot dismiss it.
/// [isDismissible] and [enableDrag] apply only while the save is idle.
/// The barrier stays out of the semantics tree.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool isDismissible = true,
  bool enableDrag = true,
  Future<void> Function()? onSuccess,
}) {
  final navigator = Navigator.of(context);
  final localizations = MaterialLocalizations.of(context);
  late final _QuietBarrierSheetRoute<T> route;
  route = _QuietBarrierSheetRoute<T>(
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
    builder: (sheetContext) {
      return SizedBox.expand(
        child: MutationScope(
          onSuccess: onSuccess,
          child: _SheetDismissLock(
            lock: route,
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
                        color: Theme.of(sheetContext).colorScheme.surface,
                        elevation: 1,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Builder(builder: builder),
                      ),
                    ),
                    if (enableDrag)
                      const Positioned.fill(child: _IdleDragDismiss()),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  return navigator.push(route);
}

/// Bottom sheet whose scrim still dismisses when idle, without a semantics tap.
///
/// [ModalBottomSheetRoute.enableDrag] is copied into a private sheet and
/// cannot change after the route is built, and that drag calls [Navigator.pop]
/// directly. The route is therefore created with drag off. [_IdleDragDismiss]
/// pops only while the caller asked for drag and the scope is idle.
abstract class _SheetLock {
  void setSaving(bool saving);
  bool get barrierDismissible;
}

class _QuietBarrierSheetRoute<T> extends ModalBottomSheetRoute<T>
    implements _SheetLock {
  _QuietBarrierSheetRoute({
    required super.builder,
    super.capturedThemes,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.backgroundColor,
    super.elevation,
    required super.isDismissible,
    required super.isScrollControlled,
  }) : _requestedDismiss = isDismissible,
       _open = isDismissible,
       super(enableDrag: false);

  final bool _requestedDismiss;
  bool _open;

  /// [saving] follows the sheet [MutationScope]. Escape and the barrier read
  /// [barrierDismissible], so both close only while this stays true.
  @override
  void setSaving(bool saving) {
    final open = _requestedDismiss && !saving;
    if (_open == open) return;
    _open = open;
    if (!isActive) return;
    final building =
        SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks;
    if (building) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isActive) changedInternalState();
      });
      return;
    }
    changedInternalState();
  }

  @override
  bool get barrierDismissible => _open;

  @override
  bool get semanticsDismissible => false;
}

/// Keeps [PopScope] and the route barrier aligned with the sheet scope.
class _SheetDismissLock extends StatefulWidget {
  const _SheetDismissLock({required this.lock, required this.child});

  final _SheetLock lock;
  final Widget child;

  @override
  State<_SheetDismissLock> createState() => _SheetDismissLockState();
}

class _SheetDismissLockState extends State<_SheetDismissLock> {
  MutationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = MutationScope.maybeOf(context);
    if (identical(next, _controller)) return;
    _controller?.removeListener(_sync);
    _controller = next;
    _controller?.addListener(_sync);
    _sync();
  }

  void _sync() {
    widget.lock.setSaving(_controller?.busy ?? false);
  }

  @override
  void dispose() {
    _controller?.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _controller?.busy ?? MutationScope.busyOf(context);
    return PopScope(
      canPop: widget.lock.barrierDismissible && !busy,
      child: widget.child,
    );
  }
}

class _SheetScrim extends StatelessWidget {
  const _SheetScrim({required this.dismissible});

  final bool dismissible;

  @override
  Widget build(BuildContext context) {
    final busy = MutationScope.busyOf(context);
    final open = dismissible && !busy;
    // The scrim fills the route, behind the sheet. A button node here wins
    // the semantics hit test on the web and the text field never focuses.
    return ExcludeSemantics(
      child: open
          ? RawGestureDetector(
              excludeFromSemantics: true,
              behavior: HitTestBehavior.opaque,
              gestures: <Type, GestureRecognizerFactory>{
                TapGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                      () => TapGestureRecognizer(debugOwner: this),
                      (TapGestureRecognizer instance) {
                        instance.onTap = () => Navigator.of(context).maybePop();
                      },
                    ),
              },
              child: const SizedBox.expand(),
            )
          : const AbsorbPointer(child: SizedBox.expand()),
    );
  }
}

/// Downward drag dismisses the sheet only while the scope is idle.
///
/// A translucent recognizer so taps still reach the sheet controls.
///
/// It stays out of the semantics tree. A full-screen gesture node painted
/// over the form takes the web click, and the text field never becomes an
/// input.
class _IdleDragDismiss extends StatelessWidget {
  const _IdleDragDismiss();

  @override
  Widget build(BuildContext context) {
    if (MutationScope.busyOf(context)) return const SizedBox.shrink();
    return _DragToDismiss(
      onDismiss: () => Navigator.of(context).maybePop(),
    );
  }
}

class _DragToDismiss extends StatefulWidget {
  const _DragToDismiss({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  State<_DragToDismiss> createState() => _DragToDismissState();
}

class _DragToDismissState extends State<_DragToDismiss> {
  var _dy = 0.0;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      excludeFromSemantics: true,
      behavior: HitTestBehavior.translucent,
      gestures: <Type, GestureRecognizerFactory>{
        VerticalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
              () => VerticalDragGestureRecognizer(debugOwner: this),
              (VerticalDragGestureRecognizer instance) {
                instance
                  ..onlyAcceptDragOnThreshold = true
                  ..onStart = (_) {
                    _dy = 0;
                  }
                  ..onUpdate = (details) {
                    _dy += details.delta.dy;
                  }
                  ..onEnd = (details) {
                    final flung =
                        details.velocity.pixelsPerSecond.dy > 700 || _dy > 64;
                    _dy = 0;
                    if (flung) widget.onDismiss();
                  };
              },
            ),
      },
      child: const SizedBox.expand(),
    );
  }
}
