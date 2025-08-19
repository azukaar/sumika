import 'package:flutter/material.dart';

/// A wrapper widget that handles common loading, error, and empty states
class LoadingWrapper<T> extends StatelessWidget {
  final Future<T>? future;
  final T? data;
  final bool isLoading;
  final String? error;
  final Widget Function(BuildContext context, T data) builder;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final Widget? emptyWidget;
  final String? emptyMessage;
  final VoidCallback? onRetry;

  const LoadingWrapper({
    Key? key,
    this.future,
    this.data,
    this.isLoading = false,
    this.error,
    required this.builder,
    this.loadingWidget,
    this.errorWidget,
    this.emptyWidget,
    this.emptyMessage,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // If we have a future, use FutureBuilder
    if (future != null) {
      return FutureBuilder<T>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingWidget(context);
          }
          
          if (snapshot.hasError) {
            return _buildErrorWidget(context, snapshot.error.toString());
          }
          
          if (snapshot.hasData) {
            final data = snapshot.data!;
            if (_isEmpty(data)) {
              return _buildEmptyWidget(context);
            }
            return builder(context, data);
          }
          
          return _buildEmptyWidget(context);
        },
      );
    }

    // Handle manual state management
    if (isLoading) {
      return _buildLoadingWidget(context);
    }

    if (error != null) {
      return _buildErrorWidget(context, error!);
    }

    if (data != null) {
      if (_isEmpty(data!)) {
        return _buildEmptyWidget(context);
      }
      return builder(context, data!);
    }

    return _buildEmptyWidget(context);
  }

  Widget _buildLoadingWidget(BuildContext context) {
    return loadingWidget ?? 
      const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading...'),
          ],
        ),
      );
  }

  Widget _buildErrorWidget(BuildContext context, String errorMessage) {
    return errorWidget ?? 
      Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error: $errorMessage',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      );
  }

  Widget _buildEmptyWidget(BuildContext context) {
    return emptyWidget ?? 
      Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              emptyMessage ?? 'No data available',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
  }

  bool _isEmpty(T data) {
    if (data is List) return data.isEmpty;
    if (data is Map) return data.isEmpty;
    if (data is String) return data.isEmpty;
    return false;
  }
}

/// Extension to make LoadingWrapper easier to use with common patterns
extension LoadingWrapperExtension on Widget {
  Widget withLoading({
    bool isLoading = false,
    String? error,
    VoidCallback? onRetry,
  }) {
    return LoadingWrapper<bool>(
      data: true,
      isLoading: isLoading,
      error: error,
      onRetry: onRetry,
      builder: (context, _) => this,
    );
  }
}