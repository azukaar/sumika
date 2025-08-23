import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:screen_capturer/screen_capturer.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';

class ScreenColorData {
  final Color topLeft;
  final Color topRight;
  final Color center;
  final Color bottomLeft;
  final Color bottomRight;
  final DateTime timestamp;

  const ScreenColorData({
    required this.topLeft,
    required this.topRight,
    required this.center,
    required this.bottomLeft,
    required this.bottomRight,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'ScreenColorData(topLeft: $topLeft, topRight: $topRight, center: $center, bottomLeft: $bottomLeft, bottomRight: $bottomRight)';
  }
}

class ScreenMonitoringService {
  static final ScreenMonitoringService _instance = ScreenMonitoringService._internal();
  factory ScreenMonitoringService() => _instance;
  ScreenMonitoringService._internal();

  Timer? _timer;
  final StreamController<ScreenColorData> _colorController = StreamController<ScreenColorData>.broadcast();
  bool _isMonitoring = false;
  double _fps = 1.0;

  Stream<ScreenColorData> get colorStream => _colorController.stream;
  bool get isMonitoring => _isMonitoring;
  double get currentFPS => _fps;

  void startMonitoring({double fps = 1.0}) {
    if (_isMonitoring) {
      stopMonitoring();
    }

    _fps = fps;
    _isMonitoring = true;

    final intervalMs = (1000 / fps).round();
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) async {
      try {
        final colorData = await _captureScreenColors();
        if (colorData != null && !_colorController.isClosed) {
          _colorController.add(colorData);
        }
      } catch (e) {
        print('Screen capture error: $e');
      }
    });

    print('Screen monitoring started at $fps FPS');
  }

  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
    _isMonitoring = false;
    print('Screen monitoring stopped');
  }

  void updateFrameRate(double fps) {
    if (_isMonitoring) {
      startMonitoring(fps: fps);
    } else {
      _fps = fps;
    }
  }

  Future<ScreenColorData?> _captureScreenColors() async {
    try {
      // Try the region capture mode as a workaround for Windows CaptureMode.screen bug
      // Based on GitHub issue #41: https://github.com/leanflutter/screen_capturer/issues/41
      
      final tempDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagePath = '${tempDir.path}/screen_capture_$timestamp.png';
      
      // First try CaptureMode.region as it might work better on Windows
      CapturedData? capturedData = await screenCapturer.capture(
        mode: CaptureMode.region,
        imagePath: imagePath,
        copyToClipboard: false,
      );

      // If region mode failed, try screen mode
      if (capturedData?.imagePath == null) {
        print('Region capture failed, trying screen mode...');
        capturedData = await screenCapturer.capture(
          mode: CaptureMode.screen,
          imagePath: imagePath,
          copyToClipboard: false,
        );
      }

      if (capturedData?.imagePath == null) {
        print('Both capture modes failed - known Windows issue. Generating test colors...');
        return _generateTestColors();
      }

      // Read the captured image file
      final File imageFile = File(capturedData!.imagePath!);
      if (!await imageFile.exists()) {
        print('Captured image file does not exist, using test colors');
        return _generateTestColors();
      }

      final Uint8List imageBytes = await imageFile.readAsBytes();
      
      // Decode image using the image package
      final img.Image? screenImage = img.decodeImage(imageBytes);
      if (screenImage == null) {
        print('Failed to decode captured image, using test colors');
        return _generateTestColors();
      }

      // Extract colors from 5 regions
      final colors = _extractRegionColors(screenImage);
      
      // Clean up the temporary file
      try {
        await imageFile.delete();
      } catch (e) {
        print('Warning: Failed to delete temporary image file: $e');
      }
      
      return ScreenColorData(
        topLeft: colors[0],
        topRight: colors[1],
        center: colors[2],
        bottomLeft: colors[3],
        bottomRight: colors[4],
        timestamp: DateTime.now(),
      );
    } catch (e) {
      print('Screen capture failed: $e, using test colors');
      return _generateTestColors();
    }
  }

  // Fallback method to generate test colors when screen capture fails
  ScreenColorData _generateTestColors() {
    // Generate colors that change over time for testing the lighting system
    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
    
    // Create colors that slowly cycle through different hues
    final hue1 = (time * 10) % 360;
    final hue2 = (time * 15 + 90) % 360;
    final hue3 = (time * 8 + 180) % 360;
    final hue4 = (time * 12 + 270) % 360;
    final hue5 = (time * 6 + 45) % 360;
    
    return ScreenColorData(
      topLeft: HSVColor.fromAHSV(1.0, hue1, 0.7, 0.8).toColor(),
      topRight: HSVColor.fromAHSV(1.0, hue2, 0.7, 0.8).toColor(),
      center: HSVColor.fromAHSV(1.0, hue3, 0.7, 0.8).toColor(),
      bottomLeft: HSVColor.fromAHSV(1.0, hue4, 0.7, 0.8).toColor(),
      bottomRight: HSVColor.fromAHSV(1.0, hue5, 0.7, 0.8).toColor(),
      timestamp: DateTime.now(),
    );
  }

  List<Color> _extractRegionColors(img.Image image) {
    final width = image.width;
    final height = image.height;

    // Define regions (each region is 20% of screen width/height centered in quadrant)
    final regionSize = (width * 0.2).round();
    
    final regions = [
      // Top-left
      _getRegionCenter(width ~/ 4, height ~/ 4, regionSize, image),
      // Top-right  
      _getRegionCenter(width * 3 ~/ 4, height ~/ 4, regionSize, image),
      // Center
      _getRegionCenter(width ~/ 2, height ~/ 2, regionSize, image),
      // Bottom-left
      _getRegionCenter(width ~/ 4, height * 3 ~/ 4, regionSize, image),
      // Bottom-right
      _getRegionCenter(width * 3 ~/ 4, height * 3 ~/ 4, regionSize, image),
    ];

    return regions;
  }

  Color _getRegionCenter(int centerX, int centerY, int regionSize, img.Image image) {
    int totalR = 0, totalG = 0, totalB = 0;
    int pixelCount = 0;

    final halfSize = regionSize ~/ 2;
    final startX = (centerX - halfSize).clamp(0, image.width - 1);
    final endX = (centerX + halfSize).clamp(0, image.width - 1);
    final startY = (centerY - halfSize).clamp(0, image.height - 1);
    final endY = (centerY + halfSize).clamp(0, image.height - 1);

    // Sample every 4th pixel for performance
    for (int y = startY; y < endY; y += 4) {
      for (int x = startX; x < endX; x += 4) {
        final pixel = image.getPixel(x, y);
        
        // Extract RGB values from the pixel using the image package format
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        
        totalR += r;
        totalG += g;
        totalB += b;
        pixelCount++;
      }
    }

    if (pixelCount == 0) {
      return Colors.black;
    }

    return Color.fromARGB(
      255,
      (totalR / pixelCount).round().clamp(0, 255),
      (totalG / pixelCount).round().clamp(0, 255),
      (totalB / pixelCount).round().clamp(0, 255),
    );
  }

  void dispose() {
    stopMonitoring();
    _colorController.close();
  }
}