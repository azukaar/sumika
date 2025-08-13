import '../types.dart';

class DeviceUtils {
  static String getDeviceType(Device device) {
    final model = device.definition.model?.toLowerCase() ?? '';
    final description = device.definition.description?.toLowerCase() ?? '';
    final friendlyName = device.friendlyName.toLowerCase();
    final vendor = device.definition.vendor?.toLowerCase() ?? '';
    
    // More comprehensive keyword matching
    final sensorKeywords = ['sensor', 'motion', 'pir', 'occupancy', 'presence'];
    final lightKeywords = ['light', 'bulb', 'lamp', 'led', 'strip', 'dimmer', 'hue', 'white', 'color', 'ambiance'];
    final switchKeywords = ['switch', 'plug', 'outlet', 'socket', 'relay'];
    final contactKeywords = ['door', 'window', 'contact', 'magnet', 'open', 'close'];
    final thermostatKeywords = ['thermostat', 'temperature', 'temp', 'climate'];
    
    // Check all fields against keywords
    final allText = '$model $description $friendlyName $vendor';
    
    // Check more specific device types first to avoid misclassification
    if (_containsAny(allText, switchKeywords)) {
      return 'switch';
    }
    
    if (_containsAny(allText, lightKeywords)) {
      return 'light';
    }
    
    if (_containsAny(allText, sensorKeywords)) {
      return 'sensor';
    }
    
    if (_containsAny(allText, contactKeywords)) {
      return 'door_window';
    }
    
    if (_containsAny(allText, thermostatKeywords)) {
      return 'thermostat';
    }
    
    return 'unknown';
  }
  
  static bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  // Get the display name for a device (custom name if available, otherwise friendly name)
  static String getDeviceDisplayName(Device device) {
    if (device.customName != null && device.customName!.isNotEmpty) {
      return device.customName!;
    }
    return device.friendlyName;
  }

  // Get the display name for a device by friendly name from a list of devices
  static String getDeviceDisplayNameByFriendlyName(List<Device> devices, String friendlyName) {
    try {
      final device = devices.firstWhere((d) => d.friendlyName == friendlyName);
      return getDeviceDisplayName(device);
    } catch (e) {
      // If device not found in list, return the friendly name as fallback
      return friendlyName;
    }
  }

  static String getDeviceIcon(String deviceType) {
    switch (deviceType) {
      case 'light':
        return '💡';
      case 'sensor':
        return '📊';
      case 'switch':
        return '🔌';
      case 'door_window':
        return '🚪';
      default:
        return '📱';
    }
  }
}