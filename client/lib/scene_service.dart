import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import './supercard/scene_models.dart';
import 'api_config.dart';

class SceneService {
  static Future<String> get baseUrl => ApiConfig.manageApiUrl;

  // Get all scenes
  Future<List<LightingScene>> getAllScenes() async {
    try {
      final url = await baseUrl;
      final response = await http.get(Uri.parse('$url/scene-management'));
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => LightingScene.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load scenes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load scenes: $e');
    }
  }

  // Get featured scenes (first 5)
  Future<List<LightingScene>> getFeaturedScenes() async {
    try {
      final allScenes = await getAllScenes();
      return allScenes.take(5).toList();
    } catch (e) {
      throw Exception('Failed to load featured scenes: $e');
    }
  }

  // Get scene by name
  Future<LightingScene?> getSceneByName(String name) async {
    try {
      final allScenes = await getAllScenes();
      try {
        return allScenes.firstWhere((scene) => scene.name == name);
      } catch (e) {
        return null; // Scene not found
      }
    } catch (e) {
      throw Exception('Failed to load scene: $e');
    }
  }
}

// Scene service provider
final sceneServiceProvider = Provider<SceneService>((ref) {
  return SceneService();
});

// Provider for all scenes
final allScenesProvider = FutureProvider<List<LightingScene>>((ref) async {
  final service = ref.watch(sceneServiceProvider);
  return service.getAllScenes();
});

// Provider for featured scenes
final featuredScenesProvider = FutureProvider<List<LightingScene>>((ref) async {
  final service = ref.watch(sceneServiceProvider);
  return service.getFeaturedScenes();
});

// Provider for scene by name
final sceneByNameProvider = FutureProvider.family<LightingScene?, String>((ref, name) async {
  final service = ref.watch(sceneServiceProvider);
  return service.getSceneByName(name);
});