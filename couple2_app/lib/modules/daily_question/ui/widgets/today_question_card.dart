import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/session_provider.dart';
import '../../data/daily_question_providers.dart';
import '../../domain/domain.dart';
import '../../routing/routes.dart';

class TodayQuestionCard extends ConsumerWidget {
  const TodayQuestionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayQuestionProvider);
    final session = ref.watch(sessionProvider).asData?.value;
    final partnerName = session?.partnerName ?? '';

    final question = today.asData?.value;
    final copy = question == null
        ? null
        : todayCardCopy(
            answeredByMe: question.answeredByMe,
            unlocked: question.unlocked,
            partnerName: partnerName,
            partnerAnswered: question.partnerAnswered,
          );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: InkWell(
        onTap: () => context.push(DailyQuestionRoutes.today),
        child: IgnorePointer(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        'Pergunta do dia',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      if (today.isLoading && question == null)
                        const LinearProgressIndicator()
                      else if (today.hasError)
                        AppText(
                          'Não foi possível carregar a pergunta. Toque para abrir.',
                        )
                      else if (copy != null)
                        AppText(copy.title)
                      else
                        const AppText('Responda a pergunta de hoje'),
                    ],
                  ),
                ),
                if (copy != null && copy.kind != TodayCardKind.unanswered) ...[
                  const SizedBox(width: 12),
                  _PartnerAvatar(
                    pictureUrl: session?.partnerPicture,
                    gray: copy.grayPartnerAvatar,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PartnerAvatar extends StatelessWidget {
  const _PartnerAvatar({required this.pictureUrl, required this.gray});

  final String? pictureUrl;
  final bool gray;

  @override
  Widget build(BuildContext context) {
    final avatar = pictureUrl == null || pictureUrl!.isEmpty
        ? const CircleAvatar(child: Icon(Icons.person))
        : CircleAvatar(
            backgroundImage: NetworkImage(pictureUrl!),
            onBackgroundImageError: (_, __) {},
          );
    if (!gray) return avatar;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0,
        0,
        0,
        0.65,
        0,
      ]),
      child: avatar,
    );
  }
}
