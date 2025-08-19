
### Backend - Duplicated messages on external broker
**Problem**: When using the internal broker, all is well, but when using any external broker, messages are being duplicated. It is NOT a timing issue with duplication, the button press message specifically always comes twice

**warning**
- [ ] DO NOT fix this by modifying the broker's config 
- [ ] DO NOT fix this by deduplicating messages in the application code

**Tasks**
- [ ] Investigate message handling logic in the external broker integration in a broad sense to understand what could be causing this
- [ ] Implement fix for specific and consistent message duplication

### Frontend - Websocket issue
**Problem**: Websocket connection drops intermittently, unable to reconnect
**Files**: Websocket service files with logs:

[WEBSOCKET] Connection status changed: WebSocketConnectionState.failed
[WEBSOCKET] Connection status changed: WebSocketConnectionState.reconnecting
[WEBSOCKET] Connection status changed: WebSocketConnectionState.connecting
[WEBSOCKET] Connection status changed: WebSocketConnectionState.failed
[WEBSOCKET] Connection status changed: WebSocketConnectionState.reconnecting
[WEBSOCKET] Connection status changed: WebSocketConnectionState.connecting
[WEBSOCKET] Connection status changed: WebSocketConnectionState.failed

**Tasks**
- [ ] Review websocket service implementation
- [ ] Implement fix for reconnection

### Frontend - Widget Organization
**Problem**: Inconsistent widget structure and naming
**Files**: Widget files throughout

**Tasks**:
- [ ] Establish consistent widget naming conventions
- [ ] Create widget organization standards
- [ ] Implement consistent prop passing patterns
- [ ] Add proper widget documentation

## 🧹 Code Cleanup (Low Priority)

### Remove Development Artifacts
**Tasks**:
- [ ] Remove debug print statements throughout codebase
- [ ] Clean up commented-out code
- [ ] Remove unused imports and variables
- [ ] Standardize code formatting

## 📊 Validation Improvements (Medium Priority)

### Backend - Input Validation
**Problem**: Limited validation on API inputs
**Files**: API handlers

**Tasks**:
- [ ] Create validation middleware
- [ ] Add input sanitization for all user inputs
- [ ] Implement proper data type validation
- [ ] Add business rule validation

### Frontend - Form Validation
**Problem**: Inconsistent form validation patterns
**Files**: Form widgets

**Tasks**:
- [ ] Create reusable form validation utilities
- [ ] Implement consistent error display patterns
- [ ] Add real-time validation feedback
- [ ] Standardize form submission handling
