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
    _error = userFacingError(error);
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
