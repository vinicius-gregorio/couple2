import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/core.dart';
import '../../../data/date_plans_providers.dart';
import '../../../domain/domain.dart';
import '../../../routing/routes.dart';

class DatePlanFormPage extends ConsumerStatefulWidget {
  const DatePlanFormPage({
    super.key,
    this.existing,
    this.sourceListItemId,
    this.initialTitle,
  });

  final DatePlan? existing;
  final String? sourceListItemId;
  final String? initialTitle;

  @override
  ConsumerState<DatePlanFormPage> createState() => _DatePlanFormPageState();
}

class _DatePlanFormPageState extends ConsumerState<DatePlanFormPage> {
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _description;
  late DateTime _when;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(
      text: existing?.title ?? widget.initialTitle ?? '',
    );
    _location = TextEditingController(text: existing?.location ?? '');
    _description = TextEditingController(text: existing?.description ?? '');
    _when = existing?.scheduledAt.toLocal() ?? _defaultWhen();
  }

  DateTime _defaultWhen() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1, 20);
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (time == null || !mounted) return;
    setState(() {
      _when = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      _toast('Dê um título ao date.');
      return;
    }
    if (!_when.isAfter(DateTime.now())) {
      _toast('Escolha um horário no futuro.');
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(datePlansRepositoryProvider);
      final location = _location.text.trim();
      final description = _description.text.trim();
      if (_editing) {
        await repo.update(
          widget.existing!.id,
          title: title,
          scheduledAt: _when,
          location: location,
          description: description,
          clearLocation: location.isEmpty,
          clearDescription: description.isEmpty,
        );
      } else {
        await repo.create(
          title: title,
          scheduledAt: _when,
          location: location.isEmpty ? null : location,
          description: description.isEmpty ? null : description,
          sourceListItemId: widget.sourceListItemId,
        );
      }
      ref.invalidate(nextDateProvider);
      ref.read(datePlansChangedProvider.notifier).bump();
      if (!mounted) return;
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go(DatePlanRoutes.list);
      }
    } on CPLHttpException catch (error) {
      _toast(
        datePlanErrorMessage(
          error.response?.statusCode,
          linkingItem: widget.sourceListItemId != null,
        ),
      );
    } catch (_) {
      _toast('Não consegui salvar agora.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppText(_editing ? 'Editar date' : 'Planejar um date'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _title,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Título',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Data e hora'),
            subtitle: Text('${datePlanWhen(_when)} · horário do aparelho'),
            trailing: const Icon(Icons.schedule),
            onTap: _saving ? null : _pickWhen,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _location,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Local (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLength: 500,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Descrição (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Salvando...' : 'Salvar'),
          ),
        ],
      ),
    );
  }
}
