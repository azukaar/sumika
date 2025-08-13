import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_config.dart';

class ZoneCategory {
  final String zone;
  final String category;
  final int deviceCount;
  final List<String> devices;

  ZoneCategory({
    required this.zone,
    required this.category,
    required this.deviceCount,
    required this.devices,
  });

  factory ZoneCategory.fromJson(Map<String, dynamic> json) => ZoneCategory(
    zone: json['zone'] as String,
    category: json['category'] as String,
    deviceCount: json['device_count'] as int,
    devices: (json['devices'] as List<dynamic>).cast<String>(),
  );
}

class ZoneAutomationService {
  static Future<String> get baseUrl => ApiConfig.manageApiUrl;

  // Get all zone/category combinations
  Future<List<ZoneCategory>> getZonesAndCategories() async {
    try {
      final url = await baseUrl;
      final response = await http.get(Uri.parse('$url/zones_categories'));
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => ZoneCategory.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load zones and categories: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load zones and categories: $e');
    }
  }

  // Get all categories in a specific zone
  Future<List<String>> getZoneCategories(String zone) async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/zone/${Uri.encodeComponent(zone)}/categories'),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> categories = json.decode(response.body);
        return categories.cast<String>();
      } else {
        throw Exception('Failed to load zone categories: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load zone categories: $e');
    }
  }

  // Get devices in a zone, optionally filtered by category
  Future<List<String>> getDevicesByZoneAndCategory(String zone, {String? category}) async {
    try {
      final url = await baseUrl;
      final uri = Uri.parse('$url/zone/${Uri.encodeComponent(zone)}/devices');
      final uriWithQuery = category != null 
          ? uri.replace(queryParameters: {'category': category})
          : uri;
      
      final response = await http.get(uriWithQuery);
      
      if (response.statusCode == 200) {
        final List<dynamic> devices = json.decode(response.body);
        return devices.cast<String>();
      } else {
        throw Exception('Failed to load zone devices: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load zone devices: $e');
    }
  }

  // Get all possible properties for a zone/category combination
  Future<List<String>> getZoneCategoryProperties(String zone, String category) async {
    try {
      final url = await baseUrl;
      final response = await http.get(
        Uri.parse('$url/zone/${Uri.encodeComponent(zone)}/category/${Uri.encodeComponent(category)}/properties'),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> properties = json.decode(response.body);
        return properties.cast<String>();
      } else {
        throw Exception('Failed to load zone category properties: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load zone category properties: $e');
    }
  }
}

// Providers for zone automation
final zoneAutomationServiceProvider = Provider<ZoneAutomationService>((ref) {
  return ZoneAutomationService();
});

// Provider for zones and categories
final zonesCategoriesProvider = FutureProvider<List<ZoneCategory>>((ref) async {
  final service = ref.watch(zoneAutomationServiceProvider);
  return service.getZonesAndCategories();
});

// Provider for categories in a specific zone
final zoneCategoriesProvider = FutureProvider.family<List<String>, String>((ref, zone) async {
  final service = ref.watch(zoneAutomationServiceProvider);
  return service.getZoneCategories(zone);
});

// Provider for zone category properties
final zoneCategoryPropertiesProvider = FutureProvider.family<List<String>, Map<String, String>>((ref, params) async {
  final service = ref.watch(zoneAutomationServiceProvider);
  return service.getZoneCategoryProperties(params['zone']!, params['category']!);
});

// Helper functions
String getCategoryDisplayName(String category) {
  switch (category) {
    case 'light':
      return 'Lights';
    case 'switch':
      return 'Switches/Plugs';
    case 'sensor':
      return 'Sensors';
    case 'button':
      return 'Buttons/Remotes';
    case 'door_window':
      return 'Doors/Windows';
    case 'motion':
      return 'Motion Sensors';
    case 'thermostat':
      return 'Thermostats';
    case 'unknown':
      return 'Unknown Devices';
    default:
      return category;
  }
}

String getCategoryIcon(String category) {
  switch (category) {
    case 'light':
      return '💡';
    case 'switch':
      return '🔌';
    case 'sensor':
      return '📊';
    case 'button':
      return '🔘';
    case 'door_window':
      return '🚪';
    case 'motion':
      return '🚶';
    case 'thermostat':
      return '🌡️';
    case 'unknown':
      return '❓';
    default:
      return '📱';
  }
}