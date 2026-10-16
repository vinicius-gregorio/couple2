import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/routing/app_back_button.dart';
import '../../../../../core/core.dart';
import '../../../../notifications/routing/routes.dart';
import '../../../domain/domain.dart';
import '../../widgets/activity_icon.dart';
import 'feed_viewmodel.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage>
    with WidgetsBindingObserver {
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
        leading: const AppBackButton(),
        title: const AppText('O que rolou'),
        actions: [
          AppIconButton(
            tooltip: 'Notificações',
            icon: const Icon(Icons.tune),
            onPressed: () => context.push(NotificationRoutes.preferences),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: viewModel.refresh,
        child: AsyncBody(
          isLoading: state.isLoading,
          hasData: state.items.isNotEmpty,
          error: state.errorMessage,
          errorMessage: state.errorMessage ?? fallbackUserMessage,
          onRetry: viewModel.refresh,
          isEmpty: state.items.isEmpty,
          emptyMessage: 'Nada por aqui ainda.',
          child: ListView.separated(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: state.items.length + 1,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == state.items.length) {
                return _Footer(state: state, onRetry: viewModel.refresh);
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
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.onRetry});

  final FeedState state;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.errorMessage != null) {
      return ErrorView(
        message: state.errorMessage!,
        compact: true,
        onRetry: onRetry,
      );
    }
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Shimmer(child: SkeletonBox(height: 48, radius: 12)),
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
    final label = '$actor $text';
    return Semantics(
      button: true,
      label: label,
      child: ListTile(
        leading: Icon(
          activityIcon(event.type),
          color: Theme.of(context).colorScheme.primary,
        ),
        title: IgnorePointer(child: AppText(label)),
        subtitle: IgnorePointer(
          child: AppText(
            _shortTime(event.createdAt.toLocal()),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

String _shortTime(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')} $hour:$minute';
}
