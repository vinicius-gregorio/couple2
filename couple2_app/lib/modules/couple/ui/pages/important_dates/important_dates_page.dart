import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/routing/app_back_button.dart';
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
  List<CoupleDate> _dates = const [];
  bool _loading = true;
  bool _saving = false;
  String? _deletingId;
  String? _loadError;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
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
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final dates = await ref.read(coupleRepositoryProvider).getDates();
      if (mounted) {
        setState(() {
          _dates = dates;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'Não foi possível carregar as datas';
        });
      }
    }
  }

  Future<void> _openSheet([CoupleDate? existing]) async {
    if (_saving || _deletingId != null) return;
    final draft = await showModalBottomSheet<CoupleDateDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CoupleDateSheet(existing: existing),
    );
    if (draft == null || !mounted || _saving) return;
    final previous = _dates;
    setState(() {
      _saving = true;
      _actionError = null;
    });
    try {
      final repo = ref.read(coupleRepositoryProvider);
      if (existing == null) {
        await repo.createDate(
          title: draft.title,
          date: draft.date,
          recurrence: draft.recurrence,
        );
      } else {
        await repo.updateDate(
          existing.id,
          title: draft.title,
          date: draft.date,
          recurrence: draft.recurrence,
        );
      }
      ref.invalidate(coupleProvider);
      if (!mounted) return;
      setState(() => _saving = false);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() {
          _dates = previous;
          _saving = false;
          _actionError = 'Não foi possível salvar a data.';
        });
      }
    }
  }

  Future<void> _delete(CoupleDate date) async {
    if (_saving || _deletingId != null) return;
    setState(() => _deletingId = date.id);
    final confirmed = await confirmDestructive(
      context,
      title: 'Excluir data?',
      message: '“${date.title}” será apagada para os dois.',
      confirmLabel: 'Excluir',
      confirmKey: const Key('confirm-delete-date'),
    );
    if (confirmed != true || !mounted) {
      if (mounted) setState(() => _deletingId = null);
      return;
    }
    final previous = _dates;
    try {
      await ref.read(coupleRepositoryProvider).deleteDate(date.id);
      ref.invalidate(coupleProvider);
      if (!mounted) return;
      setState(() {
        _dates = previous.where((item) => item.id != date.id).toList();
        _deletingId = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _dates = previous;
          _deletingId = null;
          _actionError = 'Não foi possível excluir a data.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final coupleAsync = ref.watch(coupleProvider);
    final upcoming =
        coupleAsync.asData?.value?.upcoming ?? const <UpcomingDate>[];

    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton(),
        title: AppText('Datas importantes'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _saving || _deletingId != null ? null : () => _openSheet(),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    key: LoadingButton.spinnerKey,
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Salvando…'),
                ],
              ),
            ),
          MutationErrorBanner(message: _actionError),
          const AppText(
            'Datas recorrentes do casal. Conquistas continuam na lista de marcos.',
          ),
          const SizedBox(height: 16),
          AppText(
            'Próximas datas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (upcoming.isEmpty)
            const AppText('Nada nos próximos 60 dias.')
          else
            ...upcoming.map(
              (entry) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: IgnorePointer(
                  child: AppText(
                    nextDateLine(entry).replaceFirst('Próxima data: ', ''),
                  ),
                ),
                subtitle: IgnorePointer(
                  child: AppText(formatDisplayDate(entry.date)),
                ),
                onTap: entry.coupleDateId == null
                    ? null
                    : () {
                        final match = _dates.where(
                          (date) => date.id == entry.coupleDateId,
                        );
                        if (match.isNotEmpty) _openSheet(match.first);
                      },
              ),
            ),
          const SizedBox(height: 16),
          AppText(
            'Datas do casal',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_loading && _dates.isEmpty && _loadError == null)
            const SizedBox(height: 240, child: ListSkeleton(rows: 3))
          else if (_loadError != null && _dates.isEmpty)
            ErrorView(message: _loadError!, compact: true, onRetry: _load)
          else if (_dates.isEmpty)
            EmptyView(
              message: 'Nenhuma data ainda. Adicione a primeira.',
              compact: true,
              action: FilledButton(
                onPressed: _saving || _deletingId != null
                    ? null
                    : () => _openSheet(),
                child: const Text('Adicionar data'),
              ),
            )
          else ...[
            ..._dates.map(
              (date) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: IgnorePointer(child: AppText(date.title)),
                subtitle: IgnorePointer(
                  child: AppText(
                    '${formatDisplayDate(date.date)} · ${date.recurrence == 'YEARLY' ? 'todo ano' : 'uma vez'}',
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Editar',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: _saving || _deletingId != null
                          ? null
                          : () => _openSheet(date),
                    ),
                    LoadingIconButton(
                      tooltip: 'Excluir',
                      loading: _deletingId == date.id,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _saving || _deletingId != null
                          ? null
                          : () => _delete(date),
                    ),
                  ],
                ),
                onTap: () => _openSheet(date),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
