import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import './types.dart';
import './zigbee-service.dart';
import './controls/controls.dart';
import './zone-widget.dart';
import './device_metadata_widget.dart';
import './utils/device_utils.dart';

class ZigbeeDevicePage extends ConsumerStatefulWidget {
  const ZigbeeDevicePage({super.key});

  @override
  ConsumerState<ZigbeeDevicePage> createState() => _ZigbeeDevicesPagetate();
}

class _ZigbeeDevicesPagetate extends ConsumerState<ZigbeeDevicePage> {
  String _responseData = 'No data yet';

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only reload devices when actually navigating to this page, not when dialogs open
    final route = ModalRoute.of(context);
    if (mounted && route != null && route.isCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          ref.read(devicesProvider.notifier).loadDevices();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final devicesState = ref.watch(devicesProvider);
    final deviceRef = ModalRoute.of(context)?.settings.arguments as Device;

    return devicesState.when(
      data: (devices) {
        // Get the latest version of this device
        final device = devices.firstWhere(
          (d) => d.friendlyName == deviceRef.friendlyName,
          orElse: () => deviceRef, // Fallback to prop device if not found
        );
        
        final cleanModel = device.definition.model?.replaceAll(' ', '-');

        final status = device.supported ? (
          device.interviewCompleted ? "Online" : (device.interviewing ? "Interviewing..." : "Offline")
        ) : "Unsupported";
        final statusColor = device.supported ? (
          device.interviewCompleted ? Colors.green : (device.interviewing ? Colors.orange : Colors.red)
        ) : Colors.red;
        final statusIcon = device.supported ? (
          device.interviewCompleted ? Icons.check : (device.interviewing ? Icons.hourglass_empty : Icons.close)
        ) : Icons.close;

        final deviceExposes = device.definition.exposes;

        return Scaffold(
          appBar: AppBar(
            title: Text(DeviceUtils.getDeviceDisplayName(device)),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.read(devicesProvider.notifier).loadDevices(),
              ),
            ],
          ),
          body: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                devicesState.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(child: Text('Error: $error')),
                    data: (devices) => Column(
                      children: [
                        Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 16.0),
                              child: cleanModel != null && cleanModel.isNotEmpty
                                ? Image.network(
                                  'https://www.zigbee2mqtt.io/images/devices/${cleanModel}.png',
                                  width: 100,
                                  height: 100,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.device_unknown); // Fallback icon if image fails to load
                                  },
                                )
                                : const Icon(Icons.device_unknown),
                            ),
                            
                            Expanded(
                              child: ListView(
                                shrinkWrap: true, // Add this
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                children: [
                                  ListTile(
                                    leading: Icon(statusIcon, color: statusColor),
                                    title: Text(status),
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.info),
                                    title: Text(device.definition.description ?? ''),
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.info),
                                    title: Text("Model: " + (device.definition.vendor ?? '') + " " + (device.definition.model ?? '')),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        ZoneManagementWidget(device: device),
                        DeviceMetadataWidget(key: ValueKey(device.friendlyName), device: device),
                        Column(
                          children: (deviceExposes??[]).map((expose) {
                            return ControlFromZigbeeWidget(expose: expose, device: device);
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => Text('Error: $error'),
    );
  }
}