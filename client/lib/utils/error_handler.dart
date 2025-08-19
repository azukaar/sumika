import 'package:flutter/material.dart';
import 'dart:developer' as developer;

/// Types of errors that can occur in the application
enum ErrorType {
  network,
  validation,
  authentication,
  permission,
  notFound,
  serverError,
  unknown,
}

/// Structured error class for consistent error handling
class AppError implements Exception {
  final String message;
  final ErrorType type;
  final Object? originalError;
  final StackTrace? stackTrace;
  final String? code;
  final Map<String, dynamic>? details;

  const AppError({
    required this.message,
    this.type = ErrorType.unknown,
    this.originalError,
    this.stackTrace,
    this.code,
    this.details,
  });

  /// Factory constructor for network errors
  factory AppError.network({
    String? message,
    Object? originalError,
    StackTrace? stackTrace,
    String? code,
  }) {
    return AppError(
      message: message ?? 'Network connection failed',
      type: ErrorType.network,
      originalError: originalError,
      stackTrace: stackTrace,
      code: code,
    );
  }

  /// Factory constructor for validation errors
  factory AppError.validation({
    required String message,
    Map<String, dynamic>? details,
    Object? originalError,
    StackTrace? stackTrace,
  }) {
    return AppError(
      message: message,
      type: ErrorType.validation,
      originalError: originalError,
      stackTrace: stackTrace,
      details: details,
    );
  }

  /// Factory constructor for server errors
  factory AppError.serverError({
    String? message,
    String? code,
    Object? originalError,
    StackTrace? stackTrace,
  }) {
    return AppError(
      message: message ?? 'Server error occurred',
      type: ErrorType.serverError,
      originalError: originalError,
      stackTrace: stackTrace,
      code: code,
    );
  }

  /// Factory constructor for not found errors
  factory AppError.notFound({
    String? message,
    Object? originalError,
    StackTrace? stackTrace,
  }) {
    return AppError(
      message: message ?? 'Resource not found',
      type: ErrorType.notFound,
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }

  @override
  String toString() => message;

  /// Convert error to user-friendly message
  String get userMessage {
    switch (type) {
      case ErrorType.network:
        return 'Connection failed. Please check your internet connection.';
      case ErrorType.validation:
        return message; // Validation messages are already user-friendly
      case ErrorType.authentication:
        return 'Authentication failed. Please try again.';
      case ErrorType.permission:
        return 'You don\'t have permission to perform this action.';
      case ErrorType.notFound:
        return 'The requested resource was not found.';
      case ErrorType.serverError:
        return 'Server error occurred. Please try again later.';
      case ErrorType.unknown:
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Get appropriate icon for error type
  IconData get icon {
    switch (type) {
      case ErrorType.network:
        return Icons.wifi_off;
      case ErrorType.validation:
        return Icons.warning;
      case ErrorType.authentication:
        return Icons.lock;
      case ErrorType.permission:
        return Icons.block;
      case ErrorType.notFound:
        return Icons.search_off;
      case ErrorType.serverError:
        return Icons.cloud_off;
      case ErrorType.unknown:
      default:
        return Icons.error;
    }
  }
}

/// Centralized error handling utilities
class ErrorHandler {
  /// Convert various error types to AppError
  static AppError fromException(dynamic error, {StackTrace? stackTrace}) {
    if (error is AppError) {
      return error;
    }

    final errorString = error.toString().toLowerCase();

    // Network-related errors
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('socket') ||
        errorString.contains('timeout')) {
      return AppError.network(
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // HTTP status code errors
    if (errorString.contains('400')) {
      return AppError.validation(
        message: 'Invalid request data',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (errorString.contains('401') || errorString.contains('unauthorized')) {
      return AppError(
        message: 'Authentication failed',
        type: ErrorType.authentication,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (errorString.contains('403') || errorString.contains('forbidden')) {
      return AppError(
        message: 'Access denied',
        type: ErrorType.permission,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (errorString.contains('404') || errorString.contains('not found')) {
      return AppError.notFound(
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (errorString.contains('500') || errorString.contains('server')) {
      return AppError.serverError(
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Default to unknown error
    return AppError(
      message: error.toString(),
      type: ErrorType.unknown,
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Log error with structured information
  static void logError(
    AppError error, {
    String? context,
    Map<String, dynamic>? extra,
  }) {
    final logMessage = StringBuffer();
    if (context != null) logMessage.write('[$context] ');
    logMessage.write('${error.type.name}: ${error.message}');

    developer.log(
      logMessage.toString(),
      name: context ?? 'ErrorHandler',
      error: error.originalError,
      stackTrace: error.stackTrace,
      time: DateTime.now(),
    );

    // Log additional structured data for debugging
    if (error.details != null || extra != null) {
      final logData = <String, dynamic>{
        'error_type': error.type.name,
        'message': error.message,
        if (error.code != null) 'code': error.code,
        if (error.details != null) 'details': error.details,
        if (extra != null) ...extra,
      };

      developer.log(
        'ErrorData: $logData',
        name: '${context ?? 'ErrorHandler'}.Data',
        time: DateTime.now(),
      );
    }
  }

  /// Show a snackbar with error message (enhanced)
  static void showError(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show structured error with better UX
  static void showStructuredError(
    BuildContext context,
    AppError error, {
    String? action,
    VoidCallback? onAction,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error.icon,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(error.userMessage)),
          ],
        ),
        backgroundColor: _getErrorColor(error.type),
        behavior: SnackBarBehavior.floating,
        action: action != null && onAction != null
            ? SnackBarAction(
                label: action,
                onPressed: onAction,
                textColor: Colors.white,
              )
            : null,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Get color based on error type
  static Color _getErrorColor(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return Colors.orange;
      case ErrorType.validation:
        return Colors.amber;
      case ErrorType.authentication:
        return Colors.red;
      case ErrorType.permission:
        return Colors.red;
      case ErrorType.notFound:
        return Colors.blue;
      case ErrorType.serverError:
        return Colors.red;
      case ErrorType.unknown:
      default:
        return Colors.grey;
    }
  }

  /// Show a snackbar with success message
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Handle common async operations with error handling
  static Future<T?> handleAsync<T>(
    BuildContext context,
    Future<T> operation, {
    String? errorMessage,
    String? successMessage,
    bool showLoading = false,
  }) async {
    try {
      if (showLoading && context.mounted) {
        // You could show a loading dialog here if needed
      }

      final result = await operation;
      
      if (successMessage != null && context.mounted) {
        showSuccess(context, successMessage);
      }
      
      return result;
    } catch (e) {
      if (context.mounted) {
        showError(context, errorMessage ?? 'An error occurred: $e');
      }
      return null;
    }
  }

  /// Convert exception to user-friendly message
  static String getErrorMessage(dynamic error) {
    if (error is String) return error;
    if (error is Exception) return error.toString();
    return 'An unexpected error occurred';
  }

  /// Standard error widget for consistent UI
  static Widget buildErrorWidget({
    required String message,
    VoidCallback? onRetry,
    IconData icon = Icons.error_outline,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
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
}

/// Mixin to add error handling capabilities to StatefulWidgets
mixin ErrorHandlerMixin<T extends StatefulWidget> on State<T> {
  void showError(String message) {
    ErrorHandler.showError(context, message);
  }

  void showSuccess(String message) {
    ErrorHandler.showSuccess(context, message);
  }

  /// Handle structured error with logging and optional user notification
  void handleError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    bool showSnackBar = true,
    String? retryAction,
    VoidCallback? onRetry,
  }) {
    final appError = ErrorHandler.fromException(error, stackTrace: stackTrace);
    
    ErrorHandler.logError(
      appError,
      context: context ?? widget.runtimeType.toString(),
    );

    if (showSnackBar && mounted) {
      ErrorHandler.showStructuredError(
        this.context,
        appError,
        action: retryAction,
        onAction: onRetry,
      );
    }
  }

  /// Execute async operation with automatic structured error handling
  Future<R?> executeWithErrorHandling<R>(
    Future<R> Function() operation, {
    String? context,
    bool showSnackBar = true,
    String? retryAction,
    VoidCallback? onRetry,
    R? fallbackValue,
  }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      handleError(
        error,
        stackTrace: stackTrace,
        context: context,
        showSnackBar: showSnackBar,
        retryAction: retryAction,
        onRetry: onRetry,
      );
      return fallbackValue;
    }
  }

  Future<R?> handleAsync<R>(
    Future<R> operation, {
    String? errorMessage,
    String? successMessage,
  }) {
    return ErrorHandler.handleAsync(
      context,
      operation,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

/// Extension on Future to add error handling
extension FutureErrorHandling<T> on Future<T> {
  /// Handle errors automatically with AppError conversion
  Future<T> handleErrors({
    String? context,
    T? fallbackValue,
  }) async {
    try {
      return await this;
    } catch (error, stackTrace) {
      final appError = ErrorHandler.fromException(error, stackTrace: stackTrace);
      ErrorHandler.logError(appError, context: context);
      
      if (fallbackValue != null) {
        return fallbackValue;
      }
      
      throw appError;
    }
  }
}