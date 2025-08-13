import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import './types.dart';
import './zigbee-service.dart';
import './utils/device_utils.dart';

class ZonesPage extends ConsumerStatefulWidget {
  const ZonesPage({super.key});

  @override
  ConsumerState<ZonesPage> createState() => _ZonesPageState();
}

class _ZonesPageState extends ConsumerState<ZonesPage> {
  List<String> zones = [];
  Map<String, List<String>> zoneDevices = {};
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadZoneDevices();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload data when returning to this page
    if (mounted) {
      _loadZoneDevices();
    }
  }

  Future<void> _loadZoneDevices() async {
    setState(() {
      isLoading = true;
    });

    try {
      final allZones = await ref.read(devicesProvider.notifier).getAllZones();
      Map<String, List<String>> newZoneDevices = {};
      
      for (String zone in allZones) {
        final devices = await ref.read(devicesProvider.notifier).getDevicesByZone(zone);
        newZoneDevices[zone] = devices;
      }
      
      setState(() {
        zones = allZones;
        zoneDevices = newZoneDevices;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _createZone() async {
    final TextEditingController controller = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create New Zone'),
          content: Focus(
            autofocus: true,
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Zone Name',
                hintText: 'Enter zone name (e.g., "guest_room")',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.of(context).pop(value.trim());
                }
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Create'),
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      // Check if zone already exists
      if (zones.contains(result)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Zone "$result" already exists')),
          );
        }
        return;
      }
      
      final success = await ref.read(devicesProvider.notifier).createZone(result);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Zone created successfully')),
          );
        }
        _loadZoneDevices();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create zone "$result". Server returned an error.')),
          );
        }
      }
    }
  }

  Future<void> _renameZone(String oldName) async {
    final TextEditingController controller = TextEditingController(text: oldName);
    
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rename Zone'),
          content: Focus(
            autofocus: true,
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'New Zone Name',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty && value.trim() != oldName) {
                  Navigator.of(context).pop(value.trim());
                }
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Rename'),
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty && result != oldName) {
      final success = await ref.read(devicesProvider.notifier).renameZone(oldName, result);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Zone renamed successfully')),
          );
        }
        _loadZoneDevices();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to rename zone. The new name may already exist.')),
          );
        }
      }
    }
  }

  Future<void> _deleteZone(String zoneName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Zone'),
          content: Text('Are you sure you want to delete "$zoneName"? This will remove all device associations with this zone.'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Delete'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final success = await ref.read(devicesProvider.notifier).deleteZone(zoneName);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Zone deleted successfully')),
          );
        }
        _loadZoneDevices();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete zone')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createZone,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadZoneDevices,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: zones.length,
              itemBuilder: (context, index) {
                final zone = zones[index];
                final devices = zoneDevices[zone] ?? [];
                final zoneDisplayName = zone.replaceAll('_', ' ').toUpperCase();

                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ExpansionTile(
                    leading: const Icon(Icons.home),
                    title: Text(zoneDisplayName),
                    subtitle: Text('${devices.length} device${devices.length == 1 ? '' : 's'}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _renameZone(zone),
                          tooltip: 'Rename zone',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteZone(zone),
                          tooltip: 'Delete zone',
                        ),
                        const Icon(Icons.expand_more),
                      ],
                    ),
                    children: devices.isEmpty
                        ? [
                            const ListTile(
                              title: Text('No devices in this zone'),
                              leading: Icon(Icons.info_outline),
                            ),
                          ]
                        : devices.map((deviceName) {
                            return Consumer(
                              builder: (context, ref, child) {
                                final devicesAsyncValue = ref.watch(devicesProvider);
                                return devicesAsyncValue.when(
                                  data: (devicesList) {
                                    final device = devicesList.firstWhere(
                                      (d) => d.friendlyName == deviceName,
                                      orElse: () => devicesList.isNotEmpty ? devicesList.first : Device(
                                        dateCode: '', definition: DeviceDefinition.fromJson({}), state: {}, 
                                        endpoint: '', friendlyName: deviceName, disabled: false, ieeeAddress: '',
                                        interviewCompleted: false, interviewing: false, manufacturer: '', 
                                        modelId: '', networkAddress: 0, powerSource: '', supported: false, 
                                        type: '', zones: [], customName: null, customCategory: null
                                      ),
                                    );
                                    return ListTile(
                                      leading: const Icon(Icons.device_hub),
                                      title: Text(DeviceUtils.getDeviceDisplayName(device)),
                                      trailing: const Icon(Icons.arrow_forward_ios),
                                      onTap: () {
                                        // Navigate to device page if needed
                                        final devicesState = ref.read(devicesProvider);
                                        devicesState.whenData((devicesList) {
                                          final device = devicesList.firstWhere(
                                            (d) => d.friendlyName == deviceName,
                                            orElse: () => devicesList.first,
                                          );
                                        Navigator.pushNamed(
                                          context,
                                          '/zigbee/device',
                                          arguments: device,
                                        );
                                      });
                                    },
                                  );
                                },
                                loading: () => ListTile(
                                  leading: const Icon(Icons.device_hub),
                                  title: Text(deviceName),
                                  trailing: const Icon(Icons.arrow_forward_ios),
                                ),
                                error: (error, stack) => ListTile(
                                  leading: const Icon(Icons.device_hub),
                                  title: Text(deviceName),
                                  trailing: const Icon(Icons.arrow_forward_ios),
                                ),
                              );
                            });
                          }).toList(),
                  ),
                );
              },
            ),
    );
  }
}