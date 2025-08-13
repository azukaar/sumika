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
      final response = await http.get(Uri.parse('$url/scenes'));
      
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
      final url = await baseUrl;
      final response = await http.get(Uri.parse('$url/scenes/featured'));
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => LightingScene.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load featured scenes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load featured scenes: $e');
    }
  }

  // Get scene by name
  Future<LightingScene?> getSceneByName(String name) async {
    try {
      final url = await baseUrl;
      final response = await http.get(Uri.parse('$url/scenes/$name'));
      
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