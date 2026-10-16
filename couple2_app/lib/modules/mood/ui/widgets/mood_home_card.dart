import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/session_provider.dart';
import '../../../../app/ui/home_failure_scope.dart';
import '../../../../core/core.dart';
import '../../../feed/data/feed_providers.dart';
import '../../data/mood_providers.dart';
import '../../domain/domain.dart';
import '../../routing/routes.dart';
import 'mood_picker_sheet.dart';
import 'nudge_composer_sheet.dart';

class MoodHomeCard extends ConsumerStatefulWidget {
  const MoodHomeCard({super.key});

  @override
  ConsumerState<MoodHomeCard> createState() => _MoodHomeCardState();
}

class _MoodHomeCardState extends ConsumerState<MoodHomeCard> {
  bool _sending = false;
  String? _nudgeError;

  Future<void> _send(NudgeKind kind, {String? message}) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _nudgeError = null;
    });
    try {
      await ref
          .read(nudgesRepositoryProvider)
          .send(kind: kind, message: message);
      ref.invalidate(feedPreviewProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Carinho enviado: ${kind.label}')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _nudgeError = userFacingError(error));
      Error.throwWithStackTrace(error, StackTrace.current);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _compose() async {
    await showNudgeComposerSheet(
      context,
      onSend: (draft) => _send(draft.kind, message: draft.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mood = ref.watch(currentMoodProvider);
    final session = ref.watch(sessionProvider).asData?.value;
    final partnerName = _name(session?.partnerName);

    return StableSlot(
      height: homeMoodCardHeight,
      child: mood.when(
        skipError: true,
        data: (current) {
          if (current == null) {
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppText(
                      'Como vocês estão',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 12),
                    ActionErrorReporter(message: _nudgeError),
                    _CareButton(
                      sending: _sending,
                      onTap: () => _send(NudgeKind.thinkingOfYou),
                      onLongPress: _sending ? null : _compose,
                    ),
                    LoadingButton(
                      variant: LoadingButtonVariant.text,
                      onPressed: _sending ? null : _compose,
                      child: const Text('Escolher um carinho'),
                    ),
                  ],
                ),
              ),
            );
          }
          final caring = suggestCaringNudge(current.partner?.mood);
          final theme = Theme.of(context);
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppText(
                    'Como vocês estão',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _MoodSide(
                          title: 'Você',
                          snapshot: current.me,
                          empty: 'Toque para dizer',
                          onTap: () => showMoodPickerSheet(context),
                        ),
                      ),
                      Expanded(
                        child: _MoodSide(
                          title: partnerName,
                          snapshot: current.partner,
                          empty: 'Quando quiser',
                          onTap: () => context.push(MoodRoutes.history),
                        ),
                      ),
                    ],
                  ),
                  if (caring) ...[
                    const SizedBox(height: 12),
                    AppText(
                      'Mandar um carinho?',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                  const SizedBox(height: 12),
                  ActionErrorReporter(message: _nudgeError),
                  _CareButton(
                    sending: _sending,
                    onTap: () => _send(NudgeKind.thinkingOfYou),
                    onLongPress: _sending ? null : _compose,
                  ),
                  const SizedBox(height: 4),
                  const AppText(
                    'Toque para enviar. Segure para escolher.',
                    textAlign: TextAlign.center,
                  ),
                  LoadingButton(
                    variant: LoadingButtonVariant.text,
                    onPressed: _sending ? null : _compose,
                    child: const Text('Escolher um carinho'),
                  ),
                  const SizedBox(height: 8),
                  LoadingButton(
                    variant: LoadingButtonVariant.outlined,
                    onPressed: () {
                      context.push(MoodRoutes.history);
                    },
                    child: const Text('Histórico'),
                  ),
                  const SizedBox(height: 8),
                  LoadingButton(
                    variant: LoadingButtonVariant.outlined,
                    onPressed: () {
                      context.push(MoodRoutes.nudges);
                    },
                    child: const Text('Carinhos recebidos'),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const CardSkeleton(
          lines: 2,
          minHeight: homeMoodCardHeight,
        ),
        error: (error, _) => LoadErrorCard(
          message: homeCardMessage(error, homeMoodLoadError),
          onRetry: () {
            if (!HomeFailureScope.retry(context)) {
              ref.invalidate(currentMoodProvider);
            }
          },
          minHeight: homeMoodCardHeight,
        ),
      ),
    );
  }

  String _name(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return 'Parceiro';
    return trimmed;
  }
}

class _MoodSide extends StatelessWidget {
  const _MoodSide({
    required this.title,
    required this.snapshot,
    required this.empty,
    required this.onTap,
  });

  final String title;
  final MoodSnapshot? snapshot;
  final String empty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mood = snapshot;
    final faded = mood?.stale ?? false;
    return AppInkWell(
      onTap: onTap,
      child: Opacity(
        opacity: faded ? 0.45 : 1,
        child: Column(
          children: [
            Text(
              mood?.mood.emoji ?? '🤍',
              style: const TextStyle(fontSize: 40),
            ),
            const SizedBox(height: 4),
            AppText(title, textAlign: TextAlign.center),
            AppText(
              mood == null ? empty : moodAgeLabel(mood.createdAt),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CareButton extends StatelessWidget {
  const _CareButton({
    required this.sending,
    required this.onTap,
    required this.onLongPress,
  });

  final bool sending;
  final Future<void> Function() onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return StableSlot(
      height: careButtonSlotHeight,
      child: LoadingButton(
      key: const Key('thinking-of-you'),
      loading: sending,
      onPressed: sending
          ? null
          : () async {
              try {
                await onTap();
              } catch (_) {}
            },
      onLongPress: sending ? null : onLongPress,
      child: const Text('💗 Pensando em você'),
      ),
    );
  }
}
