import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import './automation_types.dart';
import './automation_service.dart';
import './types.dart';
import './zigbee-service.dart';
import './utils/device_utils.dart';
import './zone_automation_service.dart';
import './scene_service.dart';

enum PropertyValueType {
  boolean,
  numeric,
  text,
}

class AutomationCreatePage extends ConsumerStatefulWidget {
  final Automation? automationToEdit;
  
  const AutomationCreatePage({super.key, this.automationToEdit});

  @override
  ConsumerState<AutomationCreatePage> createState() => _AutomationCreatePageState();
}

class _AutomationCreatePageState extends ConsumerState<AutomationCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedType = AutomationTypes.ifttt;
  String? _triggerDevice;
  String? _triggerProperty;
  String? _triggerCondition;
  dynamic _triggerValue;
  // Action type selection
  String _actionType = 'device'; // 'device', 'zone', or 'scene'
  
  // Individual device action
  String? _actionDevice;
  
  // Zone-based action
  String? _actionZone;
  String? _actionCategory;
  
  // Scene-based action
  String? _sceneZone;
  String? _sceneName;
  
  // Common action fields
  String? _actionProperty;
  dynamic _actionValue;
  
  List<String> _triggerDeviceProperties = [];
  List<String> _actionDeviceProperties = [];
  List<String> _actionZoneCategories = [];
  List<String> _actionZoneCategoryProperties = [];
  
  // Store device states to check actual property value types
  Map<String, Map<String, dynamic>> _deviceStates = {};
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeEditMode();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _initializeEditMode() {
    final automation = widget.automationToEdit;
    if (automation != null) {
      // Populate basic info
      _nameController.text = automation.name;
      _descriptionController.text = automation.description;
      _selectedType = automation.type;

      // Populate trigger
      _triggerDevice = automation.trigger.deviceName;
      _triggerProperty = automation.trigger.property;
      _triggerCondition = automation.trigger.condition;
      _triggerValue = automation.trigger.value;

      // Populate action
      final action = automation.action;
      if (action.sceneZone != null && action.sceneName != null) {
        // Scene-based action
        _actionType = 'scene';
        _sceneZone = action.sceneZone;
        _sceneName = action.sceneName;
      } else if (action.zone != null && action.category != null) {
        // Zone-based action
        _actionType = 'zone';
        _actionZone = action.zone;
        _actionCategory = action.category;
      } else {
        // Individual device action
        _actionType = 'device';
        _actionDevice = action.deviceName;
      }
      _actionProperty = action.property;
      _actionValue = action.value;

      // Load properties for the selected devices/zones
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadInitialProperties();
      });
    }
  }

  Future<void> _loadInitialProperties() async {
    // Load trigger device properties
    if (_triggerDevice != null) {
      await _loadTriggerDeviceProperties(_triggerDevice!);
    }

    // Load action properties
    if (_actionType == 'zone') {
      if (_actionZone != null) {
        await _loadZoneCategories(_actionZone!);
        if (_actionCategory != null) {
          await _loadZoneCategoryProperties(_actionZone!, _actionCategory!);
        }
      }
    } else if (_actionType == 'device' && _actionDevice != null) {
      await _loadActionDeviceProperties(_actionDevice!);
    }
    // Scene actions don't need additional property loading
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsyncValue = ref.watch(devicesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.automationToEdit != null ? 'Edit Automation' : 'Create Automation',
          style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        leading: Container(
          margin: const EdgeInsets.all(8),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _isLoading ? null : _saveAutomation,
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.automationToEdit != null ? 'Update' : 'Save'),
            ),
          ),
        ],
      ),
      body: devicesAsyncValue.when(
        data: (devices) => _buildForm(context, devices),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('Error loading devices: $error'),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, List<Device> devices) {
    // Store device states for value type checking
    _deviceStates.clear();
    for (final device in devices) {
      if (device.state != null) {
        _deviceStates[device.friendlyName] = device.state!;
      }
    }
    
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildBasicInfoSection(context),
          const SizedBox(height: 24),
          _buildTriggerSection(context, devices),
          const SizedBox(height: 24),
          _buildActionSection(context, devices),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter automation name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Describe what this automation does',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSection(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Automation Type',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ...AutomationTypes.all.map((type) => _buildTypeOption(context, type)),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption(BuildContext context, String type) {
    final isSelected = _selectedType == type;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectedType = type),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                type == AutomationTypes.ifttt ? Icons.rule_rounded : Icons.link_rounded,
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AutomationTypes.getDisplayName(type),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected 
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      AutomationTypes.getDescription(type),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTriggerSection(BuildContext context, List<Device> devices) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.play_circle_outline_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Trigger (When)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDeviceDropdown(
              'Device',
              _triggerDevice,
              devices,
              (value) async {
                setState(() {
                  _triggerDevice = value;
                  _triggerProperty = null; // Reset property when device changes
                  _triggerValue = null;
                  _triggerDeviceProperties = [];
                });
                if (value != null) {
                  await _loadTriggerDeviceProperties(value);
                }
              },
            ),
            if (_triggerDevice != null) ...[
              const SizedBox(height: 16),
              _buildPropertyDropdown(
                'Property',
                _triggerProperty,
                _triggerDeviceProperties,
                (value) => setState(() {
                  _triggerProperty = value;
                  _triggerValue = null; // Reset value when property changes
                  _triggerCondition = null; // Reset condition when property changes
                }),
              ),
            ],
            if (_triggerProperty != null) ...[
              const SizedBox(height: 16),
              _buildConditionDropdown(),
            ],
            if (_triggerCondition != null && _needsTriggerValue(_triggerCondition!)) ...[
              const SizedBox(height: 16),
              _buildValueFieldForPropertyAndDevice('Trigger Value', _triggerValue, _triggerProperty, _triggerDevice, (value) => setState(() => _triggerValue = value)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionSection(BuildContext context, List<Device> devices) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.flash_on_rounded,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Action (Then)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Action type selection
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Single Device'),
                        value: 'device',
                        groupValue: _actionType,
                        onChanged: (value) {
                          setState(() {
                            _actionType = value!;
                            _resetActionFields();
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Zone Based'),
                        value: 'zone',
                        groupValue: _actionType,
                        onChanged: (value) {
                          setState(() {
                            _actionType = value!;
                            _resetActionFields();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                RadioListTile<String>(
                  title: const Text('Scene'),
                  value: 'scene',
                  groupValue: _actionType,
                  onChanged: (value) {
                    setState(() {
                      _actionType = value!;
                      _resetActionFields();
                    });
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Individual device action
            if (_actionType == 'device') ...[
              _buildDeviceDropdown(
                'Device',
                _actionDevice,
                devices,
                (value) async {
                  setState(() {
                    _actionDevice = value;
                    _actionProperty = null;
                    _actionValue = null;
                    _actionDeviceProperties = [];
                  });
                  if (value != null) {
                    await _loadActionDeviceProperties(value);
                  }
                },
              ),
              if (_actionDevice != null) ...[
                const SizedBox(height: 16),
                _buildPropertyDropdown(
                  'Property',
                  _actionProperty,
                  _actionDeviceProperties,
                  (value) => setState(() {
                    _actionProperty = value;
                    _actionValue = null;
                  }),
                ),
              ],
            ],
            
            // Zone-based action
            if (_actionType == 'zone') ...[
              _buildZoneDropdown(),
              if (_actionZone != null) ...[
                const SizedBox(height: 16),
                _buildZoneCategoryDropdown(),
              ],
              if (_actionZone != null && _actionCategory != null) ...[
                const SizedBox(height: 16),
                _buildZoneCategoryPropertyDropdown(),
              ],
            ],
            
            // Scene-based action
            if (_actionType == 'scene') ...[
              _buildSceneZoneDropdown(),
              if (_sceneZone != null) ...[
                const SizedBox(height: 16),
                _buildSceneDropdown(),
              ],
            ],
            
            // Value field (common to device and zone action types, not scene)
            if (_actionProperty != null) ...[
              const SizedBox(height: 16),
              _buildActionValueField(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceDropdown(String label, String? value, List<Device> devices, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      value: value,
      items: devices.map((device) {
        return DropdownMenuItem(
          value: device.friendlyName,
          child: Text(DeviceUtils.getDeviceDisplayName(device)),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? '$label is required' : null,
    );
  }

  Widget _buildPropertyDropdown(String label, String? value, List<String> properties, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      value: value,
      items: properties.map((property) {
        return DropdownMenuItem(
          value: property,
          child: Text(property),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? '$label is required' : null,
    );
  }

  Widget _buildConditionDropdown() {
    // Get available conditions based on the trigger property type
    List<String> availableConditions = _getAvailableConditions();
    
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Condition',
        border: OutlineInputBorder(),
      ),
      value: availableConditions.contains(_triggerCondition) ? _triggerCondition : null,
      items: availableConditions.map((condition) {
        return DropdownMenuItem(
          value: condition,
          child: Text(AutomationConditions.getDisplayName(condition)),
        );
      }).toList(),
      onChanged: (value) => setState(() => _triggerCondition = value),
      validator: (value) => value == null ? 'Condition is required' : null,
    );
  }
  
  List<String> _getAvailableConditions() {
    if (_triggerProperty == null || _triggerDevice == null) {
      return AutomationConditions.generalConditions;
    }
    
    // Determine property type from the trigger device and property
    final propertyType = _getPropertyValueType(_triggerDevice!, _triggerProperty!);
    
    switch (propertyType) {
      case PropertyValueType.boolean:
        return AutomationConditions.booleanConditions;
      case PropertyValueType.numeric:
        return AutomationConditions.numericConditions;
      case PropertyValueType.text:
      default:
        // For any unknown/text properties, include button conditions too
        // since we can't reliably predict what's a button
        return AutomationConditions.booleanConditions;
    }
  }
  
  bool _needsTriggerValue(String condition) {
    // These conditions don't need a specific value
    switch (condition) {
      case AutomationConditions.changed:
      case AutomationConditions.pressed:
      case AutomationConditions.doublePressed:
      case AutomationConditions.triplePressed:
      case AutomationConditions.longPressed:
        return false;
      case AutomationConditions.equals:
      case AutomationConditions.greaterThan:
      case AutomationConditions.lessThan:
      default:
        return true;
    }
  }

  Widget _buildValueFieldForPropertyAndDevice(String label, dynamic value, String? property, String? deviceName, ValueChanged<dynamic> onChanged) {
    if (property == null || deviceName == null) {
      return _buildDefaultTextField(label, value, onChanged);
    }

    // Get the actual value type from device state
    final propertyType = _getPropertyValueType(deviceName, property);
    
    switch (propertyType) {
      case PropertyValueType.boolean:
        return _buildStateToggle(label, value, onChanged);
      case PropertyValueType.numeric:
        return _buildNumericField(label, value, onChanged);
      case PropertyValueType.text:
      default:
        return _buildDefaultTextField(label, value, onChanged);
    }
  }

  Widget _buildValueFieldForProperty(String label, dynamic value, String? property, ValueChanged<dynamic> onChanged) {
    return _buildValueFieldForPropertyAndDevice(label, value, property, null, onChanged);
  }

  Widget _buildValueFieldForZoneProperty(String label, dynamic value, String? property, ValueChanged<dynamic> onChanged) {
    if (property == null) {
      return _buildDefaultTextField(label, value, onChanged);
    }

    // Determine the property type from the property name for zone-based actions
    final propertyType = _getPropertyValueTypeFromName(property);
    
    switch (propertyType) {
      case PropertyValueType.boolean:
        return _buildStateToggle(label, value, onChanged);
      case PropertyValueType.numeric:
        return _buildNumericField(label, value, onChanged);
      case PropertyValueType.text:
      default:
        return _buildDefaultTextField(label, value, onChanged);
    }
  }

  PropertyValueType _getPropertyValueTypeFromName(String property) {
    // Determine property type based on common property names
    switch (property) {
      case 'state':
      case 'occupancy':
      case 'motion':
      case 'contact':
        return PropertyValueType.boolean;
      case 'brightness':
      case 'color_temp':
      case 'temperature':
      case 'humidity':
      case 'illuminance':
      case 'battery':
        return PropertyValueType.numeric;
      case 'color':
      default:
        return PropertyValueType.text;
    }
  }

  Widget _buildDefaultTextField(String label, dynamic value, ValueChanged<dynamic> onChanged) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      initialValue: value?.toString() ?? '',
      onChanged: onChanged,
      validator: (val) => val == null || val.isEmpty ? '$label is required' : null,
    );
  }
  
  // Deprecated method - use _buildValueFieldForProperty instead
  Widget _buildValueField(String label, dynamic value, ValueChanged<dynamic> onChanged) {
    return _buildValueFieldForProperty(label, value, null, onChanged);
  }

  Widget _buildStateToggle(String label, dynamic value, ValueChanged<dynamic> onChanged) {
    // Determine current selection
    final isOff = value == 'OFF' || value == false;
    final isOn = value == 'ON' || value == true;
    final isToggle = value == 'TOGGLE';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onChanged('OFF'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isOff 
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : Colors.transparent,
                    border: Border.all(
                      color: isOff 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline.withOpacity(0.5),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'OFF',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isOff 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onChanged('ON'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isOn 
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : Colors.transparent,
                    border: Border.all(
                      color: isOn 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline.withOpacity(0.5),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ON',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isOn 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onChanged('TOGGLE'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isToggle 
                        ? Theme.of(context).colorScheme.secondary.withOpacity(0.1)
                        : Colors.transparent,
                    border: Border.all(
                      color: isToggle 
                          ? Theme.of(context).colorScheme.secondary
                          : Theme.of(context).colorScheme.outline.withOpacity(0.5),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'TOGGLE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: isToggle 
                          ? Theme.of(context).colorScheme.secondary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNumericField(String label, dynamic value, ValueChanged<dynamic> onChanged) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      initialValue: value?.toString() ?? '',
      onChanged: (val) {
        final numValue = num.tryParse(val);
        onChanged(numValue ?? val);
      },
      validator: (val) => val == null || val.isEmpty ? '$label is required' : null,
    );
  }

  List<String> _getAvailableProperties(List<Device> devices, String deviceName, {bool forAction = false}) {
    final device = devices.firstWhere((d) => d.friendlyName == deviceName);
    final deviceType = DeviceUtils.getDeviceType(device);
    
    var properties = DeviceProperties.getAvailablePropertiesForDeviceType(deviceType);
    
    // For actions, filter out read-only properties
    if (forAction) {
      properties = properties.where((prop) => 
          prop != DeviceProperties.battery &&
          prop != DeviceProperties.temperature &&
          prop != DeviceProperties.humidity &&
          prop != DeviceProperties.illuminance
      ).toList();
    }
    
    return properties;
  }

  PropertyValueType _getPropertyValueType(String deviceName, String property) {
    // Get the device state
    final deviceState = _deviceStates[deviceName];
    if (deviceState == null) {
      return PropertyValueType.text; // Default fallback
    }
    
    // Get the actual current value for this property
    final currentValue = deviceState[property];
    if (currentValue == null) {
      return PropertyValueType.text; // Default fallback
    }
    
    // Determine type based on actual value
    // Boolean detection: traditional boolean values OR button action values
    if (currentValue is bool || 
        currentValue == 'ON' || 
        currentValue == 'OFF' ||
        currentValue == true ||
        currentValue == false ||
        // Button action values should be treated as boolean for trigger conditions
        currentValue == 'single' ||
        currentValue == 'double' ||
        currentValue == 'triple' ||
        currentValue == 'hold' ||
        currentValue == 'press' ||
        currentValue == 'long' ||
        // Any string that looks like button action should be boolean
        (currentValue is String && _isButtonActionValue(currentValue))) {
      return PropertyValueType.boolean;
    }
    
    if (currentValue is num || 
        (currentValue is String && double.tryParse(currentValue) != null)) {
      return PropertyValueType.numeric;
    }
    
    return PropertyValueType.text;
  }
  
  bool _isButtonActionValue(String value) {
    // Common button action values that should be treated as boolean for trigger conditions
    const buttonActions = {
      'single', 'double', 'triple', 'hold', 'press', 'long',
      'click', 'double_click', 'triple_click', 'long_press',
      'short_press', 'release', 'action'
    };
    return buttonActions.contains(value.toLowerCase());
  }

  // Legacy methods - kept for compatibility but should use _getPropertyValueType instead
  bool _isStateProperty(String? property) {
    return property == 'state';
  }

  bool _isNumericProperty(String? property) {
    return property == 'brightness' ||
           property == 'color_temp' ||
           property == 'temperature' ||
           property == 'humidity' ||
           property == 'illuminance' ||
           property == 'battery';
  }

  Future<void> _loadTriggerDeviceProperties(String deviceName) async {
    try {
      final properties = await ref.read(devicePropertiesProvider(deviceName).future);
      setState(() {
        _triggerDeviceProperties = properties ?? [];
      });
      
      // If no properties found, show a helpful message
      if ((properties ?? []).isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No properties found for device $deviceName. The device might be offline or not have any controllable properties.')),
        );
      }
    } catch (e) {
      setState(() {
        _triggerDeviceProperties = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load device properties: $e')),
        );
      }
    }
  }

  Future<void> _loadActionDeviceProperties(String deviceName) async {
    try {
      final properties = await ref.read(devicePropertiesProvider(deviceName).future);
      setState(() {
        _actionDeviceProperties = properties ?? [];
      });
      
      // If no properties found, show a helpful message
      if ((properties ?? []).isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No properties found for device $deviceName. The device might be offline or not have any controllable properties.')),
        );
      }
    } catch (e) {
      setState(() {
        _actionDeviceProperties = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load device properties: $e')),
        );
      }
    }
  }
  
  // Helper methods for resetting action fields
  void _resetActionFields() {
    _actionDevice = null;
    _actionZone = null;
    _actionCategory = null;
    _sceneZone = null;
    _sceneName = null;
    _actionProperty = null;
    _actionValue = null;
    _actionDeviceProperties = [];
    _actionZoneCategories = [];
    _actionZoneCategoryProperties = [];
  }

  Widget _buildZoneDropdown() {
    final zonesAsyncValue = ref.watch(allZonesProvider);
    
    return zonesAsyncValue.when(
      data: (zones) => DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          labelText: 'Zone',
          border: OutlineInputBorder(),
        ),
        value: _actionZone,
        items: zones.map((zone) {
          return DropdownMenuItem(
            value: zone,
            child: Text(zone.replaceAll('_', ' ').toUpperCase()),
          );
        }).toList(),
        onChanged: (value) async {
          setState(() {
            _actionZone = value;
            _actionCategory = null;
            _actionProperty = null;
            _actionValue = null;
            _actionZoneCategories = [];
            _actionZoneCategoryProperties = [];
          });
          if (value != null) {
            await _loadZoneCategories(value);
          }
        },
        validator: (value) => value == null ? 'Zone is required' : null,
      ),
      loading: () => DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          labelText: 'Loading zones...',
          border: OutlineInputBorder(),
        ),
        items: const [],
        onChanged: null,
      ),
      error: (error, stack) => DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          labelText: 'Error loading zones',
          border: OutlineInputBorder(),
        ),
        items: const [],
        onChanged: null,
      ),
    );
  }
  
  Widget _buildZoneCategoryDropdown() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Device Category',
        border: OutlineInputBorder(),
      ),
      value: _actionCategory,
      items: _actionZoneCategories.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Row(
            children: [
              Text(getCategoryIcon(category)),
              const SizedBox(width: 8),
              Text(getCategoryDisplayName(category)),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) async {
        setState(() {
          _actionCategory = value;
          _actionProperty = null;
          _actionValue = null;
          _actionZoneCategoryProperties = [];
        });
        if (value != null && _actionZone != null) {
          await _loadZoneCategoryProperties(_actionZone!, value);
        }
      },
      validator: (value) => value == null ? 'Device category is required' : null,
    );
  }

  Widget _buildZoneCategoryPropertyDropdown() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Property',
        border: OutlineInputBorder(),
      ),
      value: _actionProperty,
      items: _actionZoneCategoryProperties.map((property) {
        return DropdownMenuItem(
          value: property,
          child: Text(property),
        );
      }).toList(),
      onChanged: (value) => setState(() {
        _actionProperty = value;
        _actionValue = null;
      }),
      validator: (value) => value == null ? 'Property is required' : null,
    );
  }
  
  Widget _buildActionValueField() {
    if (_actionType == 'zone') {
      // For zone-based actions, we need to determine the property type from the property name itself
      // since we don't have a specific device to reference
      return _buildValueFieldForZoneProperty('Set To', _actionValue, _actionProperty, (value) => setState(() => _actionValue = value));
    } else {
      // For individual devices, use the existing method with device context
      return _buildValueFieldForPropertyAndDevice('Set To', _actionValue, _actionProperty, _actionDevice, (value) => setState(() => _actionValue = value));
    }
  }

  Widget _buildSceneZoneDropdown() {
    final zonesAsyncValue = ref.watch(allZonesProvider);
    
    return zonesAsyncValue.when(
      data: (zones) => DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          labelText: 'Zone for Scene',
          border: OutlineInputBorder(),
        ),
        value: _sceneZone,
        items: zones.map((zone) {
          return DropdownMenuItem(
            value: zone,
            child: Text(zone.replaceAll('_', ' ').toUpperCase()),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _sceneZone = value;
            _sceneName = null; // Reset scene when zone changes
          });
        },
        validator: (value) => value == null ? 'Zone is required' : null,
      ),
      loading: () => DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          labelText: 'Loading zones...',
          border: OutlineInputBorder(),
        ),
        items: const [],
        onChanged: null,
      ),
      error: (error, stack) => DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          labelText: 'Error loading zones',
          border: OutlineInputBorder(),
        ),
        items: const [],
        onChanged: null,
      ),
    );
  }

  Widget _buildSceneDropdown() {
    final allScenesAsync = ref.watch(allScenesProvider);
    
    return allScenesAsync.when(
      data: (scenes) => DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          labelText: 'Scene',
          border: OutlineInputBorder(),
        ),
        value: _sceneName,
        items: scenes.map((scene) {
          return DropdownMenuItem(
            value: scene.name,
            child: Text(scene.name),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _sceneName = value;
          });
        },
        validator: (value) => value == null ? 'Scene is required' : null,
      ),
      loading: () => DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          labelText: 'Loading scenes...',
          border: OutlineInputBorder(),
        ),
        items: const [],
        onChanged: null,
      ),
      error: (error, stack) => DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          labelText: 'Error loading scenes',
          border: OutlineInputBorder(),
        ),
        items: const [],
        onChanged: null,
      ),
    );
  }
  
  Future<void> _loadZoneCategories(String zone) async {
    try {
      final service = ref.read(zoneAutomationServiceProvider);
      final categories = await service.getZoneCategories(zone);
      setState(() {
        _actionZoneCategories = categories;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load zone categories: $e')),
        );
      }
    }
  }
  
  Future<void> _loadZoneCategoryProperties(String zone, String category) async {
    try {
      final service = ref.read(zoneAutomationServiceProvider);
      final properties = await service.getZoneCategoryProperties(zone, category);
      setState(() {
        _actionZoneCategoryProperties = properties;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load zone category properties: $e')),
        );
      }
    }
  }

  Future<void> _saveAutomation() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate required fields based on automation type
    bool validationFailed = false;
    String errorMessage = '';
    
    // Validate trigger fields
    if (_triggerDevice == null || _triggerProperty == null) {
      validationFailed = true;
      errorMessage = 'Please select trigger device and property';
    } else if (_triggerCondition == null) {
      validationFailed = true;
      errorMessage = 'Please select a trigger condition';
    } else if (_needsTriggerValue(_triggerCondition!) && _triggerValue == null) {
      validationFailed = true;
      errorMessage = 'Please set a trigger value';
    }
    
    // Validate action fields
    if (!validationFailed) {
      if (_actionType == 'scene') {
        if (_sceneZone == null || _sceneName == null) {
          validationFailed = true;
          errorMessage = 'Please select zone and scene';
        }
      } else if (_actionType == 'zone') {
        if (_actionZone == null || _actionCategory == null || _actionProperty == null) {
          validationFailed = true;
          errorMessage = 'Please select zone, category, and property';
        } else if (_actionValue == null) {
          validationFailed = true;
          errorMessage = 'Please set an action value';
        }
      } else {
        if (_actionDevice == null || _actionProperty == null) {
          validationFailed = true;
          errorMessage = 'Please select action device and property';
        } else if (_actionValue == null) {
          validationFailed = true;
          errorMessage = 'Please set an action value';
        }
      }
    }
    
    if (validationFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final existingAutomation = widget.automationToEdit;
      final automation = Automation(
        id: existingAutomation?.id ?? '', // Preserve existing ID for updates
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        enabled: existingAutomation?.enabled ?? true, // Preserve enabled state for updates
        type: _selectedType,
        trigger: AutomationTrigger(
          deviceName: _triggerDevice!,
          property: _triggerProperty!,
          condition: _triggerCondition!,
          value: _triggerValue,
        ),
        action: _actionType == 'scene'
            ? AutomationAction(
                sceneZone: _sceneZone!,
                sceneName: _sceneName!,
              )
            : _actionType == 'zone'
                ? AutomationAction(
                    zone: _actionZone!,
                    category: _actionCategory!,
                    property: _actionProperty!,
                    value: _actionValue,
                  )
                : AutomationAction(
                    deviceName: _actionDevice!,
                    property: _actionProperty!,
                    value: _actionValue,
                  ),
        createdAt: existingAutomation?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (existingAutomation != null) {
        // Update existing automation
        await ref.read(automationNotifierProvider.notifier).updateAutomation(automation);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Automation "${automation.name}" updated successfully')),
          );
        }
      } else {
        // Create new automation
        await ref.read(automationNotifierProvider.notifier).createAutomation(automation);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Automation "${automation.name}" created successfully')),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${widget.automationToEdit != null ? 'update' : 'create'} automation: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}