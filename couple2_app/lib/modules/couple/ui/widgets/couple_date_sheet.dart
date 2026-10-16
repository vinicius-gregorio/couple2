import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../domain/domain.dart';

class CoupleDateDraft {
  const CoupleDateDraft({
    required this.title,
    required this.date,
    required this.recurrence,
  });

  final String title;
  final String date;
  final String recurrence;
}

class CoupleDateSheet extends StatefulWidget {
  const CoupleDateSheet({
    super.key,
    this.existing,
    this.onSave,
    this.hostContext,
  });

  final CoupleDate? existing;
  final BuildContext? hostContext;

  /// Saves the draft. Null means success. A message keeps the sheet open.
  final Future<String?> Function(CoupleDateDraft draft)? onSave;

  @override
  State<CoupleDateSheet> createState() => _CoupleDateSheetState();
}

class _CoupleDateSheetState extends State<CoupleDateSheet> {
  late final TextEditingController _title;
  late DateTime? _date;
  late String _recurrence;
  var _saving = false;
  String? _error;
  final _pop = PopGuard();

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _date = parseDateOnly(widget.existing?.date) ?? DateTime.now();
    _recurrence = widget.existing?.recurrence ?? 'YEARLY';
    _title.addListener(_onTitleChanged);
  }

  void _onTitleChanged() {
    if (mounted) setState(() {});
  }

  bool get _canSubmit {
    final title = _title.text.trim();
    return title.isNotEmpty && title.length <= 60 && _date != null;
  }

  @override
  void dispose() {
    _title.removeListener(_onTitleChanged);
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final host = widget.hostContext;
    final navigator = Navigator.of(
      host != null && host.mounted ? host : context,
      rootNavigator: true,
    );
    final picked = await showAppDatePicker(
      context: navigator.context,
      useRootNavigator: true,
      initialDate: _date ?? now,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final date = _date;
    if (_saving ||
        title.isEmpty ||
        title.length > 60 ||
        date == null ||
        _pop.used) {
      return;
    }
    final draft = CoupleDateDraft(
      title: title,
      date: formatDateOnly(date),
      recurrence: _recurrence,
    );
    final save = widget.onSave;
    if (save == null) {
      _pop.pop(context, true);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final message = await save(draft);
    if (!mounted || _pop.used) return;
    if (message != null) {
      setState(() {
        _saving = false;
        _error = message;
      });
      return;
    }
    _pop.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppText(
            editing ? 'Editar data' : 'Nova data',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const AppText(
            'Datas recorrentes do casal. Conquistas continuam na lista de marcos.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            enabled: !_saving,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Título'),
            autofocus: true,
          ),
          const SizedBox(height: 8),
          LoadingButton(
            variant: LoadingButtonVariant.outlined,
            onPressed: _saving
                ? null
                : () {
                    _pickDate();
                  },
            child: Text(
              _date == null
                  ? 'Escolher data'
                  : formatDisplayDate(formatDateOnly(_date!)),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _recurrence,
            decoration: const InputDecoration(labelText: 'Repetição'),
            items: const [
              DropdownMenuItem(value: 'YEARLY', child: Text('Todo ano')),
              DropdownMenuItem(value: 'NONE', child: Text('Uma vez')),
            ],
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) setState(() => _recurrence = value);
                  },
          ),
          ActionErrorReporter(message: _error),
          const SizedBox(height: 16),
          LoadingButton(
            loading: _saving,
            onPressed: _canSubmit && !_saving ? _submit : null,
            child: Text(
              editing ? 'Salvar' : 'Adicionar',
            ),
          ),
        ],
      ),
    );
  }
}
