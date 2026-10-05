import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/session_provider.dart';
import '../../../data/mood_providers.dart';
import '../../../domain/domain.dart';

class MoodHistoryPage extends ConsumerStatefulWidget {
  const MoodHistoryPage({super.key});

  @override
  ConsumerState<MoodHistoryPage> createState() => _MoodHistoryPageState();
}

class _MoodHistoryPageState extends ConsumerState<MoodHistoryPage> {
  MoodHistory? _history;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final history = await ref.read(moodRepositoryProvider).history();
      if (!mounted) return;
      setState(() {
        _history = history;
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

  @override
  Widget build(BuildContext context) {
    final history = _history;
    final session = ref.watch(sessionProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: const AppText('Humor')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading && history == null
            ? const Center(child: CircularProgressIndicator())
            : history == null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 48),
                  AppText(
                    _error == null
                        ? 'Quando vocês quiserem, os check-ins aparecem aqui.'
                        : 'Não foi possível carregar o histórico.',
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : _HistoryList(
                history: history,
                currentUserId: session?.id,
                partnerName: session?.partnerName,
              ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.history,
    required this.currentUserId,
    required this.partnerName,
  });

  final MoodHistory history;
  final String? currentUserId;
  final String? partnerName;

  @override
  Widget build(BuildContext context) {
    if (history.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          AppText(
            'Quando vocês quiserem, os check-ins aparecem aqui.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    final groups = <String, List<MoodCheckin>>{};
    final order = <String>[];
    for (final item in history.items) {
      final label = moodDayLabel(item.createdAt);
      if (!groups.containsKey(label)) {
        groups[label] = [];
        order.add(label);
      }
      groups[label]!.add(item);
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final label in order) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
            child: AppText(
              label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          for (final item in groups[label]!)
            ListTile(
              leading: Text(
                item.mood.emoji,
                style: const TextStyle(fontSize: 28),
              ),
              title: AppText(
                item.userId == currentUserId ? 'Você' : _partner(partnerName),
              ),
              subtitle: AppText(
                [
                  moodAgeLabel(item.createdAt),
                  if (item.note != null && item.note!.isNotEmpty) item.note!,
                ].join(' · '),
              ),
            ),
        ],
      ],
    );
  }

  String _partner(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return 'Parceiro';
    return trimmed;
  }
}
