import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  String? _error;

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
      _error = null;
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
          _error = 'Não foi possível carregar as datas';
        });
      }
    }
  }

  Future<void> _openSheet([CoupleDate? existing]) async {
    final draft = await showModalBottomSheet<CoupleDateDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CoupleDateSheet(existing: existing),
    );
    if (draft == null) return;
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
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível salvar a data');
      }
    }
  }

  Future<void> _delete(CoupleDate date) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir data?'),
        content: Text('“${date.title}” será apagada para os dois.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(coupleRepositoryProvider).deleteDate(date.id);
      ref.invalidate(coupleProvider);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível excluir a data');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final coupleAsync = ref.watch(coupleProvider);
    final upcoming =
        coupleAsync.asData?.value?.upcoming ?? const <UpcomingDate>[];

    return Scaffold(
      appBar: AppBar(title: const AppText('Datas importantes')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openSheet(),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AppText(
            'Datas recorrentes do casal. Conquistas continuam na lista Milestones.',
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
          if (_error != null) ...[AppText(_error!), const SizedBox(height: 8)],
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_dates.isEmpty)
            const AppText('Nenhuma data ainda. Adicione a primeira.')
          else
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
                      onPressed: () => _openSheet(date),
                    ),
                    IconButton(
                      tooltip: 'Excluir',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(date),
                    ),
                  ],
                ),
                onTap: () => _openSheet(date),
              ),
            ),
        ],
      ),
    );
  }
}
