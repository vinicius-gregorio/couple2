import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/date_plans_providers.dart';
import '../../domain/domain.dart';
import '../../routing/routes.dart';

class NextDateCard extends ConsumerWidget {
  const NextDateCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = ref.watch(nextDateProvider);
    final theme = Theme.of(context);

    return next.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppText('Próximo date', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              const AppText('Não consegui carregar os dates.'),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => ref.invalidate(nextDateProvider),
                  child: const Text('Tentar de novo'),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (plan) {
        if (plan == null) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppText('Próximo date', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => context.push(DatePlanRoutes.create),
                    icon: const Icon(Icons.event_available_outlined),
                    label: const Text('Planejar um date'),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          child: InkWell(
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
                  Text('Horário do aparelho', style: theme.textTheme.bodySmall),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push(DatePlanRoutes.list),
                      child: const Text('Ver dates'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
