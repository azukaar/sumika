import 'package:flutter/material.dart';
import './numeric.dart';
import './bool.dart';
import './color.dart';
import './zone_control.dart';
import './master_control.dart';
import './zone_helpers.dart';
import '../types.dart';
import 'package:flutter/foundation.dart';

// Export zone controls for easy importing
export './zone_control.dart';
export './master_control.dart';
export './zone_helpers.dart';

class ControlFromZigbeeWidget extends StatelessWidget {
  final Map<String, dynamic> expose;
  final Device device;
  final bool hideIcons;
  final bool hideLabel;

  const ControlFromZigbeeWidget({
    Key? key,
    required this.device,
    required this.expose,
    this.hideIcons = false,
    this.hideLabel = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final type = expose['type'];
    final label = expose['label'];
    final features = expose['features'];
    final name = expose['name'];

    switch (type) {
      case 'numeric':
        return NumericControl(expose: expose, device: device, hideIcons: hideIcons, hideLabel: hideLabel);
      case 'binary':
        return BoolControl(expose: expose, device: device);
      default:
        if(type == 'composite' && name == 'color_hs') {
          return ColorControl(expose: expose, device: device);
        } 
        if(type == 'composite' && name == 'color_xy') {
          return SizedBox();
        } else if (features != null) {
          return Column(children: features.map<Widget>((feature) {
            return ControlFromZigbeeWidget(expose: feature, device: device, hideIcons: hideIcons, hideLabel: hideLabel);
          }).toList());
        } else {
          
          return kReleaseMode ? SizedBox() : Text('Unsupported control: $label ($type)');
        }
    }
  }
}