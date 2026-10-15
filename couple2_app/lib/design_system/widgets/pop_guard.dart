import 'package:flutter/widgets.dart';

/// Pops at most once.
///
/// A modal sheet and the page under it share one navigator. After the sheet
/// route is gone, [Navigator.canPop] is still true, so a second tap removes
/// the page and leaves a blank route. The flag has to live on [State]: a
/// guard created inside a dialog builder is recreated on the next rebuild.
class PopGuard {
  var _used = false;

  bool get used => _used;

  /// Marks this guard spent. The first mounted caller wins.
  bool claim(BuildContext context) {
    if (_used || !context.mounted) return false;
    _used = true;
    return true;
  }

  /// Pops [result] once, and only while the navigator can pop.
  ///
  /// Returns false when this guard already popped, the context is unmounted,
  /// or there is nothing to pop. It does not pop in those cases.
  bool pop<T extends Object?>(BuildContext context, [T? result]) {
    if (_used || !context.mounted) return false;
    final navigator = Navigator.maybeOf(context);
    if (navigator == null || !navigator.canPop()) return false;
    _used = true;
    navigator.pop<T>(result);
    return true;
  }
}

/// Owns one [PopGuard] for a dialog built inside `showDialog`'s builder.
///
/// The builder runs again while the route is closing. This state keeps the
/// same flag so Cancelar and the confirm button cannot both pop.
class SinglePop extends StatefulWidget {
  const SinglePop({super.key, required this.builder});

  final Widget Function(BuildContext context, PopGuard guard) builder;

  @override
  State<SinglePop> createState() => _SinglePopState();
}

class _SinglePopState extends State<SinglePop> {
  final _guard = PopGuard();

  @override
  Widget build(BuildContext context) => widget.builder(context, _guard);
}
