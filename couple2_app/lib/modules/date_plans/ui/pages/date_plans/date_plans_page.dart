import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/date_plans_providers.dart';
import '../../../domain/domain.dart';
import '../../../routing/routes.dart';

class DatePlansPage extends ConsumerStatefulWidget {
  const DatePlansPage({super.key});

  @override
  ConsumerState<DatePlansPage> createState() => _DatePlansPageState();
}

class _DatePlansPageState extends ConsumerState<DatePlansPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _upcoming = <DatePlan>[];
  final _past = <DatePlan>[];
  String? _upcomingCursor;
  String? _pastCursor;
  bool _loadingUpcoming = true;
  bool _loadingPast = true;
  Object? _upcomingError;
  Object? _pastError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    Future<void>.microtask(() async {
      await Future.wait([
        _load('upcoming', reset: true),
        _load('past', reset: true),
      ]);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load(String scope, {bool reset = false}) async {
    final isUpcoming = scope == 'upcoming';
    final cursor = isUpcoming ? _upcomingCursor : _pastCursor;
    if (!reset && cursor == null && _started(scope)) return;
    setState(() {
      if (isUpcoming) {
        _loadingUpcoming = true;
        _upcomingError = null;
      } else {
        _loadingPast = true;
        _pastError = null;
      }
    });
    try {
      final page = await ref
          .read(datePlansRepositoryProvider)
          .list(scope: scope, cursor: reset ? null : cursor);
      if (!mounted) return;
      setState(() {
        final target = isUpcoming ? _upcoming : _past;
        if (reset) target.clear();
        target.addAll(page.items);
        if (isUpcoming) {
          _upcomingCursor = page.nextCursor;
          _loadingUpcoming = false;
        } else {
          _pastCursor = page.nextCursor;
          _loadingPast = false;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (isUpcoming) {
          _upcomingError = error;
          _loadingUpcoming = false;
        } else {
          _pastError = error;
          _loadingPast = false;
        }
      });
    }
  }

  bool _started(String scope) {
    if (scope == 'upcoming') return !_loadingUpcoming || _upcoming.isNotEmpty;
    return !_loadingPast || _past.isNotEmpty;
  }

  Future<void> _refreshAll() async {
    ref.invalidate(nextDateProvider);
    await Future.wait([
      _load('upcoming', reset: true),
      _load('past', reset: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('Dates'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Próximos'),
            Tab(text: 'Passados'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push(DatePlanRoutes.create);
          if (!mounted) return;
          await _refreshAll();
        },
        icon: const Icon(Icons.add),
        label: const Text('Planejar um date'),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _DateList(
            items: _upcoming,
            loading: _loadingUpcoming,
            error: _upcomingError,
            hasMore: _upcomingCursor != null,
            empty: 'Nenhum date por vir.',
            onRefresh: () => _load('upcoming', reset: true),
            onMore: () => _load('upcoming'),
            onOpen: (id) async {
              await context.push(DatePlanRoutes.detail(id));
              if (!mounted) return;
              await _refreshAll();
            },
          ),
          _DateList(
            items: _past,
            loading: _loadingPast,
            error: _pastError,
            hasMore: _pastCursor != null,
            empty: 'Nenhum date passado.',
            onRefresh: () => _load('past', reset: true),
            onMore: () => _load('past'),
            onOpen: (id) async {
              await context.push(DatePlanRoutes.detail(id));
              if (!mounted) return;
              await _refreshAll();
            },
          ),
        ],
      ),
    );
  }
}

class _DateList extends StatelessWidget {
  const _DateList({
    required this.items,
    required this.loading,
    required this.error,
    required this.hasMore,
    required this.empty,
    required this.onRefresh,
    required this.onMore,
    required this.onOpen,
  });

  final List<DatePlan> items;
  final bool loading;
  final Object? error;
  final bool hasMore;
  final String empty;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onMore;
  final Future<void> Function(String id) onOpen;

  @override
  Widget build(BuildContext context) {
    if (loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppText('Não consegui carregar os dates.'),
            TextButton(
              onPressed: onRefresh,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      );
    }
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            Center(child: AppText(empty)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: items.length + (hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return TextButton(
              onPressed: loading ? null : onMore,
              child: const Text('Carregar mais'),
            );
          }
          final plan = items[index];
          return Card(
            child: ListTile(
              title: Text(plan.title),
              subtitle: Text(
                '${datePlanWhen(plan.scheduledAt)} · horário do aparelho',
              ),
              trailing: Chip(label: Text(plan.status.label)),
              onTap: () => onOpen(plan.id),
            ),
          );
        },
      ),
    );
  }
}
