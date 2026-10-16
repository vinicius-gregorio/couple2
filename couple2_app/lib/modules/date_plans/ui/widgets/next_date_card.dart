import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/ui/home_failure_scope.dart';
import '../../data/date_plans_providers.dart';
import '../../domain/domain.dart';
import '../../routing/routes.dart';

class NextDateCard extends ConsumerWidget {
  const NextDateCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = ref.watch(nextDateProvider);
    final theme = Theme.of(context);

    return StableSlot(
      height: homeNextDateCardHeight,
      child: next.when(
        skipError: true,
        loading: () => const CardSkeleton(
          lines: 2,
          minHeight: homeNextDateCardHeight,
        ),
        error: (error, _) => LoadErrorCard(
          message: homeCardMessage(error, homeDatesLoadError),
          onRetry: () {
            if (!HomeFailureScope.retry(context)) {
              ref.invalidate(nextDateProvider);
            }
          },
          minHeight: homeNextDateCardHeight,
        ),
        data: (plan) {
          if (plan == null) return _emptyCard(context, theme);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: AppInkWell(
              onTap: () => context.push(DatePlanRoutes.detail(plan.id)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      nextDateHeadline(plan),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Horário do aparelho',
                      style: theme.textTheme.bodySmall,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: LoadingButton(
                        variant: LoadingButtonVariant.text,
                        onPressed: () {
                          context.push(DatePlanRoutes.list);
                        },
                        child: const Text('Ver encontros'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
    ),
    );
  }
}

Widget _emptyCard(BuildContext context, ThemeData theme) {
  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 24),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppText('Próximo encontro', style: theme.textTheme.labelLarge),
          const SizedBox(height: 12),
          LoadingButton(
            variant: LoadingButtonVariant.outlined,
            icon: const Icon(Icons.event_available_outlined),
            onPressed: () {
              context.push(DatePlanRoutes.create);
            },
            child: const Text('Planejar um encontro'),
          ),
        ],
      ),
    ),
  );
}
