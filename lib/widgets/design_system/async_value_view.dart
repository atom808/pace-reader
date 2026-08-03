import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'motion_tokens.dart';
import 'skeleton.dart';

/// Bridges a Riverpod [AsyncValue] directly to a consistent skeleton/error/
/// data cross-fade (SPEC.md §9.7.4, §9.7.6) — every feature screen uses
/// this instead of hand-rolling its own loading/error branches.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.error,
  });

  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) data;
  final WidgetBuilder? loading;
  final Widget Function(BuildContext context, Object error, StackTrace stackTrace)?
      error;

  @override
  Widget build(BuildContext context) {
    final child = value.when(
      data: (d) => KeyedSubtree(key: const ValueKey('data'), child: data(context, d)),
      loading: () => KeyedSubtree(
        key: const ValueKey('loading'),
        child: loading?.call(context) ?? const _DefaultLoading(),
      ),
      error: (err, stack) => KeyedSubtree(
        key: const ValueKey('error'),
        child: error?.call(context, err, stack) ?? _DefaultError(error: err),
      ),
    );

    return AnimatedSwitcher(
      duration: AppDurations.medium,
      switchInCurve: AppCurves.standard,
      child: child,
    );
  }
}

class _DefaultLoading extends StatelessWidget {
  const _DefaultLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Skeleton(height: 20),
          SizedBox(height: 12),
          Skeleton(height: 20),
          SizedBox(height: 12),
          Skeleton(height: 20, width: 160),
        ],
      ),
    );
  }
}

class _DefaultError extends StatelessWidget {
  const _DefaultError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'Something went wrong: $error',
        style: TextStyle(color: scheme.error),
      ),
    );
  }
}
