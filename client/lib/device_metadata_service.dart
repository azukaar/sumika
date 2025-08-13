import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import './types.dart';
import 'api_config.dart';

class DeviceMetadata {
  final String deviceName;
  final String customName;
  final String customCategory;
  final String displayName;
  final String? guessedCategory;
  final String? effectiveCategory;

  DeviceMetadata({
    required this.deviceName,
    required this.customName,
    required this.customCategory,
    required this.displayName,
    this.guessedCategory,
    this.effectiveCategory,
  });

  factory DeviceMetadata.fromJson(Map<String, dynamic> json) => DeviceMetadata(
    deviceName: json['device_name'] as String,
    customName: json['custom_name'] as String? ?? '',
    customCategory: json['custom_category'] as String? ?? '',
    displayName: json['display_name'] as String,
    guessedCategory: json['guessed_category'] as String?,
    effectiveCategory: json['effective_category'] as String?,
  );
}

class DeviceMetadataService {
  static Future<String> get baseUrl => ApiConfig.manageApiUrl;

  // Get device metadata
  Future<DeviceMetadata> getDeviceMetadata(String deviceName) async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/device/${Uri.encodeComponent(deviceName)}/metadata'),
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return DeviceMetadata.fromJson(json);
      } else {
        throw Exception('Failed to load device metadata: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load device metadata: $e');
    }
  }

  // Set device custom name
  Future<void> setDeviceCustomName(String deviceName, String customName) async {
    try {
      final url = await baseUrl;
      final response = await http.put(
        Uri.parse('$url/device/${Uri.encodeComponent(deviceName)}/custom_name?custom_name=${Uri.encodeComponent(customName)}'),
      );
      
      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to set custom name');
      }
    } catch (e) {
      throw Exception('Failed to set device custom name: $e');
    }
  }

  // Set device custom category
  Future<void> setDeviceCustomCategory(String deviceName, String category) async {
    try {
      final url = await baseUrl;
      final response = await http.put(
        Uri.parse('$url/device/${Uri.encodeComponent(deviceName)}/custom_category?category=${Uri.encodeComponent(category)}'),
      );
      
      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to set custom category');
      }
    } catch (e) {
      throw Exception('Failed to set device custom category: $e');
    }
  }

  // Get all available device categories
  Future<List<String>> getAllDeviceCategories() async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/device_categories'),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> categories = jsonDecode(response.body);
        return categories.cast<String>();
      } else {
        throw Exception('Failed to load device categories: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load device categories: $e');
    }
  }
}

// Device metadata providers
final deviceMetadataServiceProvider = Provider<DeviceMetadataService>((ref) {
  return DeviceMetadataService();
});

// Provider for device metadata
final deviceMetadataProvider = FutureProvider.family<DeviceMetadata, String>((ref, deviceName) async {
  final service = ref.watch(deviceMetadataServiceProvider);
  return service.getDeviceMetadata(deviceName);
});

// Provider for device categories
final deviceCategoriesProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.watch(deviceMetadataServiceProvider);
  return service.getAllDeviceCategories();
});

// Device metadata notifier for managing state
class DeviceMetadataNotifier extends StateNotifier<AsyncValue<Map<String, DeviceMetadata>>> {
  DeviceMetadataNotifier(this._service) : super(const AsyncValue.loading());

  final DeviceMetadataService _service;

  Future<void> loadDeviceMetadata(String deviceName) async {
    try {
      final metadata = await _service.getDeviceMetadata(deviceName);
      state = state.whenData((currentData) {
        final newData = Map<String, DeviceMetadata>.from(currentData);
        newData[deviceName] = metadata;
        return newData;
      });
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> setCustomName(String deviceName, String customName) async {
    try {
      await _service.setDeviceCustomName(deviceName, customName);
      await loadDeviceMetadata(deviceName); // Refresh metadata
    } catch (error) {
      rethrow;
    }
  }

  Future<void> setCustomCategory(String deviceName, String category) async {
    try {
      await _service.setDeviceCustomCategory(deviceName, category);
      await loadDeviceMetadata(deviceName); // Refresh metadata
    } catch (error) {
      rethrow;
    }
  }
}

final deviceMetadataNotifierProvider = StateNotifierProvider<DeviceMetadataNotifier, AsyncValue<Map<String, DeviceMetadata>>>((ref) {
  final service = ref.watch(deviceMetadataServiceProvider);
  return DeviceMetadataNotifier(service);
});

// Helper functions for getting display information
String getDeviceDisplayName(Device device, DeviceMetadata? metadata) {
  if (metadata?.customName.isNotEmpty == true) {
    return metadata!.customName;
  }
  return device.friendlyName;
}

String getDeviceCategory(Device device, DeviceMetadata? metadata) {
  if (metadata?.effectiveCategory?.isNotEmpty == true) {
    return metadata!.effectiveCategory!;
  }
  return 'unknown';
}