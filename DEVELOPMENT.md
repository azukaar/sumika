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
- Middleware-based architecture for cross-cutting concerns

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

**1. HTTP Layer (`/server/manage/*_api.go`, `/server/zigbee2mqtt/API.go`)**
- Thin HTTP handlers focused on request/response transformation
- Input validation and parameter extraction
- Error handling and response formatting
- No business logic - delegates to service layer

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
│   └── config.go                 # Centralized configuration management
├── errors/
│   ├── types.go                  # Structured error types and factories
│   ├── middleware.go             # Error handling middleware
│   └── helpers.go                # Validation and parsing helpers
├── http/
│   ├── response.go               # HTTP response utilities
│   └── params.go                 # URL parameter extraction
├── manage/
│   ├── zones_api.go              # Zone management endpoints
│   ├── automations_api.go        # Automation CRUD operations
│   ├── device_metadata_api.go    # Device metadata management
│   └── scene_management_api.go   # Scene operations
├── services/
│   ├── container.go              # Dependency injection container
│   ├── zone_service.go           # Zone business logic
│   ├── automation_service.go     # Automation business logic
│   └── device_service.go         # Device metadata business logic
├── storage/
│   ├── interfaces.go             # Repository interfaces
│   ├── json_datastore.go         # JSON file storage implementation
│   └── types.go                  # Storage data types
├── utils/
│   ├── log.go                    # Basic logging infrastructure
│   └── structured_log.go         # Structured logging with context
├── realtime/
│   └── websocket.go              # WebSocket real-time communication
└── zigbee2mqtt/
    └── API.go                    # Zigbee device communication
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

**Error Recovery:**
- Automatic retry for network errors
- Rollback for optimistic updates that fail
- User-initiated retry with progress indication
- Graceful degradation for non-critical features

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

**WebSocket Integration:**
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

**Update Strategies:**
- **Optimistic Updates**: Immediate UI feedback with rollback on error
- **Real-time Sync**: WebSocket updates for live device state
- **Periodic Refresh**: Background polling for data consistency
- **Cache Invalidation**: Smart refresh based on operation types

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