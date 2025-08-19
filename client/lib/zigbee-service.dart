// zigbee_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import './types.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show rootBundle;
import './websocket_service.dart';
import 'api_config.dart';

class ZigbeeService {
  static Future<String> get baseZigbeeUrl => ApiConfig.zigbeeApiUrl;
  static Future<String> get baseUrl => ApiConfig.apiBaseUrl;
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, Map<String, dynamic>> _debounceUpdates = {};

  Future<List<Device>> fetchDevices() async {
    try {
      final url = await baseZigbeeUrl;
      final response = await http.get(Uri.parse('$url/list_devices'));

      if (response.statusCode == 200) {
        if (response.body == 'null') {
          return [];
        }
        List<dynamic> jsonList = jsonDecode(response.body) as List<dynamic>;
        return jsonList.map((json) => Device.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load devices: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('Error fetching devices: $e\n$stackTrace');
      throw Exception('Error fetching devices: $e');
    }
  }

  Future<void> pair(String deviceId, String state) async {
    try {
      final url = await baseZigbeeUrl;
      final response = await http.get(
        Uri.parse('$url/allow_join'),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to set device state: ${response.statusCode}');
      }
    } catch (e) {
      print('Error setting device state: $e');
      throw Exception('Error setting device state: $e');
    }
  }

  Future<void> setDeviceZones(String deviceId, List<String> zones) async {
    try {
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse(
            '$url/manage/set-zones/${Uri.encodeComponent(deviceId)}?zones=${zones.join(',')}'),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to set device zones: ${response.statusCode}');
      }
    } catch (e) {
      print('Error setting device zones: $e');
      throw Exception('Error setting device zones: $e');
    }
  }

  Future<List<String>> getDeviceZones(String deviceId) async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/manage/get-zones/${Uri.encodeComponent(deviceId)}'),
      );

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody == 'null' || responseBody.isEmpty) {
          return [];
        }
        final decoded = jsonDecode(responseBody);
        if (decoded == null) {
          return [];
        }
        List<dynamic> jsonList = decoded as List<dynamic>;
        return jsonList.cast<String>();
      } else {
        return [];
      }
    } catch (e) {
      print('Error getting device zones: $e');
      return [];
    }
  }

  Future<List<String>> getDevicesByZone(String zone) async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/manage/get-by-zone/$zone'),
      );

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody == 'null' || responseBody.isEmpty) {
          return [];
        }
        final decoded = jsonDecode(responseBody);
        if (decoded == null) {
          return [];
        }
        List<dynamic> jsonList = decoded as List<dynamic>;
        return jsonList.cast<String>();
      } else {
        return [];
      }
    } catch (e) {
      // Silently handle errors to prevent spam
      return [];
    }
  }

  Future<List<String>> getAllZones() async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/manage/zones'),
      );

      if (response.statusCode == 200) {
        List<dynamic> jsonList = jsonDecode(response.body) as List<dynamic>;
        return jsonList.cast<String>();
      } else {
        return [];
      }
    } catch (e) {
      print('Error getting all zones: $e');
      return [];
    }
  }

  Future<bool> createZone(String zoneName) async {
    try {
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/manage/zones/$zoneName'),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error creating zone: $e');
      return false;
    }
  }

  Future<bool> deleteZone(String zoneName) async {
    try {
      final url = await baseUrl;
      final response = await http.delete(
        Uri.parse('$url/manage/zones/$zoneName'),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting zone: $e');
      return false;
    }
  }

  Future<bool> renameZone(String oldName, String newName) async {
    try {
      final url = await baseUrl;
      final response = await http.put(
        Uri.parse('$url/manage/zones/$oldName/rename?new_name=$newName'),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error renaming zone: $e');
      return false;
    }
  }

  // Device metadata management functions
  Future<Map<String, String>> getDeviceMetadata(String deviceId) async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse(
            '$url/manage/device-metadata/${Uri.encodeComponent(deviceId)}'),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded == null) {
          return {};
        }
        return Map<String, String>.from(decoded);
      } else {
        return {};
      }
    } catch (e) {
      print('Error getting device metadata: $e');
      return {};
    }
  }

  Future<bool> setDeviceMetadata(
      String deviceId, String customName, String customCategory) async {
    try {
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse(
            '$url/manage/device-metadata/${Uri.encodeComponent(deviceId)}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'custom_name': customName,
          'custom_category': customCategory,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error setting device metadata: $e');
      return false;
    }
  }

  Future<void> setDeviceState(
      String deviceId, Map<String, dynamic> state) async {
    _debounceUpdates[deviceId] = state;

    if (!_debounceTimers.containsKey(deviceId)) {
      _debounceTimers[deviceId] =
          Timer(const Duration(milliseconds: 200), () async {
        try {
          var newState = jsonEncode(_debounceUpdates[deviceId]);
          final url = await baseZigbeeUrl;
          final response = await http.get(
            Uri.parse('$url/set/$deviceId?state=$newState'),
          );

          if (response.statusCode != 200) {
            throw Exception(
                'Failed to set device state: ${response.statusCode}');
          }
        } catch (e) {
          print('Error setting device state: $e');
          throw Exception('Error setting device state: $e');
        } finally {
          // Clean up the timer reference
          _debounceTimers.remove(deviceId);
          _debounceUpdates.remove(deviceId);
        }
      });
    }
  }

  // Clean up method to cancel any pending timers
  void dispose() {
    for (var timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
  }
}

// Device state notifier with real-time WebSocket updates and polling fallback
class DevicesNotifier extends StateNotifier<AsyncValue<List<Device>>> {
  final ZigbeeService _service;
  final WebSocketService _webSocketService;
  Timer? _syncTimer;
  final Duration _syncInterval = const Duration(seconds: 10);
  final Duration _fallbackSyncInterval =
      const Duration(seconds: 30); // Slower when WebSocket is connected
  final Map<String, Timer> _debounceTimers = {};
  StreamSubscription? _deviceUpdateSubscription;
  StreamSubscription? _connectionStatusSubscription;
  bool _webSocketConnected = false;

  DevicesNotifier(this._service, this._webSocketService)
      : super(const AsyncValue.loading()) {
    loadDevices();
    _initializeWebSocket();
  }

  // Initialize WebSocket connection and listeners
  void _initializeWebSocket() {
    // Connect to WebSocket
    _webSocketService.connect();

    // Listen to device updates
    _deviceUpdateSubscription = _webSocketService.deviceUpdates.listen(
      _handleDeviceUpdate,
      onError: (error) {
        print('[WEBSOCKET] Device update error: $error');
      },
    );

    // Listen to connection status
    _connectionStatusSubscription = _webSocketService.connectionState.listen(
      _handleConnectionStatusChange,
      onError: (error) {
        print('[WEBSOCKET] Connection status error: $error');
      },
    );

    // Start with polling (will be adjusted based on WebSocket status)
    _startPeriodicSync();
  }

  // Handle WebSocket connection status changes
  void _handleConnectionStatusChange(WebSocketConnectionState state) {
    _webSocketConnected = state == WebSocketConnectionState.connected;
    print('[WEBSOCKET] Connection status changed: $state');

    // Adjust sync interval based on connection status
    _syncTimer?.cancel();
    _startPeriodicSync();
  }

  // Handle real-time device updates from WebSocket
  void _handleDeviceUpdate(DeviceUpdate update) {
    print('[WEBSOCKET] Applying device update for ${update.deviceName}');

    // Apply incremental update to the current state
    state.whenData((devices) {
      final updatedDevices = devices.map<Device>((device) {
        if (device.friendlyName == update.deviceName) {
          // Merge the incremental state update
          final currentState = Map<String, dynamic>.from(device.state ?? {});

          // Apply the diff - null values mean field was removed
          update.state.forEach((key, value) {
            if (value == null) {
              currentState.remove(key);
            } else {
              currentState[key] = value;
            }
          });

          return Device(
            dateCode: device.dateCode,
            definition: device.definition,
            state: currentState,
            endpoint: device.endpoint,
            friendlyName: device.friendlyName,
            disabled: device.disabled,
            ieeeAddress: device.ieeeAddress,
            interviewCompleted: device.interviewCompleted,
            interviewing: device.interviewing,
            manufacturer: device.manufacturer,
            modelId: device.modelId,
            networkAddress: device.networkAddress,
            powerSource: device.powerSource,
            supported: device.supported,
            type: device.type,
            lastSeen: device.lastSeen,
            zones: device.zones,
          );
        }
        return device;
      }).toList();

      if (mounted) {
        state = AsyncValue.data(updatedDevices);
      }
    });
  }

  void _startPeriodicSync() {
    // Use slower polling when WebSocket is connected, faster when it's not
    final interval =
        _webSocketConnected ? _fallbackSyncInterval : _syncInterval;

    _syncTimer = Timer.periodic(interval, (timer) {
      if (mounted) {
        _syncWithServer();
      }
    });
  }

  Future<void> _syncWithServer() async {
    // Don't sync if there are pending debounced updates to avoid overriding optimistic UI
    if (_debounceTimers.isNotEmpty) {
      print('Skipping sync - pending UI updates');
      return;
    }

    try {
      final devices = await _service.fetchDevices();
      if (mounted) {
        state = AsyncValue.data(devices);
      }
    } catch (e) {
      // Silent sync failure - keep current state
      print('Background sync failed: $e');
    }
  }

  Future<void> loadDevices() async {
    try {
      state = const AsyncValue.loading();
      final devices = await _service.fetchDevices();
      if (mounted) {
        state = AsyncValue.data(devices);
      }
    } catch (e) {
      if (mounted) {
        state = AsyncValue.error(e, StackTrace.current);
      }
    }
  }

  Future<void> setDeviceState(
      String deviceId, Map<String, dynamic> stateToSet) async {
    // Determine if this is a continuous control that should be debounced
    final isContinuous = stateToSet.containsKey('brightness') ||
        stateToSet.containsKey('color_temp') ||
        stateToSet.containsKey('color');

    if (isContinuous) {
      // For continuous controls, debounce UI updates
      _debounceTimers[deviceId]?.cancel();
      _debounceTimers[deviceId] = Timer(const Duration(milliseconds: 100), () {
        _updateDeviceStateInUI(deviceId, stateToSet);
      });
    } else {
      // For discrete controls (like switches), update immediately
      _updateDeviceStateInUI(deviceId, stateToSet);
    }

    // Send to server in background (this already has its own debouncing)
    try {
      await _service.setDeviceState(deviceId, stateToSet);
    } catch (e) {
      // On error, refresh from server to get correct state
      print('Error setting device state: $e');
      _syncWithServer();
    }
  }

  void _updateDeviceStateInUI(
      String deviceId, Map<String, dynamic> stateToSet) {
    state.whenData((devices) {
      final updatedDevices = devices.map<Device>((device) {
        if (device.friendlyName == deviceId) {
          // Create updated device with new state
          final currentState = Map<String, dynamic>.from(device.state ?? {});
          currentState.addAll(stateToSet);

          return Device(
            dateCode: device.dateCode,
            definition: device.definition,
            state: currentState,
            endpoint: device.endpoint,
            friendlyName: device.friendlyName,
            disabled: device.disabled,
            ieeeAddress: device.ieeeAddress,
            interviewCompleted: device.interviewCompleted,
            interviewing: device.interviewing,
            manufacturer: device.manufacturer,
            modelId: device.modelId,
            networkAddress: device.networkAddress,
            powerSource: device.powerSource,
            supported: device.supported,
            type: device.type,
            lastSeen: device.lastSeen,
            zones: device.zones,
          );
        }
        return device;
      }).toList();

      if (mounted) {
        state = AsyncValue.data(updatedDevices);
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    for (var timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();

    // Clean up WebSocket resources
    _deviceUpdateSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    _webSocketService.disconnect();

    super.dispose();
  }

  Future<void> pair() async {
    try {
      await _service.pair('', '');
      loadDevices();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> setDeviceZones(String deviceId, List<String> zones) async {
    try {
      await _service.setDeviceZones(deviceId, zones);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<List<String>> getDeviceZones(String deviceId) async {
    return await _service.getDeviceZones(deviceId);
  }

  Future<List<String>> getDevicesByZone(String zone) async {
    return await _service.getDevicesByZone(zone);
  }

  Future<List<String>> getAllZones() async {
    return await _service.getAllZones();
  }

  Future<bool> createZone(String zoneName) async {
    return await _service.createZone(zoneName);
  }

  Future<bool> deleteZone(String zoneName) async {
    return await _service.deleteZone(zoneName);
  }

  Future<bool> renameZone(String oldName, String newName) async {
    return await _service.renameZone(oldName, newName);
  }

  // Device metadata methods
  Future<Map<String, String>> getDeviceMetadata(String deviceId) async {
    return await _service.getDeviceMetadata(deviceId);
  }

  Future<bool> setDeviceMetadata(
      String deviceId, String customName, String customCategory) async {
    final success =
        await _service.setDeviceMetadata(deviceId, customName, customCategory);
    if (success) {
      // Refresh devices to show updated metadata
      loadDevices();
    }
    return success;
  }
}

// Providers
final zigbeeServiceProvider = Provider((ref) => ZigbeeService());

final devicesProvider =
    StateNotifierProvider<DevicesNotifier, AsyncValue<List<Device>>>(
  (ref) => DevicesNotifier(
    ref.watch(zigbeeServiceProvider),
    ref.watch(webSocketServiceProvider),
  ),
);

// Provider for all zones
final allZonesProvider = FutureProvider<List<String>>((ref) async {
  final devicesNotifier = ref.watch(devicesProvider.notifier);
  return devicesNotifier.getAllZones();
});
