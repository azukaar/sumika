import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UrlConfigService {
  static const String _serverUrlKey = 'server_url';
  static const String _defaultMobileUrl = 'http://localhost:8081';
  
  static SharedPreferences? _prefs;
  
  // Initialize SharedPreferences
  static Future<void> initialize() async {
    if (kIsWeb) {
      // Web apps don't need preferences
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
    
    await initialize();
    // For mobile apps, get from SharedPreferences or return default
    return _prefs?.getString(_serverUrlKey) ?? _defaultMobileUrl;
  }
  
  // Set the server URL (only for mobile apps)
  static Future<void> setServerUrl(String url) async {
    if (kIsWeb) {
      // Don't save URLs for web apps
      return;
    }
    
    await initialize();
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
    
    await initialize();
    final url = _prefs?.getString(_serverUrlKey);
    return url != null && url.isNotEmpty;
  }
  
  // Clear the server URL (for resetting configuration)
  static Future<void> clearServerUrl() async {
    if (kIsWeb) {
      return;
    }
    
    await initialize();
    if (_prefs != null) {
      await _prefs!.remove(_serverUrlKey);
    }
  }
  
  // Validate URL format
  static bool isValidUrl(String url) {
    if (url.isEmpty) return false;
    
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https') && uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }
  
  // Format URL (ensure proper format)
  static String formatUrl(String url) {
    url = url.trim();
    
    // Remove trailing slash
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    
    // Add http:// if no scheme
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    
    return url;
  }
}