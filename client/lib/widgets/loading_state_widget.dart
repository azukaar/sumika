import 'package:flutter/material.dart';

/// Widget that handles loading states for regular boolean-based loading patterns
class LoadingStateWidget extends StatelessWidget {
  const LoadingStateWidget({
    Key? key,
    required this.isLoading,
    required this.child,
    this.loadingWidget,
    this.loadingOverlay = false,
    this.loadingOpacity = 0.3,
  }) : super(key: key);

  /// Whether currently in loading state
  final bool isLoading;
  
  /// The main content widget
  final Widget child;
  
  /// Custom loading widget (defaults to CircularProgressIndicator)
  final Widget? loadingWidget;
  
  /// Whether to show loading as overlay over content
  final bool loadingOverlay;
  
  /// Opacity of content when loading overlay is active
  final double loadingOpacity;

  @override
  Widget build(BuildContext context) {
    if (isLoading && !loadingOverlay) {
      return loadingWidget ?? _defaultLoading();
    }

    if (isLoading && loadingOverlay) {
      return Stack(
        children: [
          Opacity(
            opacity: loadingOpacity,
            child: AbsorbPointer(child: child),
          ),
          Center(
            child: loadingWidget ?? _defaultLoading(),
          ),
        ],
      );
    }

    return child;
  }

  Widget _defaultLoading() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

/// Widget that handles error states with retry functionality
class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    Key? key,
    required this.error,
    this.onRetry,
    this.title,
    this.showDetails = false,
  }) : super(key: key);

  /// The error object
  final Object error;
  
  /// Callback for retry action
  final VoidCallback? onRetry;
  
  /// Custom error title
  final String? title;
  
  /// Whether to show error details
  final bool showDetails;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
              title ?? 'Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            if (showDetails) ...[
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A comprehensive widget that handles loading, error, and content states
class StateHandlerWidget extends StatelessWidget {
  const StateHandlerWidget({
    Key? key,
    required this.child,
    this.isLoading = false,
    this.error,
    this.onRetry,
    this.loadingWidget,
    this.errorWidget,
    this.loadingOverlay = false,
    this.loadingOpacity = 0.3,
    this.showErrorDetails = false,
  }) : super(key: key);

  /// The main content widget
  final Widget child;
  
  /// Whether currently loading
  final bool isLoading;
  
  /// Error object if in error state
  final Object? error;
  
  /// Retry callback for error state
  final VoidCallback? onRetry;
  
  /// Custom loading widget
  final Widget? loadingWidget;
  
  /// Custom error widget
  final Widget? errorWidget;
  
  /// Whether to show loading as overlay
  final bool loadingOverlay;
  
  /// Content opacity during loading overlay
  final double loadingOpacity;
  
  /// Whether to show error details
  final bool showErrorDetails;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return errorWidget ?? ErrorStateWidget(
        error: error!,
        onRetry: onRetry,
        showDetails: showErrorDetails,
      );
    }

    return LoadingStateWidget(
      isLoading: isLoading,
      loadingWidget: loadingWidget,
      loadingOverlay: loadingOverlay,
      loadingOpacity: loadingOpacity,
      child: child,
    );
  }
}