import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../zigbee-service.dart';
import 'base_async_notifier.dart';

class ZoneNotifier extends BaseListAsyncNotifier<String> {
  final ZigbeeService _service;
  
  ZoneNotifier(this._service);

  @override
  String get notifierName => 'ZoneNotifier';

  @override
  Future<List<String>> loadData() async {
    return _service.getAllZones();
  }

  Future<void> createZone(String zoneName) async {
    await executeOperation(() async {
      final success = await _service.createZone(zoneName);
      if (success) {
        await load(); // Refresh to show new zone
      }
      return success;
    });
  }

  Future<void> deleteZone(String zoneName) async {
    await removeItem(
      (zone) => zone == zoneName,
      () async {
        final success = await _service.deleteZone(zoneName);
        if (success) {
          return await loadData();
        } else {
          throw Exception('Failed to delete zone');
        }
      },
    );
  }

  Future<void> renameZone(String oldName, String newName) async {
    await executeOperation(() async {
      final success = await _service.renameZone(oldName, newName);
      if (success) {
        await load(); // Refresh to show renamed zone
      }
      return success;
    });
  }

  bool zoneExists(String zoneName) {
    return currentList.contains(zoneName);
  }

  String? validateZoneName(String zoneName) {
    if (zoneName.trim().isEmpty) {
      return 'Zone name cannot be empty';
    }
    if (zoneExists(zoneName)) {
      return 'Zone already exists';
    }
    return null;
  }
}

// Provider for zone notifier
final zoneNotifierProvider = StateNotifierProvider<ZoneNotifier, AsyncValue<List<String>>>((ref) {
  final service = ref.watch(zigbeeServiceProvider);
  return ZoneNotifier(service);
});