import 'package:flutter/foundation.dart';

class Automation {
  final String id;
  final String name;
  final String description;
  final bool enabled;
  final String type; // "ifttt" or "device_link"
  final AutomationTrigger trigger;
  final AutomationAction action;
  final DateTime createdAt;
  final DateTime updatedAt;

  Automation({
    required this.id,
    required this.name,
    required this.description,
    required this.enabled,
    required this.type,
    required this.trigger,
    required this.action,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Automation.fromJson(Map<String, dynamic> json) => Automation(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        enabled: json['enabled'] as bool,
        type: json['type'] as String,
        trigger: AutomationTrigger.fromJson(json['trigger'] as Map<String, dynamic>),
        action: AutomationAction.fromJson(json['action'] as Map<String, dynamic>),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'enabled': enabled,
        'type': type,
        'trigger': trigger.toJson(),
        'action': action.toJson(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  Automation copyWith({
    String? id,
    String? name,
    String? description,
    bool? enabled,
    String? type,
    AutomationTrigger? trigger,
    AutomationAction? action,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Automation(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      type: type ?? this.type,
      trigger: trigger ?? this.trigger,
      action: action ?? this.action,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Automation &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.enabled == enabled &&
        other.type == type &&
        other.trigger == trigger &&
        other.action == action &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      description,
      enabled,
      type,
      trigger,
      action,
      createdAt,
      updatedAt,
    );
  }
}

class AutomationTrigger {
  final String deviceName;
  final String property; // e.g., "state", "brightness", "temperature"
  final String condition; // "equals", "greater_than", "less_than", "changed"
  final dynamic value;
  final dynamic previousValue; // For "changed" condition

  AutomationTrigger({
    required this.deviceName,
    required this.property,
    required this.condition,
    this.value,
    this.previousValue,
  });

  factory AutomationTrigger.fromJson(Map<String, dynamic> json) => AutomationTrigger(
        deviceName: json['device_name'] as String,
        property: json['property'] as String,
        condition: json['condition'] as String,
        value: json['value'],
        previousValue: json['previous_value'],
      );

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'device_name': deviceName,
      'property': property,
      'condition': condition,
    };
    
    // Only include value if it's not null
    if (value != null) {
      data['value'] = value;
    }
    
    if (previousValue != null) {
      data['previous_value'] = previousValue;
    }
    
    return data;
  }

  AutomationTrigger copyWith({
    String? deviceName,
    String? property,
    String? condition,
    dynamic value,
    dynamic previousValue,
  }) {
    return AutomationTrigger(
      deviceName: deviceName ?? this.deviceName,
      property: property ?? this.property,
      condition: condition ?? this.condition,
      value: value ?? this.value,
      previousValue: previousValue ?? this.previousValue,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AutomationTrigger &&
        other.deviceName == deviceName &&
        other.property == property &&
        other.condition == condition &&
        other.value == value &&
        other.previousValue == previousValue;
  }

  @override
  int get hashCode {
    return Object.hash(
      deviceName,
      property,
      condition,
      value,
      previousValue,
    );
  }
}

class AutomationAction {
  // Individual device action
  final String? deviceName;
  
  // Zone-based action
  final String? zone;
  final String? category;
  
  // Scene-based action
  final String? sceneZone;
  final String? sceneName;
  
  // Common fields (not used for scene actions)
  final String? property;
  final dynamic value;

  AutomationAction({
    this.deviceName,
    this.zone,
    this.category,
    this.sceneZone,
    this.sceneName,
    this.property,
    this.value,
  });

  factory AutomationAction.fromJson(Map<String, dynamic> json) => AutomationAction(
        deviceName: json['device_name'] as String?,
        zone: json['zone'] as String?,
        category: json['category'] as String?,
        sceneZone: json['scene_zone'] as String?,
        sceneName: json['scene_name'] as String?,
        property: json['property'] as String?,
        value: json['value'],
      );

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    
    // Include property if present (not for scene actions)
    if (property != null) {
      data['property'] = property;
    }
    
    // Include device-based fields
    if (deviceName != null) {
      data['device_name'] = deviceName;
    }
    
    // Include zone-based fields
    if (zone != null) {
      data['zone'] = zone;
    }
    if (category != null) {
      data['category'] = category;
    }
    
    // Include scene-based fields
    if (sceneZone != null) {
      data['scene_zone'] = sceneZone;
    }
    if (sceneName != null) {
      data['scene_name'] = sceneName;
    }
    
    // Only include value if it's not null
    if (value != null) {
      data['value'] = value;
    }
    
    return data;
  }

  AutomationAction copyWith({
    String? deviceName,
    String? zone,
    String? category,
    String? sceneZone,
    String? sceneName,
    String? property,
    dynamic value,
  }) {
    return AutomationAction(
      deviceName: deviceName ?? this.deviceName,
      zone: zone ?? this.zone,
      category: category ?? this.category,
      sceneZone: sceneZone ?? this.sceneZone,
      sceneName: sceneName ?? this.sceneName,
      property: property ?? this.property,
      value: value ?? this.value,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AutomationAction &&
        other.deviceName == deviceName &&
        other.zone == zone &&
        other.category == category &&
        other.sceneZone == sceneZone &&
        other.sceneName == sceneName &&
        other.property == property &&
        other.value == value;
  }

  @override
  int get hashCode {
    return Object.hash(deviceName, zone, category, sceneZone, sceneName, property, value);
  }
}

// Helper class for automation conditions
class AutomationConditions {
  static const String equals = 'equals';
  static const String greaterThan = 'greater_than';
  static const String lessThan = 'less_than';
  static const String changed = 'changed';
  
  // Button-specific conditions for boolean properties
  static const String pressed = 'pressed';
  static const String doublePressed = 'double_pressed';
  static const String triplePressed = 'triple_pressed';
  static const String longPressed = 'long_pressed';

  static const List<String> all = [equals, greaterThan, lessThan, changed, pressed, doublePressed, triplePressed, longPressed];
  
  // Conditions available for boolean/button properties
  static const List<String> booleanConditions = [equals, changed, pressed, doublePressed, longPressed];
  
  // Conditions available for numeric properties
  static const List<String> numericConditions = [equals, greaterThan, lessThan, changed];
  
  // General conditions available for all property types
  static const List<String> generalConditions = [equals, changed];

  static String getDisplayName(String condition) {
    switch (condition) {
      case equals:
        return 'Equals';
      case greaterThan:
        return 'Greater than';
      case lessThan:
        return 'Less than';
      case changed:
        return 'Changed';
      case pressed:
        return 'Pressed';
      case doublePressed:
        return 'Double pressed';
      case triplePressed:
        return 'Triple pressed';
      case longPressed:
        return 'Long pressed';
      default:
        return condition;
    }
  }
}

// Helper class for automation types
class AutomationTypes {
  static const String ifttt = 'ifttt';

  static const List<String> all = [ifttt];

  static String getDisplayName(String type) {
    switch (type) {
      case ifttt:
        return 'IFTTT Rule';
      default:
        return type;
    }
  }

  static String getDescription(String type) {
    switch (type) {
      case ifttt:
        return 'If this happens, then do that';
      default:
        return '';
    }
  }
}

// Helper class for common device properties
class DeviceProperties {
  // Common properties across different device types
  static const String state = 'state';
  static const String brightness = 'brightness';
  static const String color = 'color';
  static const String colorTemp = 'color_temp';
  static const String temperature = 'temperature';
  static const String humidity = 'humidity';
  static const String contact = 'contact';
  static const String occupancy = 'occupancy';
  static const String motion = 'motion';
  static const String illuminance = 'illuminance';
  static const String battery = 'battery';

  static String getDisplayName(String property) {
    switch (property) {
      case state:
        return 'On/Off State';
      case brightness:
        return 'Brightness';
      case color:
        return 'Color';
      case colorTemp:
        return 'Color Temperature';
      case temperature:
        return 'Temperature';
      case humidity:
        return 'Humidity';
      case contact:
        return 'Contact';
      case occupancy:
        return 'Occupancy';
      case motion:
        return 'Motion';
      case illuminance:
        return 'Light Level';
      case battery:
        return 'Battery Level';
      default:
        return property;
    }
  }

  static List<String> getAvailablePropertiesForDeviceType(String deviceType) {
    switch (deviceType) {
      case 'light':
        return [state, brightness, color, colorTemp];
      case 'sensor':
        return [temperature, humidity, occupancy, motion, illuminance, battery];
      case 'switch':
        return [state, battery];
      case 'door_window':
        return [contact, battery];
      default:
        return [state];
    }
  }
}