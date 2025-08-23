import 'dart:convert';
import 'package:http/http.dart' as http;
import 'url_config_service.dart';
import './utils/greeting_utils.dart';

class WeatherService {
  static WeatherData? _cachedWeatherData;
  static DateTime? _lastFetched;
  static const Duration _cacheDuration = Duration(minutes: 10);

  // Get cached weather data if available and not expired
  static WeatherData? get cachedWeather {
    if (_cachedWeatherData != null && _lastFetched != null) {
      if (DateTime.now().difference(_lastFetched!) < _cacheDuration) {
        return _cachedWeatherData;
      }
    }
    return null;
  }

  // Fetch current weather from the server
  static Future<WeatherData?> getCurrentWeather() async {
    // Return cached data if available
    final cached = cachedWeather;
    if (cached != null) {
      return cached;
    }

    final serverUrl = await UrlConfigService.getServerUrl();
    if (serverUrl == null || serverUrl.isEmpty) {
      return null; // No server configured
    }

    try {
      final response = await http.get(
        Uri.parse('$serverUrl/api/weather/current'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final weatherData = WeatherData.fromJson(data);
        
        // Cache the data
        _cachedWeatherData = weatherData;
        _lastFetched = DateTime.now();
        
        return weatherData;
      } else if (response.statusCode == 400) {
        // Weather not configured or disabled
        return null;
      } else {
        throw Exception('Weather API returned status ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching weather: $e');
      return null; // Return null on error to gracefully degrade
    }
  }

  // Clear cached weather data (useful when configuration changes)
  static void clearCache() {
    _cachedWeatherData = null;
    _lastFetched = null;
  }
}

class WeatherData {
  final CurrentWeather current;
  final LocationInfo location;

  WeatherData({
    required this.current,
    required this.location,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      current: CurrentWeather.fromJson(json['current'] ?? {}),
      location: LocationInfo.fromJson(json['location'] ?? {}),
    );
  }
}

class CurrentWeather {
  final double temperature;
  final int weatherCode;
  final String weatherIcon;
  final String weatherDesc;
  final double humidity;
  final double windSpeed;
  final double windDirection;
  final double pressure;
  final double visibility;
  final double uvIndex;
  final bool isDay;
  final DateTime lastUpdated;

  CurrentWeather({
    required this.temperature,
    required this.weatherCode,
    required this.weatherIcon,
    required this.weatherDesc,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.pressure,
    required this.visibility,
    required this.uvIndex,
    required this.isDay,
    required this.lastUpdated,
  });

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    return CurrentWeather(
      temperature: (json['temperature'] ?? 0.0).toDouble(),
      weatherCode: json['weather_code'] ?? 0,
      weatherIcon: json['weather_icon'] ?? 'unknown',
      weatherDesc: json['weather_desc'] ?? 'Unknown',
      humidity: (json['humidity'] ?? 0.0).toDouble(),
      windSpeed: (json['wind_speed'] ?? 0.0).toDouble(),
      windDirection: (json['wind_direction'] ?? 0.0).toDouble(),
      pressure: (json['pressure'] ?? 0.0).toDouble(),
      visibility: (json['visibility'] ?? 0.0).toDouble(),
      uvIndex: (json['uv_index'] ?? 0.0).toDouble(),
      isDay: json['is_day'] ?? true,
      lastUpdated: DateTime.tryParse(json['last_updated'] ?? '') ?? DateTime.now(),
    );
  }

  // Get temperature with unit
  String get temperatureString => '${temperature.round()}°C';
  
  // Get wind speed with unit
  String get windSpeedString => '${windSpeed.round()} km/h';
  
  // Get weather emoji based on weather code and day/night
  String get weatherEmoji {
    switch (weatherCode) {
      case 0: return isDay ? '☀️' : '🌙'; // Clear
      case 1: case 2: case 3: return isDay ? '⛅' : '☁️'; // Cloudy
      case 45: case 48: return '🌫️'; // Fog
      case 51: case 53: case 55: case 56: case 57: return '🌦️'; // Drizzle
      case 61: case 63: case 65: case 66: case 67: return '🌧️'; // Rain
      case 71: case 73: case 75: case 77: case 85: case 86: return '🌨️'; // Snow
      case 80: case 81: case 82: return '🌦️'; // Rain showers
      case 95: case 96: case 99: return '⛈️'; // Thunderstorm
      default: return isDay ? '☀️' : '🌙';
    }
  }
}

class LocationInfo {
  final double latitude;
  final double longitude;
  final String location;
  final String timezone;
  final DateTime currentTime;

  LocationInfo({
    required this.latitude,
    required this.longitude,
    required this.location,
    required this.timezone,
    required this.currentTime,
  });

  factory LocationInfo.fromJson(Map<String, dynamic> json) {
    return LocationInfo(
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      location: json['location'] ?? '',
      timezone: json['timezone'] ?? 'UTC',
      currentTime: DateTime.tryParse(json['current_time'] ?? '') ?? DateTime.now(),
    );
  }

  // Get formatted current time
  String get formattedTime {
    final hour = currentTime.hour;
    final minute = currentTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // Get formatted date
  String get formattedDate {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    
    final weekday = weekdays[currentTime.weekday - 1];
    final month = months[currentTime.month - 1];
    final day = currentTime.day;
    
    return '$weekday, $month $day';
  }

  // Get time of day greeting
  String get greeting {
    return 'Good ${GreetingUtils.getTimeOfDay(dateTime: currentTime).toLowerCase()}';
  }
}