import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/session_provider.dart';
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

  Future<void> _send(NudgeKind kind, {String? message}) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(nudgesRepositoryProvider)
          .send(kind: kind, message: message);
      ref.invalidate(feedPreviewProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Carinho enviado')));
    } on CPLHttpException catch (error) {
      if (!mounted) return;
      final limited = error.response?.statusCode == 429;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            limited ? nudgeRateLimitMessage() : 'Não consegui enviar agora.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não consegui enviar agora.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _compose() async {
    final draft = await showNudgeComposerSheet(context);
    if (draft == null) return;
    await _send(draft.kind, message: draft.message);
  }

  @override
  Widget build(BuildContext context) {
    final mood = ref.watch(currentMoodProvider);
    final session = ref.watch(sessionProvider).asData?.value;
    final partnerName = _name(session?.partnerName);

    return mood.when(
      data: (current) {
        if (current == null) return const SizedBox.shrink();
        final caring = suggestCaringNudge(current.partner?.mood);
        final theme = Theme.of(context);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppText('Como vocês estão', style: theme.textTheme.labelLarge),
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
                _CareButton(
                  caring: caring,
                  sending: _sending,
                  onTap: () => _send(NudgeKind.thinkingOfYou),
                  onLongPress: _sending ? null : _compose,
                ),
                const SizedBox(height: 4),
                const AppText(
                  'Toque para enviar. Segure para escolher.',
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: () => context.push(MoodRoutes.history),
                  child: const Text('Histórico'),
                ),
                TextButton(
                  onPressed: () => context.push(MoodRoutes.nudges),
                  child: const Text('Carinhos recebidos'),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: AppText('Não foi possível carregar o humor: $error'),
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
    return InkWell(
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
    required this.caring,
    required this.sending,
    required this.onTap,
    required this.onLongPress,
  });

  final bool caring;
  final bool sending;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Material(
      color: caring ? color.primaryContainer : color.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: sending ? null : onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Text(
            sending ? 'Enviando…' : '💗 Pensando em você',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}
