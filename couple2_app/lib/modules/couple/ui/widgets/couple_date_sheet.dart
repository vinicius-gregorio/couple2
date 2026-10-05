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
  const CoupleDateSheet({super.key, this.existing});

  final CoupleDate? existing;

  @override
  State<CoupleDateSheet> createState() => _CoupleDateSheetState();
}

class _CoupleDateSheetState extends State<CoupleDateSheet> {
  late final TextEditingController _title;
  late DateTime? _date;
  late String _recurrence;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _date = parseDateOnly(widget.existing?.date);
    _recurrence = widget.existing?.recurrence ?? 'YEARLY';
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    final title = _title.text.trim();
    final date = _date;
    if (title.isEmpty || title.length > 60 || date == null) return;
    Navigator.of(context).pop(
      CoupleDateDraft(
        title: title,
        date: formatDateOnly(date),
        recurrence: _recurrence,
      ),
    );
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
            'Datas recorrentes do casal. Conquistas continuam na lista Milestones.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Título'),
            autofocus: true,
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _pickDate,
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
            onChanged: (value) {
              if (value != null) setState(() => _recurrence = value);
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submit,
            child: Text(editing ? 'Salvar' : 'Adicionar'),
          ),
        ],
      ),
    );
  }
}
