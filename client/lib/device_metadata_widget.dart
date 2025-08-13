import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import './types.dart';
import './device_metadata_service.dart';
import './utils/device_utils.dart';

class DeviceMetadataWidget extends ConsumerStatefulWidget {
  final Device device;

  const DeviceMetadataWidget({
    super.key,
    required this.device,
  });

  @override
  ConsumerState<DeviceMetadataWidget> createState() =>
      _DeviceMetadataWidgetState();
}

class _DeviceMetadataWidgetState extends ConsumerState<DeviceMetadataWidget> {
  DeviceMetadata? deviceMetadata;
  List<String> availableCategories = [];
  bool isLoading = false;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceMetadata();
  }

  @override
  void didUpdateWidget(DeviceMetadataWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only reload if the device actually changed (not just object reference)
    if (oldWidget.device.friendlyName != widget.device.friendlyName) {
      _loadDeviceMetadata();
    }
  }

  Future<void> _loadDeviceMetadata() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      final service = ref.read(deviceMetadataServiceProvider);
      final metadata =
          await service.getDeviceMetadata(widget.device.friendlyName);
      final categories = await service.getAllDeviceCategories();

      setState(() {
        deviceMetadata = metadata;
        availableCategories = categories;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        hasError = true;
      });
    }
  }

  Future<void> _updateCustomName(String newName) async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final service = ref.read(deviceMetadataServiceProvider);
      await service.setDeviceCustomName(widget.device.friendlyName, newName);

      // Reload metadata to get updated display name
      await _loadDeviceMetadata();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device name updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating device name: $e')),
        );
      }
    }
  }

  Future<void> _updateCustomCategory(String newCategory) async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final service = ref.read(deviceMetadataServiceProvider);
      await service.setDeviceCustomCategory(
          widget.device.friendlyName, newCategory);

      // Reload metadata to get updated category
      await _loadDeviceMetadata();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device category updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating device category: $e')),
        );
      }
    }
  }

  void _showNameEditDialog() {
    final controller =
        TextEditingController(text: deviceMetadata?.customName ?? '');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Device Name'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Custom Name',
              hintText: widget.device.friendlyName,
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                Navigator.of(context).pop();
                _updateCustomName(controller.text.trim());
              },
            ),
          ],
        );
      },
    );
  }

  void _showCategorySelectionDialog() {
    String selectedCategory = deviceMetadata?.customCategory ??
        deviceMetadata?.guessedCategory ??
        'unknown';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Device Category'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (deviceMetadata?.guessedCategory != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome,
                                size: 16, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Auto-detected: ${_getCategoryDisplayName(deviceMetadata!.guessedCategory!)}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    ...availableCategories.map((category) {
                      return RadioListTile<String>(
                        title: Text(_getCategoryDisplayName(category)),
                        value: category,
                        groupValue: selectedCategory,
                        onChanged: (String? value) {
                          setDialogState(() {
                            selectedCategory = value!;
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
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('Save'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _updateCustomCategory(selectedCategory);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'light':
        return 'Light';
      case 'switch':
        return 'Switch/Plug';
      case 'sensor':
        return 'Sensor';
      case 'button':
        return 'Button/Remote';
      case 'door_window':
        return 'Door/Window';
      case 'motion':
        return 'Motion Sensor';
      case 'thermostat':
        return 'Thermostat';
      case 'unknown':
        return 'Unknown';
      default:
        return category;
    }
  }

  String _getCategoryIcon(String category) {
    switch (category) {
      case 'light':
        return '💡';
      case 'switch':
        return '🔌';
      case 'sensor':
        return '📊';
      case 'button':
        return '🔘';
      case 'door_window':
        return '🚪';
      case 'motion':
        return '🚶';
      case 'thermostat':
        return '🌡️';
      case 'unknown':
        return '❓';
      default:
        return '📱';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const ListTile(
        leading: Icon(Icons.settings),
        title: Text('Loading device info...'),
        trailing: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (hasError) {
      return ListTile(
        leading: const Icon(Icons.error, color: Colors.red),
        title: const Text('Failed to load device metadata'),
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadDeviceMetadata,
        ),
      );
    }

    final displayName = deviceMetadata?.displayName ??
        DeviceUtils.getDeviceDisplayName(widget.device);
    final category = deviceMetadata?.effectiveCategory ?? 'unknown';
    final isCustomName = deviceMetadata?.customName.isNotEmpty == true;
    final isCustomCategory = deviceMetadata?.customCategory.isNotEmpty == true;

    return Column(
      children: [
        // Device Name Row
        ListTile(
          leading: const Icon(Icons.label),
          title: Text(
            isCustomName ? displayName : 'Name: $displayName',
            style: TextStyle(
              fontWeight: isCustomName ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          subtitle: isCustomName
              ? Text('Custom name (was: ${widget.device.friendlyName})')
              : null,
          trailing: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showNameEditDialog,
            tooltip: 'Edit device name',
          ),
        ),

        // Device Category Row
        ListTile(
          leading: const Icon(Icons.category),
          title: Row(
            children: [
              Text(_getCategoryIcon(category)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getCategoryDisplayName(category),
                  style: TextStyle(
                    fontWeight:
                        isCustomCategory ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
          subtitle: !isCustomCategory && deviceMetadata?.guessedCategory != null
              ? const Text('Auto-detected category')
              : isCustomCategory
                  ? const Text('Custom category')
                  : null,
          trailing: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showCategorySelectionDialog,
            tooltip: 'Edit device category',
          ),
        ),
      ],
    );
  }
}
