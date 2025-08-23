import 'package:flutter/material.dart';
import 'weather_service.dart';
import './utils/greeting_utils.dart';

class WeatherWidget extends StatefulWidget {
  final String? selectedZone;

  const WeatherWidget({
    Key? key,
    this.selectedZone,
  }) : super(key: key);

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  WeatherData? _weatherData;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadWeatherData();
  }

  Future<void> _loadWeatherData() async {
    // Check cached data first
    final cached = WeatherService.cachedWeather;
    if (cached != null) {
      setState(() {
        _weatherData = cached;
        _errorMessage = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final weather = await WeatherService.getCurrentWeather();
      if (mounted) {
        setState(() {
          _weatherData = weather;
          _isLoading = false;
          _errorMessage = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load weather';
          print('Weather error: $e');
        });
      }
    }
  }

  // Fallback widget when weather is not available
  Widget _buildFallbackHeader() {
    final greeting = 'Good ${GreetingUtils.getTimeOfDay().toLowerCase()}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            fontWeight: FontWeight.normal,
          ),
        ),
        Text(
          widget.selectedZone?.replaceAll('_', ' ') ?? 'Dashboard',
          style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
      ],
    );
  }

  // Weather widget with time and weather info
  Widget _buildWeatherHeader() {
    final weather = _weatherData!;
    final location = weather.location;
    final current = weather.current;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting - only show if screen width >= 400px
              if (MediaQuery.of(context).size.width >= 400)
                Text(
                  location.greeting,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              
              // Time
              Text(
                location.formattedTime,
                style: TextStyle(
                  fontSize: 28,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              // Date
              Text(
                location.formattedDate,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        
        // Weather info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
                Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                current.weatherEmoji,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    current.temperatureString,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    current.weatherDesc,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              
              // Additional info for larger screens
              if (MediaQuery.of(context).size.width > 450) ...[
                const SizedBox(width: 16),
                Container(
                  width: 1,
                  height: 30,
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (current.windSpeed > 0) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.air_rounded,
                            size: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            current.windSpeedString,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (current.humidity > 0) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.water_drop_rounded,
                            size: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${current.humidity.round()}%',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Loading state
  Widget _buildLoadingHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 14,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 180,
                height: 16,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 100,
          height: 50,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingHeader();
    }
    
    if (_weatherData != null && _errorMessage.isEmpty) {
      return _buildWeatherHeader();
    }
    
    // Fallback to simple header if weather is not available
    return _buildFallbackHeader();
  }
}

// Extension to make the widget refreshable
extension WeatherWidgetRefresh on WeatherWidget {
  static void refreshWeather() {
    WeatherService.clearCache();
  }
}