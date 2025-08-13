import 'package:flutter/foundation.dart';

// Shared interface - just defines the contract
// Note: Dart doesn't support static abstract methods, so this is just documentation

// Shared implementation for utility methods
class UrlConfigBase {
  static const String defaultMobileUrl = 'http://localhost:8081';
  
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