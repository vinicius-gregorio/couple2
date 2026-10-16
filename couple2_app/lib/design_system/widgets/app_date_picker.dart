import 'package:flutter/material.dart';

import 'app_icon_button.dart';
import 'app_ink_well.dart';
import 'loading_button.dart';

/// Date dialog whose month and year controls always have a PT-BR name.
///
/// The Material picker leaves the previous-month control without a tooltip
/// on the first month, and on web a tooltip is not the accessible name.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  bool useRootNavigator = true,
}) {
  final first = DateTime(firstDate.year, firstDate.month, firstDate.day);
  final last = DateTime(lastDate.year, lastDate.month, lastDate.day);
  var initial = DateTime(initialDate.year, initialDate.month, initialDate.day);
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;
  return showDialog<DateTime>(
    context: context,
    useRootNavigator: useRootNavigator,
    builder: (context) {
      return _AppDateDialog(initial: initial, first: first, last: last);
    },
  );
}

const _monthNames = <String>[
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

class _AppDateDialog extends StatefulWidget {
  const _AppDateDialog({
    required this.initial,
    required this.first,
    required this.last,
  });

  final DateTime initial;
  final DateTime first;
  final DateTime last;

  @override
  State<_AppDateDialog> createState() => _AppDateDialogState();
}

class _AppDateDialogState extends State<_AppDateDialog> {
  late DateTime _visible;

  @override
  void initState() {
    super.initState();
    _visible = DateTime(widget.initial.year, widget.initial.month);
  }

  bool _inRange(DateTime day) {
    return !day.isBefore(widget.first) && !day.isAfter(widget.last);
  }

  void _shiftMonth(int delta) {
    final next = DateTime(_visible.year, _visible.month + delta);
    final firstMonth = DateTime(widget.first.year, widget.first.month);
    final lastMonth = DateTime(widget.last.year, widget.last.month);
    if (next.isBefore(firstMonth) || next.isAfter(lastMonth)) return;
    setState(() => _visible = next);
  }

  void _shiftYear(int delta) {
    _shiftMonth(delta * 12);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = DateTime(_visible.year, _visible.month + 1, 0).day;
    final leading = DateTime(_visible.year, _visible.month, 1).weekday % 7;
    final firstMonth = DateTime(widget.first.year, widget.first.month);
    final lastMonth = DateTime(widget.last.year, widget.last.month);
    final visibleMonth = DateTime(_visible.year, _visible.month);
    final canPrevMonth = visibleMonth.isAfter(firstMonth);
    final canNextMonth = visibleMonth.isBefore(lastMonth);
    final canPrevYear = !DateTime(
      _visible.year - 1,
      _visible.month,
    ).isBefore(firstMonth);
    final canNextYear = !DateTime(
      _visible.year + 1,
      _visible.month,
    ).isAfter(lastMonth);

    return AlertDialog(
      title: Text(
        '${_monthNames[_visible.month - 1]} ${_visible.year}',
        textAlign: TextAlign.center,
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _NavButton(
                  label: 'Ano anterior',
                  icon: Icons.arrow_back,
                  enabled: canPrevYear,
                  onPressed: () => _shiftYear(-1),
                ),
                _NavButton(
                  label: 'Próximo ano',
                  icon: Icons.chevron_right,
                  enabled: canNextYear,
                  onPressed: () => _shiftYear(1),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _NavButton(
                  label: 'Mês anterior',
                  icon: Icons.arrow_back,
                  enabled: canPrevMonth,
                  onPressed: () => _shiftMonth(-1),
                ),
                _NavButton(
                  label: 'Próximo mês',
                  icon: Icons.chevron_right,
                  enabled: canNextMonth,
                  onPressed: () => _shiftMonth(1),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              childAspectRatio: 1.3,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < leading; i++) const SizedBox.shrink(),
                for (var day = 1; day <= days; day++)
                  _DayCell(
                    day: day,
                    enabled: _inRange(
                      DateTime(_visible.year, _visible.month, day),
                    ),
                    color: scheme.primary,
                    onPressed: () {
                      final nav = Navigator.of(context);
                      final picked = DateTime(
                        _visible.year,
                        _visible.month,
                        day,
                      );
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (nav.mounted) nav.pop(picked);
                      });
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        LoadingButton(
          variant: LoadingButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: enabled ? onPressed : null,
      child: ExcludeSemantics(
        child: AppIconButton(
          tooltip: label,
          onPressed: enabled ? onPressed : null,
          icon: Icon(icon),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.enabled,
    required this.color,
    required this.onPressed,
  });

  final int day;
  final bool enabled;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppInkWell(
      onTap: enabled ? onPressed : null,
      child: Center(
        child: Text(
          '$day',
          style: TextStyle(color: enabled ? color : color.withValues(alpha: 0.3)),
        ),
      ),
    );
  }
}
