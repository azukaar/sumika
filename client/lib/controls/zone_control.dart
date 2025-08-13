import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../types.dart';
import '../zigbee-service.dart';
import './numeric.dart';
import './color.dart';
import './utils.dart';
import './custom_color_picker.dart';
import '../utils/device_utils.dart';

/// A control that operates on multiple devices (zone-level control)
class ZoneControlFromZigbeeWidget extends ConsumerWidget {
  final Map<String, dynamic> expose;
  final List<Device> devices;
  final bool hideIcons;
  final bool hideLabel;

  const ZoneControlFromZigbeeWidget({
    Key? key,
    required this.devices,
    required this.expose,
    this.hideIcons = false,
    this.hideLabel = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (devices.isEmpty) {
      return const SizedBox.shrink();
    }

    final type = expose['type'];
    final property = expose['property'] ?? expose['name'];

    switch (type) {
      case 'numeric':
        return _ZoneNumericControl(
            expose: expose,
            devices: devices,
            hideIcons: hideIcons,
            hideLabel: hideLabel);
      case 'binary':
        return _ZoneBinaryControl(expose: expose, devices: devices);
      default:
        if (type == 'composite' &&
            (expose['name'] == 'color_hs' || property == 'color')) {
          return _ZoneColorControl(expose: expose, devices: devices);
        } else if (expose['features'] != null) {
          // Handle composite controls with features
          return Column(
            children: (expose['features'] as List).map<Widget>((feature) {
              return ZoneControlFromZigbeeWidget(
                  expose: feature,
                  devices: devices,
                  hideIcons: hideIcons,
                  hideLabel: hideLabel);
            }).toList(),
          );
        } else {
          return const SizedBox.shrink();
        }
    }
  }
}

/// Zone-aware numeric control (brightness, color_temp, etc.)
class _ZoneNumericControl extends ConsumerStatefulWidget {
  final Map<String, dynamic> expose;
  final List<Device> devices;
  final bool hideIcons;
  final bool hideLabel;

  const _ZoneNumericControl({
    required this.expose,
    required this.devices,
    this.hideIcons = false,
    this.hideLabel = false,
  });

  @override
  ConsumerState<_ZoneNumericControl> createState() =>
      _ZoneNumericControlState();
}

class _ZoneNumericControlState extends ConsumerState<_ZoneNumericControl> {
  double? _currentValue; // null means not initialized yet

  @override
  void initState() {
    super.initState();
  }

  /// Calculate the average value of the property across all ON devices
  double _calculateAverageValue(List<Device> currentDevices) {
    final property = widget.expose['property'];
    if (property == null) return 0.0;

    double totalValue = 0.0;
    int validDevices = 0;

    for (var device in currentDevices) {
      final state = device.state ?? {};

      // For brightness, only include ON devices
      if (property == 'brightness') {
        final isOn = state['state'] == 'ON';
        if (isOn) {
          final value = (state[property] as num?)?.toDouble() ?? 254.0;
          totalValue += value;
          validDevices++;
        }
      } else {
        // For other properties, include all devices that have the property
        final value = (state[property] as num?)?.toDouble();
        if (value != null) {
          totalValue += value;
          validDevices++;
        }
      }
    }

    return validDevices > 0 ? totalValue / validDevices : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final devicesState = ref.watch(devicesProvider);

    return devicesState.when(
      data: (allDevices) {
        // Get current device states
        final currentDevices = widget.devices.map((device) {
          return allDevices.firstWhere(
            (d) => d.friendlyName == device.friendlyName,
            orElse: () => device,
          );
        }).toList();

        final averageValue = _calculateAverageValue(currentDevices);
        final property = widget.expose['property'];
        final minValue = (widget.expose['value_min'] ?? 0).toDouble();

        // Initialize _currentValue on first build, or update if significantly different
        final displayValue = _currentValue ?? averageValue;

        if (_currentValue == null) {
          // First build - set initial value
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _currentValue = averageValue;
              });
            }
          });
        } else if ((_currentValue! - averageValue).abs() > 1.0) {
          // Significant change from server - update
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _currentValue = averageValue;
              });
            }
          });
        }

        return getSlider(
          widget.expose,
          displayValue,
          hideIcons: widget.hideIcons,
          hideLabel: widget.hideLabel,
          onChanged: (double newValue) {
            setState(() {
              _currentValue = newValue;
            });

            for (var device in currentDevices) {
              if (property == 'brightness') {
                final currentState = device.state ?? {};
                final currentIsOn = currentState['state'] == 'ON';
                final shouldBeOn = newValue > minValue;

                Map<String, dynamic> jsonState = {};

                // Always send brightness value
                jsonState['brightness'] = newValue;

                // Only send state change if ON/OFF status is actually changing
                if (currentIsOn != shouldBeOn) {
                  jsonState['state'] = shouldBeOn ? 'ON' : 'OFF';
                }

                // Only send update if there's something to update
                if (jsonState.isNotEmpty) {
                  ref.read(devicesProvider.notifier).setDeviceState(
                        device.friendlyName,
                        jsonState,
                      );
                }
              } else {
                // For other numeric properties, just set the value
                ref.read(devicesProvider.notifier).setDeviceState(
                  device.friendlyName,
                  {property: newValue},
                );
              }
            }
          },
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (error, stack) => const Center(child: Icon(Icons.error)),
    );
  }
}

/// Zone-aware binary control (on/off switches)
class _ZoneBinaryControl extends ConsumerWidget {
  final Map<String, dynamic> expose;
  final List<Device> devices;

  const _ZoneBinaryControl({
    required this.expose,
    required this.devices,
  });

  /// Determine the current state based on majority of devices
  bool _getMajorityState(List<Device> currentDevices) {
    final property = expose['property'] ?? 'state';
    final valueOn = expose['value_on'] ?? 'ON';

    int onCount = 0;
    for (var device in currentDevices) {
      final state = device.state ?? {};
      if (state[property] == valueOn) {
        onCount++;
      }
    }

    return onCount > currentDevices.length / 2;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

        final isOn = _getMajorityState(currentDevices);
        final property = expose['property'] ?? 'state';
        final valueOn = expose['value_on'] ?? 'ON';
        final valueOff = expose['value_off'] ?? 'OFF';

        return Switch(
          value: isOn,
          onChanged: (bool value) {
            final newState = value ? valueOn : valueOff;
            for (var device in currentDevices) {
              ref.read(devicesProvider.notifier).setDeviceState(
                device.friendlyName,
                {property: newState},
              );
            }
          },
        );
      },
      loading: () => const CircularProgressIndicator(strokeWidth: 2),
      error: (error, stack) => const Icon(Icons.error),
    );
  }
}

/// Zone-aware color control
class _ZoneColorControl extends ConsumerStatefulWidget {
  final Map<String, dynamic> expose;
  final List<Device> devices;

  const _ZoneColorControl({
    required this.expose,
    required this.devices,
  });

  @override
  ConsumerState<_ZoneColorControl> createState() => _ZoneColorControlState();
}

class _ZoneColorControlState extends ConsumerState<_ZoneColorControl> {
  double? _currentHue;
  double? _currentSaturation;

  /// Calculate the average color across all devices with color support
  (double, double) _calculateAverageColor(List<Device> currentDevices) {
    final property = widget.expose['property'] ?? 'color_hs';

    double totalHue = 0.0;
    double totalSaturation = 0.0;
    int validDevices = 0;

    for (var device in currentDevices) {
      final state = device.state ?? {};

      // Try different possible color property names
      var colorValue = state[property] ?? state['color_hs'] ?? state['color'];

      if (colorValue != null) {
        double hue = 0.0;
        double saturation = 0.0;

        if (colorValue is List && colorValue.length >= 2) {
          hue = (colorValue[0] as num?)?.toDouble() ?? 0.0;
          saturation = (colorValue[1] as num?)?.toDouble() ?? 0.0;
        } else if (colorValue is Map) {
          hue = (colorValue['hue'] as num?)?.toDouble() ?? 0.0;
          saturation = (colorValue['saturation'] as num?)?.toDouble() ?? 0.0;
          // Zigbee saturation is often 0-100, convert to 0-1
          if (saturation > 1.0) {
            saturation = saturation / 100.0;
          }
        }

        if (hue > 0 || saturation > 0) {
          // Only count devices with actual color data
          totalHue += hue;
          totalSaturation += saturation;
          validDevices++;
        }
      }
    }

    if (validDevices > 0) {
      final avgHue = totalHue / validDevices;
      final avgSat = totalSaturation / validDevices;
      return (avgHue, avgSat);
    } else {
      // Default to a visible color when no color data is available
      return (200.0, 0.8); // Nice blue with good saturation
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final devicesState = ref.watch(devicesProvider);

    return devicesState.when(
      data: (allDevices) {
        // Get current device states
        final currentDevices = widget.devices.map((device) {
          return allDevices.firstWhere(
            (d) => d.friendlyName == device.friendlyName,
            orElse: () => device,
          );
        }).toList();

        final (averageHue, averageSaturation) =
            _calculateAverageColor(currentDevices);
        final property = widget.expose['property'] ?? 'color_hs';
        final access = widget.expose['access'];
        final label = widget.expose['label'];

        // Initialize current values only once
        if (_currentHue == null || _currentSaturation == null) {
          _currentHue = averageHue;
          _currentSaturation = averageSaturation;
        }

        final displayHue = _currentHue!;
        final displaySaturation = _currentSaturation!;

        if (access == 1 || access == 5) {
          return Text(
              '$label (HS): ${displayHue.toStringAsFixed(1)}, ${displaySaturation.toStringAsFixed(3)}');
        }

        return Center(
          child: CustomColorPicker(
            hue: displayHue,
            saturation: displaySaturation,
            onColorChanged: (double newHue, double newSaturation) {
              setState(() {
                _currentHue = newHue;
                _currentSaturation = newSaturation;
              });

              // Apply color to all devices in the zone
              for (var device in currentDevices) {
                var jsonState = Map<String, dynamic>.from({
                  "color": {
                    "hue": newHue,
                    "saturation": newSaturation * 100,
                  }
                });

                // Add transition if supported
                if (hasOption(device, 'transition')) {
                  jsonState['transition'] = 0.2;
                }

                ref
                    .read(devicesProvider.notifier)
                    .setDeviceState(device.friendlyName, jsonState);
              }
            },
          ),
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (error, stack) => const Center(child: Icon(Icons.error)),
    );
  }
}
