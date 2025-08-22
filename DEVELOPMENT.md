# Sumika Smart Home Platform - Development Guide

## 📋 Table of Contents

1. [Philosophy & Design Principles](#philosophy--design-principles)
2. [Architecture Overview](#architecture-overview)
3. [Backend Architecture](#backend-architecture)
4. [Frontend Architecture](#frontend-architecture)
5. [Code Quality Standards](#code-quality-standards)
6. [File Structure & Purpose](#file-structure--purpose)
7. [Development Patterns](#development-patterns)
8. [Error Handling](#error-handling)
9. [Logging Strategy](#logging-strategy)
10. [State Management](#state-management)
11. [UI Design System](#ui-design-system)
12. [API Design](#api-design)
13. [Configuration Management](#configuration-management)
14. [Testing Strategy](#testing-strategy)
15. [Security Considerations](#security-considerations)
16. [Performance Guidelines](#performance-guidelines)
17. [Deployment & Operations](#deployment--operations)

---

## Philosophy & Design Principles

### Core Values

**1. Code Quality Over Speed**
- Prioritize maintainable, readable code over quick fixes
- Follow DRY (Don't Repeat Yourself) and KISS (Keep It Simple, Stupid) principles
- Every feature should be built to last and scale

**2. Consistency Above All**
- Uniform patterns across frontend and backend
- Standardized error handling, logging, and state management
- Consistent UI/UX patterns and component usage

**3. Developer Experience**
- Self-documenting code with clear patterns
- Comprehensive error messages and debugging information
- Tooling that prevents common mistakes

**4. Operational Excellence**
- Observable systems with structured logging
- Graceful error handling and recovery
- Configuration-driven behavior for different environments

### Design Decisions

**Backend: Go with Domain-Driven Design**
- Clean separation of concerns with service/repository patterns
- Structured error handling with typed errors
- Configuration-driven behavior
- Centralized HTTP routing with domain-specific handlers
- Repository pattern for data persistence abstraction
- Type-safe domain models in dedicated `/types` package

**Frontend: Flutter with Riverpod State Management**
- Reactive state management with consistent patterns
- Component-based UI with reusable widgets
- Unified async data handling
- Structured error handling with user-friendly messages

**Data Storage: JSON Files with Atomic Operations**
- Simple, readable data storage
- Atomic write operations for data integrity
- Backup and versioning support
- Easy debugging and inspection

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    SUMIKA ARCHITECTURE                      │
├─────────────────────────────────────────────────────────────┤
│  Frontend (Flutter)          │  Backend (Go)                │
│  ┌─────────────────────────┐  │  ┌─────────────────────────┐ │
│  │ UI Layer                │  │  │ HTTP Handlers           │ │
│  │ - Widgets               │  │  │ - REST API              │ │
│  │ - Screens               │  │  │ - WebSocket             │ │
│  │ - Navigation            │  │  │ - Middleware            │ │
│  ├─────────────────────────┤  │  ├─────────────────────────┤ │
│  │ State Management        │  │  │ Service Layer           │ │
│  │ - Notifiers             │  │  │ - Business Logic        │ │
│  │ - Providers             │  │  │ - Validation            │ │
│  │ - AsyncValue Handling   │  │  │ - Error Handling        │ │
│  ├─────────────────────────┤  │  ├─────────────────────────┤ │
│  │ Service Layer           │  │  │ Repository Layer        │ │
│  │ - API Clients           │  │  │ - Data Access           │ │
│  │ - WebSocket Service     │  │  │ - Storage Abstraction   │ │
│  │ - Error Handling        │  │  │ - Atomic Operations     │ │
│  └─────────────────────────┘  │  └─────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│                    Shared Protocols                         │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ HTTP REST API + WebSocket Real-time Updates            │ │
│  │ JSON Data Format + Structured Error Responses          │ │
│  └─────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│                    External Services                        │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ Zigbee2MQTT (Device Communication)                     │ │
│  │ MQTT Broker (Message Queue)                            │ │
│  │ File System (Data Storage)                             │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## Backend Architecture

### Layered Architecture

**1. HTTP Layer (`/server/http/*_handlers.go`)**
- Thin HTTP handlers focused on request/response transformation
- Input validation and parameter extraction
- Error handling and response formatting
- No business logic - delegates to service layer
- Centralized routing in `init.go`

**2. Service Layer (`/server/services/*.go`)**
- Contains all business logic and validation rules
- Orchestrates between repositories and external services
- Handles complex operations and transactions
- Provides clean interfaces for HTTP handlers

**3. Repository Layer (`/server/storage/*.go`)**
- Data access abstraction with interfaces
- Atomic file operations for data integrity
- CRUD operations with proper error handling
- Backup and versioning support

**4. Infrastructure Layer**
- Configuration management (`/server/config/`)
- Logging utilities (`/server/utils/`)
- Error handling (`/server/errors/`)
- WebSocket real-time communication (`/server/realtime/`)

### Key Components

**Error Handling System (`/server/errors/`)**
```go
// Structured error types with automatic HTTP mapping
type AppError struct {
    Type       ErrorType              `json:"type"`
    Message    string                 `json:"message"`
    Code       string                 `json:"code,omitempty"`
    Details    map[string]interface{} `json:"details,omitempty"`
    Timestamp  time.Time              `json:"timestamp"`
    RequestID  string                 `json:"request_id,omitempty"`
    StatusCode int                    `json:"-"`
    Cause      error                  `json:"-"`
}

// Usage pattern in handlers
if err := errors.ParseJSONBody(r, &request); err != nil {
    errorHandler.HandleError(w, r, err, "parse_request")
    return
}
```

**Configuration System (`/server/config/config.go`)**
- Centralized configuration with environment override support
- Validation and default values
- Type-safe access throughout application
```go
cfg := config.GetConfig()
server := &http.Server{
    Addr:         fmt.Sprintf("%s:%d", cfg.Server.Host, cfg.Server.Port),
    ReadTimeout:  cfg.Server.ReadTimeout,
    WriteTimeout: cfg.Server.WriteTimeout,
}
```

**Structured Logging (`/server/utils/structured_log.go`)**
```go
// Rich context for debugging and monitoring
context := utils.NewLogContext("automation").
    WithOperation("create").
    WithUser(userID).
    WithMetadata("automation_type", automationType)

utils.InfoWithContext("Creating automation", context)
```

### Service Layer Patterns

**Dependency Injection (`/server/services/container.go`)**
- Centralized service creation and dependency management
- Clean separation of concerns
- Easy testing with mock dependencies

**Repository Pattern (`/server/storage/interfaces.go`)**
- Abstract data access behind interfaces
- Support for different storage backends
- Atomic operations for data consistency

**Validation Pattern**
- Input validation at service layer boundaries
- Structured validation errors with field-level details
- Business rule validation separate from data validation

---

## Frontend Architecture

### State Management Philosophy

**Unified Riverpod Architecture**
- All state managed through Riverpod providers
- Consistent AsyncValue handling across the app
- No direct setState() calls in widgets
- Optimistic updates with automatic rollback on errors

### Base Classes for Consistency

**BaseAsyncNotifier (`/client/lib/state/base_async_notifier.dart`)**
```dart
abstract class BaseAsyncNotifier<T> extends StateNotifier<AsyncValue<T>> {
  // Automatic error handling and logging
  // Optimistic updates with rollback
  // Consistent loading states
  // Mount checking for safety
}
```

**Specialized Notifiers**
- `BaseListAsyncNotifier<T>` - For managing collections
- `BaseEntityAsyncNotifier<T>` - For single entities
- Domain-specific notifiers (DeviceNotifier, ZoneNotifier, etc.)

### Widget Architecture

**Consistent Async Handling (`/client/lib/widgets/async_value_widget.dart`)**
```dart
// Unified pattern for all async operations
AsyncValueWidget<List<Device>>(
  value: ref.watch(deviceNotifierProvider),
  data: (devices) => DeviceList(devices: devices),
  loading: CustomLoadingWidget(),
  error: (error, stack) => CustomErrorWidget(error),
)
```

**Specialized Widgets**
- `AsyncValueListWidget` - Lists with empty states
- `AsyncValueRefreshWidget` - Pull-to-refresh support
- `LoadingStateWidget` - Non-AsyncValue loading states
- `StateHandlerWidget` - Comprehensive state management

### Service Layer

**API Services (`/client/lib/*_service.dart`)**
- Raw API communication
- HTTP request/response handling
- Error transformation to structured errors

**Business Services (`/client/lib/services/*.dart`)**
- Complex business logic
- Data aggregation and transformation
- Cache management

### Error Handling

**Structured Error System (`/client/lib/utils/error_handler.dart`)**
```dart
// Typed errors with user-friendly messages
enum ErrorType {
  network, validation, authentication, 
  permission, notFound, serverError, unknown
}

// Automatic error classification and handling
class AppError implements Exception {
  final ErrorType type;
  final String message;
  String get userMessage; // User-friendly version
  IconData get icon;      // Appropriate icon
}
```

**Error Handling Mixin**
```dart
mixin ErrorHandlingMixin<T extends StatefulWidget> on State<T> {
  void handleError(dynamic error, {
    bool showSnackBar = true,
    String? retryAction,
    VoidCallback? onRetry,
  });
}
```

---

## Code Quality Standards

### Duplication Prevention

**❌ NEVER Duplicate These Patterns:**

1. **HTTP Response Handling**
   - Use `http.WriteJSON()`, `http.WriteError()` helpers
   - Never manually encode JSON in handlers

2. **URL Parameter Extraction**
   - Use `errors.GetPathParam()`, `errors.GetQueryParam()`
   - Never directly call `mux.Vars(r)`

3. **Error Handling**
   - Backend: Use `AppError` types and middleware
   - Frontend: Use `ErrorHandlingMixin` and structured errors

4. **State Management**
   - Use `BaseAsyncNotifier` subclasses
   - Never use direct `setState()` for async operations

5. **Async Widget Patterns**
   - Use `AsyncValueWidget` family
   - Never manually write `AsyncValue.when()` logic

6. **Logging**
   - Use structured logging with `LogContext`
   - Never use raw `print()` statements

### Code Review Checklist

**Before Creating New Code:**
1. ✅ Search existing codebase for similar functionality
2. ✅ Check if base classes or helpers already exist
3. ✅ Follow established patterns in similar files
4. ✅ Use existing error handling and logging patterns
5. ✅ Ensure consistent naming conventions

**Quality Gates:**
- Functions should be <30 lines (extract helpers if longer)
- No copy-paste code - create shared utilities
- All errors must use structured error types
- All async operations must use established patterns
- All new features must follow existing architectural patterns

### Naming Conventions

**Backend (Go):**
- Packages: lowercase, descriptive (`errors`, `config`, `storage`)
- Functions: PascalCase for public, camelCase for private
- Types: PascalCase with descriptive names
- Interfaces: Type + "er" suffix (`ZoneRepository`, `DeviceService`)

**Frontend (Dart):**
- Files: snake_case with descriptive names
- Classes: PascalCase
- Functions/variables: camelCase
- Constants: SCREAMING_SNAKE_CASE
- Providers: descriptive + "Provider" suffix

### Documentation Standards

**Required Documentation:**
1. All public functions must have doc comments
2. Complex business logic must be explained
3. API endpoints must document parameters and responses
4. State management patterns must be documented
5. Error conditions must be documented

---

## File Structure & Purpose

### Backend Structure

```
server/
├── config/
│   └── config.go                      # Centralized configuration management
├── errors/
│   ├── types.go                       # Structured error types and factories
│   ├── middleware.go                  # Error handling middleware
│   └── helpers.go                     # Validation and parsing helpers
├── http/
│   ├── init.go                        # HTTP server initialization and routing
│   ├── health_handlers.go             # Health check endpoints
│   ├── automation_handlers.go         # Automation management endpoints
│   ├── device_handlers.go             # Device management endpoints
│   ├── scene_handlers.go              # Scene management endpoints
│   ├── voice_handlers.go              # Voice processing endpoints
│   └── zone_handlers.go               # Zone management endpoints
├── services/
│   ├── automation_service.go          # Automation business logic and orchestration
│   ├── scene_service.go               # Scene management and execution
│   ├── voice_service.go               # Voice recognition service management
│   └── voice_background.go            # Voice processing background worker
├── storage/
│   ├── general_repository.go          # General-purpose storage operations
│   ├── automation_repository.go       # Automation data access layer
│   ├── scene_repository.go            # Scene data access layer
│   ├── voice_intent_generator.go      # Voice intent data generation
│   └── zigbee.go                      # Zigbee device data structures
├── types/
│   ├── automation_types.go            # Automation-specific data types
│   ├── device_types.go                # Device data structures
│   ├── scene_types.go                 # Scene management types
│   ├── storage_types.go               # Storage abstraction types
│   └── voice_types.go                 # Voice processing data structures
├── realtime/
│   └── websocket.go                   # WebSocket real-time communication
├── assets/voice/
│   ├── intent.py                      # Voice command processing engine
│   └── intents.json                   # Generated voice intent data
└── zigbee2mqtt/
    ├── API.go                         # Zigbee device communication and deletion
    └── index.go                       # Intelligent device merging and synchronization
```

### Frontend Structure

```
client/lib/
├── state/
│   ├── base_async_notifier.dart  # Base classes for state management
│   ├── device_notifier.dart      # Device state management
│   ├── zone_notifier.dart        # Zone state management
│   ├── scene_notifier.dart       # Scene state management
│   ├── automation_notifier.dart  # Automation state management
│   └── README.md                 # State management documentation
├── widgets/
│   ├── async_value_widget.dart   # Unified async widget handling
│   └── loading_state_widget.dart # Loading and error state widgets
├── services/
│   ├── dashboard_service.dart    # Dashboard data aggregation
│   └── error_handler.dart        # Centralized error handling
├── utils/
│   ├── error_handler.dart        # Error handling utilities
│   └── device_utils.dart         # Device-specific utilities
├── types.dart                    # Core data types
├── automation_types.dart         # Automation-specific types
├── websocket_service.dart        # Real-time communication
├── zigbee-service.dart          # Device communication service
├── automation_service.dart      # Automation business logic
├── scene_management_service.dart # Scene management
├── dashboard.dart               # Main dashboard screen
├── automation.dart              # Automation management screen
├── automation_create.dart       # Automation creation screen
└── zones.dart                   # Zone management screen
```

### Configuration Files

```
├── todo-code.md                  # Code quality improvement tracking
├── DEVELOPMENT.md               # This comprehensive development guide
└── build-data/                 # Runtime data storage
    ├── zones_data.json          # Zone and device assignments
    ├── automations.json         # Automation rules
    └── device_metadata.json     # Device customization data
```

---

## Development Patterns

### Backend Patterns

**1. API Handler Pattern**
```go
func API_HandleResource(w http.ResponseWriter, r *http.Request) {
    // 1. Parameter extraction with validation
    id, err := errors.GetPathParam(r, "id")
    if err != nil {
        errorHandler.HandleError(w, r, err, "extract_id")
        return
    }

    // 2. Request body parsing (if needed)
    var request ResourceRequest
    if err := errors.ParseJSONBody(r, &request); err != nil {
        errorHandler.HandleError(w, r, err, "parse_body")
        return
    }

    // 3. Delegate to service layer
    result, err := container.ResourceService.HandleResource(id, request)
    if err != nil {
        errorHandler.HandleError(w, r, err, "handle_resource")
        return
    }

    // 4. Success response
    http.WriteJSON(w, result)
}
```

**2. Service Layer Pattern**
```go
func (s *ResourceService) HandleResource(id string, request ResourceRequest) (*Resource, error) {
    // 1. Input validation
    validator := errors.NewValidator()
    errors.ValidateRequired(validator, "name", request.Name)
    if err := validator.ToAppError(); err != nil {
        return nil, err
    }

    // 2. Business logic
    resource, err := s.repository.FindByID(id)
    if err != nil {
        return nil, errors.WrapDatabaseError(err, "find_resource")
    }

    // 3. Update and save
    resource.Update(request)
    if err := s.repository.Save(resource); err != nil {
        return nil, errors.WrapDatabaseError(err, "save_resource")
    }

    return resource, nil
}
```

**3. Repository Pattern**
```go
type ResourceRepository interface {
    FindByID(id string) (*Resource, error)
    Save(resource *Resource) error
    Delete(id string) error
    List() ([]*Resource, error)
}
```

### Frontend Patterns

**1. Notifier Pattern**
```dart
class ResourceNotifier extends BaseListAsyncNotifier<Resource> {
  final ResourceService _service;
  
  ResourceNotifier(this._service);

  @override
  String get notifierName => 'ResourceNotifier';

  @override
  Future<List<Resource>> loadData() async {
    return _service.getAllResources();
  }

  Future<void> createResource(Resource resource) async {
    await addItem(resource, () async {
      await _service.createResource(resource);
      return loadData();
    });
  }
}
```

**2. Widget Pattern**
```dart
class ResourceListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('Resources')),
      body: AsyncValueWidget<List<Resource>>(
        value: ref.watch(resourceNotifierProvider),
        data: (resources) => ListView.builder(
          itemCount: resources.length,
          itemBuilder: (context, index) => ResourceListItem(
            resource: resources[index],
            onTap: () => _handleResourceTap(resources[index]),
          ),
        ),
      ),
    );
  }
}
```

**3. Service Pattern**
```dart
class ResourceService {
  static Future<String> get baseUrl => ApiConfig.manageApiUrl;

  Future<List<Resource>> getAllResources() async {
    try {
      final url = await baseUrl;
      final response = await http.get(Uri.parse('$url/resources'));
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Resource.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load resources: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load resources: $e');
    }
  }
}
```

---

## Error Handling

### Backend Error Strategy

**Error Type Classification:**
```go
const (
    ValidationError    ErrorType = "validation"    // 400 - Bad Request
    NotFoundError     ErrorType = "not_found"     // 404 - Not Found
    ConflictError     ErrorType = "conflict"      // 409 - Conflict
    UnauthorizedError ErrorType = "unauthorized"  // 401 - Unauthorized
    ForbiddenError    ErrorType = "forbidden"     // 403 - Forbidden
    InternalError     ErrorType = "internal"      // 500 - Internal Server Error
    NetworkError      ErrorType = "network"       // 503 - Service Unavailable
    TimeoutError      ErrorType = "timeout"       // 503 - Service Unavailable
)
```

**Error Response Format:**
```json
{
  "error": {
    "type": "validation",
    "message": "Request validation failed",
    "code": "VAL_001",
    "timestamp": "2023-12-07T10:30:00Z",
    "request_id": "req_123456",
    "details": {
      "validation_errors": {
        "name": "This field is required",
        "email": "Invalid email format"
      }
    }
  }
}
```

**Error Handling Middleware:**
- Automatic error classification and HTTP status mapping
- Request ID tracking for debugging
- Sanitization of internal errors for security
- Structured logging with context

### Frontend Error Strategy

**Error Classification and User Experience:**
```dart
enum ErrorType {
  network,      // "Check your internet connection"
  validation,   // Show specific field errors
  authentication, // "Please log in again"
  permission,   // "You don't have permission"
  notFound,     // "Resource not found"
  serverError,  // "Server error, try again later"
  unknown,      // "An unexpected error occurred"
}
```

**Error Display Patterns:**
- **SnackBar**: For operation results (success/failure)
- **Dialog**: For critical errors requiring user action
- **Inline**: For form validation errors
- **Screen**: For major failures with retry options
- **Dashboard Error States**: Connection failure UI with retry button and settings access

**Error Recovery:**
- Automatic retry for network errors
- Rollback for optimistic updates that fail
- User-initiated retry with progress indication
- Graceful degradation for non-critical features
- **Dashboard Recovery**: Error state UI with manual retry and settings gear access
- **State Clearing**: Clear app state on server URL changes to prevent stale data

---

## Logging Strategy

### Backend Logging

**Structured Logging with Context:**
```go
context := utils.NewLogContext("automation").
    WithOperation("create").
    WithUser(userID).
    WithRequest(requestID, "POST", "/automations").
    WithDuration(time.Since(startTime)).
    WithMetadata("automation_type", "ifttt")

utils.InfoWithContext("Automation created successfully", context)
```

**Log Levels and Usage:**
- **DEBUG**: Detailed execution flow, variable values
- **INFO**: Normal operations, successful requests
- **WARNING**: Recoverable errors, deprecated usage
- **ERROR**: Failures requiring attention
- **FATAL**: Critical failures causing shutdown

**Specialized Logging:**
- **HTTP Requests**: Method, path, status, timing
- **Database Operations**: Query type, table, duration, rows affected
- **Security Events**: Authentication attempts, permission checks
- **Performance**: Operation timing, resource usage

### Frontend Logging

**Development Logging:**
```dart
developer.log(
  'Device state updated',
  name: 'DeviceNotifier',
  error: error,
  time: DateTime.now(),
);
```

**Error Tracking:**
- All errors logged with stack traces
- User actions leading to errors
- Device and app context information
- Network request/response logging

---

## State Management

### Riverpod Architecture

**Provider Hierarchy:**
```dart
// Service providers (singletons)
final deviceServiceProvider = Provider<ZigbeeService>((ref) => ZigbeeService());

// State notifier providers (reactive state)
final deviceNotifierProvider = StateNotifierProvider<DeviceNotifier, AsyncValue<List<Device>>>(
  (ref) => DeviceNotifier(ref.watch(deviceServiceProvider))
);

// Computed providers (derived state)
final devicesByZoneProvider = Provider.family<List<Device>, String>((ref, zone) {
  return ref.watch(deviceNotifierProvider).value?.where((d) => d.zones?.contains(zone) ?? false).toList() ?? [];
});
```

**State Management Rules:**
1. All state goes through Riverpod providers
2. No direct setState() in StatefulWidgets for async operations
3. Use BaseAsyncNotifier subclasses for consistency
4. Optimistic updates with automatic rollback
5. Loading states handled automatically

**Data Flow:**
```
User Action → Notifier Method → Service Call → Repository → Database
     ↓              ↓              ↓            ↓           ↓
UI Update ← State Update ← Response ← Data Access ← Storage
```

### Real-time Updates

**WebSocket Integration with Reconnection:**
```dart
class DeviceNotifier extends BaseListAsyncNotifier<Device> {
  void _initializeWebSocket() {
    _webSocketService.deviceUpdates.listen(_handleDeviceUpdate);
  }

  void _handleDeviceUpdate(DeviceUpdate update) {
    // Apply incremental updates to current state
    state.whenData((devices) => {
      // Update specific device with new state
    });
  }
}
```

**Connection Management (`/client/lib/websocket_service.dart`):**
- **Automatic Reconnection**: Progressive backoff with max attempts
- **Extended Retry**: 2-minute retry after initial attempts exhausted  
- **Manual Restart**: User-triggered reconnection capability
- **Connection State**: Real-time connection status tracking

**Update Strategies:**
- **Optimistic Updates**: Immediate UI feedback with rollback on error
- **Real-time Sync**: WebSocket updates for live device state
- **Periodic Refresh**: Background polling for data consistency
- **Cache Invalidation**: Smart refresh based on operation types
- **Reconnection Recovery**: Auto-refresh data after reconnection

### App Lifecycle Management

**Mobile App State Handling (`/client/lib/main.dart`):**
```dart
class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  DateTime? _pauseTime;
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _pauseTime = DateTime.now();
        break;
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
    }
  }
  
  void _handleAppResumed() {
    if (_pauseTime != null) {
      final pauseDuration = DateTime.now().difference(_pauseTime!);
      if (pauseDuration.inMinutes >= 5) {
        // Auto-refresh after extended absence
        _reconnectAndRefresh();
      }
    }
  }
}
```

**Lifecycle Strategies:**
- **Extended Absence Detection**: 5+ minute pause triggers refresh
- **Automatic Reconnection**: WebSocket restart on app resume
- **Data Refresh**: Device state update after background periods
- **State Preservation**: Maintain UI state during brief interruptions

---

## UI Design System

### Design Philosophy

**Material Design 3 Foundation:**
- Consistent spacing using 8dp grid system
- Material color system with theme support
- Typography scale with semantic naming
- Elevation and shadows for depth

**Component Hierarchy:**
```
Screens (Full page layouts)
  ↓
Sections (Major UI areas)
  ↓
Components (Reusable widgets)
  ↓
Elements (Basic building blocks)
```

### Visual Consistency

**Color Usage:**
- Primary: Main brand color for important actions
- Secondary: Supporting colors for less important actions
- Surface: Background colors for cards and containers
- Error: Red variations for errors and warnings
- Success: Green variations for positive actions

**Typography:**
- headlineLarge: Major page titles
- headlineMedium: Section headers
- titleLarge: Card titles
- bodyLarge: Primary text content
- bodyMedium: Secondary text content
- labelLarge: Button text

**Spacing System:**
```dart
// Base unit: 8dp
const double spacingXS = 4.0;   // 0.5x
const double spacingS = 8.0;    // 1x
const double spacingM = 16.0;   // 2x
const double spacingL = 24.0;   // 3x
const double spacingXL = 32.0;  // 4x
const double spacingXXL = 48.0; // 6x
```

### Component Standards

**Card Components:**
- Consistent elevation and border radius
- Standard padding and margin
- Appropriate content density

**Button Patterns:**
- ElevatedButton: Primary actions
- OutlinedButton: Secondary actions
- TextButton: Tertiary actions
- IconButton: Icon-only actions

**Form Components:**
- Consistent validation and error display
- Standard input field styling
- Accessible labels and hints

**List Components:**
- Consistent item height and padding
- Standard dividers and separators
- Appropriate touch targets (48dp minimum)

**Card Interaction Standards:**
- All interactive cards must use `CardInteractionIndicator` widget
- Consistent messaging: "Hold or right-click to [action]"
- Universal support for both desktop (right-click) and mobile (long press)
- Platform-optimized tooltips:
  - Desktop: Show on hover
  - Mobile: Show on tap for better UX (separate from long press action)
- Standard `touch_app_rounded` icon with consistent styling

**Haptic Feedback Standards:**
- Card long press: `HapticFeedback.mediumImpact()` - Substantial feedback for modal/expansion actions
- Switch toggles: `HapticFeedback.lightImpact()` - Light feedback for binary state changes
- Scene selection: `HapticFeedback.selectionClick()` - Precise feedback for selections
- Slider min/max toggle: `HapticFeedback.mediumImpact()` - Clear feedback for significant value jumps

```dart
// Standard pattern for interactive cards
CardInteractionIndicator(
  customTooltip: 'Hold or right-click to view details', // Action-specific message
),

// Usage in GestureDetector
GestureDetector(
  onSecondaryTap: onExpand, // Right click for desktop
  onLongPress: onExpand,    // Long press for mobile
  child: cardContent,
)
```

**Device Metadata Integration:**
- Uses Node.js script with zigbee-herdsman-converters v25.5.0 for enhanced metadata
- Go backend executes Node script via command-line interface
- Results cached for 24 hours to improve performance
- Provides rich device definitions, exposes metadata, and configuration options

```go
// Get enhanced metadata for a device
metadataService := utils.NewDeviceMetadataService()
metadata, err := metadataService.GetDeviceMetadata(modelID, manufacturerName)
if err != nil {
    // Handle error
}
// Use metadata.Exposes for rich control information
```

**Device Specifications API Endpoints:**
- `GET /api/manage/device-specs?model_id=X&manufacturer=Y` - Get device specifications
- `GET /api/manage/device-specs/model/{model}` - Get specifications by model ID  
- `POST /api/manage/device-specs/identify` - Identify device and get specifications
- `GET /api/manage/device-specs/version` - Get zigbee-herdsman-converters version info
- `POST /api/manage/device-specs/cache/clear` - Clear specifications cache
- `GET /api/manage/devices` - Get all devices from local storage with their specifications

**Device Metadata API Endpoints:**
- `GET /api/manage/device/{device}/metadata` - Get device metadata (custom names, categories)
- `PUT /api/manage/device/{device}/custom_name` - Set device custom name
- `PUT /api/manage/device/{device}/custom_category` - Set device custom category
- `GET /api/manage/device_categories` - Get all available device categories

---

## API Design

### REST API Conventions

**URL Structure:**
```
GET    /manage/zones                    # List all zones
POST   /manage/zones                    # Create new zone
GET    /manage/zones/{zone}            # Get specific zone
PUT    /manage/zones/{zone}            # Update zone
DELETE /manage/zones/{zone}            # Delete zone

GET    /manage/zones/{zone}/devices    # Get devices in zone
POST   /manage/zones/{zone}/devices    # Add device to zone
```

**Request/Response Format:**
```json
// Success Response
{
  "data": {
    "id": "zone_001",
    "name": "Living Room",
    "devices": ["device_001", "device_002"]
  },
  "meta": {
    "timestamp": "2023-12-07T10:30:00Z",
    "version": "1.0"
  }
}

// Error Response
{
  "error": {
    "type": "validation",
    "message": "Invalid zone name",
    "code": "ZONE_001",
    "details": {
      "field": "name",
      "reason": "Zone name already exists"
    }
  }
}
```

**HTTP Status Codes:**
- 200: Success with content
- 201: Created successfully
- 204: Success without content
- 400: Bad request (validation error)
- 401: Unauthorized
- 403: Forbidden
- 404: Not found
- 409: Conflict
- 500: Internal server error

### WebSocket API

**Real-time Events:**
```json
// Device state update
{
  "type": "device_update",
  "device_name": "living_room_light",
  "state": {
    "brightness": 75,
    "color_temp": 400
  },
  "timestamp": "2023-12-07T10:30:00Z"
}

// System status update
{
  "type": "system_status",
  "status": "online",
  "connected_devices": 15,
  "timestamp": "2023-12-07T10:30:00Z"
}
```

---

## Voice Processing System

### Voice Command Processing Pipeline

**Complete Voice Recognition Flow:**
```
Audio Input → Wake Word Detection → Speech-to-Text → Intent Processing → Device Commands → MQTT Execution
```

**Core Components:**

**1. Voice Intent Generator (`/server/storage/voice_intent_generator.go`)**
- Generates comprehensive device command mappings from Zigbee2MQTT data
- Exports current device states alongside properties for context-aware commands
- Creates device categories with natural language synonyms (lights, lamps, bulbs)
- Builds command-to-value mappings for direct device control
- Supports zones and custom device names for natural language targeting

```go
type Device struct {
    FriendlyName   string            `json:"friendly_name"`
    IEEEAddress    string            `json:"ieee_address"`
    CustomName     string            `json:"custom_name,omitempty"`
    Categories     []string          `json:"categories"`      // Natural language categories
    Zones          []string          `json:"zones"`
    Properties     []DeviceProperty  `json:"properties"`
    VoicePatterns  []string          `json:"voice_patterns"`
}

type DeviceProperty struct {
    Name         string                 `json:"name"`
    Commands     map[string]interface{} `json:"commands"`  // Command phrase → target value
    CurrentValue interface{}            `json:"current_value,omitempty"`
}
```

**2. Voice Command Processor (`/server/assets/voice/intent.py`)**
- Priority-based device filtering: name > category > zone
- Direct command-to-value mapping using JSON structure
- Normalized text processing with filler word removal
- Support for general commands (affects all lights/switches)
- Returns structured device commands with IEEE addresses

```python
def find_devices(self, text: str) -> List[Dict]:
    # 1. Try specific device names first (highest priority)
    # 2. Try device categories (lights, switches, etc.)
    # 3. Try zone-based targeting (living room, bedroom)
    # 4. General commands for all controllable devices

def process_command(self, text: str) -> Dict:
    return {
        'success': True,
        'input': text,
        'normalized': normalized_text,
        'commands': [
            {
                'ieee_address': '0x001788010c7caac9',
                'property': 'state',
                'value': 'ON',
                'command': 'turn on'
            }
        ]
    }
```

**3. Voice Service Management (`/server/services/voice_service.go`)**
- High-level voice service lifecycle management
- Configuration updates with automatic restart
- WebSocket event broadcasting for real-time updates
- Device command execution via MQTT
- Voice command history tracking

**4. Voice Background Processing (`/server/services/voice_background.go`)**
- Background voice processing worker
- Integration with Python intent processor
- Enhanced logging with device command details
- Graceful audio device failure handling (non-fatal)
- Supports running without audio devices (e.g., in Docker containers)
- Error callbacks for voice service events

### Voice Intent Data Structure

**Generated Intent Structure (`intents.json`):**
```json
{
  "devices": [
    {
      "friendly_name": "0x001788010c7caac9",
      "ieee_address": "0x001788010c7caac9",
      "custom_name": "Right Lamp",
      "categories": ["light", "lamp", "bulb"],
      "zones": ["living_room"],
      "properties": [
        {
          "name": "state",
          "commands": {
            "turn on": "ON",
            "turn off": "OFF",
            "toggle": "TOGGLE"
          },
          "current_value": "ON"
        },
        {
          "name": "brightness",
          "commands": {
            "brighter": 254,
            "dimmer": 203.2,
            "max": 254,
            "minimum": 0
          },
          "current_value": 254
        }
      ]
    }
  ],
  "zones": {
    "living_room": ["Right Lamp", "Left Lamp"]
  }
}
```

### Voice Processing Types

**Voice Command Flow (`/server/types/voice_types.go`):**
```go
type IntentResult struct {
    Success    bool            `json:"success"`
    Input      string          `json:"input"`
    Normalized string          `json:"normalized,omitempty"`
    Commands   []DeviceCommand `json:"commands,omitempty"`
    Error      string          `json:"error,omitempty"`
}

type DeviceCommand struct {
    IEEEAddress  string      `json:"ieee_address"`
    FriendlyName string      `json:"friendly_name"`
    CustomName   string      `json:"custom_name"`
    Property     string      `json:"property"`
    Value        interface{} `json:"value"`
    Command      string      `json:"command"`
}
```

### Voice Processing Features

**Device Targeting Strategies:**
- **Direct Device Names**: "Turn on right lamp" → Targets specific device
- **Category-based**: "Turn off lights" → All light-category devices
- **Zone-based**: "Dim living room" → All devices in living room zone
- **General Commands**: "Turn everything off" → All controllable devices

**Command Processing Features:**
- **Current State Awareness**: Commands consider current device values
- **Computed Values**: Direct value calculation instead of relative changes
- **Min/Max Support**: "Set brightness to minimum/maximum"
- **Percentage Handling**: "Set brightness to 50%" → Calculated absolute value
- **Natural Language**: Support for synonyms and varied phrasing

**Error Handling and Recovery:**
- **Device Not Found**: Clear error messages with suggestions
- **Invalid Commands**: Property validation with supported actions
- **Connection Issues**: Graceful degradation with retry logic
- **History Tracking**: All commands logged with success/failure status

---

## Device Management

### Device Lifecycle Operations

**Device Deletion (`/server/manage/device.go`, `/client/lib/zigbee-device.dart`):**
```go
// Backend: Complete device removal
func API_DeleteDevice(w http.ResponseWriter, r *http.Request) {
    deviceName, err := errors.GetPathParam(r, "device_name")
    if err != nil {
        errorHandler.HandleError(w, r, err, "extract_device_name")
        return
    }

    // Remove from storage, cache, zones, and metadata
    // Send MQTT command to Zigbee2MQTT to forget device
    if err := container.DeviceService.DeleteDevice(deviceName); err != nil {
        errorHandler.HandleError(w, r, err, "delete_device")
        return
    }

    http.WriteJSON(w, map[string]string{"status": "deleted"})
}
```

```dart
// Frontend: User confirmation and navigation
Future<void> _deleteDevice() async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete Device'),
      content: Text('Are you sure? This action cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete')),
      ],
    ),
  );

  if (confirmed == true) {
    try {
      await zigbeeService.deleteDevice(widget.device.name);
      Navigator.pop(context); // Return to device list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete device: $e')),
      );
    }
  }
}
```

**Device Operations:**
- **Complete Removal**: Device deleted from storage, cache, zones, and metadata
- **MQTT Integration**: Zigbee2MQTT device forgetting via MQTT commands  
- **User Confirmation**: Confirmation dialog with error handling
- **Navigation Flow**: Automatic return to device list after successful deletion

### Zigbee2MQTT Device Synchronization

**Intelligent Device Merging (`/server/zigbee2mqtt/index.go`):**
- **Preserve Metadata**: Keep user customizations during Zigbee2MQTT restarts
- **Smart Merging**: Update Zigbee devices while preserving non-Zigbee devices
- **Stale Device Cleanup**: Remove devices no longer in Zigbee2MQTT broadcasts
- **Configuration Retention**: Maintain zone assignments, names, and categories
- **Comprehensive Logging**: Detailed merge operation tracking

---

## Configuration Management

### Environment-Based Configuration

**Configuration Hierarchy:**
1. Default values (hardcoded)
2. Configuration file (sumika.json)
3. Environment variables (highest priority)

**Configuration Categories:**
```go
type Config struct {
    Server    ServerConfig    `json:"server"`
    Logging   LoggingConfig   `json:"logging"`
    Database  DatabaseConfig  `json:"database"`
    API       APIConfig       `json:"api"`
    WebSocket WebSocketConfig `json:"websocket"`
    Zigbee    ZigbeeConfig    `json:"zigbee"`
    Debug     DebugConfig     `json:"debug"`
}
```

**Environment Variables:**
```bash
# Server configuration
SUMIKA_HOST=localhost
SUMIKA_PORT=8080
SUMIKA_CORS_ENABLED=true

# Logging configuration
SUMIKA_LOG_LEVEL=INFO
SUMIKA_LOG_FILE=./logs/sumika.log
SUMIKA_STRUCTURED_LOGS=true

# Database configuration
SUMIKA_DATA_DIR=./data
SUMIKA_BACKUP_DIR=./backups

# MQTT configuration
SUMIKA_MQTT_BROKER=localhost
SUMIKA_MQTT_PORT=1883
SUMIKA_MQTT_USER=sumika
SUMIKA_MQTT_PASSWORD=secret

# Debug configuration
SUMIKA_DEBUG=false
SUMIKA_SHOW_INTERNAL_ERRORS=false
```

### Settings Management

**Frontend Settings Handling (`/client/lib/system_settings.dart`):**
```dart
// Clear app state on server URL changes
void _onServerConfigChanged() {
  // Clear cached data to prevent stale state
  ref.invalidate(deviceNotifierProvider);
  ref.invalidate(zoneNotifierProvider);
  
  // Navigate home for fresh start
  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
}
```

**Settings UX Patterns:**
- **Persistent Access**: Settings gear icon available in loading and error states
- **State Management**: Clear app state when configuration changes
- **Navigation Flow**: Return to home screen after server config changes
- **Data Consistency**: Invalidate providers to prevent stale data

---

## Testing Strategy

### Backend Testing

**Unit Tests:**
- Service layer business logic
- Repository implementations
- Error handling scenarios
- Configuration validation

**Integration Tests:**
- API endpoint functionality
- Database operations
- WebSocket communication
- External service integration

**Test Structure:**
```go
func TestZoneService_CreateZone(t *testing.T) {
    // Arrange
    mockRepo := &MockZoneRepository{}
    service := NewZoneService(mockRepo)
    
    // Act
    zone, err := service.CreateZone("Living Room")
    
    // Assert
    assert.NoError(t, err)
    assert.Equal(t, "Living Room", zone.Name)
    mockRepo.AssertCalled(t, "Save", mock.Anything)
}
```

### Frontend Testing

**Widget Tests:**
- Component behavior and rendering
- State management integration
- Error handling scenarios
- User interaction flows

**Unit Tests:**
- Service layer functionality
- State notifier logic
- Utility functions
- Error handling

**Integration Tests:**
- End-to-end user flows
- API communication
- Real-time updates
- Error recovery

---

## Security Considerations

### Backend Security

**Input Validation:**
- All user input validated at service layer
- SQL injection prevention (though we use JSON files)
- XSS prevention in API responses
- File path validation for storage operations

**Error Handling Security:**
- Internal error details not exposed to clients
- Stack traces only in debug mode
- Structured error responses without sensitive data
- Request ID tracking for audit trails

**Configuration Security:**
- Sensitive values via environment variables
- No secrets in configuration files
- Secure default configurations
- Runtime configuration validation

### Frontend Security

**Data Handling:**
- Input sanitization for user data
- Secure storage of sensitive information
- Proper error message handling
- Network request validation

**UI Security:**
- User permission checks before actions
- Proper loading states to prevent race conditions
- Secure WebSocket communication
- Error message sanitization

---

## Performance Guidelines

### Backend Performance

**Database Operations:**
- Atomic file operations for data integrity
- Lazy loading for large datasets
- Efficient JSON parsing and serialization
- Background cleanup and maintenance

**Memory Management:**
- Efficient data structures for device state
- Garbage collection optimization
- Connection pooling for external services
- Resource cleanup in error scenarios

**Concurrency:**
- Thread-safe operations for shared state
- Efficient WebSocket connection management
- Proper context cancellation
- Deadlock prevention

### Frontend Performance

**State Management:**
- Efficient state updates with minimal rebuilds
- Optimistic updates for immediate feedback
- Smart caching with cache invalidation
- Background data synchronization

**UI Performance:**
- Lazy loading for large lists
- Efficient widget rebuilds
- Image caching and optimization
- Smooth animations and transitions

**Network Performance:**
- Request batching where appropriate
- Efficient WebSocket usage
- Proper timeout handling
- Connection pooling

---

## Deployment & Operations

### Build Process

**Backend Build:**
```bash
# Development build
go build -o sumika ./server

# Production build with optimization
go build -ldflags="-w -s" -o sumika ./server

# Cross-platform builds
GOOS=linux GOARCH=amd64 go build -o sumika-linux ./server
GOOS=windows GOARCH=amd64 go build -o sumika.exe ./server
```

**Frontend Build:**
```bash
# Development build
flutter run

# Production build
flutter build apk --release
flutter build ios --release
flutter build web --release
```

### Configuration Management

**Development Environment:**
```json
{
  "server": {
    "host": "localhost",
    "port": 8080
  },
  "logging": {
    "level": "DEBUG",
    "console_output": true,
    "color_output": true
  },
  "debug": {
    "enabled": true,
    "show_internal_errors": true
  }
}
```

**Production Environment:**
```bash
export SUMIKA_HOST=0.0.0.0
export SUMIKA_PORT=80
export SUMIKA_LOG_LEVEL=INFO
export SUMIKA_DEBUG=false
export SUMIKA_DATA_DIR=/var/lib/sumika
export SUMIKA_BACKUP_DIR=/var/backups/sumika
```

### Monitoring and Observability

**Logging:**
- Structured logs with JSON format
- Log aggregation and analysis
- Error tracking and alerting
- Performance monitoring

**Metrics:**
- Request/response times
- Error rates by endpoint
- WebSocket connection counts
- Device state update frequency

**Health Checks:**
- API endpoint availability
- Database connectivity
- External service status
- WebSocket functionality

---

## Conclusion

This development guide establishes the foundation for consistent, maintainable, and scalable development of the Sumika smart home platform. By following these patterns and principles, developers can:

1. **Avoid Duplication**: Use existing patterns and utilities
2. **Maintain Consistency**: Follow established architectural decisions
3. **Ensure Quality**: Implement robust error handling and logging
4. **Scale Effectively**: Build on solid architectural foundations
5. **Debug Efficiently**: Leverage structured logging and error handling

**Key Takeaways:**
- Always search for existing patterns before creating new ones
- Use the established base classes and utilities
- Follow the error handling and logging patterns
- Maintain consistency in naming and structure
- Prioritize code quality and maintainability

**Before Writing New Code:**
1. Read the relevant sections of this guide
2. Check existing similar implementations
3. Use established patterns and base classes
4. Follow error handling and logging conventions
5. Ensure consistency with existing code style

This guide should be updated as new patterns emerge and architectural decisions are made, ensuring it remains the single source of truth for development practices.