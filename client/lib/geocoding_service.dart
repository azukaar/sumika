import 'dart:convert';
import 'package:http/http.dart' as http;
import 'url_config_service.dart';

class GeocodingService {
  static const int _defaultCount = 10;
  static const int _maxCount = 50;

  // City/Location models
  static GeocodingResult? _selectedCity;
  static TimezoneInfo? _selectedTimezone;
  
  static GeocodingResult? get selectedCity => _selectedCity;
  static TimezoneInfo? get selectedTimezone => _selectedTimezone;
  
  static void setSelectedCity(GeocodingResult? city) {
    _selectedCity = city;
  }
  
  static void setSelectedTimezone(TimezoneInfo? timezone) {
    _selectedTimezone = timezone;
  }

  // Search for cities using the server's geocoding API
  static Future<List<GeocodingResult>> searchCities(String query, {int count = _defaultCount}) async {
    if (query.length < 2) {
      return [];
    }

    final serverUrl = await UrlConfigService.getServerUrl();
    if (serverUrl == null || serverUrl.isEmpty) {
      throw Exception('No server URL configured');
    }

    try {
      final uri = Uri.parse('$serverUrl/api/geocoding/search')
          .replace(queryParameters: {
        'name': query,
        'count': count.clamp(1, _maxCount).toString(),
      });

      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>? ?? [];
        
        return results.map((json) => GeocodingResult.fromJson(json)).toList();
      } else if (response.statusCode == 400) {
        // Handle bad request (e.g., query too short)
        return [];
      } else {
        throw Exception('Geocoding API returned status ${response.statusCode}');
      }
    } catch (e) {
      print('Error searching cities: $e');
      throw Exception('Failed to search cities: $e');
    }
  }

  // Search for timezones using the server's timezone API
  static Future<List<TimezoneInfo>> searchTimezones(String query, {int limit = 50}) async {
    final serverUrl = await UrlConfigService.getServerUrl();
    if (serverUrl == null || serverUrl.isEmpty) {
      throw Exception('No server URL configured');
    }

    try {
      final uri = Uri.parse('$serverUrl/api/timezones/search')
          .replace(queryParameters: {
        'q': query,
        'limit': limit.toString(),
      });

      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>? ?? [];
        
        return results.map((json) => TimezoneInfo.fromJson(json)).toList();
      } else {
        throw Exception('Timezone API returned status ${response.statusCode}');
      }
    } catch (e) {
      print('Error searching timezones: $e');
      throw Exception('Failed to search timezones: $e');
    }
  }

  // Get all available timezones
  static Future<List<TimezoneInfo>> getAllTimezones() async {
    final serverUrl = await UrlConfigService.getServerUrl();
    if (serverUrl == null || serverUrl.isEmpty) {
      throw Exception('No server URL configured');
    }

    try {
      final response = await http.get(
        Uri.parse('$serverUrl/api/timezones'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>? ?? [];
        
        return results.map((json) => TimezoneInfo.fromJson(json)).toList();
      } else {
        throw Exception('Timezone API returned status ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting all timezones: $e');
      throw Exception('Failed to get timezones: $e');
    }
  }
}

class GeocodingResult {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final double elevation;
  final String featureCode;
  final String countryCode;
  final int countryId;
  final String country;
  final String timezone;
  final int population;
  final String? admin1;
  final String? admin2;
  final String? admin3;
  final String? admin4;

  GeocodingResult({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.elevation,
    required this.featureCode,
    required this.countryCode,
    required this.countryId,
    required this.country,
    required this.timezone,
    required this.population,
    this.admin1,
    this.admin2,
    this.admin3,
    this.admin4,
  });

  factory GeocodingResult.fromJson(Map<String, dynamic> json) {
    return GeocodingResult(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      elevation: (json['elevation'] ?? 0.0).toDouble(),
      featureCode: json['feature_code'] ?? '',
      countryCode: json['country_code'] ?? '',
      countryId: json['country_id'] ?? 0,
      country: json['country'] ?? '',
      timezone: json['timezone'] ?? 'UTC',
      population: json['population'] ?? 0,
      admin1: json['admin1'],
      admin2: json['admin2'],
      admin3: json['admin3'],
      admin4: json['admin4'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'elevation': elevation,
      'feature_code': featureCode,
      'country_code': countryCode,
      'country_id': countryId,
      'country': country,
      'timezone': timezone,
      'population': population,
      'admin1': admin1,
      'admin2': admin2,
      'admin3': admin3,
      'admin4': admin4,
    };
  }

  // Display name for dropdown
  String get displayName {
    final parts = <String>[name];
    if (admin1 != null && admin1!.isNotEmpty) {
      parts.add(admin1!);
    }
    parts.add(country);
    return parts.join(', ');
  }

  // Short display name for selected items
  String get shortDisplayName {
    return '$name, $country';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GeocodingResult && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => displayName;
}

class TimezoneInfo {
  final String id;
  final String displayName;
  final String region;
  final String city;

  TimezoneInfo({
    required this.id,
    required this.displayName,
    required this.region,
    required this.city,
  });

  factory TimezoneInfo.fromJson(Map<String, dynamic> json) {
    return TimezoneInfo(
      id: json['id'] ?? '',
      displayName: json['display_name'] ?? '',
      region: json['region'] ?? '',
      city: json['city'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'region': region,
      'city': city,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TimezoneInfo && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => displayName;
}