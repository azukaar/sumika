import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import './types.dart';
import './controls/controls.dart';
import './zigbee-service.dart';
import './utils/device_utils.dart';
import './widgets/card_interaction_indicator.dart';
import './widgets/specialized_device_cards.dart';

enum DeviceWidgetMode { mini, full }

class DeviceWidget extends ConsumerWidget {
  final Device device;
  final DeviceWidgetMode mode;
  final VoidCallback? onTap;

  const DeviceWidget({
    super.key,
    required this.device,
    required this.mode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (mode) {
      case DeviceWidgetMode.mini:
        return _buildMiniCard(context, ref);
      case DeviceWidgetMode.full:
        return _buildFullCard(context, ref);
    }
  }

  Widget _buildMiniCard(BuildContext context, WidgetRef ref) {
    final cleanModel = device.definition.model?.replaceAll(' ', '-');
    final status = _getDeviceStatus();
    final isActive = status == 'active';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surface.withOpacity(0.8),
          ],
        ),
        border: Border.all(
          color: isActive
              ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
              : Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          if (isActive)
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: GestureDetector(
        onSecondaryTap: onTap, // Right click
        onLongPress: () {
          HapticFeedback.mediumImpact();
          onTap?.call();
        }, // Long press with haptic feedback
        child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Device header with image and status
                Row(
                  children: [
                    // Device image with status indicator
                    Stack(
                      children: [
                        _buildDeviceImage(cleanModel, 36, context),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getStatusColor(status),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.surface,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DeviceUtils.getDeviceDisplayName(device),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              color: _getStatusColor(status),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const CardInteractionIndicator(
                      customTooltip: 'Hold or right-click to view device details',
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Device controls (simplified for dashboard)
                Expanded(
                  child: _buildSimplifiedControls(context, ref),
                ),
              ],
            ), // Column
        ), // Container (GestureDetector's child)
      ), // GestureDetector
    ); // Main Container
  }

  Widget _buildFullCard(BuildContext context, WidgetRef ref) {
    final cleanModel = device.definition.model?.replaceAll(' ', '-');
    final status = _getDeviceStatus();
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Tooltip(
        message: 'Tap for details',
        child: GestureDetector(
          onTap: onTap, // Left click / touch
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildDeviceImage(cleanModel, 60, context),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DeviceUtils.getDeviceDisplayName(device),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        device.definition.description ?? 'Smart Device',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${device.definition.vendor ?? ''} ${device.definition.model ?? ''}'
                            .trim(),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (device.zones != null && device.zones!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          device.zones!.join(', ').replaceAll('_', ' '),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'No zones',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceImage(
      String? cleanModel, double size, BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size < 50 ? 12 : 16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
            Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size < 50 ? 12 : 16),
        child: cleanModel != null && cleanModel.isNotEmpty
            ? Image.network(
                'https://www.zigbee2mqtt.io/images/devices/$cleanModel.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDeviceIconFallback(size, context);
                },
              )
            : _buildDeviceIconFallback(size, context),
      ),
    );
  }

  Widget _buildDeviceIconFallback(double size, BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
            Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(size < 50 ? 12 : 16),
      ),
      child: Icon(
        _getDeviceIcon(),
        size: size * 0.5,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  IconData _getDeviceIcon() {
    final deviceType = device.definition.model?.toLowerCase() ?? '';

    if (deviceType.contains('light') || deviceType.contains('bulb')) {
      return Icons.lightbulb_outline;
    } else if (deviceType.contains('switch') || deviceType.contains('plug')) {
      return Icons.power;
    } else if (deviceType.contains('sensor') || deviceType.contains('motion')) {
      return Icons.sensors;
    } else if (deviceType.contains('door') || deviceType.contains('window')) {
      return Icons.door_front_door_outlined;
    } else {
      return Icons.device_hub;
    }
  }

  String _getDeviceStatus() {
    if (!device.supported) {
      return "unsupported";
    }

    // Priority 1: Interview status (always show if interviewing)
    if (device.interviewing) {
      return "connecting";
    }

    // Priority 2: If interview not completed, show offline
    if (!device.interviewCompleted) {
      return "offline";
    }

    // Priority 3: Use last_seen for completed devices
    if (device.lastSeen != null) {
      final lastSeenTime = DateTime.tryParse(device.lastSeen!);
      if (lastSeenTime != null) {
        final hoursSince = DateTime.now().difference(lastSeenTime).inHours;
        if (hoursSince < 24) {
          return "active"; // Recently seen
        } else {
          return "inactive"; // Not seen in 24h
        }
      }
    }

    // Fallback: no last_seen data available
    return "unknown";
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "active":
        return Colors.green;
      case "connecting":
        return Colors.orange;
      case "inactive":
        return Colors.orange[300]!;
      case "offline":
      case "unsupported":
        return Colors.red;
      case "unknown":
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case "active":
        return Icons.check_circle;
      case "connecting":
        return Icons.hourglass_empty;
      case "inactive":
        return Icons.schedule;
      case "offline":
        return Icons.offline_bolt;
      case "unsupported":
        return Icons.error;
      case "unknown":
        return Icons.help;
      default:
        return Icons.help;
    }
  }

  Widget _buildSimplifiedControls(BuildContext context, WidgetRef ref) {
    final exposes = device.definition.exposes;
    if (exposes == null || exposes.isEmpty) {
      return Center(
        child: Text(
          'No controls',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
      );
    }

    // Get device type for smart control selection
    final deviceType = DeviceUtils.getDeviceType(device);

    // Use specialized cards for specific device types
    switch (deviceType) {
      case 'switch':
        // Check if this is a smart plug (has power/energy measurements)
        bool hasPowerMeasurement = false;
        for (var expose in exposes) {
          final property = expose['property'] ?? expose['name'];
          if (property == 'power' || property == 'energy') {
            hasPowerMeasurement = true;
            break;
          }
          // Check features within composite exposes
          if (expose['features'] != null) {
            for (var feature in expose['features']) {
              final featureProperty = feature['property'] ?? feature['name'];
              if (featureProperty == 'power' || featureProperty == 'energy') {
                hasPowerMeasurement = true;
                break;
              }
            }
          }
          if (hasPowerMeasurement) break;
        }
        
        if (hasPowerMeasurement) {
          return SmartPlugCard(device: device);
        }
        break;
      
      case 'sensor':
        return SensorCard(device: device);
      
      case 'light':
        // For lights, find and show brightness control specifically
        for (var expose in exposes) {
          if (expose is Map<String, dynamic>) {
            if (expose['property'] == 'brightness' ||
                expose['name'] == 'brightness') {
              return Container(
                constraints: const BoxConstraints(maxHeight: 80),
                child: ControlFromZigbeeWidget(
                    expose: expose,
                    device: device,
                    hideIcons: true,
                    hideLabel: true),
              );
            }
            // Check features within composite exposes
            if (expose['features'] != null) {
              for (var feature in expose['features']) {
                if (feature['property'] == 'brightness' ||
                    feature['name'] == 'brightness') {
                  return Container(
                    constraints: const BoxConstraints(maxHeight: 80),
                    child: ControlFromZigbeeWidget(
                        expose: feature,
                        device: device,
                        hideIcons: true,
                        hideLabel: true),
                  );
                }
              }
            }
          }
        }

        // Fallback if no brightness found - use state control
        final primaryControl =
            _getPrimaryControlForDeviceType(deviceType, exposes);
        if (primaryControl != null) {
          return Container(
            constraints: const BoxConstraints(maxHeight: 80),
            child:
                ControlFromZigbeeWidget(expose: primaryControl, device: device),
          );
        }
        break;
    }

    // For other devices, use existing control logic
    final primaryControl = _getPrimaryControlForDeviceType(deviceType, exposes);

    if (primaryControl == null) {
      return Center(
        child: Text(
          'Tap for details',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
      );
    }

    // Use the existing control system but in a compact form
    return Container(
      constraints: const BoxConstraints(maxHeight: 80),
      child: ControlFromZigbeeWidget(expose: primaryControl, device: device),
    );
  }

  Map<String, dynamic>? _getPrimaryControlForDeviceType(
      String deviceType, List<dynamic> exposes) {
    for (var expose in exposes) {
      final property = expose['property'] ?? expose['name'] ?? 'unnamed';
      final type = expose['type'];
      final access = expose['access'];
    }

    // Priority order for different device types
    Map<String, List<String>> devicePriorities = {
      'light': ['state', 'brightness', 'color_temp', 'color_hs'],
      'switch': ['state'],
      'sensor':
          [], // Sensors are typically read-only, show nothing in mini mode
      'door_window': ['contact', 'state'],
      'thermostat': [
        'local_temperature',
        'occupied_heating_setpoint',
        'system_mode'
      ],
      'unknown': ['state', 'brightness'], // Default fallback
    };

    final priorities =
        devicePriorities[deviceType] ?? devicePriorities['unknown']!;
    // Find the highest priority control that exists and is writable
    for (String priority in priorities) {
      for (var expose in exposes) {
        final access = expose['access'];
        final property = expose['property'];
        final name = expose['name'];

        // Skip read-only controls (access 1 or 5)
        if (access == 1 || access == 5) continue;

        // Check if this expose matches our priority
        if (property == priority || name == priority) {
          return expose;
        }

        // Handle composite controls (like color)
        if (expose['type'] == 'composite' && name == priority) {
          return expose;
        }

        // Handle features within composite controls
        if (expose['features'] != null) {
          for (var feature in expose['features']) {
            if (feature['property'] == priority ||
                feature['name'] == priority) {
              final featureAccess = feature['access'];
              if (featureAccess != 1 && featureAccess != 5) {
                return feature;
              }
            }
          }
        }
      }
    }

    // If device type is unknown or no priority match, use intelligent fallback
    if (deviceType == 'unknown') {
      return _getIntelligentFallbackControl(exposes);
    }

    // If no priority match for known type, find any writable control
    for (var expose in exposes) {
      final access = expose['access'];
      if (access != 1 && access != 5) {
        // Not read-only
        return expose;
      }

      // Check features for writable controls
      if (expose['features'] != null) {
        for (var feature in expose['features']) {
          final featureAccess = feature['access'];
          if (featureAccess != 1 && featureAccess != 5) {
            return feature;
          }
        }
      }
    }
    return null; // No writable controls found
  }

  Map<String, dynamic>? _getIntelligentFallbackControl(List<dynamic> exposes) {
    // For unknown devices, prioritize common control types
    final commonPriorities = [
      'state', // On/off switches
      'brightness', // Dimmers
      'position', // Blinds, covers
      'temperature', // Thermostats
      'volume', // Audio devices
      'level', // Generic level controls
    ];

    for (String priority in commonPriorities) {
      for (var expose in exposes) {
        final access = expose['access'];
        final property = expose['property'];

        if (access != 1 && access != 5 && property == priority) {
          return expose;
        }

        // Check features
        if (expose['features'] != null) {
          for (var feature in expose['features']) {
            final featureAccess = feature['access'];
            final featureProperty = feature['property'];
            if (featureAccess != 1 &&
                featureAccess != 5 &&
                featureProperty == priority) {
              return feature;
            }
          }
        }
      }
    }

    return null;
  }

  Widget _buildQuickControls(BuildContext context) {
    final exposes = device.definition.exposes;
    if (exposes == null || exposes.isEmpty) {
      return const SizedBox();
    }

    // Find primary control and use the existing control system
    for (var expose in exposes) {
      final access = expose['access'];

      if (access == 1 || access == 5) continue;

      // Use existing control but in a constrained container
      return Container(
        constraints: const BoxConstraints(maxWidth: 100, maxHeight: 40),
        child: ControlFromZigbeeWidget(expose: expose, device: device),
      );
    }

    return const SizedBox();
  }
}
