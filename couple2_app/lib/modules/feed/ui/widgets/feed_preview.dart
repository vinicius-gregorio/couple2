import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/session_provider.dart';
import '../../../../app/ui/home_failure_scope.dart';
import '../../../../core/core.dart';
import '../../data/feed_providers.dart';
import '../../domain/domain.dart';
import 'activity_icon.dart';

class FeedPreview extends ConsumerWidget {
  const FeedPreview({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(feedPreviewProvider);
    final session = ref.watch(sessionProvider).asData?.value;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextButton(
              onPressed: onOpen,
              child: const Row(
                children: [
                  Text('O que rolou'),
                  Spacer(),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
            if (preview.hasError && !collapseThisError(context, preview.error!))
              ErrorView(
                message: userFacingError(
                  preview.error!,
                  fallback: 'Não foi possível carregar o feed',
                ),
                compact: true,
                onRetry: () => ref.invalidate(feedPreviewProvider),
              ),
            _FeedLines(
              loading: preview.isLoading && preview.value == null,
              items: preview.value,
              failed: preview.hasError,
              sessionId: session?.id,
              onOpen: onOpen,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedLines extends StatelessWidget {
  const _FeedLines({
    required this.loading,
    required this.items,
    required this.failed,
    required this.sessionId,
    required this.onOpen,
  });

  final bool loading;
  final List<ActivityEvent>? items;
  final bool failed;
  final String? sessionId;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Shimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(height: 14),
              SizedBox(height: 10),
              SkeletonBox(height: 14, width: 180),
            ],
          ),
        ),
      );
    }
    final rows = items;
    if (rows == null || (rows.isEmpty && failed)) {
      return const SizedBox.shrink();
    }
    if (rows.isEmpty) {
      return const EmptyView(message: 'Nada por aqui ainda.', compact: true);
    }
    return Column(
      children: [
        for (final event in rows)
          ListTile(
            dense: true,
            leading: Icon(
              activityIcon(event.type),
              color: Theme.of(context).colorScheme.primary,
            ),
            title: IgnorePointer(
              child: AppText(
                '${feedActorLabel(actorId: event.actorId, currentUserId: sessionId, actorName: event.payload['actorName'] is String ? event.payload['actorName'] as String : null)} ${feedActionText(event.type, event.payload)}',
              ),
            ),
            onTap: onOpen,
          ),
      ],
    );
  }
}
