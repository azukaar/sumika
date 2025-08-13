import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../types.dart';
import './utils.dart';
import '../zigbee-service.dart';
import 'package:flutter/cupertino.dart';
import 'package:interactive_slider/interactive_slider.dart';
import './custom_color_picker.dart';

class ColorControl extends ConsumerStatefulWidget {
  final Map<String, dynamic> expose;
  final Device device;

  const ColorControl({
    Key? key,
    required this.expose,
    required this.device,
  }) : super(key: key);

  @override
  ConsumerState<ColorControl> createState() => _ColorControlState();
}

class _ColorControlState extends ConsumerState<ColorControl> {
  late double _hue;
  late double _saturation;

  @override
  void initState() {
    super.initState();
    final prop = widget.expose['property'];
    
    // Try to get initial color values from device state
    final colorValue = widget.device.state?[prop] ?? widget.device.state?['color_hs'] ?? widget.device.state?['color'];
    if (colorValue != null) {
      if (colorValue is List && colorValue.length >= 2) {
        _hue = (colorValue[0] as num?)?.toDouble() ?? 0.0;
        _saturation = (colorValue[1] as num?)?.toDouble() ?? 0.0;
      } else if (colorValue is Map) {
        _hue = (colorValue['hue'] as num?)?.toDouble() ?? 0.0;
        var sat = (colorValue['saturation'] as num?)?.toDouble() ?? 0.0;
        // Zigbee saturation is often 0-100, convert to 0-1
        _saturation = sat > 1.0 ? sat / 100.0 : sat;
      } else {
        _hue = 0.0;
        _saturation = 0.0;
      }
    } else {
      _hue = 0.0;
      _saturation = 0.0;
    }
  }

  List<Color> getHueColors(double sat) {
    // return [
    //   HSVColor.fromAHSV(1, 1, 1.0, 1).toColor(),
    //   HSVColor.fromAHSV(1, 100, 1.0, 1).toColor(),
    // ];

    if (sat < 0.1) {
      sat = 0.1;
    }

    List<Color> colors = [];

    for (var i = 0; i < 36; i++) {
      colors.add(HSVColor.fromAHSV(1, i.toDouble() * 10, 1.0, 1).toColor());
    }

    return colors;
  }

  @override
  Widget build(BuildContext context) {
    final devicesState = ref.watch(devicesProvider);

    return devicesState.when(
      data: (allDevices) {
        // Get current device state
        final currentDevice = allDevices.firstWhere(
          (d) => d.friendlyName == widget.device.friendlyName,
          orElse: () => widget.device,
        );

        final prop = widget.expose['property'] as String;
        final access = widget.expose['access'];
        final name = widget.expose['name'];
        final label = widget.expose['label'];


        if (access == 1 || access == 5) {
          return Text('$label (HS): $_hue, $_saturation');
        } else {
          return Center(
            child: CustomColorPicker(
              hue: _hue,
              saturation: _saturation,
              onColorChanged: (double newHue, double newSaturation) {
                setState(() {
                  _hue = newHue;
                  _saturation = newSaturation;
                });

                var jsonState = Map<String, dynamic>.from({
                  "color": {
                    "hue": newHue,
                    "saturation": newSaturation * 100,
                  }
                });

                if (hasOption(widget.device, 'transition')) {
                  jsonState['transition'] = 0.2;
                }

                ref.read(devicesProvider.notifier).setDeviceState(widget.device.friendlyName, jsonState);
              },
            ),
          );
        }
      },
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (error, stack) => const Center(child: Icon(Icons.error)),
    );
  }
}

