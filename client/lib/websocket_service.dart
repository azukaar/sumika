import 'dart:convert';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import './types.dart';
import 'api_config.dart';

/// Connection states for the WebSocket
enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

/// WebSocket service for real-time device updates with improved reliability
class WebSocketService {
  static Future<String> get wsUrl => ApiConfig.wsUrl;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _connectionTimeoutTimer;
  
  WebSocketConnectionState _connectionState = WebSocketConnectionState.disconnected;
  int _reconnectAttempts = 0;
  
  // Configuration constants
  static const int _maxReconnectAttempts = 5;
  static const Duration _initialReconnectDelay = Duration(seconds: 2);
  static const Duration _connectionTimeout = Duration(seconds: 10);
  static const Duration _maxReconnectDelay = Duration(seconds: 30);

  // Stream controllers
  final StreamController<DeviceUpdate> _deviceUpdateController =
      StreamController<DeviceUpdate>.broadcast();
  final StreamController<WebSocketConnectionState> _connectionStateController =
      StreamController<WebSocketConnectionState>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  // Public getters
  Stream<DeviceUpdate> get deviceUpdates => _deviceUpdateController.stream;
  Stream<WebSocketConnectionState> get connectionState => _connectionStateController.stream;
  Stream<String> get errors => _errorController.stream;
  WebSocketConnectionState get currentState => _connectionState;
  bool get isConnected => _connectionState == WebSocketConnectionState.connected;

  /// Connect to WebSocket server with proper state management
  Future<void> connect() async {
    if (_connectionState == WebSocketConnectionState.connecting ||
        _connectionState == WebSocketConnectionState.connected) {
      _log('Already connected or connecting, ignoring connect request');
      return;
    }

    _updateConnectionState(WebSocketConnectionState.connecting);
    _cancelTimers();

    try {
      final url = await wsUrl;
      _log('Attempting to connect to: $url');

      _channel = WebSocketChannel.connect(
        Uri.parse(url),
        protocols: ['websocket'], // Specify protocol for better compatibility
      );

      // Set up connection timeout
      _connectionTimeoutTimer = Timer(_connectionTimeout, () {
        if (_connectionState == WebSocketConnectionState.connecting) {
          _log('Connection timeout');
          _handleConnectionFailure('Connection timeout');
        }
      });

      // Listen for messages
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: false, // Keep trying to receive messages
      );

      // Don't set as connected immediately - wait for first successful message
      // or implement a ping/pong mechanism
      _log('WebSocket stream listener established');

    } catch (e) {
      _log('Connection failed: $e');
      _handleConnectionFailure('Connection failed: $e');
    }
  }

  /// Handle incoming WebSocket messages with better error handling
  void _handleMessage(dynamic message) {
    try {
      // Cancel connection timeout on first successful message
      if (_connectionState == WebSocketConnectionState.connecting) {
        _connectionTimeoutTimer?.cancel();
        _updateConnectionState(WebSocketConnectionState.connected);
        _reconnectAttempts = 0;
        _log('WebSocket connection established');
      }

      final data = _parseMessage(message);
      if (data != null) {
        _handleParsedMessage(data);
      }
    } catch (e) {
      _log('Error handling message: $e');
      _errorController.add('Message handling error: $e');
    }
  }

  /// Parse incoming message with proper error handling
  Map<String, dynamic>? _parseMessage(dynamic message) {
    try {
      if (message is String) {
        return json.decode(message) as Map<String, dynamic>;
      } else {
        _log('Received non-string message: ${message.runtimeType}');
        return null;
      }
    } catch (e) {
      _log('Failed to parse JSON message: $e');
      _errorController.add('JSON parsing error: $e');
      return null;
    }
  }

  /// Handle parsed message based on type
  void _handleParsedMessage(Map<String, dynamic> data) {
    final messageType = data['type'] as String?;
    
    switch (messageType) {
      case 'device_update':
        _handleDeviceUpdate(data);
        break;
      case 'ping':
        _handlePing(data);
        break;
      case 'pong':
        _handlePong(data);
        break;
      default:
        _log('Unknown message type: $messageType');
    }
  }

  /// Handle device update messages
  void _handleDeviceUpdate(Map<String, dynamic> data) {
    try {
      final update = DeviceUpdate.fromJson(data);
      _deviceUpdateController.add(update);
      _log('Device update processed for: ${update.deviceName}');
    } catch (e) {
      _log('Failed to create DeviceUpdate from JSON: $e');
      _errorController.add('DeviceUpdate parsing error: $e');
    }
  }

  /// Handle ping messages (respond with pong)
  void _handlePing(Map<String, dynamic> data) {
    _log('Received ping, sending pong');
    _sendMessage({'type': 'pong', 'timestamp': DateTime.now().millisecondsSinceEpoch});
  }

  /// Handle pong messages
  void _handlePong(Map<String, dynamic> data) {
    _log('Received pong');
  }

  /// Send message to server if connected
  void _sendMessage(Map<String, dynamic> message) {
    if (_channel?.sink != null && isConnected) {
      try {
        final jsonMessage = json.encode(message);
        _channel!.sink.add(jsonMessage);
      } catch (e) {
        _log('Failed to send message: $e');
        _errorController.add('Failed to send message: $e');
      }
    }
  }

  /// Handle WebSocket errors
  void _handleError(dynamic error) {
    _log('WebSocket error: $error');
    _handleConnectionFailure('WebSocket error: $error');
  }

  /// Handle WebSocket disconnection
  void _handleDisconnect() {
    _log('WebSocket disconnected');
    if (_connectionState != WebSocketConnectionState.disconnected) {
      _updateConnectionState(WebSocketConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  /// Handle connection failures with proper cleanup
  void _handleConnectionFailure(String reason) {
    _log('Connection failure: $reason');
    _errorController.add(reason);
    _updateConnectionState(WebSocketConnectionState.failed);
    _cleanup(closeControllers: false);
    _scheduleReconnect();
  }

  /// Schedule reconnection with exponential backoff
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _log('Max reconnect attempts reached, will retry after longer delay');
      _updateConnectionState(WebSocketConnectionState.failed);
      
      // Instead of giving up permanently, schedule a retry after a longer delay
      _reconnectTimer = Timer(const Duration(minutes: 2), () {
        _log('Retrying connection after extended delay');
        _reconnectAttempts = 0; // Reset attempts for fresh start
        if (_connectionState != WebSocketConnectionState.connected) {
          connect();
        }
      });
      return;
    }

    _reconnectAttempts++;
    _updateConnectionState(WebSocketConnectionState.reconnecting);

    // Exponential backoff: 2s, 4s, 8s, 16s, 30s (capped)
    final delay = Duration(
      milliseconds: (_initialReconnectDelay.inMilliseconds * 
                    (1 << (_reconnectAttempts - 1))).clamp(
                      _initialReconnectDelay.inMilliseconds,
                      _maxReconnectDelay.inMilliseconds
                    )
    );

    _log('Scheduling reconnect attempt $_reconnectAttempts in ${delay.inSeconds}s');

    _reconnectTimer = Timer(delay, () {
      if (_connectionState != WebSocketConnectionState.connected) {
        connect();
      }
    });
  }

  /// Update connection state and notify listeners
  void _updateConnectionState(WebSocketConnectionState newState) {
    if (_connectionState != newState) {
      _connectionState = newState;
      _connectionStateController.add(newState);
      _log('Connection state changed to: $newState');
    }
  }

  /// Cancel all active timers
  void _cancelTimers() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = null;
  }

  /// Disconnect from WebSocket
  void disconnect() {
    _log('Disconnecting WebSocket');
    _updateConnectionState(WebSocketConnectionState.disconnected);
    _cleanup(closeControllers: false);
  }

  /// Clean up resources
  void _cleanup({bool closeControllers = true}) {
    _cancelTimers();
    
    _subscription?.cancel();
    _subscription = null;

    if (_channel != null) {
      try {
        _channel!.sink.close(status.normalClosure);
      } catch (e) {
        _log('Error closing WebSocket channel: $e');
      }
      _channel = null;
    }

    if (closeControllers) {
      _deviceUpdateController.close();
      _connectionStateController.close();
      _errorController.close();
    }
  }

  /// Dispose of the service
  void dispose() {
    _log('Disposing WebSocket service');
    disconnect();
    _cleanup(closeControllers: true);
  }

  /// Reset connection attempts (useful for manual retry)
  void resetReconnectAttempts() {
    _reconnectAttempts = 0;
    _log('Reconnect attempts reset');
  }

  /// Force reconnection
  void forceReconnect() {
    _log('Force reconnecting...');
    disconnect();
    Timer(const Duration(milliseconds: 100), () => connect());
  }

  /// Restart connection attempts (useful when user manually retries)
  void restartConnection() {
    _log('Restarting connection attempts...');
    _cancelTimers();
    _reconnectAttempts = 0;
    
    // If currently failed, try connecting immediately
    if (_connectionState == WebSocketConnectionState.failed ||
        _connectionState == WebSocketConnectionState.disconnected) {
      connect();
    }
  }

  /// Log messages with proper formatting
  void _log(String message) {
    developer.log(
      message,
      name: 'WebSocketService',
      time: DateTime.now(),
    );
  }
}

/// Enhanced device update model
class DeviceUpdate {
  final String type;
  final String deviceName;
  final Map<String, dynamic> state;
  final String timestamp;

  DeviceUpdate({
    required this.type,
    required this.deviceName,
    required this.state,
    required this.timestamp,
  });

  factory DeviceUpdate.fromJson(Map<String, dynamic> json) {
    // Validate required fields
    if (!json.containsKey('type') || !json.containsKey('device_name')) {
      throw FormatException('Missing required fields in DeviceUpdate JSON');
    }

    return DeviceUpdate(
      type: json['type'] as String,
      deviceName: json['device_name'] as String,
      state: Map<String, dynamic>.from(json['state'] as Map? ?? {}),
      timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'device_name': deviceName,
      'state': state,
      'timestamp': timestamp,
    };
  }

  @override
  String toString() {
    return 'DeviceUpdate(type: $type, deviceName: $deviceName, timestamp: $timestamp)';
  }
}

/// Singleton provider for WebSocket service
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for WebSocket connection state
final webSocketConnectionStateProvider = StreamProvider<WebSocketConnectionState>((ref) {
  final service = ref.watch(webSocketServiceProvider);
  return service.connectionState;
});

/// Provider for real-time device updates
final deviceUpdatesProvider = StreamProvider<DeviceUpdate>((ref) {
  final service = ref.watch(webSocketServiceProvider);
  return service.deviceUpdates;
});

/// Provider for WebSocket errors
final webSocketErrorsProvider = StreamProvider<String>((ref) {
  final service = ref.watch(webSocketServiceProvider);
  return service.errors;
});