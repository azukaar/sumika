import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../types.dart';
import '../controls/controls.dart';

/// Specialized card widget for smart-plug devices showing toggle, power, and energy
class SmartPlugCard extends ConsumerWidget {
  final Device device;

  const SmartPlugCard({
    super.key,
    required this.device,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exposes = device.definition.exposes ?? [];

    // Find the key exposes we need
    Map<String, dynamic>? stateExpose;
    Map<String, dynamic>? powerExpose;
    Map<String, dynamic>? energyExpose;

    for (var expose in exposes) {
      final property = expose['property'] ?? expose['name'];
      final access = expose['access'] ?? 0;

      switch (property) {
        case 'state':
          if (access != 1 && access != 5) stateExpose = expose;
          break;
        case 'power':
          powerExpose = expose;
          break;
        case 'energy':
          energyExpose = expose;
          break;
      }

      // Check features within composite exposes
      if (expose['features'] != null) {
        for (var feature in expose['features']) {
          final featureProperty = feature['property'] ?? feature['name'];
          final featureAccess = feature['access'] ?? 0;

          switch (featureProperty) {
            case 'state':
              if (featureAccess != 1 && featureAccess != 5)
                stateExpose = feature;
              break;
            case 'power':
              powerExpose = feature;
              break;
            case 'energy':
              energyExpose = feature;
              break;
          }
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle control
        if (stateExpose != null)
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              child: ControlFromZigbeeWidget(
                expose: stateExpose!,
                device: device,
                hideLabel: true,
              ),
            ),
          )
        else
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                'No toggle',
                style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ),
          ),

        const SizedBox(height: 8),

        // Power and Energy display in a row
        Expanded(
          flex: 1,
          child: Row(
            children: [
              // Power display
              Expanded(
                child: _buildMetricDisplay(
                  context,
                  'Power',
                  _getCurrentValue(powerExpose),
                  _getUnit(powerExpose, 'W'),
                  Icons.bolt,
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              // Energy display
              Expanded(
                child: _buildMetricDisplay(
                  context,
                  'Energy',
                  _getCurrentValue(energyExpose),
                  _getUnit(energyExpose, 'Wh'),
                  Icons.energy_savings_leaf,
                  Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricDisplay(
    BuildContext context,
    String label,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(height: 2),
          RichText(
            text: TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              children: [
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.normal,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _getCurrentValue(Map<String, dynamic>? expose) {
    if (expose == null) return '--';

    final property = expose['property'] ?? expose['name'];
    if (property == null || device.state == null) return '--';

    final value = device.state![property];
    if (value == null) return '--';

    if (value is num) {
      if (value == value.toInt()) {
        return value.toInt().toString();
      } else {
        return value.toStringAsFixed(1);
      }
    }

    return value.toString();
  }

  String _getUnit(Map<String, dynamic>? expose, String defaultUnit) {
    if (expose == null) return defaultUnit;
    return expose['unit'] ?? defaultUnit;
  }
}

/// Specialized card widget for sensor devices showing first 4 values in a 2x2 grid
class SensorCard extends ConsumerWidget {
  final Device device;

  const SensorCard({
    super.key,
    required this.device,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exposes = device.definition.exposes ?? [];

    // Find readable sensor values (access 1 or 5 means read-only)
    List<Map<String, dynamic>> sensorValues = [];

    for (var expose in exposes) {
      final access = expose['access'] ?? 0;
      final property = expose['property'] ?? expose['name'];

      // Only include read-only properties (sensors)
      if ((access == 1 || access == 5) && property != null) {
        sensorValues.add(expose);
      }

      // Check features within composite exposes
      if (expose['features'] != null) {
        for (var feature in expose['features']) {
          final featureAccess = feature['access'] ?? 0;
          final featureProperty = feature['property'] ?? feature['name'];

          if ((featureAccess == 1 || featureAccess == 5) &&
              featureProperty != null) {
            sensorValues.add(feature);
          }
        }
      }
    }

    // Sort by priority and take first 4
    sensorValues
        .sort((a, b) => _getSensorPriority(a).compareTo(_getSensorPriority(b)));
    final displayValues = sensorValues.take(4).toList();

    if (displayValues.isEmpty) {
      return Center(
        child: Text(
          'No sensor data',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
      );
    }

    return Column(
      children: [
        // First row
        Expanded(
          child: Row(
            children: [
              if (displayValues.isNotEmpty)
                Expanded(child: _buildSensorValue(context, displayValues[0]))
              else
                const Expanded(child: SizedBox.shrink()),
              if (displayValues.length > 1) ...[
                const SizedBox(width: 8),
                Expanded(child: _buildSensorValue(context, displayValues[1])),
              ] else
                const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
        if (displayValues.length > 2) ...[
          const SizedBox(height: 8),
          // Second row
          Expanded(
            child: Row(
              children: [
                if (displayValues.length > 2)
                  Expanded(child: _buildSensorValue(context, displayValues[2]))
                else
                  const Expanded(child: SizedBox.shrink()),
                if (displayValues.length > 3) ...[
                  const SizedBox(width: 8),
                  Expanded(child: _buildSensorValue(context, displayValues[3])),
                ] else
                  const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSensorValue(BuildContext context, Map<String, dynamic> expose) {
    final property = expose['property'] ?? expose['name'] ?? 'Unknown';
    final label = expose['label'] ?? property;
    final unit = expose['unit'] ?? '';
    final icon = _getSensorIcon(property);
    final color = _getSensorColor(context, property);

    final value = _getCurrentValue(expose);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(height: 2),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              children: [
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.normal,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            _getShortLabel(label),
            style: TextStyle(
              fontSize: 8,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getCurrentValue(Map<String, dynamic> expose) {
    final property = expose['property'] ?? expose['name'];
    if (property == null || device.state == null) return '--';

    final value = device.state![property];
    if (value == null) return '--';

    if (value is num) {
      if (value == value.toInt()) {
        return value.toInt().toString();
      } else {
        return value.toStringAsFixed(1);
      }
    } else if (value is bool) {
      return value ? 'Yes' : 'No';
    }

    return value.toString();
  }

  int _getSensorPriority(Map<String, dynamic> expose) {
    final property = expose['property'] ?? expose['name'] ?? '';

    // Priority order for sensor values
    const priorities = {
      'temperature': 0,
      'humidity': 1,
      'pressure': 2,
      'battery': 3,
      'illuminance': 4,
      'occupancy': 5,
      'contact': 6,
      'motion': 7,
      'co2': 8,
      'pm25': 9,
      'voltage': 10,
      'current': 11,
      'power': 12,
      'energy': 13,
    };

    for (var key in priorities.keys) {
      if (property.toLowerCase().contains(key)) {
        return priorities[key]!;
      }
    }

    return 999; // Default for unknown properties
  }

  IconData _getSensorIcon(String property) {
    final prop = property.toLowerCase();

    if (prop.contains('temperature')) return Icons.thermostat;
    if (prop.contains('humidity')) return Icons.water_drop;
    if (prop.contains('pressure')) return Icons.speed;
    if (prop.contains('battery')) return Icons.battery_std;
    if (prop.contains('illuminance') || prop.contains('lux'))
      return Icons.wb_sunny;
    if (prop.contains('occupancy') || prop.contains('motion'))
      return Icons.motion_photos_on;
    if (prop.contains('contact') ||
        prop.contains('door') ||
        prop.contains('window')) return Icons.door_front_door;
    if (prop.contains('co2')) return Icons.air;
    if (prop.contains('pm25') || prop.contains('pm2.5')) return Icons.masks;
    if (prop.contains('voltage')) return Icons.electric_bolt;
    if (prop.contains('current')) return Icons.electrical_services;
    if (prop.contains('power')) return Icons.bolt;
    if (prop.contains('energy')) return Icons.energy_savings_leaf;

    return Icons.sensors;
  }

  Color _getSensorColor(BuildContext context, String property) {
    final prop = property.toLowerCase();

    if (prop.contains('temperature')) return Colors.orange;
    if (prop.contains('humidity')) return Colors.blue;
    if (prop.contains('pressure')) return Colors.purple;
    if (prop.contains('battery')) return Colors.green;
    if (prop.contains('illuminance') || prop.contains('lux'))
      return Colors.amber;
    if (prop.contains('occupancy') || prop.contains('motion'))
      return Colors.red;
    if (prop.contains('contact') ||
        prop.contains('door') ||
        prop.contains('window')) return Colors.brown;
    if (prop.contains('co2')) return Colors.grey;
    if (prop.contains('pm25') || prop.contains('pm2.5'))
      return Colors.deepOrange;
    if (prop.contains('voltage')) return Colors.yellow;
    if (prop.contains('current')) return Colors.cyan;
    if (prop.contains('power')) return Theme.of(context).colorScheme.primary;
    if (prop.contains('energy')) return Theme.of(context).colorScheme.secondary;

    return Theme.of(context).colorScheme.tertiary;
  }

  String _getShortLabel(String label) {
    // Shorten common labels to fit in small spaces
    final shortcuts = {
      'temperature': 'Temp',
      'humidity': 'Hum',
      'pressure': 'Press',
      'battery': 'Batt',
      'illuminance': 'Light',
      'occupancy': 'Occ',
      'contact': 'Door',
      'motion': 'Motion',
      'local_temperature': 'Temp',
      'relative_humidity': 'Hum',
      'atmospheric_pressure': 'Press',
      'battery_percentage': 'Batt',
    };

    final lowerLabel = label.toLowerCase();
    for (var key in shortcuts.keys) {
      if (lowerLabel.contains(key)) {
        return shortcuts[key]!;
      }
    }

    // Truncate long labels
    if (label.length > 6) {
      return label.substring(0, 6);
    }

    return label;
  }
}
