import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A unified widget for handling AsyncValue states with consistent UI patterns
class AsyncValueWidget<T> extends StatelessWidget {
  const AsyncValueWidget({
    Key? key,
    required this.value,
    required this.data,
    this.loading,
    this.error,
    this.skipLoadingOnRefresh = true,
    this.skipLoadingOnReload = false,
    this.skipError = false,
  }) : super(key: key);

  /// The AsyncValue to handle
  final AsyncValue<T> value;
  
  /// Widget builder for the data state
  final Widget Function(T data) data;
  
  /// Widget to show while loading (defaults to centered CircularProgressIndicator)
  final Widget? loading;
  
  /// Widget builder for error state (defaults to standard error display)
  final Widget Function(Object error, StackTrace? stackTrace)? error;
  
  /// Whether to skip loading widget when refreshing (when we already have data)
  final bool skipLoadingOnRefresh;
  
  /// Whether to skip loading widget when reloading from scratch
  final bool skipLoadingOnReload;
  
  /// Whether to skip error display and show loading instead
  final bool skipError;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: skipLoadingOnRefresh,
      skipLoadingOnReload: skipLoadingOnReload,
      skipError: skipError,
      data: data,
      loading: () => loading ?? _defaultLoading(),
      error: (err, stackTrace) => error?.call(err, stackTrace) ?? _defaultError(context, err, stackTrace),
    );
  }

  Widget _defaultLoading() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _defaultError(BuildContext context, Object error, StackTrace? stackTrace) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A specialized AsyncValueWidget for lists with empty state handling
class AsyncValueListWidget<T> extends StatelessWidget {
  const AsyncValueListWidget({
    Key? key,
    required this.value,
    required this.data,
    this.loading,
    this.error,
    this.empty,
    this.skipLoadingOnRefresh = true,
    this.skipLoadingOnReload = false,
    this.skipError = false,
  }) : super(key: key);

  /// The AsyncValue<List<T>> to handle
  final AsyncValue<List<T>> value;
  
  /// Widget builder for the data state when list has items
  final Widget Function(List<T> data) data;
  
  /// Widget to show while loading
  final Widget? loading;
  
  /// Widget builder for error state
  final Widget Function(Object error, StackTrace? stackTrace)? error;
  
  /// Widget to show when list is empty (defaults to "No items" message)
  final Widget? empty;
  
  final bool skipLoadingOnRefresh;
  final bool skipLoadingOnReload;
  final bool skipError;

  @override
  Widget build(BuildContext context) {
    return AsyncValueWidget<List<T>>(
      value: value,
      loading: loading,
      error: error,
      skipLoadingOnRefresh: skipLoadingOnRefresh,
      skipLoadingOnReload: skipLoadingOnReload,
      skipError: skipError,
      data: (list) {
        if (list.isEmpty) {
          return empty ?? _defaultEmpty(context);
        }
        return data(list);
      },
    );
  }

  Widget _defaultEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No items found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A specialized AsyncValueWidget with refresh capability
class AsyncValueRefreshWidget<T> extends StatelessWidget {
  const AsyncValueRefreshWidget({
    Key? key,
    required this.value,
    required this.data,
    required this.onRefresh,
    this.loading,
    this.error,
    this.skipLoadingOnRefresh = true,
    this.skipLoadingOnReload = false,
    this.skipError = false,
  }) : super(key: key);

  /// The AsyncValue to handle
  final AsyncValue<T> value;
  
  /// Widget builder for the data state
  final Widget Function(T data) data;
  
  /// Callback to refresh data
  final Future<void> Function() onRefresh;
  
  /// Widget to show while loading
  final Widget? loading;
  
  /// Widget builder for error state
  final Widget Function(Object error, StackTrace? stackTrace)? error;
  
  final bool skipLoadingOnRefresh;
  final bool skipLoadingOnReload;
  final bool skipError;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: AsyncValueWidget<T>(
        value: value,
        loading: loading,
        error: error,
        skipLoadingOnRefresh: skipLoadingOnRefresh,
        skipLoadingOnReload: skipLoadingOnReload,
        skipError: skipError,
        data: data,
      ),
    );
  }
}