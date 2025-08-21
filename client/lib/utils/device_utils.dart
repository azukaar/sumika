import '../types.dart';

class DeviceUtils {
  static String getDeviceType(Device device) {
    // Use server-side category if available (this is the authoritative source)
    if (device.customCategory != null && device.customCategory!.isNotEmpty) {
      return device.customCategory!;
    }
    
    // If no server-side category is available, return unknown
    // The server is responsible for all device categorization
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