import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../scene_management_service.dart';
import '../supercard/scene_models.dart';
import 'base_async_notifier.dart';

class SceneNotifier extends BaseListAsyncNotifier<LightingScene> {
  final SceneManagementService _service;
  
  SceneNotifier(this._service);

  @override
  String get notifierName => 'SceneNotifier';

  @override
  Future<List<LightingScene>> loadData() async {
    return _service.getAllScenes();
  }

  Future<void> createScene(LightingScene scene) async {
    await addItem(scene, () async {
      await _service.createScene(scene);
      return loadData();
    });
  }

  Future<void> updateScene(String id, LightingScene scene) async {
    await updateItem(
      (s) => s.id == id,
      (s) => scene,
      () async {
        await _service.updateScene(id, scene);
        return loadData();
      },
    );
  }

  Future<void> deleteScene(String id) async {
    await removeItem(
      (scene) => scene.id == id,
      () async {
        await _service.deleteScene(id);
        return loadData();
      },
    );
  }

  Future<void> duplicateScene(String id) async {
    await executeOperation(() async {
      final duplicatedScene = await _service.duplicateScene(id);
      await load(); // Refresh to show the new scene
      return duplicatedScene;
    });
  }

  Future<void> reorderScenes(List<Map<String, dynamic>> sceneOrders) async {
    await executeOperation(() async {
      await _service.reorderScenes(sceneOrders);
      await load(); // Refresh to show new order
    });
  }

  Future<void> testSceneInZone(String sceneId, String zone) async {
    await executeOperation(() => _service.testSceneInZone(sceneId, zone));
  }

  LightingScene? getSceneById(String id) {
    return currentList.where((scene) => scene.id == id).firstOrNull;
  }
}

// Provider for scene notifier
final sceneNotifierProvider = StateNotifierProvider<SceneNotifier, AsyncValue<List<LightingScene>>>((ref) {
  final service = ref.watch(sceneManagementServiceProvider);
  return SceneNotifier(service);
});