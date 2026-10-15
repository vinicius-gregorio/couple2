import 'package:flutter/material.dart';

import 'skeleton.dart';

/// Covers the navigator until auth and the session are known.
///
/// The router keeps the browser URL in that window. Without this cover, Home
/// or Login can paint for a frame before the redirect lands.
class SessionSplash extends StatelessWidget {
  const SessionSplash({super.key});

  static const splashKey = Key('sessionSplash');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: splashKey,
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Icon(
                Icons.favorite,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text('Couple', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Abrindo a sessão…',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              const CardSkeleton(),
              const SizedBox(height: 16),
              const CardSkeleton(lines: 2),
            ],
          ),
        ),
      ),
    );
  }
}
