import 'package:flutter/foundation.dart';
import 'url_config_service_interface.dart';

// Web-only implementation - no SharedPreferences needed
class UrlConfigService {
  // Get the server URL - always empty for web (relative URLs)
  static Future<String> getServerUrl() async {
    // For web, always use relative URLs (same server)
    return '';
  }
  
  // Set the server URL - no-op for web
  static Future<void> setServerUrl(String url) async {
    // Web apps don't save URLs
  }
  
  // Check if server URL is configured - always true for web
  static Future<bool> isServerUrlConfigured() async {
    // Web apps are always "configured"
    return true;
  }
  
  // Clear the server URL - no-op for web
  static Future<void> clearServerUrl() async {
    // Web apps don't store URLs
  }
  
  // Validate URL format
  static bool isValidUrl(String url) => UrlConfigBase.isValidUrl(url);
  
  // Format URL (ensure proper format)
  static String formatUrl(String url) => UrlConfigBase.formatUrl(url);
}