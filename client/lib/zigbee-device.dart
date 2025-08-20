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
  bool _isDeletingDevice = false;

  @override
  void initState() {
    super.initState();
  }

  void _showDeleteConfirmationDialog(BuildContext context, Device device) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Forget Device'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to forget "${DeviceUtils.getDeviceDisplayName(device)}"?'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Warning',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This will permanently remove the device from both the server and Zigbee2MQTT. '
                      'You will need to re-pair the device if you want to use it again.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isDeletingDevice ? null : () => _deleteDevice(context, device),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: _isDeletingDevice
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Forget Device'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteDevice(BuildContext context, Device device) async {
    setState(() {
      _isDeletingDevice = true;
    });

    try {
      final success = await ref.read(devicesProvider.notifier).removeDevice(device.friendlyName);
      
      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Device "${DeviceUtils.getDeviceDisplayName(device)}" has been forgotten'),
              backgroundColor: Colors.green,
            ),
          );
          // Navigate back to device list
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to forget device. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingDevice = false;
        });
      }
    }
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
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    _showDeleteConfirmationDialog(context, device);
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Forget Device',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
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