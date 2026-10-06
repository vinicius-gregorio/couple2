import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/session_provider.dart';
import '../../../../../core/core.dart';
import '../../../../feed/data/feed_providers.dart';
import '../../../../lists/data/lists_providers.dart';
import '../../../../lists/ui/pages/lists/lists_viewmodel.dart';
import '../../../data/date_plans_providers.dart';
import '../../../domain/domain.dart';
import '../date_plan_form/date_plan_form_page.dart';

class DatePlanDetailPage extends ConsumerStatefulWidget {
  const DatePlanDetailPage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<DatePlanDetailPage> createState() => _DatePlanDetailPageState();
}

class _DatePlanDetailPageState extends ConsumerState<DatePlanDetailPage> {
  DatePlan? _plan;
  Object? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = _plan == null;
      _error = null;
    });
    try {
      final plan = await ref.read(datePlansRepositoryProvider).get(widget.id);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _run(Future<DatePlan> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final plan = await action();
      ref.invalidate(nextDateProvider);
      ref.invalidate(feedPreviewProvider);
      ref.read(datePlansChangedProvider.notifier).bump();
      if (!mounted) return;
      setState(() => _plan = plan);
    } on CPLHttpException catch (error) {
      _toast(datePlanErrorMessage(error.response?.statusCode));
      await _load();
    } catch (_) {
      _toast('Não consegui salvar agora.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept() {
    return _run(() => ref.read(datePlansRepositoryProvider).accept(widget.id));
  }

  Future<void> _decline() async {
    final note = await _askNote(title: 'Recusar date', confirm: 'Recusar');
    if (note == null) return;
    await _run(
      () =>
          ref.read(datePlansRepositoryProvider).decline(widget.id, note: note),
    );
  }

  Future<void> _cancel() async {
    final note = await _askNote(title: 'Cancelar date', confirm: 'Cancelar');
    if (note == null) return;
    await _run(
      () => ref.read(datePlansRepositoryProvider).cancel(widget.id, note: note),
    );
  }

  Future<void> _counter() async {
    final current = _plan?.scheduledAt.toLocal() ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    final when = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!when.isAfter(DateTime.now())) {
      _toast('Escolha um horário no futuro.');
      return;
    }
    final note = await _askNote(
      title: 'Sugerir outro horário',
      confirm: 'Sugerir',
    );
    if (note == null) return;
    await _run(
      () => ref
          .read(datePlansRepositoryProvider)
          .counter(widget.id, scheduledAt: when, note: note),
    );
  }

  Future<void> _done() async {
    DatePlan? updated;
    await _run(() async {
      updated = await ref.read(datePlansRepositoryProvider).done(widget.id);
      return updated!;
    });
    final plan = updated;
    if (plan == null || !mounted) return;
    await _offerCompleteSource(plan);
  }

  Future<void> _offerCompleteSource(DatePlan plan) async {
    final item = plan.sourceListItem;
    if (plan.sourceListItemId == null || item == null || item.isCompleted) {
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text("Marcar '${item.content}' como assistido?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Agora não'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Marcar'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await ref.read(listsRepositoryProvider).toggleItem(item.id);
      ref.invalidate(listsViewModelProvider);
    } catch (_) {
      _toast('O date foi marcado, mas o item da lista não.');
    }
  }

  Future<void> _edit() async {
    final plan = _plan;
    if (plan == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => DatePlanFormPage(existing: plan)),
    );
    if (saved == true) await _load();
  }

  /// Returns the note, or null when the dialog is dismissed.
  /// An empty string means the partner skipped the optional note.
  Future<String?> _askNote({required String title, required String confirm}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLength: 140,
          decoration: const InputDecoration(labelText: 'Nota (opcional)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(confirm),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    if (_loading && plan == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (plan == null) {
      final missing =
          _error is CPLHttpException &&
          (_error! as CPLHttpException).response?.statusCode == 404;
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: AppText(
            missing ? 'Date não encontrado' : 'Não consegui carregar o date.',
          ),
        ),
      );
    }

    final me = ref.watch(sessionProvider).asData?.value?.id;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: AppText(plan.title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(label: Text(plan.status.label)),
          ),
          const SizedBox(height: 12),
          Text(
            datePlanWhen(plan.scheduledAt),
            style: theme.textTheme.headlineSmall,
          ),
          Text('Horário do aparelho', style: theme.textTheme.bodySmall),
          if (plan.location != null && plan.location!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(plan.location!),
          ],
          if (plan.description != null && plan.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(plan.description!),
          ],
          const SizedBox(height: 12),
          Text(
            me != null && plan.proposerId == me
                ? 'Proposto por você'
                : 'Proposto pelo parceiro',
          ),
          if (plan.sourceListItem != null)
            Text('A partir de ${plan.sourceListItem!.content}'),
          if (plan.sourceRemoved) const Text('Item removido'),
          if (plan.responseNote != null && plan.responseNote!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Nota: ${plan.responseNote}'),
          ],
          const SizedBox(height: 24),
          if (me == null)
            const AppText('Entre de novo para responder.')
          else
            _Actions(
              plan: plan,
              me: me,
              busy: _busy,
              onAccept: _accept,
              onDecline: _decline,
              onCounter: _counter,
              onEdit: _edit,
              onCancel: _cancel,
              onDone: _done,
            ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.plan,
    required this.me,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    required this.onCounter,
    required this.onEdit,
    required this.onCancel,
    required this.onDone,
  });

  final DatePlan plan;
  final String me;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onCounter;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      if (plan.canAccept(me))
        FilledButton(
          onPressed: busy ? null : onAccept,
          child: const Text('Aceitar'),
        ),
      if (plan.canDecline(me))
        OutlinedButton(
          onPressed: busy ? null : onDecline,
          child: const Text('Recusar'),
        ),
      if (plan.canCounter(me))
        TextButton(
          onPressed: busy ? null : onCounter,
          child: const Text('Sugerir outro horário'),
        ),
      if (plan.canEdit(me))
        FilledButton(
          onPressed: busy ? null : onEdit,
          child: const Text('Editar'),
        ),
      if (plan.canCancel(me))
        OutlinedButton(
          onPressed: busy ? null : onCancel,
          child: const Text('Cancelar'),
        ),
      if (plan.canDone(me))
        FilledButton(
          onPressed: busy ? null : onDone,
          child: const Text('Marcar como feito'),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final button in buttons) ...[button, const SizedBox(height: 8)],
      ],
    );
  }
}
