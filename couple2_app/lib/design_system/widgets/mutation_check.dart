import 'package:flutter/material.dart';

import 'app_ink_well.dart';
import 'loading_button.dart';
import 'mutation_scope.dart';

/// Checkbox that joins [MutationScope].
///
/// A second change while any mutation is in flight is ignored. The parent
/// keeps [value], so a failed request can put the old value back. The control
/// occupies a fixed slot, with the spinner in that same box.
class MutationCheckbox extends StatefulWidget {
  const MutationCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.loading = false,
    this.busyKey,
  });

  final bool value;
  final Future<void> Function(bool value)? onChanged;
  final bool loading;
  final Key? busyKey;

  static const double slot = 40;

  @override
  State<MutationCheckbox> createState() => _MutationCheckboxState();
}

class _MutationCheckboxState extends State<MutationCheckbox> {
  var _busy = false;
  MutationController? _scope;

  bool get _showSpinner => _busy || widget.loading;

  Future<void> _change(bool next) async {
    if (_busy || widget.loading || widget.onChanged == null) return;
    final scope = MutationScope.maybeOf(context);
    if (scope != null && scope.busy) return;
    if (scope != null && !scope.claim(this)) return;
    _scope = scope;
    setState(() => _busy = true);
    try {
      await widget.onChanged!(next);
      await _scope?.refresh();
    } finally {
      _scope?.release(this);
      _scope = null;
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _scope?.release(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scopeBusy =
        MutationScope.busyOf(context) &&
        !(MutationScope.maybeOf(context)?.owns(this) ?? false);
    final locked = widget.onChanged == null || _showSpinner || scopeBusy;
    return SizedBox(
      width: MutationCheckbox.slot,
      height: MutationCheckbox.slot,
      child: _showSpinner
          ? Center(child: AppSpinner(key: widget.busyKey, size: 24))
          : Checkbox(
              value: widget.value,
              onChanged: locked
                  ? null
                  : (value) {
                      if (value == null) return;
                      _change(value);
                    },
            ),
    );
  }
}

/// Switch or switch row that joins [MutationScope].
///
/// Async [onChanged] shows a spinner in a fixed slot and does not paint the
/// unsaved thumb. The parent owns [value] and reverts it when the request
/// fails. A sync callback only updates local state and does not lock.
class MutationSwitch extends StatefulWidget {
  const MutationSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.contentPadding,
  });

  final bool value;
  final Function(bool value)? onChanged;
  final Widget? title;
  final Widget? subtitle;
  final EdgeInsetsGeometry? contentPadding;

  @override
  State<MutationSwitch> createState() => _MutationSwitchState();
}

class _MutationSwitchState extends State<MutationSwitch> {
  var _busy = false;
  var _epoch = 0;
  MutationController? _scope;

  Future<void> _change(bool next) async {
    if (_busy || widget.onChanged == null) return;
    final scope = MutationScope.maybeOf(context);
    if (scope != null && scope.busy) return;
    final result = widget.onChanged!(next);
    if (result is! Future) {
      if (mounted) setState(() => _epoch++);
      return;
    }
    if (scope != null && !scope.claim(this)) return;
    _scope = scope;
    setState(() {
      _busy = true;
      _epoch++;
    });
    try {
      await result;
      await _scope?.refresh();
    } finally {
      _scope?.release(this);
      _scope = null;
      if (mounted) {
        setState(() {
          _busy = false;
          _epoch++;
        });
      }
    }
  }

  @override
  void dispose() {
    _scope?.release(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scopeBusy =
        MutationScope.busyOf(context) &&
        !(MutationScope.maybeOf(context)?.owns(this) ?? false);
    final locked = widget.onChanged == null || _busy || scopeBusy;
    final control = SizedBox(
      width: 52,
      height: 40,
      child: _busy
          ? const Center(child: AppSpinner(size: 24))
          : Switch(
              key: ValueKey('mutation-switch-$_epoch'),
              value: widget.value,
              onChanged: locked ? null : _change,
            ),
    );
    if (widget.title == null && widget.subtitle == null) return control;
    return AppInkWell(
      onTap: locked ? null : () => _change(!widget.value),
      child: Padding(
        padding:
            widget.contentPadding ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.title != null) widget.title!,
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    widget.subtitle!,
                  ],
                ],
              ),
            ),
            control,
          ],
        ),
      ),
    );
  }
}
