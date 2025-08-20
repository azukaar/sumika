import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as developer;
import '../utils/error_handler.dart';

/// Base class for async state management with consistent error handling and loading states
abstract class BaseAsyncNotifier<T> extends StateNotifier<AsyncValue<T>> {
  BaseAsyncNotifier() : super(const AsyncValue.loading());

  /// Abstract method for loading data - to be implemented by subclasses
  Future<T> loadData();

  /// Abstract method for the notifier name for logging
  String get notifierName;

  /// Load data with consistent error handling and logging
  Future<void> load() async {
    if (mounted) {
      state = const AsyncValue.loading();
    }
    
    try {
      _log('Loading data...');
      final data = await loadData();
      
      if (mounted) {
        state = AsyncValue.data(data);
        _log('Data loaded successfully');
      }
    } catch (error, stackTrace) {
      final appError = ErrorHandler.fromException(error, stackTrace: stackTrace);
      ErrorHandler.logError(appError, context: notifierName);
      _log('Error loading data: ${appError.message}');
      
      if (mounted) {
        state = AsyncValue.error(appError, stackTrace);
      }
    }
  }

  /// Refresh data (alias for load for consistency)
  Future<void> refresh() => load();

  /// Update data optimistically with rollback on error
  Future<void> updateData(Future<T> Function() updateOperation) async {
    final previousState = state;
    
    try {
      _log('Updating data...');
      final newData = await updateOperation();
      
      if (mounted) {
        state = AsyncValue.data(newData);
        _log('Data updated successfully');
      }
    } catch (error, stackTrace) {
      final appError = ErrorHandler.fromException(error, stackTrace: stackTrace);
      ErrorHandler.logError(appError, context: notifierName);
      _log('Error updating data: ${appError.message}');
      
      if (mounted) {
        // Rollback to previous state on error
        state = previousState;
        // Then set error state
        state = AsyncValue.error(appError, stackTrace);
      }
    }
  }

  /// Execute an operation that doesn't change the main state but might show loading
  Future<R> executeOperation<R>(
    Future<R> Function() operation, {
    bool showLoading = false,
  }) async {
    final previousState = state;
    
    try {
      if (showLoading && mounted) {
        state = AsyncValue.loading();
      }
      
      _log('Executing operation...');
      final result = await operation();
      _log('Operation completed successfully');
      
      if (showLoading && mounted) {
        state = previousState;
      }
      
      return result;
    } catch (error, stackTrace) {
      final appError = ErrorHandler.fromException(error, stackTrace: stackTrace);
      ErrorHandler.logError(appError, context: notifierName);
      _log('Error executing operation: ${appError.message}');
      
      if (mounted) {
        if (showLoading) {
          state = previousState;
        }
        // Don't change the main state for operations, just rethrow the structured error
        throw appError;
      }
      throw appError;
    }
  }

  /// Check if currently loading
  bool get isLoading => state.isLoading;

  /// Check if has error
  bool get hasError => state.hasError;

  /// Check if has data
  bool get hasData => state.hasValue;

  /// Get data safely
  T? get data => state.value;

  /// Get error safely
  Object? get error => state.error;

  void _log(String message) {
    developer.log(
      message,
      name: notifierName,
      time: DateTime.now(),
    );
  }
}

/// Base class for async notifiers that manage lists of items
abstract class BaseListAsyncNotifier<T> extends BaseAsyncNotifier<List<T>> {
  
  /// Add an item to the list optimistically
  Future<void> addItem(T item, Future<List<T>> Function() addOperation) async {
    await updateData(() async {
      final newList = await addOperation();
      return newList;
    });
  }

  /// Remove an item from the list optimistically
  Future<void> removeItem(bool Function(T) predicate, Future<List<T>> Function() removeOperation) async {
    await updateData(() async {
      final newList = await removeOperation();
      return newList;
    });
  }

  /// Update an item in the list optimistically
  Future<void> updateItem(
    bool Function(T) predicate,
    T Function(T) updateFunction,
    Future<List<T>> Function() updateOperation,
  ) async {
    await updateData(() async {
      final newList = await updateOperation();
      return newList;
    });
  }

  /// Get current list safely
  List<T> get currentList => data ?? [];

  /// Check if list is empty
  bool get isEmpty => currentList.isEmpty;

  /// Get list length
  int get length => currentList.length;
}

/// Base class for managing single entity state
abstract class BaseEntityAsyncNotifier<T> extends BaseAsyncNotifier<T?> {
  
  /// Update the entity
  Future<void> updateEntity(Future<T> Function() updateOperation) async {
    await updateData(() async {
      final updatedEntity = await updateOperation();
      return updatedEntity;
    });
  }

  /// Clear the entity
  void clearEntity() {
    if (mounted) {
      state = const AsyncValue.data(null);
    }
  }

  /// Check if entity exists
  bool get hasEntity => data != null;
}