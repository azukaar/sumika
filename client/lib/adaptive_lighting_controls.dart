import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'adaptive_lighting_service.dart';
import 'screen_monitoring_service.dart';

class AdaptiveLightingControls extends ConsumerWidget {
  const AdaptiveLightingControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adaptiveState = ref.watch(adaptiveLightingNotifierProvider);
    final adaptiveNotifier = ref.read(adaptiveLightingNotifierProvider.notifier);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outlined,
                  color: adaptiveState.isEnabled 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 12),
                Text(
                  'Adaptive Lighting',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: adaptiveState.isEnabled,
                  onChanged: (_) => adaptiveNotifier.toggleAdaptiveLighting(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Automatically adjusts living room lights based on screen colors',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            if (adaptiveState.isEnabled) ...[
              const SizedBox(height: 24),
              _buildFPSControl(context, adaptiveState, adaptiveNotifier),
              const SizedBox(height: 20),
              _buildBrightnessControl(context, adaptiveState, adaptiveNotifier),
              const SizedBox(height: 20),
              _buildLivePreview(context, ref),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFPSControl(BuildContext context, AdaptiveLightingState state, AdaptiveLightingNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Update Rate',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${state.fps.toStringAsFixed(1)} FPS',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: state.fps,
          min: 0.5,
          max: 10.0,
          divisions: 19, // 0.5, 1.0, 1.5, ... 10.0
          onChanged: (value) => notifier.updateFPS(value),
          label: '${state.fps.toStringAsFixed(1)} FPS',
        ),
        Text(
          'Higher rates provide smoother transitions but use more resources',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildBrightnessControl(BuildContext context, AdaptiveLightingState state, AdaptiveLightingNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Brightness Scale',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(state.brightnessScale * 100).round()}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: state.brightnessScale,
          min: 0.1,
          max: 1.0,
          divisions: 9, // 10%, 20%, ... 100%
          onChanged: (value) => notifier.updateBrightnessScale(value),
          label: '${(state.brightnessScale * 100).round()}%',
        ),
        Text(
          'Controls the overall brightness of adaptive lighting',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildLivePreview(BuildContext context, WidgetRef ref) {
    final adaptiveService = ref.read(adaptiveLightingServiceProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Live Color Preview',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<ScreenColorData>(
          stream: adaptiveService.screenColors,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('Waiting for color data...'),
                ),
              );
            }

            final colors = snapshot.data!;
            return Container(
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  _buildColorPreview('TL', colors.topLeft),
                  _buildColorPreview('TR', colors.topRight),
                  _buildColorPreview('C', colors.center, isCenter: true),
                  _buildColorPreview('BL', colors.bottomLeft),
                  _buildColorPreview('BR', colors.bottomRight),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          'TL=Top Left, TR=Top Right, C=Center (used for lights), BL=Bottom Left, BR=Bottom Right',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPreview(String label, Color color, {bool isCenter = false}) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: color,
          border: isCenter ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: _getContrastColor(color),
                fontWeight: isCenter ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
            ),
            if (isCenter) ...[
              const SizedBox(height: 2),
              Icon(
                Icons.lightbulb,
                color: _getContrastColor(color),
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getContrastColor(Color color) {
    // Calculate luminance to determine if white or black text is better
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}

// Quick toggle widget for dashboard integration
class AdaptiveLightingQuickToggle extends ConsumerWidget {
  const AdaptiveLightingQuickToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adaptiveState = ref.watch(adaptiveLightingNotifierProvider);
    final adaptiveNotifier = ref.read(adaptiveLightingNotifierProvider.notifier);

    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: adaptiveState.isEnabled
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          adaptiveState.isEnabled ? Icons.lightbulb : Icons.lightbulb_outlined,
          color: adaptiveState.isEnabled
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          size: 20,
        ),
      ),
      onPressed: () => adaptiveNotifier.toggleAdaptiveLighting(),
      tooltip: adaptiveState.isEnabled 
          ? 'Disable Adaptive Lighting'
          : 'Enable Adaptive Lighting',
    );
  }
}