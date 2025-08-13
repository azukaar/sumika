import 'package:flutter/material.dart';

/// A custom color picker widget with a single square picker
class CustomColorPicker extends StatefulWidget {
  final double hue;
  final double saturation;
  final Function(double hue, double saturation) onColorChanged;

  const CustomColorPicker({
    Key? key,
    required this.hue,
    required this.saturation,
    required this.onColorChanged,
  }) : super(key: key);

  @override
  State<CustomColorPicker> createState() => _CustomColorPickerState();
}

class _CustomColorPickerState extends State<CustomColorPicker> {
  static const double _size = 240.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      child: _buildHueSaturationSquare(),
    );
  }

  Widget _buildHueSaturationSquare() {
    return GestureDetector(
      onPanUpdate: (details) => _handleSquarePan(details),
      onTapDown: (details) => _handleSquareTap(details),
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Stack(
            children: [
              // Hue gradient (left to right)
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFFFF0000), // Red
                      Color(0xFFFF8000), // Orange
                      Color(0xFFFFFF00), // Yellow
                      Color(0xFF80FF00), // Yellow-Green
                      Color(0xFF00FF00), // Green
                      Color(0xFF00FF80), // Green-Cyan
                      Color(0xFF00FFFF), // Cyan
                      Color(0xFF0080FF), // Cyan-Blue
                      Color(0xFF0000FF), // Blue
                      Color(0xFF8000FF), // Blue-Magenta
                      Color(0xFFFF00FF), // Magenta
                      Color(0xFFFF0080), // Magenta-Red
                    ],
                  ),
                ),
              ),
              // Saturation gradient (top to bottom: full saturation to white)
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.white],
                  ),
                ),
              ),
              // Current selection indicator
              Positioned(
                left: (widget.hue / 360.0).clamp(0.0, 1.0) * _size - 6,
                top: (1.0 - widget.saturation).clamp(0.0, 1.0) * _size - 6, // Invert saturation for natural feel
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSquarePan(DragUpdateDetails details) {
    _updateHueSaturation(details.localPosition);
  }

  void _handleSquareTap(TapDownDetails details) {
    _updateHueSaturation(details.localPosition);
  }

  void _updateHueSaturation(Offset position) {
    final hue = ((position.dx / _size) * 360.0).clamp(0.0, 360.0);
    final saturation = (1.0 - (position.dy / _size)).clamp(0.0, 1.0); // Invert Y for natural feel
    widget.onColorChanged(hue, saturation);
  }
}