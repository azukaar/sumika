import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../types.dart';
import '../zigbee-service.dart';
import '../utils/device_utils.dart';
import '../device-widget.dart';
import './zone_control.dart';
import './zone_helpers.dart';

/// A master control widget that displays zone-level controls for multiple devices
class MasterControlWidget extends ConsumerWidget {
  final List<Device> devices;
  final bool showIndividualControls;
  final bool compactMode;

  const MasterControlWidget({
    Key? key,
    required this.devices,
    this.showIndividualControls = false,
    this.compactMode = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the devicesProvider for real-time updates
    final devicesState = ref.watch(devicesProvider);
    
    return devicesState.when(
      data: (allDevices) {
        // Get updated devices with current state
        final currentDevices = devices.map((device) {
          return allDevices.firstWhere(
            (d) => d.friendlyName == device.friendlyName,
            orElse: () => device,
          );
        }).toList();
        
        if (currentDevices.isEmpty) {
          return const Center(child: Text('No devices'));
        }

        // Determine device type (assuming all devices in zone are same type)
        final deviceType = DeviceUtils.getDeviceType(currentDevices.first);
        
        // Get common controls across all devices
        final commonControls = ZoneControlHelpers.getCommonControls(currentDevices);
        
        // Prioritize controls based on device type
        final prioritizedControls = ZoneControlHelpers.prioritizeControls(commonControls, deviceType);

        if (compactMode) {
          return _buildCompactControls(prioritizedControls, deviceType, currentDevices);
        } else {
          return _buildFullControls(prioritizedControls, deviceType, currentDevices);
        }
      },
      loading: () => _buildLoadingState(),
      error: (error, stack) => _buildErrorState(error),
    );
  }
  
  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
  
  Widget _buildErrorState(Object error) {
    return Center(
      child: Text('Error loading devices: $error'),
    );
  }

  /// Build compact controls (for dashboard super card)
  Widget _buildCompactControls(List<Map<String, dynamic>> controls, String deviceType, List<Device> currentDevices) {
    // For compact mode, show only the most important control
    if (controls.isEmpty) {
      return const Center(child: Text('No controls available'));
    }

    // Find the primary control (usually brightness for lights, state for switches)
    Map<String, dynamic>? primaryControl;
    
    if (deviceType == 'light') {
      // For lights, prioritize brightness if available
      primaryControl = controls.firstWhere(
        (c) => (c['property'] ?? c['name']) == 'brightness',
        orElse: () => controls.first,
      );
    } else {
      // For other devices, use the first available control
      primaryControl = controls.first;
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 80),
      child: ZoneControlFromZigbeeWidget(
        expose: primaryControl,
        devices: devices,
        hideIcons: true,
        hideLabel: true,
      ),
    );
  }

  /// Build full controls (for modal or detail view)
  Widget _buildFullControls(List<Map<String, dynamic>> controls, String deviceType, List<Device> currentDevices) {
    if (controls.isEmpty) {
      return const Center(child: Text('No controls available'));
    }

    // Limit controls for modal view to avoid clutter - show the most important ones
    // For lights: state, brightness, color_temp, and any color controls
    final displayControls = <Map<String, dynamic>>[];
    
    // Always include the first 3 controls
    displayControls.addAll(controls.take(3));
    
    // Also include color controls if they exist (and not already included)
    for (var control in controls.skip(3)) {
      final property = control['property'] ?? control['name'];
      if (property == 'color_hs' || property == 'color' || control['name'] == 'color_hs') {
        displayControls.add(control);
        break; // Only add one color control
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Master controls (limited for modal)
        ...displayControls.map((control) => _buildControlCard(control, currentDevices)).toList(),
        
        // Individual device controls (if requested)
        if (showIndividualControls) ...[
          const SizedBox(height: 24),
          _buildIndividualDevicesSection(currentDevices),
        ],
      ],
    );
  }

  /// Build a card for each control type
  Widget _buildControlCard(Map<String, dynamic> control, List<Device> currentDevices) {
    final property = control['property'] ?? control['name'];
    final type = control['type'];
    
    IconData icon;
    String title;
    Color color;
    
    // Determine icon and title based on control type
    switch (property) {
      case 'state':
        icon = Icons.power_settings_new;
        title = 'Power';
        color = Colors.green;
        break;
      case 'brightness':
        icon = Icons.brightness_6;
        title = 'Brightness';
        color = Colors.orange;
        break;
      case 'color_temp':
        icon = Icons.wb_sunny;
        title = 'Color Temperature';
        color = Colors.amber;
        break;
      case 'color_hs':
      case 'color':
        icon = Icons.palette;
        title = 'Color';
        color = Colors.purple;
        break;
      default:
        icon = Icons.tune;
        title = property?.toString().replaceAll('_', ' ').toUpperCase() ?? 'Control';
        color = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                // Debug label with tooltip (only in debug mode)
                if (kDebugMode) ...[
                  _buildDebugTooltip(control, property, type),
                ],
              ],
            ),
            const SizedBox(height: 16),
            ZoneControlFromZigbeeWidget(
              expose: control,
              devices: currentDevices,
              hideIcons: false,
              hideLabel: false,
            ),
          ],
        ),
      ),
    );
  }

  /// Build debug tooltip with current values from devices
  Widget _buildDebugTooltip(Map<String, dynamic> control, String? property, String? type) {
    return Consumer(
      builder: (context, ref, child) {
        final devicesState = ref.watch(devicesProvider);
        
        return devicesState.when(
          data: (allDevices) {
            // Get current device states
            final currentDevices = devices.map((device) {
              return allDevices.firstWhere(
                (d) => d.friendlyName == device.friendlyName,
                orElse: () => device,
              );
            }).toList();

            // Collect current values from all devices
            final values = <String>[];
            for (var device in currentDevices) {
              final state = device.state ?? {};
              final value = state[property];
              if (value != null) {
                values.add('${DeviceUtils.getDeviceDisplayName(device)}: $value');
              }
            }

            // Create detailed tooltip content
            final tooltipText = '''
Property: $property
Type: $type
Devices: ${currentDevices.length}
Access: ${control['access'] ?? 'unknown'}
${control['value_min'] != null ? 'Min: ${control['value_min']}' : ''}
${control['value_max'] != null ? 'Max: ${control['value_max']}' : ''}
${control['value_on'] != null ? 'On: ${control['value_on']}' : ''}
${control['value_off'] != null ? 'Off: ${control['value_off']}' : ''}

Current Values:
${values.isEmpty ? 'No values' : values.join('\n')}
'''.trim();

            return Tooltip(
              message: tooltipText,
              textStyle: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: Colors.white,
              ),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              preferBelow: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[400]!, width: 0.5),
                ),
                child: Text(
                  'prop: ${property ?? "null"} | type: ${type ?? "null"}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[700],
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            );
          },
          loading: () => _buildSimpleDebugLabel(property, type),
          error: (error, stack) => _buildSimpleDebugLabel(property, type),
        );
      },
    );
  }

  /// Build simple debug label (fallback when data is loading/error)
  Widget _buildSimpleDebugLabel(String? property, String? type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[400]!, width: 0.5),
      ),
      child: Text(
        'prop: ${property ?? "null"} | type: ${type ?? "null"}',
        style: TextStyle(
          fontSize: 10,
          color: Colors.grey[700],
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  /// Build individual devices section
  Widget _buildIndividualDevicesSection(List<Device> currentDevices) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Individual Controls:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: currentDevices.length,
              itemBuilder: (context, index) {
                final device = currentDevices[index];
                return DeviceWidget(
                  key: ValueKey('device-${device.friendlyName}-${device.state.hashCode}'),
                  device: device,
                  mode: DeviceWidgetMode.mini,
                  onTap: () {
                    Navigator.pushNamed(context, '/zigbee/device', arguments: device);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Removed: _getDeviceState - now using proper DeviceWidget
}