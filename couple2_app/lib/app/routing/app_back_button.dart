import 'package:flutter/material.dart';

import '../../design_system/widgets/app_icon_button.dart';
import '../../design_system/widgets/mutation_scope.dart';
import '../../design_system/widgets/pop_guard.dart';
import 'pop_or_go.dart';
import 'routes.dart';

/// Back control that still works after a reload.
///
/// A pushed page pops. A deep link has an empty stack, so the arrow goes to
/// [fallback] instead of disappearing. A second tap does not pop again.
class AppBackButton extends StatefulWidget {
  const AppBackButton({
    super.key,
    this.fallback = APPRoutes.home,
    this.enabled = true,
  });

  final String fallback;

  /// False while a save or confirm is in flight, so the arrow cannot leave.
  final bool enabled;

  @override
  State<AppBackButton> createState() => _AppBackButtonState();
}

class _AppBackButtonState extends State<AppBackButton> {
  final _pop = PopGuard();

  @override
  Widget build(BuildContext context) {
    final locked = MutationScope.busyOf(context);
    return AppIconButton(
      tooltip: 'Voltar',
      icon: const BackButtonIcon(),
      onPressed: widget.enabled && !locked
          ? () => popOrGo(context, widget.fallback, guard: _pop)
          : null,
    );
  }
}
