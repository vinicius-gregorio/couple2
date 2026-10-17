import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_facing_error.dart';
import 'loading_button.dart';
import 'skeleton.dart';
import 'stable_slot.dart';

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
    this.slotHeight,
    this.emptyMessage = 'Nada por aqui ainda.',
    this.errorMessage = fallbackUserMessage,
  });

  final bool isLoading;
  final Object? error;
  final bool isEmpty;
  final bool hasData;
  final VoidCallback? onRetry;
  final Widget? skeleton;

  /// Loaded-card height. The skeleton and the error card use this same number.
  final double? slotHeight;
  final String emptyMessage;
  final String errorMessage;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (isLoading && !hasData) {
      final loading = skeleton ??
          (slotHeight == null
              ? const ListSkeleton()
              : CardSkeleton(minHeight: slotHeight));
      if (slotHeight == null) return loading;
      return StableSlot(height: slotHeight!, child: loading);
    }
    if (error != null && !hasData) {
      final failure = error;
      final message = failure is String ? failure : userFacingError(failure!);
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          LoadErrorCard(
            message: message,
            onRetry: onRetry,
          ),
        ],
      );
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
    this.errorMessage = fallbackUserMessage,
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
      return ErrorView(
        message: userFacingError(value.error!),
        onRetry: onRetry,
      );
    }
    return skeleton ?? const ListSkeleton(rows: 3);
  }
}

/// Load failure in place of a card or a screen.
///
/// The message comes from [userFacingError]. Retry reloads that content.
class LoadErrorCard extends StatelessWidget {
  const LoadErrorCard({
    super.key,
    required this.message,
    this.onRetry,
    this.margin = const EdgeInsets.symmetric(horizontal: 24),
    this.retryKey = ErrorView.retryKey,
  });

  final String message;
  final VoidCallback? onRetry;
  final EdgeInsetsGeometry margin;
  final Key retryKey;

  static const retryLabel = 'Tentar de novo';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: margin,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            if (onRetry != null)
              LoadingButton(
                key: retryKey,
                variant: LoadingButtonVariant.text,
                compact: true,
                onPressed: onRetry,
                child: const Text(retryLabel),
              ),
          ],
        ),
      ),
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
    final card = LoadErrorCard(
      message: message,
      onRetry: onRetry,
      retryKey: retryKey,
      margin: compact ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 24),
    );
    if (compact) return card;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [const SizedBox(height: 48), card],
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
