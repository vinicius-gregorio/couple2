import 'package:flutter/material.dart';

import '../../core/errors/user_facing_error.dart';

/// One in-flight mutation for the screen under this scope.
///
/// A second call while [busy] is ignored, so a double tap cannot send two
/// requests. Every button, the back arrow, and the FAB read [busy] and lock.
class MutationController extends ChangeNotifier {
  var _busy = false;
  var _disposed = false;
  Object? _owner;
  String? _error;

  bool get busy => _busy;
  String? get error => _error;

  bool owns(Object owner) => _busy && identical(_owner, owner);

  /// True when this caller may start or continue the in-flight request.
  bool claim(Object owner) {
    if (_disposed || _busy) return false;
    _busy = true;
    _owner = owner;
    _error = null;
    notifyListeners();
    return true;
  }

  void release(Object owner) {
    if (_disposed || !_busy || !identical(_owner, owner)) return;
    _busy = false;
    _owner = null;
    notifyListeners();
  }

  void report(Object error) {
    if (_disposed) return;
    _error = error is String ? error : userFacingError(error);
    notifyListeners();
  }

  void clearError() {
    if (_disposed || _error == null) return;
    _error = null;
    notifyListeners();
  }

  /// Runs [action] once. A call while [busy] does nothing and returns null.
  /// Failures are mapped with [userFacingError] and stored on [error].
  Future<T?> run<T>(Object owner, Future<T> Function() action) async {
    if (!claim(owner)) return null;
    try {
      return await action();
    } catch (error) {
      report(error);
      return null;
    } finally {
      release(owner);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Locks the whole scaffold (or sheet) for the duration of one mutation.
class MutationScope extends StatefulWidget {
  const MutationScope({super.key, required this.child});

  final Widget child;

  static MutationController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_MutationInherited>()
        ?.controller;
  }

  static bool busyOf(BuildContext context) => maybeOf(context)?.busy ?? false;

  /// One SnackBar for a failed mutation. The nearest scope records it, and the
  /// bar itself is always this standard SnackBar.
  static void reportError(BuildContext context, Object error) {
    maybeOf(context)?.report(error);
    final message = error is String ? error : userFacingError(error);
    showActionSnackBar(context, message);
  }

  @override
  State<MutationScope> createState() => _MutationScopeState();
}

class _MutationScopeState extends State<MutationScope> {
  final _controller = MutationController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _MutationInherited(
      controller: _controller,
      busy: _controller.busy,
      child: Stack(
        children: [
          widget.child,
          if (_controller.busy)
            const Positioned.fill(
              child: ModalBarrier(
                dismissible: false,
                color: Color(0x00000000),
              ),
            ),
        ],
      ),
    );
  }
}

class _MutationInherited extends InheritedWidget {
  const _MutationInherited({
    required this.controller,
    required this.busy,
    required super.child,
  });

  final MutationController controller;
  final bool busy;

  @override
  bool updateShouldNotify(_MutationInherited oldWidget) {
    return busy != oldWidget.busy || controller != oldWidget.controller;
  }
}

/// Standard SnackBar for a PT-BR action failure. It does not take layout space.
void showActionSnackBar(BuildContext context, String message) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Watches a failure string and presents it through [MutationScope.reportError].
///
/// The widget itself is empty, so the message never pushes the page.
class ActionErrorReporter extends StatefulWidget {
  const ActionErrorReporter({super.key, this.message, this.onReported});

  final String? message;
  final VoidCallback? onReported;

  @override
  State<ActionErrorReporter> createState() => _ActionErrorReporterState();
}

class _ActionErrorReporterState extends State<ActionErrorReporter> {
  String? _last;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(ActionErrorReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final message = widget.message;
      if (message == null || message.isEmpty) {
        if (_last != null) {
          ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
        }
        _last = null;
        return;
      }
      if (message == _last) return;
      _last = message;
      MutationScope.reportError(context, message);
      widget.onReported?.call();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Reports disabled while a mutation is in flight.
///
/// A grey icon with a live semantics node still reads as enabled. This wrapper
/// removes the children's nodes and exposes one disabled control instead.
class MutationLock extends StatelessWidget {
  const MutationLock({super.key, required this.child, this.locked = false});

  final Widget child;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final busy = locked || MutationScope.busyOf(context);
    if (!busy) return child;
    return Semantics(
      container: true,
      button: true,
      enabled: false,
      child: ExcludeSemantics(child: IgnorePointer(child: child)),
    );
  }
}
