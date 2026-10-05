import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../domain/domain.dart';

class DaysTogetherCard extends StatelessWidget {
  const DaysTogetherCard({
    super.key,
    required this.couple,
    required this.onOpenSettings,
    required this.onOpenDates,
  });

  final Couple couple;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenDates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = couple.upcoming.isEmpty ? null : couple.upcoming.first;
    final hasAnniversary = couple.anniversaryDate != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (!hasAnniversary)
              ElevatedButton(
                onPressed: onOpenSettings,
                child: const Text('Quando vocês começaram?'),
              )
            else ...[
              AppText(
                daysTogetherLabel(couple.daysTogether),
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onOpenSettings,
                child: const Text('Editar data de início'),
              ),
            ],
            if (next != null) ...[
              const SizedBox(height: 8),
              AppText(
                nextDateLine(next),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 4),
            TextButton(
              onPressed: onOpenDates,
              child: const Text('Datas importantes'),
            ),
          ],
        ),
      ),
    );
  }
}
