import 'dart:convert';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import './types.dart';
import 'api_config.dart';

// WebSocket service for real-time device updates
class WebSocketService {
  static Future<String> get wsUrl => ApiConfig.wsUrl;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);

  // Stream controller for device updates
  final StreamController<DeviceUpdate> _deviceUpdateController =
      StreamController<DeviceUpdate>.broadcast();

  // Stream controller for connection status
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();

  Stream<DeviceUpdate> get deviceUpdates => _deviceUpdateController.stream;
  Stream<bool> get connectionStatus => _connectionStatusController.stream;
  bool get isConnected => _isConnected;

  // Connect to WebSocket server
  Future<void> connect() async {
    if (_isConnected || _channel != null) {
      return; // Already connected or connecting
    }

    try {
      final url = await wsUrl;
      _channel = WebSocketChannel.connect(Uri.parse(url));

      // Listen for messages
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      _isConnected = true;
      _reconnectAttempts = 0;
      _connectionStatusController.add(true);
    } catch (e) {
      print('[WEBSOCKET] Connection failed: $e');
      _handleConnectionFailure();
    }
  }

  // Handle incoming WebSocket messages
  void _handleMessage(dynamic message) {
    try {
      final data = json.decode(message as String);

      if (data['type'] == 'device_update') {
        final update = DeviceUpdate.fromJson(data);
        _deviceUpdateController.add(update);
      }
    } catch (e) {
      print('[WEBSOCKET] Error parsing message: $e');
    }
  }

  // Handle WebSocket errors
  void _handleError(error) {
    print('[WEBSOCKET] Error: $error');
    _handleConnectionFailure();
  }

  // Handle WebSocket disconnection
  void _handleDisconnect() {
    _isConnected = false;
    _connectionStatusController.add(false);

    if (_shouldReconnect) {
      _scheduleReconnect();
    }
  }

  // Handle connection failures
  void _handleConnectionFailure() {
    _isConnected = false;
    _connectionStatusController.add(false);
    _cleanup();

    if (_shouldReconnect) {
      _scheduleReconnect();
    }
  }

  // Schedule reconnection attempt
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      return;
    }

    _reconnectAttempts++;

    _reconnectTimer = Timer(_reconnectDelay, () {
      if (_shouldReconnect) {
        connect();
      }
    });
  }

  // Disconnect from WebSocket
  void disconnect() {
    _shouldReconnect = false;
    _cleanup();
  }

  // Clean up resources
  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;

    _channel?.sink.close(status.normalClosure);
    _channel = null;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _isConnected = false;
  }

  // Dispose of the service
  void dispose() {
    disconnect();
    _deviceUpdateController.close();
    _connectionStatusController.close();
  }
}

// Device update model for WebSocket messages
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
    return DeviceUpdate(
      type: json['type'] as String,
      deviceName: json['device_name'] as String,
      state: Map<String, dynamic>.from(json['state'] as Map),
      timestamp: json['timestamp'] as String,
    );
  }
}

// Provider for WebSocket service
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

// Provider for WebSocket connection status
final webSocketConnectionProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(webSocketServiceProvider);
  return service.connectionStatus;
});

// Provider for real-time device updates
final deviceUpdatesProvider = StreamProvider<DeviceUpdate>((ref) {
  final service = ref.watch(webSocketServiceProvider);
  return service.deviceUpdates;
});
