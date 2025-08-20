import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../zigbee-service.dart';
import 'base_async_notifier.dart';

class DeviceSpecsNotifier extends BaseAsyncNotifier<Map<String, dynamic>> {
  final ZigbeeService _service;
  
  DeviceSpecsNotifier(this._service);

  @override
  String get notifierName => 'DeviceSpecsNotifier';

  @override
  Future<Map<String, dynamic>> loadData() async {
    print('[DEBUG] DeviceSpecsNotifier: Starting to load device specifications');
    try {
      final specs = await _service.fetchDeviceSpecifications();
      print('[DEBUG] DeviceSpecsNotifier: Successfully loaded ${specs.length} device specifications');
      return specs;
    } catch (e, stackTrace) {
      print('[DEBUG] DeviceSpecsNotifier: Error loading device specifications: $e');
      print('[DEBUG] DeviceSpecsNotifier: Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Get specifications for a specific device by IEEE address
  Map<String, dynamic>? getDeviceSpecs(String ieeeAddress) {
    try {
      return state.whenData((specs) => specs[ieeeAddress]).value;
    } catch (e) {
      print('[DEBUG] DeviceSpecsNotifier: Error getting specs for device $ieeeAddress: $e');
      return null;
    }
  }

  // Get enhanced metadata for a specific device
  Map<String, dynamic>? getEnhancedMetadata(String ieeeAddress) {
    try {
      final deviceSpecs = getDeviceSpecs(ieeeAddress);
      final metadata = deviceSpecs?['enhanced_metadata'];
      return metadata is Map<String, dynamic> ? metadata : null;
    } catch (e) {
      print('[DEBUG] DeviceSpecsNotifier: Error getting enhanced metadata for device $ieeeAddress: $e');
      return null;
    }
  }

  // Get exposes (capabilities) for a specific device
  List<dynamic>? getDeviceExposes(String ieeeAddress) {
    try {
      final metadata = getEnhancedMetadata(ieeeAddress);
      final exposes = metadata?['exposes'];
      return exposes is List ? exposes : null;
    } catch (e) {
      print('[DEBUG] DeviceSpecsNotifier: Error getting device exposes for device $ieeeAddress: $e');
      return null;
    }
  }

  // Get options (configuration) for a specific device
  List<dynamic>? getDeviceOptions(String ieeeAddress) {
    try {
      final metadata = getEnhancedMetadata(ieeeAddress);
      final options = metadata?['options'];
      return options is List ? options : null;
    } catch (e) {
      print('[DEBUG] DeviceSpecsNotifier: Error getting device options for device $ieeeAddress: $e');
      return null;
    }
  }

  // Check if device specifications are available for a device
  bool hasSpecsForDevice(String ieeeAddress) {
    return getDeviceSpecs(ieeeAddress) != null;
  }
}

// Provider for device specifications notifier
final deviceSpecsNotifierProvider = StateNotifierProvider<DeviceSpecsNotifier, AsyncValue<Map<String, dynamic>>>((ref) {
  final service = ref.watch(zigbeeServiceProvider);
  return DeviceSpecsNotifier(service);
});

// Provider to easily access specs for a specific device
final deviceSpecsProvider = Provider.family<Map<String, dynamic>?, String>((ref, ieeeAddress) {
  final specsState = ref.watch(deviceSpecsNotifierProvider);
  return specsState.when(
    data: (specs) => specs[ieeeAddress],
    loading: () => null,
    error: (error, stack) => null,
  );
});

// Provider for enhanced metadata of a specific device
final deviceEnhancedMetadataProvider = Provider.family<Map<String, dynamic>?, String>((ref, ieeeAddress) {
  final deviceSpecs = ref.watch(deviceSpecsProvider(ieeeAddress));
  final metadata = deviceSpecs?['enhanced_metadata'];
  return metadata is Map<String, dynamic> ? metadata : null;
});

// Provider for device exposes (capabilities)
final deviceExposesProvider = Provider.family<List<dynamic>?, String>((ref, ieeeAddress) {
  final metadata = ref.watch(deviceEnhancedMetadataProvider(ieeeAddress));
  final exposes = metadata?['exposes'];
  return exposes is List ? exposes : null;
});

// Provider for device options (configuration)
final deviceOptionsProvider = Provider.family<List<dynamic>?, String>((ref, ieeeAddress) {
  final metadata = ref.watch(deviceEnhancedMetadataProvider(ieeeAddress));
  final options = metadata?['options'];
  return options is List ? options : null;
});