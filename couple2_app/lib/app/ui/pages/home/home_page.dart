import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/core.dart';
import '../../../read_cache.dart';
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
import '../../home_failure_scope.dart';

const homeHeaderAvatarKey = Key('home-header-avatar');
const offlineHomeNoticeKey = Key('offline-home-notice');

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionProvider);
    final coupleAsync = ref.watch(coupleProvider);
    final unread = ref.watch(unreadCountProvider).asData?.value ?? 0;
    final logout = ref.read(logoutActionProvider);
    final session = sessionAsync.asData?.value;
    final sessionFailed = sessionAsync.hasError && session == null;
    final paired = session?.coupleId != null;
    final showCoupleHome = paired || sessionFailed;
    final showNotice =
        sessionFailed ||
        _offlineCount(ref, sessionAsync) >= 1 ||
        ref.watch(staleReadsProvider).isNotEmpty;
    final noticeMessage = sessionFailed
        ? userFacingError(sessionAsync.error!)
        : offlineUserMessage;

    return MutationScope(
      child: Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'Início',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // Full-width slot under the toolbar so the sentence can wrap.
        // The slot stays when the notice is hidden, so the body does not jump.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(_offlineNoticeSlot),
          child: _OfflineNotice(
            offline: showNotice,
            message: noticeMessage,
            onRetry: () => _retryHome(ref),
          ),
        ),
        leading: sessionAsync.when(
          data: (session) => _AvatarButton(
            pictureUrl: session?.picture,
            onPressed: session == null
                ? null
                : () {
                    final host = context;
                    showAppSheet<void>(
                      context: host,
                      builder: (_) =>
                          ProfileSheet(session: session, hostContext: host),
                    );
                  },
          ),
          loading: () => const _AvatarButton(pictureUrl: null),
          error: (_, __) => const _AvatarButton(pictureUrl: null),
        ),
        actions: [
          if (showCoupleHome)
            _FeedBell(
              count: unread,
              onPressed: () => context.push(FeedRoutes.feed),
            ),
          Builder(
            builder: (context) {
              return AppIconButton(
                tooltip: 'Sair',
                icon: const Icon(Icons.logout),
                onPressed: MutationScope.busyOf(context)
                    ? null
                    : () async {
                        final accepted = await confirmDestructive(
                          context,
                          title: 'Sair da conta?',
                          message:
                              'Você volta para a tela de entrada. Sem internet, a saída também acontece neste aparelho.',
                          confirmLabel: 'Sair',
                        );
                        if (!accepted) return;
                        await logout();
                      },
              );
            },
          ),
        ],
      ),
      body: sessionFailed
          ? HomeFailureScope(
              retryAll: () => _retryHome(ref),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 24),
                children: [
                  const _HomeAvatar(picture: null),
                  const SizedBox(height: 16),
                  const _Welcome('Bem-vindo!'),
                  const SizedBox(height: 24),
                  _fixedCard(
                    homeDaysCardHeight,
                    LoadErrorCard(
                      message: homeDaysLoadError,
                      onRetry: () => _retryHome(ref),
                      minHeight: homeDaysCardHeight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _fixedCard(
                    homeMoodCardHeight,
                    LoadErrorCard(
                      message: homeMoodLoadError,
                      onRetry: () => _retryHome(ref),
                      minHeight: homeMoodCardHeight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _fixedCard(
                    homeNextDateCardHeight,
                    LoadErrorCard(
                      message: homeDatesLoadError,
                      onRetry: () => _retryHome(ref),
                      minHeight: homeNextDateCardHeight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _fixedCard(
                    homeQuestionCardHeight,
                    LoadErrorCard(
                      message: homeQuestionLoadError,
                      onRetry: () => _retryHome(ref),
                      minHeight: homeQuestionCardHeight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _fixedCard(
                    homeFeedCardHeight,
                    LoadErrorCard(
                      message: homeFeedLoadError,
                      onRetry: () => _retryHome(ref),
                      minHeight: homeFeedCardHeight,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _ListsButton(),
                ],
              ),
            )
          : sessionAsync.when(
        data: (session) {
          if (session == null) {
            return const _BootBody();
          }

          if (sessionNeedsPairing(session)) {
            return const _NeedsPairingBody();
          }

          return HomeFailureScope(
            retryAll: () => _retryHome(ref),
            child: RefreshIndicator(
              onRefresh: () async {
                await _retryHome(ref);
                try {
                  await ref.read(coupleProvider.future);
                } catch (_) {
                  // A failed refresh keeps the cached couple. The future still
                  // completes with the error when nothing was stored yet.
                }
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 24),
                children: [
                  _HomeAvatar(picture: session.picture),
                  const SizedBox(height: 16),
                  _Welcome('Bem-vindo, ${session.name}!'),
                  const SizedBox(height: 24),
                  if (session.coupleId != null)
                    _fixedCard(
                      homeDaysCardHeight,
                      coupleAsync.when(
                        skipError: true,
                        skipLoadingOnReload: true,
                        data: (couple) {
                          if (couple == null) {
                            return LoadErrorCard(
                              message: homeDaysLoadError,
                              onRetry: () => _retryHome(ref),
                              minHeight: homeDaysCardHeight,
                            );
                          }
                          return DaysTogetherCard(
                            couple: couple,
                            onOpenSettings: () {
                              context.push(CoupleRoutes.settings);
                            },
                            onOpenDates: () {
                              context.push(CoupleRoutes.dates);
                            },
                          );
                        },
                        loading: () => const CardSkeleton(
                          lines: 2,
                          minHeight: homeDaysCardHeight,
                        ),
                        error: (error, _) => LoadErrorCard(
                          message: homeCardMessage(error, homeDaysLoadError),
                          onRetry: () => _retryHome(ref),
                          minHeight: homeDaysCardHeight,
                        ),
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
                    FeedPreview(
                      onOpen: () {
                        context.push(FeedRoutes.feed);
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  const _ListsButton(),
                ],
              ),
            ),
          );
        },
        loading: () => const _BootBody(),
        error: (_, __) => const _BootBody(),
      ),
      ),
    );
  }
}

int _offlineCount(WidgetRef ref, AsyncValue<Session?> session) {
  if (session.asData?.value?.coupleId == null) return 0;
  var count = 0;
  void add(AsyncValue<dynamic> value) {
    if (value.hasError && isOfflineFailure(value.error!)) count++;
  }

  add(ref.watch(coupleProvider));
  add(ref.watch(currentMoodProvider));
  add(ref.watch(nextDateProvider));
  add(ref.watch(todayQuestionProvider));
  add(ref.watch(feedPreviewProvider));
  return count;
}

Future<void> _retryHome(WidgetRef ref) async {
  await ref.read(sessionProvider.notifier).refresh();
  ref.invalidate(coupleProvider);
  ref.invalidate(currentMoodProvider);
  ref.invalidate(nextDateProvider);
  ref.invalidate(todayQuestionProvider);
  ref.invalidate(feedPreviewProvider);
  ref.invalidate(unreadCountProvider);
}

Widget _fixedCard(double height, Widget child) {
  return StableSlot(height: height, child: child);
}

/// Two wrapped lines of the offline sentence, plus a little padding.
const _offlineNoticeSlot = 48.0;

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({
    required this.offline,
    required this.message,
    required this.onRetry,
  });

  final bool offline;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: _offlineNoticeSlot,
      width: double.infinity,
      child: offline
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppInkWell(
                  onTap: onRetry,
                  child: Text(
                    message,
                    key: offlineHomeNoticeKey,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.25,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _HomeAvatar extends StatelessWidget {
  const _HomeAvatar({required this.picture});

  final String? picture;

  @override
  Widget build(BuildContext context) {
    if (picture != null) {
      return Center(
        child: CircleAvatar(
          key: homeHeaderAvatarKey,
          radius: 50,
          backgroundImage: NetworkImage(picture!),
          onBackgroundImageError: (_, __) {},
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: CircleAvatar(
        key: homeHeaderAvatarKey,
        radius: 50,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        child: Icon(Icons.person, size: 50, color: scheme.onPrimary),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return AppText(
      text,
      style: Theme.of(context).textTheme.headlineSmall,
      textAlign: TextAlign.center,
    );
  }
}

class _ListsButton extends StatelessWidget {
  const _ListsButton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LoadingButton(
        variant: LoadingButtonVariant.outlined,
        icon: const Icon(Icons.list),
        onPressed: () {
          context.push(ListsRoutes.lists);
        },
        child: const Text('Nossas listas'),
      ),
    );
  }
}

class _BootBody extends StatelessWidget {
  const _BootBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(height: 16),
          AppText('Abrindo a sessão…'),
        ],
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
                'A Home do casal abre quando um pedido de pareamento é aceito.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              LoadingButton(
                onPressed: () {
                  context.go(PairingRoutes.hub);
                },
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
    final locked = MutationScope.busyOf(context);
    return AppIconButton(
      tooltip: 'Notificações',
      onPressed: locked ? null : onPressed,
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

    final locked = MutationScope.busyOf(context);
    return Semantics(
      button: true,
      enabled: onPressed != null && !locked,
      label: 'Perfil',
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: AppInkWell(
          onTap: onPressed == null || locked ? null : onPressed,
          child: Tooltip(message: 'Perfil', child: avatar),
        ),
      ),
    );
  }
}
