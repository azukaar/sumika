import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../types.dart';
import './utils.dart';
import '../zigbee-service.dart';
import '../state/device_specs_notifier.dart';
import 'package:flutter/cupertino.dart';
import 'package:interactive_slider/interactive_slider.dart';
import 'package:flutter/foundation.dart';

class NumericControl extends ConsumerStatefulWidget {
  final Map<String, dynamic> expose;
  final Device device;
  final bool hideIcons;
  final bool hideLabel;

  const NumericControl({
    Key? key,
    required this.expose,
    required this.device,
    this.hideIcons = false,
    this.hideLabel = false,
  }) : super(key: key);

  @override
  ConsumerState<NumericControl> createState() => _NumericControlState();
}

class _NumericControlState extends ConsumerState<NumericControl> {
  late double _value;

  @override
  void initState() {
    super.initState();
    final prop = widget.expose['property'];
    _value = (widget.device.state?[prop] ?? 0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final devicesState = ref.watch(devicesProvider);
    final deviceSpecs = ref.watch(deviceSpecsProvider(widget.device.ieeeAddress));

    final prop = widget.expose['property'] as String;
    final access = widget.expose['access'];
    final name = widget.expose['name'];
    final label = widget.expose['label'];
    var value = _value;
    
    // Cross-reference enhanced metadata for this property
    String? enhancedUnit;
    String? enhancedDescription;
    if (deviceSpecs?['enhanced_metadata'] != null) {
      final enhancedExposes = deviceSpecs!['enhanced_metadata']['exposes'] as List<dynamic>?;
      if (enhancedExposes != null) {
        for (final enhancedExpose in enhancedExposes) {
          if (enhancedExpose is Map<String, dynamic> && 
              enhancedExpose['property'] == prop) {
            enhancedUnit = enhancedExpose['unit']?.toString();
            enhancedDescription = enhancedExpose['description']?.toString();
            break;
          }
        }
      }
    }

    if (access == 1 || access == 5) {
      // Read-only display with unit and optional description tooltip
      final displayText = enhancedUnit != null 
          ? '$label: $value $enhancedUnit' 
          : '$label: $value';
          
      if (enhancedDescription != null && enhancedDescription!.isNotEmpty) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(displayText),
            const SizedBox(width: 4),
            Tooltip(
              message: enhancedDescription!,
              child: const Icon(Icons.help_outline, size: 16, color: Colors.grey),
            ),
          ],
        );
      } else {
        return Text(displayText);
      }
    } else {
      final minValue = (widget.expose['value_min'] ?? 0).toDouble();
      final maxValue = (widget.expose['value_max'] ?? 100).toDouble();
      final speadValue = maxValue - minValue;

      if (value < minValue) {
        value = minValue;
      } else if (value > maxValue) {
        value = maxValue;
      }

      return getSlider(widget.expose, value, hideIcons: widget.hideIcons, hideLabel: widget.hideLabel, 
          enhancedUnit: enhancedUnit, enhancedDescription: enhancedDescription, onChanged: (double newValue) {
        // var newValue = _newValue * speadValue + minValue;

        // state in json
        var jsonState = {
          prop: newValue,
        };

        if(hasOption(widget.device, 'transition')) {
          jsonState['transition'] = 0.2;
        }

        ref.read(devicesProvider.notifier).setDeviceState(widget.device.friendlyName, jsonState);

        setState(() {
          _value = newValue;
        });
      });
    }
  }
}

Widget getSlider(Map<String, dynamic> expose, dynamic value, {required Function(double) onChanged, bool hideIcons = false, bool hideLabel = false, String? enhancedUnit, String? enhancedDescription}) {
  final minValue = (expose['value_min'] ?? 0).toDouble();
  final maxValue = (expose['value_max'] ?? 100).toDouble();

  if (expose['property'] == "color_temp_startup") {
    return const SizedBox.shrink();
  }

  LinearGradient gradient;
  Icon startIcon;
  Icon endIcon;

  switch (expose['property']) {
    case 'brightness':
      gradient = LinearGradient(colors: [Colors.black, Colors.orange]);
      startIcon = Icon(Icons.brightness_2);
      endIcon = Icon(Icons.brightness_7);
    case 'color_temp':
      gradient = LinearGradient(colors: [Colors.blue, Colors.white, Colors.yellow, Colors.orange]);
      startIcon = Icon(Icons.ac_unit);
      endIcon = Icon(Icons.wb_sunny);
    default:
      gradient = LinearGradient(colors: [Colors.black, Colors.black]);
      startIcon = Icon(Icons.remove);
      endIcon = Icon(Icons.add);
  };

  // Create enhanced label with unit and description tooltip
  Widget labelWidget;
  if (hideLabel) {
    labelWidget = const SizedBox();
  } else {
    final label = expose['label'] ?? expose['name'] ?? expose['property'];
    final labelText = enhancedUnit != null ? '$label ($enhancedUnit)' : label;
    
    if (enhancedDescription != null && enhancedDescription!.isNotEmpty) {
      labelWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(labelText),
          const SizedBox(width: 4),
          Tooltip(
            message: enhancedDescription!,
            child: const Icon(Icons.help_outline, size: 16, color: Colors.grey),
          ),
        ],
      );
    } else {
      labelWidget = Text(labelText);
    }
  }
  
  return Column(
    children: [
      labelWidget,
      _UpdatableSlider(
        value: value.toDouble(),
        onChanged: onChanged,
        startIcon: hideIcons ? null : startIcon,
        endIcon: hideIcons ? null : endIcon,
        unfocusedHeight: hideIcons ? 70 : 30,
        focusedHeight: hideIcons ? 80 : 40,
        gradient: gradient,
        min: minValue,
        max: maxValue,
      ),
    ],
  );
}

/// A slider that recreates InteractiveSlider when value changes significantly
class _UpdatableSlider extends StatefulWidget {
  final double value;
  final Function(double) onChanged;
  final Icon? startIcon;
  final Icon? endIcon;
  final double unfocusedHeight;
  final double focusedHeight;
  final LinearGradient gradient;
  final double min;
  final double max;

  const _UpdatableSlider({
    required this.value,
    required this.onChanged,
    this.startIcon,
    this.endIcon,
    required this.unfocusedHeight,
    required this.focusedHeight,
    required this.gradient,
    required this.min,
    required this.max,
  });

  @override
  State<_UpdatableSlider> createState() => _UpdatableSliderState();
}

class _UpdatableSliderState extends State<_UpdatableSlider> {
  double? _lastKnownValue;
  bool _isUserInteracting = false;
  DateTime _lastInteractionTime = DateTime.now();
  bool _forceRecreate = false;

  @override
  void initState() {
    super.initState();
    _lastKnownValue = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    // Check if we need to recreate the slider
    final now = DateTime.now();
    final timeSinceInteraction = now.difference(_lastInteractionTime).inMilliseconds;
    final valueDifference = (_lastKnownValue! - widget.value).abs();
    final shouldRecreate = _forceRecreate || 
                          (!_isUserInteracting && 
                           timeSinceInteraction > 2000 && 
                           valueDifference > 10.0);

    if (shouldRecreate) {
      _lastKnownValue = widget.value;
      _forceRecreate = false; // Reset the force flag
    }

    final slider = GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact(); // Haptic feedback for slider min/max toggle
        
        // Toggle logic: go to 0 if current value > 0, otherwise go to max
        final currentValue = _lastKnownValue ?? widget.value;
        final newValue = currentValue > widget.min ? widget.min : widget.max;
        
        // Update state and force recreation for visual update
        setState(() {
          _lastKnownValue = newValue;
          _forceRecreate = true;
          _isUserInteracting = false;
        });
        
        widget.onChanged(newValue);
      },
      child: InteractiveSlider(
        onChanged: (double newValue) {
          setState(() {
            _isUserInteracting = true;
            _lastInteractionTime = DateTime.now();
            _lastKnownValue = newValue;
          });
          
          widget.onChanged(newValue);
          
          // Stop considering this as user interaction after a delay
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
              setState(() {
                _isUserInteracting = false;
              });
            }
          });
        },
        startIcon: widget.startIcon,
        endIcon: widget.endIcon,
        unfocusedOpacity: 1,
        unfocusedHeight: widget.unfocusedHeight,
        focusedHeight: widget.focusedHeight,
        gradient: widget.gradient,
        min: widget.min,
        max: widget.max,
        initialProgress: ((_lastKnownValue ?? widget.value) - widget.min) / (widget.max - widget.min),
      ),
    );

    // Wrap in KeyedSubtree when we need to recreate
    if (shouldRecreate) {
      return KeyedSubtree(
        key: ValueKey('slider_recreate_${(_lastKnownValue ?? widget.value).round()}_${now.millisecondsSinceEpoch}'),
        child: slider,
      );
    } else {
      // Return slider directly without KeyedSubtree during normal interaction
      return slider;
    }
  }
}