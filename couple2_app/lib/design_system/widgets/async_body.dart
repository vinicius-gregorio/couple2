import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'skeleton.dart';

/// Loading skeleton, error with retry, empty, or [child].
///
/// [hasData] keeps the current child on screen during a refresh so a reload
/// does not flash a skeleton over content that is already visible.
class AsyncBody extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.isLoading,
    required this.child,
    this.error,
    this.isEmpty = false,
    this.hasData = false,
    this.onRetry,
    this.skeleton,
    this.emptyMessage = 'Nada por aqui ainda.',
    this.errorMessage = 'Não foi possível carregar.',
  });

  final bool isLoading;
  final Object? error;
  final bool isEmpty;
  final bool hasData;
  final VoidCallback? onRetry;
  final Widget? skeleton;
  final String emptyMessage;
  final String errorMessage;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (isLoading && !hasData) {
      return skeleton ?? const ListSkeleton();
    }
    if (error != null && !hasData) {
      return ErrorView(message: errorMessage, onRetry: onRetry);
    }
    if (isEmpty) {
      return EmptyView(message: emptyMessage);
    }
    return child;
  }
}

class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.isEmpty,
    this.onRetry,
    this.skeleton,
    this.empty,
    this.emptyMessage = 'Nada por aqui ainda.',
    this.errorMessage = 'Não foi possível carregar.',
  });

  final AsyncValue<T> value;
  final bool Function(T data)? isEmpty;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final Widget? skeleton;
  final Widget? empty;
  final String emptyMessage;
  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) {
      final current = value.requireValue;
      if (isEmpty != null && isEmpty!(current)) {
        return empty ?? EmptyView(message: emptyMessage);
      }
      return data(current);
    }
    if (value.hasError) {
      return ErrorView(message: errorMessage, onRetry: onRetry);
    }
    return skeleton ?? const ListSkeleton(rows: 3);
  }
}

/// Inline PT-BR failure for a mutation that should stay on screen.
///
/// An empty message takes no space. A new message grows in place.
/// [MutationBannerTone.info] is for a notice, such as a declined request.
enum MutationBannerTone { error, info }

class MutationErrorBanner extends StatelessWidget {
  const MutationErrorBanner({
    super.key,
    this.message,
    this.tone = MutationBannerTone.error,
  });

  static const bannerKey = Key('mutation-error');

  final String? message;
  final MutationBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final text = message;
    final visible = text != null && text.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;
    // Info is body text. Primary is wine and reads as the error red.
    final color = tone == MutationBannerTone.info
        ? scheme.onSurface
        : scheme.error;
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      alignment: Alignment.topCenter,
      child: visible
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                text,
                key: bannerKey,
                textAlign: TextAlign.center,
                style: TextStyle(color: color),
              ),
            )
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Tentar de novo',
    this.compact = false,
  });

  static const retryKey = Key('asyncRetry');

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: EdgeInsets.all(compact ? 12 : 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: compact ? 28 : 40,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(
              key: retryKey,
              onPressed: onRetry,
              child: Text(retryLabel),
            ),
          ],
        ],
      ),
    );

    if (compact) return content;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [const SizedBox(height: 48), content],
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.message,
    this.action,
    this.compact = false,
  });

  static const emptyKey = Key('asyncEmpty');

  final String message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      key: emptyKey,
      padding: EdgeInsets.all(compact ? 12 : 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: compact ? 28 : 40,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
    if (compact) return content;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [const SizedBox(height: 48), content],
    );
  }
}
