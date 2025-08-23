import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screen_monitoring_service.dart';
import 'scene_management_service.dart';
import 'supercard/scene_models.dart';

class AdaptiveLightingService {
  static final AdaptiveLightingService _instance = AdaptiveLightingService._internal();
  factory AdaptiveLightingService() => _instance;
  AdaptiveLightingService._internal();

  static const String targetZone = "living room";
  
  final ScreenMonitoringService _screenService = ScreenMonitoringService();
  final SceneManagementService _sceneService = SceneManagementService();
  
  StreamSubscription<ScreenColorData>? _colorSubscription;
  bool _isEnabled = false;
  double _fps = 1.0;
  double _brightnessScale = 0.8; // Scale brightness to reasonable level
  
  bool get isEnabled => _isEnabled;
  double get currentFPS => _fps;
  double get brightnessScale => _brightnessScale;

  void startAdaptiveLighting({double fps = 1.0}) {
    if (_isEnabled) {
      stopAdaptiveLighting();
    }

    _fps = fps;
    _isEnabled = true;

    // Start screen monitoring
    _screenService.startMonitoring(fps: fps);
    
    // Listen to color changes and apply to lights
    _colorSubscription = _screenService.colorStream.listen(
      (colorData) {
        _applyScreenColorsToLivingRoom(colorData);
      },
      onError: (error) {
        print('Adaptive lighting error: $error');
      },
    );

    print('Adaptive lighting started for $targetZone at $fps FPS');
  }

  void stopAdaptiveLighting() {
    _colorSubscription?.cancel();
    _colorSubscription = null;
    _screenService.stopMonitoring();
    _isEnabled = false;
    print('Adaptive lighting stopped');
  }

  void updateSettings({double? fps, double? brightnessScale}) {
    if (fps != null) {
      _fps = fps;
      if (_isEnabled) {
        _screenService.updateFrameRate(fps);
      }
    }
    
    if (brightnessScale != null) {
      _brightnessScale = brightnessScale.clamp(0.1, 1.0);
    }
  }

  void _applyScreenColorsToLivingRoom(ScreenColorData colorData) async {
    try {
      // Generate scene from screen colors
      final scene = _generateSceneFromColors(colorData);
      
      // Apply scene to living room zone using test endpoint
      await _sceneService.testSceneDefinitionInZone(scene, targetZone);
      
      print('Applied colors to $targetZone: center=${colorData.center}');
    } catch (e) {
      print('Failed to apply colors to lights: $e');
    }
  }

  LightingScene _generateSceneFromColors(ScreenColorData colorData) {
    // Use center color as primary color for all lights
    final primaryColor = colorData.center;
    
    // Convert RGB to HSV for SceneLight format
    final hsv = HSVColor.fromColor(primaryColor);
    
    // Create scene lights - using center color for all lights for simplicity
    final lights = [
      SceneLight(
        hue: hsv.hue,
        saturation: hsv.saturation,
        brightness: (254 * _brightnessScale).round().toDouble(),
      ),
    ];

    // Create temporary scene for testing
    return LightingScene(
      id: 'adaptive_temp_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Adaptive Lighting',
      lights: lights,
      order: 0,
      isCustom: true,
    );
  }

  // Generate scene with regional color variations (future enhancement)
  LightingScene _generateMultiRegionScene(ScreenColorData colorData) {
    final colors = [
      colorData.topLeft,
      colorData.topRight,
      colorData.center,
      colorData.bottomLeft,
      colorData.bottomRight,
    ];

    final lights = colors.map((color) {
      final hsv = HSVColor.fromColor(color);
      return SceneLight(
        hue: hsv.hue,
        saturation: hsv.saturation,
        brightness: (254 * _brightnessScale).round().toDouble(),
      );
    }).toList();

    return LightingScene(
      id: 'adaptive_multi_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Adaptive Multi-Region',
      lights: lights,
      order: 0,
      isCustom: true,
    );
  }

  // Get current screen colors for preview
  Stream<ScreenColorData> get screenColors => _screenService.colorStream;

  void dispose() {
    stopAdaptiveLighting();
  }
}

// Provider for adaptive lighting service
final adaptiveLightingServiceProvider = Provider<AdaptiveLightingService>((ref) {
  return AdaptiveLightingService();
});

// State notifier for adaptive lighting controls
class AdaptiveLightingNotifier extends StateNotifier<AdaptiveLightingState> {
  final AdaptiveLightingService _service;

  AdaptiveLightingNotifier(this._service) : super(const AdaptiveLightingState());

  void toggleAdaptiveLighting() {
    if (state.isEnabled) {
      _service.stopAdaptiveLighting();
      state = state.copyWith(isEnabled: false);
    } else {
      _service.startAdaptiveLighting(fps: state.fps);
      state = state.copyWith(isEnabled: true);
    }
  }

  void updateFPS(double fps) {
    _service.updateSettings(fps: fps);
    state = state.copyWith(fps: fps);
    
    if (state.isEnabled) {
      // Restart with new FPS
      _service.stopAdaptiveLighting();
      _service.startAdaptiveLighting(fps: fps);
    }
  }

  void updateBrightnessScale(double scale) {
    _service.updateSettings(brightnessScale: scale);
    state = state.copyWith(brightnessScale: scale);
  }
}

// State class for adaptive lighting
class AdaptiveLightingState {
  final bool isEnabled;
  final double fps;
  final double brightnessScale;

  const AdaptiveLightingState({
    this.isEnabled = false,
    this.fps = 1.0,
    this.brightnessScale = 0.8,
  });

  AdaptiveLightingState copyWith({
    bool? isEnabled,
    double? fps,
    double? brightnessScale,
  }) {
    return AdaptiveLightingState(
      isEnabled: isEnabled ?? this.isEnabled,
      fps: fps ?? this.fps,
      brightnessScale: brightnessScale ?? this.brightnessScale,
    );
  }
}

// Provider for adaptive lighting state
final adaptiveLightingNotifierProvider = StateNotifierProvider<AdaptiveLightingNotifier, AdaptiveLightingState>((ref) {
  final service = ref.watch(adaptiveLightingServiceProvider);
  return AdaptiveLightingNotifier(service);
});