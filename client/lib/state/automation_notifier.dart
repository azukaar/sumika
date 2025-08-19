import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../automation_service.dart';
import '../automation_types.dart';
import 'base_async_notifier.dart';

class AutomationNotifier extends BaseListAsyncNotifier<Automation> {
  final AutomationService _service;
  
  AutomationNotifier(this._service);

  @override
  String get notifierName => 'AutomationNotifier';

  @override
  Future<List<Automation>> loadData() async {
    return _service.getAllAutomations();
  }

  Future<void> createAutomation(Automation automation) async {
    await addItem(automation, () async {
      await _service.createAutomation(automation);
      return loadData();
    });
  }

  Future<void> updateAutomation(Automation automation) async {
    await updateItem(
      (a) => a.id == automation.id,
      (a) => automation,
      () async {
        await _service.updateFullAutomation(automation);
        return loadData();
      },
    );
  }

  Future<void> updateAutomationPartial(String id, Map<String, dynamic> updates) async {
    await executeOperation(() async {
      await _service.updateAutomation(id, updates);
      await load(); // Refresh to show changes
    });
  }

  Future<void> deleteAutomation(String id) async {
    await removeItem(
      (automation) => automation.id == id,
      () async {
        await _service.deleteAutomation(id);
        return loadData();
      },
    );
  }

  Future<void> toggleAutomationEnabled(String id, bool enabled) async {
    await updateData(() async {
      // Update server first
      await _service.updateAutomation(id, {'enabled': enabled});
      
      // Return updated list with optimistic update
      final currentAutomations = data ?? [];
      return currentAutomations.map((automation) {
        if (automation.id == id) {
          return automation.copyWith(enabled: enabled);
        }
        return automation;
      }).toList();
    });
  }

  Future<void> runAutomation(String id) async {
    await executeOperation(() => _service.runAutomation(id));
  }

  Future<List<Automation>> getAutomationsForDevice(String deviceName) async {
    return executeOperation(() => _service.getAutomationsForDevice(deviceName));
  }

  Future<List<String>> getDeviceProperties(String deviceName) async {
    return executeOperation(() => _service.getDeviceProperties(deviceName));
  }

  Automation? getAutomationById(String id) {
    return currentList.where((automation) => automation.id == id).firstOrNull;
  }

  List<Automation> getEnabledAutomations() {
    return currentList.where((automation) => automation.enabled).toList();
  }

  List<Automation> getAutomationsByType(String type) {
    return currentList.where((automation) => automation.type == type).toList();
  }
}

// Provider for automation notifier (using our new consolidated pattern)
final automationNotifierProvider = StateNotifierProvider<AutomationNotifier, AsyncValue<List<Automation>>>((ref) {
  final service = ref.watch(automationServiceProvider);
  return AutomationNotifier(service);
});