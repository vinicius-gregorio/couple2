import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/core.dart';
import '../../../session.dart';
import '../../../../modules/couple/data/couple_providers.dart';
import '../../../../modules/couple/routing/routes.dart';
import '../../../../modules/pairing/routing/routes.dart';
import '../../../../modules/couple/ui/widgets/days_together_card.dart';
import '../../../../modules/couple/ui/widgets/profile_sheet.dart';
import '../../../../modules/daily_question/data/daily_question_providers.dart';
import '../../../../modules/daily_question/ui/widgets/today_question_card.dart';
import '../../../../modules/feed/data/feed_providers.dart';
import '../../../../modules/mood/data/mood_providers.dart';
import '../../../../modules/date_plans/data/date_plans_providers.dart';
import '../../../../modules/date_plans/ui/widgets/next_date_card.dart';
import '../../../../modules/mood/ui/widgets/mood_home_card.dart';
import '../../../../modules/feed/routing/routes.dart';
import '../../../../modules/feed/ui/widgets/feed_preview.dart';
import '../../../../modules/lists/routing/routes.dart';
import '../../../providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionProvider);
    final coupleAsync = ref.watch(coupleProvider);
    final unread = ref.watch(unreadCountProvider).asData?.value ?? 0;
    final logout = ref.read(logoutActionProvider);
    final needsPairing = sessionNeedsPairing(sessionAsync.asData?.value);
    final paired = sessionAsync.asData?.value?.coupleId != null;

    return Scaffold(
      appBar: AppBar(
        title: AppText(needsPairing ? 'Parear' : 'Início'),
        leading: sessionAsync.when(
          data: (session) => _AvatarButton(
            pictureUrl: session?.picture,
            onPressed: session == null
                ? null
                : () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => ProfileSheet(session: session),
                    );
                  },
          ),
          loading: () => const _AvatarButton(pictureUrl: null),
          error: (_, __) => const _AvatarButton(pictureUrl: null),
        ),
        actions: [
          if (paired)
            _FeedBell(
              count: unread,
              onPressed: () => context.push(FeedRoutes.feed),
            ),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final accepted = await confirmDestructive(
                context,
                title: 'Sair da conta?',
                message: 'Você volta para a tela de entrada.',
                confirmLabel: 'Sair',
              );
              if (!accepted) return;
              await logout();
            },
          ),
        ],
      ),
      body: sessionAsync.when(
        data: (session) {
          if (session == null) {
            return const ListSkeleton(rows: 4);
          }

          if (sessionNeedsPairing(session)) {
            return const _NeedsPairingBody();
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(sessionProvider.notifier).refresh();
              ref.invalidate(coupleProvider);
              ref.invalidate(unreadCountProvider);
              ref.invalidate(feedPreviewProvider);
              ref.invalidate(todayQuestionProvider);
              ref.invalidate(currentMoodProvider);
              ref.invalidate(nextDateProvider);
              await ref.read(coupleProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 24),
              children: [
                if (session.picture != null)
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: NetworkImage(session.picture!),
                      onBackgroundImageError: (_, __) {},
                    ),
                  )
                else
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                AppText(
                  'Bem-vindo, ${session.name}!',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (session.coupleId != null)
                  coupleAsync.when(
                    data: (couple) {
                      if (couple == null) return const SizedBox.shrink();
                      return DaysTogetherCard(
                        couple: couple,
                        onOpenSettings: () =>
                            context.push(CoupleRoutes.settings),
                        onOpenDates: () => context.push(CoupleRoutes.dates),
                      );
                    },
                    loading: () => const CardSkeleton(),
                    error: (error, _) => ErrorView(
                      message: userFacingError(
                        error,
                        fallback: 'Não foi possível carregar o casal.',
                      ),
                      compact: true,
                      onRetry: () => ref.invalidate(coupleProvider),
                    ),
                  ),
                if (session.coupleId != null) ...[
                  const SizedBox(height: 16),
                  const MoodHomeCard(),
                  const SizedBox(height: 16),
                  const NextDateCard(),
                  const SizedBox(height: 16),
                  const TodayQuestionCard(),
                  const SizedBox(height: 16),
                  FeedPreview(onOpen: () => context.push(FeedRoutes.feed)),
                ],
                const SizedBox(height: 24),
                Center(
                  child: FilledButton.icon(
                    onPressed: () => context.push(ListsRoutes.lists),
                    icon: const Icon(Icons.list),
                    label: const Text('Nossas listas'),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const ListSkeleton(rows: 4),
        error: (error, _) => ErrorView(
          message: userFacingError(
            error,
            fallback: 'Não foi possível carregar a sessão.',
          ),
          onRetry: () => ref.read(sessionProvider.notifier).refresh(),
        ),
      ),
    );
  }
}

class _NeedsPairingBody extends StatelessWidget {
  const _NeedsPairingBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText(
                'Conectar com meu par',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const AppText(
                'A Home do casal abre depois que os dois digitam o código um do outro.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(PairingRoutes.hub),
                child: const Text('Ir para o pareamento'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedBell extends StatelessWidget {
  const _FeedBell({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'O que rolou',
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.pictureUrl, this.onPressed});

  final String? pictureUrl;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final avatar = pictureUrl == null
        ? CircleAvatar(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            child: Icon(Icons.person, color: scheme.onPrimary),
          )
        : CircleAvatar(
            backgroundImage: NetworkImage(pictureUrl!),
            onBackgroundImageError: (_, __) {},
          );

    return Padding(
      padding: const EdgeInsets.all(8),
      child: InkWell(onTap: onPressed, child: avatar),
    );
  }
}
