import 'package:flutter/foundation.dart';
import 'url_config_service.dart';

class ApiConfig {
  static String? _cachedBaseUrl;
  
  static Future<String> get baseUrl async {
    if (kIsWeb) {
      // When running as web app, use relative URLs (same server)
      print('[DEBUG] ApiConfig: Web platform, using empty base URL');
      return '';
    } else {
      // Cache the URL to avoid multiple SharedPreferences calls
      _cachedBaseUrl ??= await UrlConfigService.getServerUrl();
      print('[DEBUG] ApiConfig: Native platform, using base URL: $_cachedBaseUrl');
      return _cachedBaseUrl!;
    }
  }
  
  // Clear the cache when URL is updated
  static void clearCache() {
    _cachedBaseUrl = null;
  }

  static Future<String> get apiBaseUrl async => '${await baseUrl}/api';
  
  static Future<String> get zigbeeApiUrl async => '${await baseUrl}/api/zigbee2mqtt';
  
  static Future<String> get manageApiUrl async => '${await baseUrl}/api/manage';
  
  static Future<String> get wsUrl async {
    if (kIsWeb) {
      // For web, use relative WebSocket URL
      final protocol = Uri.base.scheme == 'https' ? 'wss' : 'ws';
      return '${protocol}://${Uri.base.host}:${Uri.base.port}/ws';
    } else {
      // For mobile apps, use configured URL
      final baseUrlStr = await baseUrl;
      final uri = Uri.parse(baseUrlStr);
      final wsProtocol = uri.scheme == 'https' ? 'wss' : 'ws';
      return '$wsProtocol://${uri.host}:${uri.port}/ws';
    }
  }
}