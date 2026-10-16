import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/routing/app_back_button.dart';
import '../../../../../core/core.dart';
import '../../../data/couple_providers.dart';
import '../../../domain/domain.dart';
import '../../widgets/couple_date_sheet.dart';

class ImportantDatesPage extends ConsumerStatefulWidget {
  const ImportantDatesPage({super.key});

  @override
  ConsumerState<ImportantDatesPage> createState() => _ImportantDatesPageState();
}

class _ImportantDatesPageState extends ConsumerState<ImportantDatesPage>
    with WidgetsBindingObserver {
  String? _deletingId;
  String? _confirmingId;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(coupleProvider);
      ref.read(coupleDatesProvider.notifier).reload();
    }
  }

  /// Publishes the saved row, then re-reads the list. The sheet awaits this
  /// before it pops, so the new title is already on the page.
  Future<void> _reloadDates() async {
    ref.invalidate(coupleProvider);
    await ref.read(coupleDatesProvider.notifier).reload();
  }

  Future<void> _openSheet([CoupleDate? existing]) async {
    if (_rowLocked) return;
    setState(() => _actionError = null);
    final host = context;
    final saved = await showAppSheet<bool>(
      context: host,
      onSuccess: _reloadDates,
      builder: (_) => CoupleDateSheet(
        existing: existing,
        hostContext: host,
        onSave: (draft) => _saveDraft(existing, draft),
      ),
    );
    if (saved == true && mounted) {
      _actionError = null;
    }
  }

  Future<String?> _saveDraft(CoupleDate? existing, CoupleDateDraft draft) async {
    try {
      final repo = ref.read(coupleRepositoryProvider);
      final CoupleDate saved;
      if (existing == null) {
        saved = await repo.createDate(
          title: draft.title,
          date: draft.date,
          recurrence: draft.recurrence,
        );
      } else {
        saved = await repo.updateDate(
          existing.id,
          title: draft.title,
          date: draft.date,
          recurrence: draft.recurrence,
        );
      }
      ref.read(coupleDatesProvider.notifier).remember(saved);
      return null;
    } catch (error) {
      return userFacingError(error);
    }
  }

  bool get _rowLocked => _deletingId != null || _confirmingId != null;

  Future<void> _delete(CoupleDate date) async {
    if (_rowLocked) return;
    setState(() {
      _confirmingId = date.id;
      _actionError = null;
    });
    final confirmed = await confirmDestructive(
      context,
      title: 'Excluir data?',
      message: '“${date.title}” será apagada para os dois.',
      confirmLabel: 'Excluir',
      confirmKey: const Key('confirm-delete-date'),
    );
    if (confirmed != true || !mounted) {
      if (mounted) setState(() => _confirmingId = null);
      return;
    }
    setState(() {
      _confirmingId = null;
      _deletingId = date.id;
      _actionError = null;
    });
    try {
      await ref.read(coupleRepositoryProvider).deleteDate(date.id);
      if (!mounted) return;
      await MutationScope.refreshOf(context);
      if (mounted) setState(() => _deletingId = null);
    } catch (error) {
      if (mounted) {
        setState(() {
          _deletingId = null;
          _actionError = userFacingError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final coupleAsync = ref.watch(coupleProvider);
    final datesAsync = ref.watch(coupleDatesProvider);
    final dates = datesAsync.value ?? const <CoupleDate>[];
    final loadError = datesAsync.hasError && dates.isEmpty
        ? userFacingError(datesAsync.error!)
        : null;
    final refreshError = ref.read(coupleDatesProvider.notifier).reloadError;
    final failedEmpty = loadError != null;
    final upcoming = failedEmpty
        ? const <UpcomingDate>[]
        : coupleAsync.asData?.value?.upcoming ?? const <UpcomingDate>[];

    return MutationScope(
      onSuccess: _reloadDates,
      child: Scaffold(
      appBar: AppBar(
        leading: AppBackButton(enabled: !_rowLocked),
        title: AppText('Datas importantes'),
      ),
      floatingActionButton: AppFab(
        tooltip: 'Adicionar data',
        onPressed: _rowLocked ? null : () => _openSheet(),
        icon: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, AppFab.clearance),
        children: [
          ActionErrorReporter(message: _actionError ?? refreshError),
          const AppText(
            'Datas recorrentes do casal. Conquistas continuam na lista de marcos.',
          ),
          const SizedBox(height: 16),
          if (!failedEmpty) ...[
            AppText(
              'Próximas datas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (upcoming.isEmpty)
              const AppText('Nada nos próximos 60 dias.')
            else
              ...upcoming.map(
                (entry) => MutationLock(
                  locked: _rowLocked,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: IgnorePointer(
                      child: AppText(
                        nextDateLine(entry).replaceFirst('Próxima data: ', ''),
                      ),
                    ),
                    subtitle: IgnorePointer(
                      child: AppText(formatDisplayDate(entry.date)),
                    ),
                    onTap: _rowLocked || entry.coupleDateId == null
                        ? null
                        : () {
                            final match = dates.where(
                              (date) => date.id == entry.coupleDateId,
                            );
                            if (match.isNotEmpty) _openSheet(match.first);
                          },
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          AppText(
            'Datas do casal',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (datesAsync.isLoading && dates.isEmpty && loadError == null)
            const SizedBox(height: 240, child: ListSkeleton(rows: 3))
          else if (loadError != null)
            ErrorView(
              message: loadError,
              compact: true,
              onRetry: () => ref.read(coupleDatesProvider.notifier).reload(),
            )
          else if (dates.isEmpty)
            const EmptyView(
              message: 'Nenhuma data ainda. Toque em adicionar.',
              compact: true,
            )
          else ...[
            ...dates.map(
              (date) => _DateRow(
                key: Key('date-row-${date.id}'),
                date: date,
                deleting: _deletingId == date.id,
                locked: _rowLocked,
                onOpen: () => _openSheet(date),
                onDelete: () => _delete(date),
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    super.key,
    required this.date,
    required this.deleting,
    required this.locked,
    required this.onOpen,
    required this.onDelete,
  });

  final CoupleDate date;
  final bool deleting;
  final bool locked;
  final VoidCallback onOpen;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = locked || deleting;
    final iconColor = busy
        ? scheme.onSurface.withValues(alpha: 0.38)
        : scheme.primary;
    return MutationLock(
      locked: busy,
      child: Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: AppInkWell(
              onTap: busy ? null : onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(date.title),
                    AppText(
                      '${formatDisplayDate(date.date)} · ${date.recurrence == 'YEARLY' ? 'todo ano' : 'uma vez'}',
                    ),
                  ],
                ),
              ),
            ),
          ),
          AppIconButton(
            tooltip: 'Editar',
            onPressed: busy ? null : onOpen,
            icon: Icon(Icons.edit_outlined, color: iconColor),
          ),
          const SizedBox(width: 8),
          LoadingIconButton(
            tooltip: 'Excluir',
            loading: deleting,
            icon: const Icon(Icons.delete_outline),
            onPressed: busy
                ? null
                : () {
                    onDelete();
                  },
          ),
          const SizedBox(width: 4),
        ],
      ),
      ),
    );
  }
}
