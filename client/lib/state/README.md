# State Management Patterns

This directory contains unified state management patterns for consistent async data handling across the Flutter application.

## Architecture Overview

Our state management follows a layered architecture:

1. **Service Layer**: Raw API interactions (`*_service.dart`)
2. **State Layer**: Reactive state management (`*_notifier.dart`) 
3. **Widget Layer**: UI components with consistent state handling

## Base Classes

### BaseAsyncNotifier<T>
Base class for all async state management with built-in:
- Loading states with `AsyncValue<T>`
- Error handling and rollback
- Optimistic updates
- Consistent logging
- Mount checking for safety

### BaseListAsyncNotifier<T>
Specialized for managing lists with:
- Add/remove/update operations
- Optimistic UI updates
- List-specific helper methods

### BaseEntityAsyncNotifier<T>
For managing single entities with:
- Update operations
- Clear functionality
- Existence checking

## Usage Patterns

### 1. Creating a New Notifier

```dart
class MyDataNotifier extends BaseListAsyncNotifier<MyData> {
  final MyDataService _service;
  
  MyDataNotifier(this._service);

  @override
  String get notifierName => 'MyDataNotifier';

  @override
  Future<List<MyData>> loadData() async {
    return _service.getAllData();
  }

  Future<void> createItem(MyData item) async {
    await addItem(item, () async {
      await _service.create(item);
      return loadData();
    });
  }
}
```

### 2. Provider Registration

```dart
final myDataNotifierProvider = StateNotifierProvider<MyDataNotifier, AsyncValue<List<MyData>>>((ref) {
  final service = ref.watch(myDataServiceProvider);
  return MyDataNotifier(service);
});
```

### 3. Widget Consumption

Use the unified async widgets for consistent UI:

```dart
// For simple async data
AsyncValueWidget<List<MyData>>(
  value: ref.watch(myDataNotifierProvider),
  data: (data) => ListView.builder(
    itemCount: data.length,
    itemBuilder: (context, index) => ListTile(
      title: Text(data[index].name),
    ),
  ),
)

// For lists with empty states
AsyncValueListWidget<MyData>(
  value: ref.watch(myDataNotifierProvider),
  data: (data) => ListView.builder(...),
  empty: Text('No items found'),
)

// With refresh capability
AsyncValueRefreshWidget<List<MyData>>(
  value: ref.watch(myDataNotifierProvider),
  onRefresh: () => ref.refresh(myDataNotifierProvider),
  data: (data) => ListView.builder(...),
)
```

## Error Handling

All notifiers automatically handle:
- Network errors with rollback
- State consistency during failures  
- Structured error logging
- Mount checking to prevent state updates after disposal

## Migration from Old Patterns

### Replace Direct setState Calls

**Before:**
```dart
bool _isLoading = false;
List<Device> _devices = [];
String? _error;

void loadData() async {
  setState(() => _isLoading = true);
  try {
    final devices = await service.getDevices();
    setState(() {
      _devices = devices;
      _isLoading = false;
    });
  } catch (e) {
    setState(() {
      _error = e.toString();
      _isLoading = false;
    });
  }
}
```

**After:**
```dart
AsyncValueWidget<List<Device>>(
  value: ref.watch(deviceNotifierProvider),
  data: (devices) => DeviceList(devices: devices),
)
```

### Replace Manual AsyncValue.when Calls

**Before:**
```dart
deviceAsyncValue.when(
  loading: () => CircularProgressIndicator(),
  error: (err, stack) => Text('Error: $err'),
  data: (devices) => DeviceList(devices: devices),
)
```

**After:**
```dart
AsyncValueWidget<List<Device>>(
  value: deviceAsyncValue,
  data: (devices) => DeviceList(devices: devices),
)
```

## Available Notifiers

- **DeviceNotifier**: Device management with real-time updates
- **ZoneNotifier**: Zone CRUD operations
- **SceneNotifier**: Scene management and testing
- **AutomationNotifier**: Automation lifecycle management

## Widgets

- **AsyncValueWidget**: General async state handling
- **AsyncValueListWidget**: Lists with empty states
- **AsyncValueRefreshWidget**: Pull-to-refresh support
- **LoadingStateWidget**: Non-AsyncValue loading states
- **ErrorStateWidget**: Consistent error display
- **StateHandlerWidget**: Comprehensive state management

## Best Practices

1. **Always use notifiers for data operations** - Don't call services directly from widgets
2. **Leverage optimistic updates** - Use `updateData()` for immediate UI feedback
3. **Use appropriate base classes** - ListAsyncNotifier for collections, EntityAsyncNotifier for single items
4. **Consistent error handling** - Let base classes handle errors automatically
5. **Use unified widgets** - AsyncValueWidget family for consistent UI patterns

## Benefits

- **Reduced boilerplate**: ~80% reduction in state management code
- **Consistent patterns**: Same approach across all data types
- **Better error handling**: Automatic rollback and error display
- **Real-time updates**: Built-in support for WebSocket updates
- **Type safety**: Full TypeScript-like type checking
- **Testing**: Easier to mock and test with clear separation