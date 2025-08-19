import '../types.dart';
import '../zigbee-service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service to handle dashboard data loading and zone/device organization
class DashboardService {
  final Ref ref;
  
  DashboardService(this.ref);

  /// Load all dashboard data including zones and devices
  Future<DashboardData> loadDashboardData() async {
    try {
      // Load all zones and devices
      final allZones = await ref.read(devicesProvider.notifier).getAllZones();
      final devicesAsyncValue = ref.read(devicesProvider);
      
      return await devicesAsyncValue.when(
        data: (devicesList) async {
          return await _organizeDashboardData(allZones, devicesList);
        },
        loading: () => DashboardData.loading(),
        error: (error, stackTrace) => DashboardData.error(error.toString()),
      );
    } catch (e) {
      return DashboardData.error(e.toString());
    }
  }

  /// Organize devices into zones and handle unassigned devices
  Future<DashboardData> _organizeDashboardData(
    List<String> allZones, 
    List<Device> devicesList
  ) async {
    Map<String, List<Device>> zoneDevices = {};
    Set<String> assignedDevices = {};

    // Process regular zones
    for (String zone in allZones) {
      List<Device> zoneDevicesList = [];
      final deviceNames = await ref.read(devicesProvider.notifier).getDevicesByZone(zone);

      for (String deviceName in deviceNames) {
        assignedDevices.add(deviceName);
        final device = _findDeviceByName(devicesList, deviceName);
        if (device != null) {
          zoneDevicesList.add(device);
        }
      }

      if (zoneDevicesList.isNotEmpty) {
        zoneDevices[zone] = zoneDevicesList;
      }
    }

    // Handle unassigned devices
    final unassignedDevices = devicesList
        .where((device) => !assignedDevices.contains(device.friendlyName))
        .toList();

    if (unassignedDevices.isNotEmpty) {
      zoneDevices['Unassigned'] = unassignedDevices;
    }

    // Determine zones to display (filter out empty zones)
    final zonesToShow = zoneDevices.keys.toList();

    return DashboardData.success(
      zones: zonesToShow,
      zoneDevices: zoneDevices,
    );
  }

  /// Find device by friendly name
  Device? _findDeviceByName(List<Device> devicesList, String deviceName) {
    try {
      return devicesList.firstWhere((d) => d.friendlyName == deviceName);
    } catch (e) {
      return null; // Device not found
    }
  }

  /// Refresh device data from server
  Future<void> refreshDevices() async {
    await ref.read(devicesProvider.notifier).loadDevices();
  }
}

/// Data class to represent dashboard state
class DashboardData {
  final List<String> zones;
  final Map<String, List<Device>> zoneDevices;
  final bool isLoading;
  final String? error;

  const DashboardData({
    this.zones = const [],
    this.zoneDevices = const {},
    this.isLoading = false,
    this.error,
  });

  DashboardData.loading() : this(isLoading: true);
  
  DashboardData.error(String errorMessage) : this(error: errorMessage);
  
  DashboardData.success({
    required List<String> zones,
    required Map<String, List<Device>> zoneDevices,
  }) : this(zones: zones, zoneDevices: zoneDevices);

  bool get hasError => error != null;
  bool get hasData => zones.isNotEmpty;
}

/// Provider for dashboard service
final dashboardServiceProvider = Provider<DashboardService>((ref) {
  return DashboardService(ref);
});