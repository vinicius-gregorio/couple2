import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/routing/app_back_button.dart';
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
  final _pop = PopGuard();

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
    _title.addListener(_onTitleChanged);
  }

  void _onTitleChanged() {
    if (mounted) setState(() {});
  }

  DateTime _defaultWhen() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1, 20);
  }

  @override
  void dispose() {
    _title.removeListener(_onTitleChanged);
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
    if (_saving || _pop.used) return;
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
      final DatePlan saved;
      if (_editing) {
        saved = await repo.update(
          widget.existing!.id,
          title: title,
          scheduledAt: _when,
          location: location,
          description: description,
          clearLocation: location.isEmpty,
          clearDescription: description.isEmpty,
        );
      } else {
        saved = await repo.create(
          title: title,
          scheduledAt: _when,
          location: location.isEmpty ? null : location,
          description: description.isEmpty ? null : description,
          sourceListItemId: widget.sourceListItemId,
        );
      }
      ref.invalidate(nextDateProvider);
      ref.read(datePlansChangedProvider.notifier).bump();
      if (!mounted || _pop.used) return;
      if (context.canPop()) {
        if (!_pop.claim(context)) return;
        context.pop(saved);
      } else if (_pop.claim(context)) {
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton(enabled: !_saving),
        title: AppText(_editing ? 'Editar o date' : 'Planejar um date'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _title,
            enabled: !_saving,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Título'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Data e hora'),
            subtitle: Text('${datePlanWhen(_when)} · horário do aparelho'),
            trailing: Icon(
              Icons.schedule,
              color: _saving
                  ? scheme.onSurface.withValues(alpha: 0.38)
                  : scheme.primary,
            ),
            onTap: _saving ? null : _pickWhen,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _location,
            enabled: !_saving,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Local (opcional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            enabled: !_saving,
            maxLength: 500,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Descrição (opcional)',
            ),
          ),
          const SizedBox(height: 24),
          LoadingButton(
            variant: LoadingButtonVariant.filled,
            loading: _saving,
            onPressed: _saving || _title.text.trim().isEmpty ? null : _save,
            child: Text(_saving ? 'Salvando…' : 'Salvar'),
          ),
        ],
      ),
    );
  }
}
