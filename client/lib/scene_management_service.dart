import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import './supercard/scene_models.dart';
import 'api_config.dart';

class SceneManagementService {
  static Future<String> get baseUrl => ApiConfig.manageApiUrl;

  // Get all scenes for management
  Future<List<LightingScene>> getAllScenes() async {
    try {
      final url = await baseUrl;
      final response = await http.get(Uri.parse('$url/scene-management'));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);

        final scenes = <LightingScene>[];
        for (int i = 0; i < jsonList.length; i++) {
          try {
            final sceneJson = jsonList[i];
            final scene = LightingScene.fromJson(sceneJson);
            scenes.add(scene);
          } catch (e) {
            rethrow;
          }
        }

        return scenes;
      } else {
        throw Exception('Failed to load scenes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load scenes: $e');
    }
  }

  // Get scene by ID
  Future<LightingScene?> getSceneById(String id) async {
    try {
      final url = await baseUrl;
      final response = await http.get(Uri.parse('$url/scene-management/$id'));

      if (response.statusCode == 200) {
        return LightingScene.fromJson(json.decode(response.body));
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to load scene: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load scene: $e');
    }
  }

  // Create new scene
  Future<LightingScene> createScene(LightingScene scene) async {
    try {
      final url = await baseUrl;

      final response = await http.post(
        Uri.parse('$url/scene-management'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(scene.toJson()),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData == null) {
          throw Exception('Server returned null response');
        }

        return LightingScene.fromJson(responseData);
      } else {
        throw Exception(
            'Failed to create scene: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to create scene: $e');
    }
  }

  // Update existing scene
  Future<LightingScene> updateScene(String id, LightingScene scene) async {
    try {
      final url = await baseUrl;
      final response = await http.put(
        Uri.parse('$url/scene-management/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(scene.toJson()),
      );

      if (response.statusCode == 200) {
        return LightingScene.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to update scene: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to update scene: $e');
    }
  }

  // Delete scene
  Future<void> deleteScene(String id) async {
    try {
      final url = await baseUrl;
      final response =
          await http.delete(Uri.parse('$url/scene-management/$id'));

      if (response.statusCode != 200) {
        throw Exception('Failed to delete scene: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to delete scene: $e');
    }
  }

  // Duplicate scene
  Future<LightingScene> duplicateScene(String id) async {
    try {
      final url = await baseUrl;
      final response =
          await http.post(Uri.parse('$url/scene-management/$id/duplicate'));

      if (response.statusCode == 200) {
        return LightingScene.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to duplicate scene: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to duplicate scene: $e');
    }
  }

  // Reorder scenes
  Future<void> reorderScenes(List<Map<String, dynamic>> sceneOrders) async {
    try {
      final url = await baseUrl;
      final fullUrl = '$url/scene-management/reorder';
      final jsonBody = json.encode(sceneOrders);

      final response = await http.put(
        Uri.parse(fullUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonBody,
      );

      if (response.statusCode != 200) {
        final errorMessage = response.body.isNotEmpty
            ? response.body
            : 'HTTP ${response.statusCode}';
        throw Exception('Failed to reorder scenes: $errorMessage');
      }
    } catch (e) {
      throw Exception('Failed to reorder scenes: $e');
    }
  }

  // Test scene definition in zone (without saving)
  Future<void> testSceneDefinitionInZone(LightingScene sceneDefinition, String zone) async {
    try {
      final url = await baseUrl;
      final response = await http.post(
        Uri.parse('$url/scene-management/test?zone=$zone'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(sceneDefinition.toJson()),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to test scene: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to test scene: $e');
    }
  }
}

// Scene management service provider
final sceneManagementServiceProvider = Provider<SceneManagementService>((ref) {
  return SceneManagementService();
});

// Provider for all scenes (management)
final sceneManagementProvider =
    FutureProvider<List<LightingScene>>((ref) async {
  final service = ref.watch(sceneManagementServiceProvider);
  return service.getAllScenes();
});

// Provider for scene by ID
final sceneByIdProvider =
    FutureProvider.family<LightingScene?, String>((ref, id) async {
  final service = ref.watch(sceneManagementServiceProvider);
  return service.getSceneById(id);
});

// State notifier for scene management operations
class SceneManagementNotifier
    extends StateNotifier<AsyncValue<List<LightingScene>>> {
  final SceneManagementService _service;

  SceneManagementNotifier(this._service) : super(const AsyncValue.loading()) {
    loadScenes();
  }

  Future<void> loadScenes() async {
    try {
      state = const AsyncValue.loading();
      final scenes = await _service.getAllScenes();
      state = AsyncValue.data(scenes);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> createScene(LightingScene scene) async {
    try {
      final createdScene = await _service.createScene(scene);
      await loadScenes(); // Refresh list
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> updateScene(String id, LightingScene scene) async {
    try {
      await _service.updateScene(id, scene);
      await loadScenes(); // Refresh list
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> deleteScene(String id) async {
    try {
      await _service.deleteScene(id);
      await loadScenes(); // Refresh list
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> duplicateScene(String id) async {
    try {
      await _service.duplicateScene(id);
      await loadScenes(); // Refresh list
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> reorderScenes(List<Map<String, dynamic>> sceneOrders) async {
    try {
      await _service.reorderScenes(sceneOrders);
      await loadScenes(); // Refresh list
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

}

// Scene management notifier provider
final sceneManagementNotifierProvider = StateNotifierProvider<
    SceneManagementNotifier, AsyncValue<List<LightingScene>>>((ref) {
  final service = ref.watch(sceneManagementServiceProvider);
  return SceneManagementNotifier(service);
});
