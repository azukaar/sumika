import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import './automation_types.dart';
import 'api_config.dart';

class AutomationService {
  static Future<String> get baseUrl => ApiConfig.manageApiUrl;

  // Get all automations
  Future<List<Automation>> getAllAutomations() async {
    try {
      final url = await baseUrl;
      final response = await http.get(Uri.parse('$url/automations'));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Automation.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load automations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load automations: $e');
    }
  }

  // Get automation by ID
  Future<Automation?> getAutomation(String id) async {
    try {
      final url = await baseUrl;
      final response = await http.get(Uri.parse('$url/automations/$id'));

      if (response.statusCode == 200) {
        return Automation.fromJson(json.decode(response.body));
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to load automation: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load automation: $e');
    }
  }

  // Create new automation
  Future<String> createAutomation(Automation automation) async {
    try {
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/automations'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(automation.toJson()),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['id'] as String;
      } else {
        String errorMessage = 'Failed to create automation';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['error']?.toString() ?? 'Unknown error';
          if (errorData['details'] != null) {
            errorMessage += ': ${errorData['details']}';
          }
        } catch (e) {
          errorMessage = 'Server error: ${response.body}';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Failed to create automation: $e');
    }
  }

  // Update automation
  Future<void> updateAutomation(String id, Map<String, dynamic> updates) async {
    try {
      final url = await baseUrl;

      // Special handling for enabled toggle
      if (updates.length == 1 && updates.containsKey('enabled')) {
        final response = await http.put(
          Uri.parse('$url/automations/$id/toggle'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(updates),
        );

        if (response.statusCode != 200) {
          final errorData = json.decode(response.body);
          throw Exception(errorData['error'] ?? 'Failed to toggle automation');
        }
        return;
      }

      // For other updates, use the regular update endpoint
      final response = await http.put(
        Uri.parse('$url/automations/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updates),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to update automation');
      }
    } catch (e) {
      throw Exception('Failed to update automation: $e');
    }
  }

  // Update full automation
  Future<void> updateFullAutomation(Automation automation) async {
    try {
      final url = await baseUrl;
      final response = await http.put(
        Uri.parse('$url/automations/${automation.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(automation.toJson()),
      );

      if (response.statusCode != 200) {
        String errorMessage = 'Failed to update automation';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['error']?.toString() ?? 'Unknown error';
          if (errorData['details'] != null) {
            errorMessage += ': ${errorData['details']}';
          }
        } catch (e) {
          errorMessage = 'Server error: ${response.body}';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Failed to update automation: $e');
    }
  }

  // Delete automation
  Future<void> deleteAutomation(String id) async {
    try {
      final url = await baseUrl;
      final response = await http.delete(Uri.parse('$url/automations/$id'));

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to delete automation');
      }
    } catch (e) {
      throw Exception('Failed to delete automation: $e');
    }
  }

  // Get automations for specific device
  Future<List<Automation>> getAutomationsForDevice(String deviceName) async {
    try {
      final url = await baseUrl;
      final response =
          await http.get(Uri.parse('$url/automations/device/$deviceName'));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Automation.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to load device automations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load device automations: $e');
    }
  }

  // Get properties for specific device
  Future<List<String>> getDeviceProperties(String deviceName) async {
    try {
      final url = await baseUrl;
      final response =
          await http.get(Uri.parse('$url/device/$deviceName/properties'));

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty || responseBody == 'null') {
          return [];
        }

        final dynamic decoded = json.decode(responseBody);
        if (decoded == null) {
          return [];
        }

        if (decoded is List) {
          return decoded.whereType<String>().toList();
        } else {
          throw Exception(
              'Expected array response, got: ${decoded.runtimeType}');
        }
      } else {
        throw Exception(
            'Failed to load device properties: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load device properties: $e');
    }
  }

  // Run automation manually
  Future<void> runAutomation(String id) async {
    try {
      final url = await baseUrl;
      final response = await http.post(Uri.parse('$url/automations/$id/run'));

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to run automation');
      }
    } catch (e) {
      throw Exception('Failed to run automation: $e');
    }
  }
}

// Automation provider for state management
final automationServiceProvider = Provider<AutomationService>((ref) {
  return AutomationService();
});

// Provider for all automations
final automationsProvider = FutureProvider<List<Automation>>((ref) async {
  final service = ref.watch(automationServiceProvider);
  return service.getAllAutomations();
});

// Provider for automations by device
final automationsForDeviceProvider =
    FutureProvider.family<List<Automation>, String>((ref, deviceName) async {
  final service = ref.watch(automationServiceProvider);
  return service.getAutomationsForDevice(deviceName);
});

// Provider for device properties
final devicePropertiesProvider =
    FutureProvider.family<List<String>, String>((ref, deviceName) async {
  final service = ref.watch(automationServiceProvider);
  return service.getDeviceProperties(deviceName);
});

// State notifier for managing automations
class AutomationNotifier extends StateNotifier<AsyncValue<List<Automation>>> {
  AutomationNotifier(this._service) : super(const AsyncValue.loading()) {
    loadAutomations();
  }

  final AutomationService _service;

  Future<void> loadAutomations() async {
    state = const AsyncValue.loading();
    try {
      final automations = await _service.getAllAutomations();
      state = AsyncValue.data(automations);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> createAutomation(Automation automation) async {
    try {
      await _service.createAutomation(automation);
      await loadAutomations(); // Refresh list
    } catch (error) {
      // Handle error - could add error state management here
      rethrow;
    }
  }

  Future<void> updateAutomation(Automation automation) async {
    try {
      await _service.updateFullAutomation(automation);
      await loadAutomations(); // Refresh list
    } catch (error) {
      // Handle error
      rethrow;
    }
  }

  Future<void> updateAutomationPartial(
      String id, Map<String, dynamic> updates) async {
    try {
      await _service.updateAutomation(id, updates);
      await loadAutomations(); // Refresh list
    } catch (error) {
      // Handle error
      rethrow;
    }
  }

  Future<void> deleteAutomation(String id) async {
    try {
      await _service.deleteAutomation(id);
      await loadAutomations(); // Refresh list
    } catch (error) {
      // Handle error
      rethrow;
    }
  }

  Future<void> toggleAutomationEnabled(String id, bool enabled) async {
    try {
      await _service.updateAutomation(id, {'enabled': enabled});

      // Update local state immediately for better UX
      state.whenData((automations) {
        final updatedAutomations = automations.map((automation) {
          if (automation.id == id) {
            return automation.copyWith(enabled: enabled);
          }
          return automation;
        }).toList();
        state = AsyncValue.data(updatedAutomations);
      });
    } catch (error) {
      // Reload on error to ensure consistency
      await loadAutomations();
      rethrow;
    }
  }

  Future<void> runAutomation(String id) async {
    try {
      await _service.runAutomation(id);
    } catch (error) {
      rethrow;
    }
  }
}

final automationNotifierProvider =
    StateNotifierProvider<AutomationNotifier, AsyncValue<List<Automation>>>(
        (ref) {
  final service = ref.watch(automationServiceProvider);
  return AutomationNotifier(service);
});
