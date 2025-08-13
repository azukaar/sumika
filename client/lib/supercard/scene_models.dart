import 'package:flutter/material.dart';
import '../api_config.dart';

/// A lighting scene with colors and settings
class LightingScene {
  final String id;
  final String name;
  final List<SceneLight> lights;
  final String? imagePath;
  final int order;
  final bool isCustom;
  final String? createdAt;
  final String? updatedAt;
  final Color primaryColor;
  
  const LightingScene({
    required this.id,
    required this.name,
    required this.lights,
    this.imagePath,
    required this.order,
    required this.isCustom,
    this.createdAt,
    this.updatedAt,
    Color? primaryColor,
  }) : primaryColor = primaryColor ?? Colors.blue;
  
  factory LightingScene.fromJson(Map<String, dynamic> json) {
    final lightsData = json['lights'] as List<dynamic>? ?? [];
    
    return LightingScene(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      lights: lightsData
          .where((light) => light != null)
          .map((light) => SceneLight.fromJson(light as Map<String, dynamic>))
          .toList(),
      imagePath: json['image_path'] as String?,
      order: json['order'] as int? ?? 0,
      isCustom: json['is_custom'] as bool? ?? false,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      // For API scenes, we'll calculate a primary color from the first light
      primaryColor: _calculatePrimaryColor(lightsData),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lights': lights.map((light) => light.toJson()).toList(),
        if (imagePath != null) 'image_path': imagePath,
        'order': order,
        'is_custom': isCustom,
        if (createdAt != null) 'created_at': createdAt,
        if (updatedAt != null) 'updated_at': updatedAt,
      };
  
  /// Get the background image URL for this scene from the server
  Future<String> get imageUrl async {
    // Convert scene name to lowercase and replace spaces with underscores for filename matching
    final fileName = name.toLowerCase().replaceAll(' ', '_');
    final baseUrl = await ApiConfig.baseUrl;
    return '$baseUrl/server-assets/scenes/$fileName.jpg';
  }

  // Helper method to calculate primary color from scene lights
  static Color _calculatePrimaryColor(List<dynamic> lightsJson) {
    if (lightsJson.isEmpty) return Colors.blue;
    
    final firstLight = lightsJson.first;
    final hue = (firstLight['hue'] as num).toDouble();
    final saturation = (firstLight['saturation'] as num).toDouble();
    
    return HSVColor.fromAHSV(1.0, hue, saturation, 0.8).toColor();
  }
}

/// Individual light settings within a scene
class SceneLight {
  final double hue;        // 0-360
  final double saturation; // 0-1  
  final double brightness; // 0-254
  
  const SceneLight({
    required this.hue,
    required this.saturation,
    required this.brightness,
  });

  factory SceneLight.fromJson(Map<String, dynamic> json) => SceneLight(
        hue: (json['hue'] as num? ?? 0).toDouble(),
        saturation: (json['saturation'] as num? ?? 0).toDouble(),
        brightness: (json['brightness'] as num? ?? 180).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'hue': hue,
        'saturation': saturation,
        'brightness': brightness,
      };
}

// Note: Scene data is now served by the backend API via SceneService
// The hardcoded scenes have been moved to server/manage/scene_service.go 
// for a single source of truth. Use allScenesProvider or featuredScenesProvider
// from scene_service.dart to access scene data.