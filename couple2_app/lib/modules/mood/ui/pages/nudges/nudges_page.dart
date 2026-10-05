import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/mood_providers.dart';
import '../../../domain/domain.dart';

class NudgesPage extends ConsumerStatefulWidget {
  const NudgesPage({super.key});

  @override
  ConsumerState<NudgesPage> createState() => _NudgesPageState();
}

class _NudgesPageState extends ConsumerState<NudgesPage>
    with SingleTickerProviderStateMixin {
  final List<Nudge> _items = [];
  String? _cursor;
  bool _loading = true;
  bool _loadingMore = false;
  bool _celebrate = false;
  Object? _error;
  late final AnimationController _heart = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_refresh);
  }

  @override
  void dispose() {
    _heart.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref.read(nudgesRepositoryProvider).received();
      final unseen = page.items.where((item) => !item.seen).toList();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _cursor = page.nextCursor;
        _loading = false;
        _celebrate = unseen.isNotEmpty;
      });
      if (unseen.isNotEmpty) {
        _heart.forward(from: 0);
        await _mark(unseen);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final cursor = _cursor;
    if (cursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(nudgesRepositoryProvider)
          .received(cursor: cursor);
      final unseen = page.items.where((item) => !item.seen).toList();
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _loadingMore = false;
      });
      await _mark(unseen);
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _mark(List<Nudge> unseen) async {
    if (unseen.isEmpty) return;
    await Future.wait(
      unseen.map((item) async {
        try {
          final seen = await ref
              .read(nudgesRepositoryProvider)
              .markSeen(item.id);
          if (!mounted) return;
          final index = _items.indexWhere((row) => row.id == item.id);
          if (index >= 0) {
            setState(() => _items[index] = seen);
          }
        } catch (_) {
          // A failed seen call can be retried the next time the screen opens.
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('Carinhos')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading && _items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  if (_celebrate)
                    ScaleTransition(
                      scale: CurvedAnimation(
                        parent: _heart,
                        curve: Curves.elasticOut,
                      ),
                      child: const Text(
                        '💗',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 72),
                      ),
                    ),
                  if (_error != null && _items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: AppText(
                        'Não foi possível carregar os carinhos.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: AppText(
                        'Os carinhos que você receber aparecem aqui.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    for (final item in _items)
                      ListTile(
                        leading: Text(
                          item.kind.emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                        title: AppText(item.kind.label),
                        subtitle: AppText(
                          [
                            if (item.message != null &&
                                item.message!.isNotEmpty)
                              item.message!,
                            moodAgeLabel(item.createdAt),
                          ].join(' · '),
                        ),
                      ),
                  if (_cursor != null)
                    TextButton(
                      onPressed: _loadingMore ? null : _loadMore,
                      child: Text(_loadingMore ? 'Carregando…' : 'Ver mais'),
                    ),
                ],
              ),
      ),
    );
  }
}
