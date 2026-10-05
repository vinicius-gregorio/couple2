import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/session_provider.dart';
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
            ListTile(
              title: const AppText('O que rolou'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onOpen,
            ),
            preview.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: AppText('Não foi possível carregar o feed'),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: AppText('Nada por aqui ainda.'),
                  );
                }
                return Column(
                  children: [
                    for (final event in items)
                      ListTile(
                        dense: true,
                        leading: Icon(activityIcon(event.type)),
                        title: AppText(
                          '${feedActorLabel(actorId: event.actorId, currentUserId: session?.id, actorName: event.payload['actorName'] is String ? event.payload['actorName'] as String : null)} ${feedActionText(event.type, event.payload)}',
                        ),
                        onTap: onOpen,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
