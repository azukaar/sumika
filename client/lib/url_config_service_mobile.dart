import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'url_config_service_interface.dart';

class UrlConfigService {
  static const String _serverUrlKey = 'server_url';
  static SharedPreferences? _prefs;
  
  // Initialize SharedPreferences
  static Future<void> _initialize() async {
    if (kIsWeb) {
      // Web apps don't need preferences (shouldn't happen in this file)
      return;
    }
    
    try {
      _prefs ??= await SharedPreferences.getInstance();
    } catch (e) {
      print('Warning: Failed to initialize SharedPreferences: $e');
      // _prefs will remain null, other methods handle this gracefully
    }
  }
  
  // Get the server URL
  static Future<String> getServerUrl() async {
    if (kIsWeb) {
      // For web, always use relative URLs (same server)
      return '';
    }
    
    await _initialize();
    // For mobile apps, get from SharedPreferences or return default
    return _prefs?.getString(_serverUrlKey) ?? UrlConfigBase.defaultMobileUrl;
  }
  
  // Set the server URL (only for mobile apps)
  static Future<void> setServerUrl(String url) async {
    if (kIsWeb) {
      // Don't save URLs for web apps
      return;
    }
    
    await _initialize();
    if (_prefs != null) {
      await _prefs!.setString(_serverUrlKey, url);
    }
  }
  
  // Check if server URL is configured (for mobile apps)
  static Future<bool> isServerUrlConfigured() async {
    if (kIsWeb) {
      // Web apps are always "configured"
      return true;
    }
    
    await _initialize();
    final url = _prefs?.getString(_serverUrlKey);
    return url != null && url.isNotEmpty;
  }
  
  // Clear the server URL (for resetting configuration)
  static Future<void> clearServerUrl() async {
    if (kIsWeb) {
      return;
    }
    
    await _initialize();
    if (_prefs != null) {
      await _prefs!.remove(_serverUrlKey);
    }
  }
  
  // Validate URL format
  static bool isValidUrl(String url) => UrlConfigBase.isValidUrl(url);
  
  // Format URL (ensure proper format)
  static String formatUrl(String url) => UrlConfigBase.formatUrl(url);
}