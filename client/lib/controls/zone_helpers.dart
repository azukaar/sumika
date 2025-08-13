import '../types.dart';

/// Helper functions for zone-level device control
class ZoneControlHelpers {
  /// Find all common controls that exist across all devices in a zone
  static List<Map<String, dynamic>> getCommonControls(List<Device> devices) {
    if (devices.isEmpty) return [];
    
    // Start with the first device's exposes
    final firstDevice = devices.first;
    final firstExposes = firstDevice.definition.exposes ?? [];
    
    List<Map<String, dynamic>> commonControls = [];
    
    // Check each expose from the first device
    for (var expose in firstExposes) {
      if (expose is! Map<String, dynamic>) continue;
      
      final property = expose['property'] ?? expose['name'];
      final type = expose['type'];
      
      // Skip read-only controls
      final access = expose['access'];
      if (access == 1 || access == 5) continue;
      
      // Check if this control exists in all other devices
      bool existsInAllDevices = true;
      for (int i = 1; i < devices.length; i++) {
        final deviceExposes = devices[i].definition.exposes ?? [];
        bool foundInDevice = false;
        
        for (var otherExpose in deviceExposes) {
          if (otherExpose is! Map<String, dynamic>) continue;
          
          final otherProperty = otherExpose['property'] ?? otherExpose['name'];
          final otherType = otherExpose['type'];
          
          // Match by property and type
          if (otherProperty == property && otherType == type) {
            foundInDevice = true;
            break;
          }
          
          // Also check within composite features
          if (otherExpose['features'] != null) {
            for (var feature in otherExpose['features']) {
              final featureProperty = feature['property'] ?? feature['name'];
              final featureType = feature['type'];
              if (featureProperty == property && featureType == type) {
                foundInDevice = true;
                break;
              }
            }
          }
          
          if (foundInDevice) break;
        }
        
        if (!foundInDevice) {
          existsInAllDevices = false;
          break;
        }
      }
      
      if (existsInAllDevices) {
        commonControls.add(expose);
      }
      
      // Also check features within composite exposes
      if (expose['features'] != null) {
        for (var feature in expose['features']) {
          final featureProperty = feature['property'] ?? feature['name'];
          final featureAccess = feature['access'];
          
          // Skip read-only features
          if (featureAccess == 1 || featureAccess == 5) continue;
          
          // Check if this feature exists in all devices
          bool featureInAllDevices = true;
          for (int i = 1; i < devices.length; i++) {
            final deviceExposes = devices[i].definition.exposes ?? [];
            bool foundFeatureInDevice = false;
            
            for (var otherExpose in deviceExposes) {
              if (otherExpose is! Map<String, dynamic>) continue;
              
              if (otherExpose['features'] != null) {
                for (var otherFeature in otherExpose['features']) {
                  final otherFeatureProperty = otherFeature['property'] ?? otherFeature['name'];
                  if (otherFeatureProperty == featureProperty) {
                    foundFeatureInDevice = true;
                    break;
                  }
                }
              }
              
              if (foundFeatureInDevice) break;
            }
            
            if (!foundFeatureInDevice) {
              featureInAllDevices = false;
              break;
            }
          }
          
          if (featureInAllDevices) {
            commonControls.add(feature);
          }
        }
      }
    }
    
    return commonControls;
  }
  
  /// Get priority-ordered controls for a specific device type
  static List<String> getControlPriority(String deviceType) {
    switch (deviceType) {
      case 'light':
        return ['state', 'brightness', 'color_temp', 'color_hs', 'color'];
      case 'switch':
        return ['state'];
      case 'sensor':
        return []; // Sensors typically have no writable controls
      case 'thermostat':
        return ['system_mode', 'occupied_heating_setpoint', 'local_temperature'];
      default:
        return ['state', 'brightness', 'position', 'temperature'];
    }
  }
  
  /// Filter and sort controls based on device type priority
  static List<Map<String, dynamic>> prioritizeControls(
    List<Map<String, dynamic>> controls, 
    String deviceType
  ) {
    final priorities = getControlPriority(deviceType);
    final prioritized = <Map<String, dynamic>>[];
    final remaining = <Map<String, dynamic>>[];
    
    // First, add controls in priority order
    for (String priority in priorities) {
      for (var control in controls) {
        final property = control['property'] ?? control['name'];
        if (property == priority) {
          prioritized.add(control);
        }
      }
    }
    
    // Then add any remaining controls
    for (var control in controls) {
      final property = control['property'] ?? control['name'];
      if (!priorities.contains(property) && !prioritized.contains(control)) {
        remaining.add(control);
      }
    }
    
    return [...prioritized, ...remaining];
  }
}