import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../zigbee-service.dart';
import '../types.dart';
import 'base_async_notifier.dart';

class DeviceNotifier extends BaseListAsyncNotifier<Device> {
  final ZigbeeService _service;
  
  DeviceNotifier(this._service);

  @override
  String get notifierName => 'DeviceNotifier';

  @override
  Future<List<Device>> loadData() async {
    return _service.fetchDevices();
  }

  Future<void> setDeviceState(String deviceId, Map<String, dynamic> state) async {
    await executeOperation(() => _service.setDeviceState(deviceId, state));
  }

  Future<void> pair() async {
    await executeOperation(() async {
      await _service.pair('', '');
      await load(); // Refresh to show new devices
    });
  }

  Future<void> setDeviceZones(String deviceId, List<String> zones) async {
    await executeOperation(() => _service.setDeviceZones(deviceId, zones));
  }

  Future<List<String>> getDeviceZones(String deviceId) async {
    return executeOperation(() => _service.getDeviceZones(deviceId));
  }

  Future<List<String>> getDevicesByZone(String zone) async {
    return executeOperation(() => _service.getDevicesByZone(zone));
  }

  Future<Map<String, String>> getDeviceMetadata(String deviceId) async {
    return executeOperation(() => _service.getDeviceMetadata(deviceId));
  }

  Future<void> setDeviceMetadata(String deviceId, String customName, String customCategory) async {
    await executeOperation(() async {
      final success = await _service.setDeviceMetadata(deviceId, customName, customCategory);
      if (success) {
        await load(); // Refresh to show updated metadata
      }
      return success;
    });
  }

  Device? getDeviceById(String deviceId) {
    return currentList.where((device) => device.friendlyName == deviceId).firstOrNull;
  }

  List<Device> getDevicesByZones(List<String> zones) {
    if (zones.isEmpty) return currentList;
    return currentList.where((device) => 
      device.zones?.any((zone) => zones.contains(zone)) ?? false
    ).toList();
  }
}

// Provider for device notifier (using our new consolidated pattern)
final deviceNotifierProvider = StateNotifierProvider<DeviceNotifier, AsyncValue<List<Device>>>((ref) {
  final service = ref.watch(zigbeeServiceProvider);
  return DeviceNotifier(service);
});