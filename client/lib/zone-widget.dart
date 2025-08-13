import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import './types.dart';
import './zigbee-service.dart';

class ZoneManagementWidget extends ConsumerStatefulWidget {
  final Device device;

  const ZoneManagementWidget({
    super.key,
    required this.device,
  });

  @override
  ConsumerState<ZoneManagementWidget> createState() => _ZoneManagementWidgetState();
}

class _ZoneManagementWidgetState extends ConsumerState<ZoneManagementWidget> {
  List<String> deviceZones = [];
  List<String> availableZones = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceZones();
  }

  @override
  void didUpdateWidget(ZoneManagementWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload zones if device changed or when widget updates
    if (oldWidget.device.friendlyName != widget.device.friendlyName) {
      _loadDeviceZones();
    }
  }

  Future<void> _loadDeviceZones() async {
    setState(() {
      isLoading = true;
    });

    try {
      final zones = await ref.read(devicesProvider.notifier).getDeviceZones(widget.device.friendlyName);
      final allZones = await ref.read(devicesProvider.notifier).getAllZones();
      setState(() {
        deviceZones = zones;
        availableZones = allZones;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateZones(List<String> newZones) async {
    setState(() {
      isLoading = true;
    });

    try {
      await ref.read(devicesProvider.notifier).setDeviceZones(widget.device.friendlyName, newZones);
      setState(() {
        deviceZones = newZones;
        isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zones updated successfully')),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating zones: $e')),
        );
      }
    }
  }

  void _showZoneSelectionDialog() {
    List<String> selectedZones = List.from(deviceZones);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Zones'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...availableZones.map((zone) {
                      return CheckboxListTile(
                        title: Text(zone.replaceAll('_', ' ').toUpperCase()),
                        value: selectedZones.contains(zone),
                        onChanged: (bool? value) {
                          setDialogState(() {
                            if (value == true) {
                              selectedZones.add(zone);
                            } else {
                              selectedZones.remove(zone);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Save'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _updateZones(selectedZones);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const ListTile(
        leading: Icon(Icons.folder),
        title: Text('Loading zones...'),
        trailing: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    String zoneText;
    if (deviceZones.isEmpty) {
      zoneText = 'Not assigned to any zone';
    } else {
      zoneText = 'Zones: ${deviceZones.map((z) => z.replaceAll('_', ' ')).join(', ')}';
    }

    return ListTile(
      leading: const Icon(Icons.folder),
      title: Text(zoneText),
      trailing: IconButton(
        icon: const Icon(Icons.edit),
        onPressed: _showZoneSelectionDialog,
      ),
    );
  }
}