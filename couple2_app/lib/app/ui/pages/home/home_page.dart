import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../modules/couple/data/couple_providers.dart';
import '../../../../modules/couple/routing/routes.dart';
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
    final paired = sessionAsync.asData?.value?.coupleId != null;

    return Scaffold(
      appBar: AppBar(
        title: const AppText('Home'),
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
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await logout();
            },
          ),
        ],
      ),
      body: sessionAsync.when(
        data: (session) {
          if (session == null) {
            return const Center(child: CircularProgressIndicator());
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
                  const Center(
                    child: CircleAvatar(
                      radius: 50,
                      child: Icon(Icons.person, size: 50),
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
                    loading: () => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: AppText('Erro ao carregar o casal: $error'),
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
                  child: ElevatedButton.icon(
                    onPressed: () => context.push(ListsRoutes.lists),
                    icon: const Icon(Icons.list),
                    label: const Text('Our Lists'),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: AppText('Erro ao carregar usuário: $error')),
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
    final avatar = pictureUrl == null
        ? const CircleAvatar(child: Icon(Icons.person))
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
