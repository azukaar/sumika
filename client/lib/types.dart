class Device {
  final String dateCode;
  final DeviceDefinition definition;
  final Map<String, dynamic>? state;
  final dynamic endpoint;
  final String friendlyName;
  final bool disabled;
  final String ieeeAddress;
  final bool interviewCompleted;
  final bool interviewing;
  final String manufacturer;
  final String modelId;
  final int networkAddress;
  final String powerSource;
  final bool supported;
  final String type;
  final String? lastSeen;
  final List<String>? zones;
  final String? customName;
  final String? customCategory;

  Device({
    required this.dateCode,
    required this.definition,
    required this.state,
    required this.endpoint,
    required this.friendlyName,
    required this.disabled,
    required this.ieeeAddress,
    required this.interviewCompleted,
    required this.interviewing,
    required this.manufacturer,
    required this.modelId,
    required this.networkAddress,
    required this.powerSource,
    required this.supported,
    required this.type,
    this.lastSeen,
    this.zones,
    this.customName,
    this.customCategory,
  });

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        dateCode: json['date_code'] as String,
        definition: DeviceDefinition.fromJson(json['definition'] as Map<String, dynamic>),
        state: json['state'] as Map<String, dynamic>?,
        endpoint: json['endpoint'],
        friendlyName: json['friendly_name'] as String,
        disabled: json['disabled'] as bool,
        ieeeAddress: json['ieee_address'] as String,
        interviewCompleted: json['interview_completed'] as bool,
        interviewing: json['interviewing'] as bool,
        manufacturer: json['manufacturer'] as String,
        modelId: json['model_id'] as String,
        networkAddress: json['network_address'] as int,
        powerSource: json['power_source'] as String,
        supported: json['supported'] as bool,
        type: json['type'] as String,
        lastSeen: json['last_seen'] as String?,
        zones: (json['zones'] as List<dynamic>?)?.cast<String>(),
        customName: json['custom_name'] as String?,
        customCategory: json['custom_category'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'date_code': dateCode,
        'definition': definition.toJson(),
        'state': state,
        'endpoint': endpoint,
        'friendly_name': friendlyName,
        'disabled': disabled,
        'ieee_address': ieeeAddress,
        'interview_completed': interviewCompleted,
        'interviewing': interviewing,
        'manufacturer': manufacturer,
        'model_id': modelId,
        'network_address': networkAddress,
        'power_source': powerSource,
        'supported': supported,
        'type': type,
        'last_seen': lastSeen,
        'zones': zones,
        'custom_name': customName,
        'custom_category': customCategory,
      };
}

class DeviceDefinition {
  final String? description;
  final List<dynamic>? exposes;
  final String? model;
  final String? vendor;
  final bool? supportsOta;
  final List<DeviceOptions>? options;

  DeviceDefinition({
    this.description,
    this.exposes,
    this.model,
    this.vendor,
    this.supportsOta,
    this.options,
  });

  factory DeviceDefinition.fromJson(Map<String, dynamic> json) => DeviceDefinition(
        description: json['description'] as String?,
        exposes: json['exposes'] as List<dynamic>?,
        model: json['model'] as String?,
        vendor: json['vendor'] as String?,
        supportsOta: json['supports_ota'] as bool?,
        options: (json['options'] as List<dynamic>?)?.map((e) => DeviceOptions.fromJson(e as Map<String, dynamic>)).toList(),
      );

  Map<String, dynamic> toJson() => {
        'description': description,
        'exposes': exposes,
        'model': model,
        'vendor': vendor,
        'supports_ota': supportsOta,
        'options': options?.map((e) => e.toJson()).toList(),
      };
}

class DeviceOptions {
  final int? access;
  final String? description;
  final String? label;
  final String? name;
  final String? type;
  final int? valueMin;
  final int? valueMax;
  final String? valueOn;
  final String? valueOff;

  DeviceOptions({
    this.access,
    this.description,
    this.label,
    this.name,
    this.type,
    this.valueMin,
    this.valueMax,
    this.valueOn,
    this.valueOff,
  });

  factory DeviceOptions.fromJson(Map<String, dynamic> json) => DeviceOptions(
        access: json['access'] as int?,
        description: json['description'] as String?,
        label: json['label'] as String?,
        name: json['name'] as String?,
        type: json['type'] as String?,
        valueMin: json['value_min'] as int?,
        valueMax: json['value_max'] as int?,
        valueOn: json['value_on'] as String?,
        valueOff: json['value_off'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'access': access,
        'description': description,
        'label': label,
        'name': name,
        'type': type,
        'value_min': valueMin,
        'value_max': valueMax,
        'value_on': valueOn,
        'value_off': valueOff,
      };
}