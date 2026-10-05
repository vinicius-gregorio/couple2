import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../notifications/routing/routes.dart';
import '../../../domain/domain.dart';
import '../../widgets/activity_icon.dart';
import 'feed_viewmodel.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> with WidgetsBindingObserver {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      if (position.pixels >= position.maxScrollExtent - 240) {
        ref.read(feedViewModelProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(feedViewModelProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feedViewModelProvider);
    final viewModel = ref.read(feedViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const AppText('O que rolou'),
        actions: [
          IconButton(
            tooltip: 'Notificações',
            icon: const Icon(Icons.tune),
            onPressed: () => context.push(NotificationRoutes.preferences),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: viewModel.refresh,
        child: state.isLoading && state.items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: state.items.length + 1,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == state.items.length) {
                    return _Footer(state: state);
                  }
                  final event = state.items[index];
                  return _ActivityTile(
                    event: event,
                    actor: viewModel.actorLabel(event),
                    onTap: () {
                      final route = activityRoute(event.type, event.payload);
                      if (route != null) context.push(route);
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state});

  final FeedState state;

  @override
  Widget build(BuildContext context) {
    if (state.errorMessage != null && state.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: AppText(state.errorMessage!),
      );
    }
    if (state.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: AppText('Nada por aqui ainda.'),
      );
    }
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return const SizedBox(height: 24);
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.event,
    required this.actor,
    required this.onTap,
  });

  final ActivityEvent event;
  final String actor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = feedActionText(event.type, event.payload);
    return ListTile(
      leading: Icon(activityIcon(event.type)),
      title: AppText('$actor $text'),
      subtitle: AppText(
        _shortTime(event.createdAt.toLocal()),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: onTap,
    );
  }
}

String _shortTime(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')} $hour:$minute';
}
