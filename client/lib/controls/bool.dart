import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../types.dart';
import './utils.dart';
import '../zigbee-service.dart';
import 'package:flutter/cupertino.dart';
import 'package:interactive_slider/interactive_slider.dart';

class BoolControl extends ConsumerStatefulWidget {
  final Map<String, dynamic> expose;
  final Device device;

  const BoolControl({
    Key? key,
    required this.expose,
    required this.device,
  }) : super(key: key);

  @override
  ConsumerState<BoolControl> createState() => _BoolControlState();
}

class _BoolControlState extends ConsumerState<BoolControl> {
  late bool _value;

  bool convertToBool(String v) {
    if (v == 'true') {
      return true;
    } else if (v == 'false') {
      return false;
    } else {
      final falseValue = (widget.expose['value_off'] ?? 'false').toString();
      final trueValue = (widget.expose['value_on'] ?? 'true').toString();
      return v == trueValue;
    }
  }

  String convertToString(bool v) {
    final falseValue = (widget.expose['value_off'] ?? 'false').toString();
    final trueValue = (widget.expose['value_on'] ?? 'true').toString();
    return v ? trueValue : falseValue;
  }

  @override
  void initState() {
    super.initState();
    final prop = widget.expose['property'];
    _value = (convertToBool(widget.device.state?[prop] ?? "false"));
  }

  @override
  Widget build(BuildContext context) {
    final devicesState = ref.watch(devicesProvider);

    final prop = widget.expose['property'] as String;
    final access = widget.expose['access'];
    final name = widget.expose['name'];
    final label = widget.expose['label'];
    var value = _value;
    var valueString = convertToString(_value);

    if (access == 1 || access == 5) {
      return Text('$label: $valueString');
    } else {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 6.0, horizontal: 6.0),
        margin: EdgeInsets.symmetric(vertical: 0),
        decoration: BoxDecoration(
            // border: Border.all(
            //   color: Theme.of(context).colorScheme.secondary, // accent color
            //   width: 2.0, // border width
            // ),
            // borderRadius: BorderRadius.circular(12.0), // rounded corners
            ),
        child: Column(
          children: [
            Text('$label'),
            Switch(
              value: value,
              onChanged: (bool newValue) {
                HapticFeedback
                    .lightImpact(); // Haptic feedback for switch toggle

                var jsonState = Map<String, dynamic>.from({
                  prop: convertToString(newValue),
                });

                if (hasOption(widget.device, 'transition')) {
                  jsonState['transition'] = 0.2;
                }

                ref
                    .read(devicesProvider.notifier)
                    .setDeviceState(widget.device.friendlyName, jsonState);

                setState(() {
                  _value = newValue;
                });
              },
            ),
          ],
        ),
      );
    }
  }
}
