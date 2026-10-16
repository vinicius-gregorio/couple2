import 'package:couple2_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../app/routing/app_back_button.dart';
import '../../routing/routes.dart';

const _stepLabels = ['Seu código', 'Código do par', 'Confirmação'];

class PairingScaffold extends ConsumerStatefulWidget {
  const PairingScaffold({
    super.key,
    required this.step,
    required this.children,
    this.onRefresh,
    this.actionsEnabled = true,
  });

  /// 1, 2, or 3.
  final int step;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  /// Locks Sair and Atualizar while a submit is in flight. Atualizar stays
  /// visible whenever [onRefresh] is set.
  final bool actionsEnabled;

  @override
  ConsumerState<PairingScaffold> createState() => _PairingScaffoldState();
}

class _PairingScaffoldState extends ConsumerState<PairingScaffold> {
  var _refreshing = false;

  Future<void> _refresh() async {
    final action = widget.onRefresh;
    if (action == null || _refreshing) return;
    setState(() => _refreshing = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final children = widget.children;
    final onRefresh = widget.onRefresh;
    final actionsEnabled = widget.actionsEnabled;
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

    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: canPop
            ? AppBackButton(
                enabled: actionsEnabled,
                fallback: PairingRoutes.hub,
              )
            : null,
        title: const AppText('Parear'),
        actions: [
          if (onRefresh != null)
            IconButton(
              key: const Key('pairing-refresh'),
              tooltip: 'Atualizar',
              onPressed: _refreshing || !actionsEnabled ? null : _refresh,
              icon: _refreshing
                  ? const SizedBox(
                      key: Key('pairingRefreshSpinner'),
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          IconButton(
            tooltip: 'Sair',
            onPressed: actionsEnabled
                ? () => ref.read(logoutActionProvider)()
                : null,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: onRefresh == null
          ? body
          : RefreshIndicator(onRefresh: _refresh, child: body),
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
