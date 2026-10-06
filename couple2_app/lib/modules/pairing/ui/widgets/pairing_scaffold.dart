import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';

const _stepLabels = ['Seu código', 'Código do par', 'Confirmação'];

class PairingScaffold extends ConsumerWidget {
  const PairingScaffold({
    super.key,
    required this.step,
    required this.children,
    this.onRefresh,
  });

  /// 1, 2, or 3.
  final int step;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Steps(current: step),
                const SizedBox(height: 24),
                ...children,
              ],
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const AppText('Parear'),
        actions: [
          if (onRefresh != null)
            IconButton(
              tooltip: 'Atualizar',
              onPressed: () => onRefresh!(),
              icon: const Icon(Icons.refresh),
            ),
          IconButton(
            tooltip: 'Sair',
            onPressed: () => ref.read(logoutActionProvider)(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: onRefresh == null
          ? body
          : RefreshIndicator(onRefresh: onRefresh!, child: body),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (var index = 0; index < _stepLabels.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                Icon(
                  index + 1 < current ? Icons.check_circle : Icons.circle,
                  size: 16,
                  color: index + 1 <= current
                      ? theme.colorScheme.primary
                      : theme.disabledColor,
                ),
                const SizedBox(height: 4),
                AppText(
                  _stepLabels[index],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: index + 1 == current
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
