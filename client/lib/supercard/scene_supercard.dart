import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../types.dart';
import '../zigbee-service.dart';
import '../scene_management_service.dart';
import '../widgets/card_interaction_indicator.dart';
import './scene_models.dart';
import './scene_modal.dart';

class SceneSupercard extends ConsumerWidget {
  final List<Device> lightDevices;

  const SceneSupercard({
    super.key,
    required this.lightDevices,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.1),
            Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GestureDetector(
        onLongPress: () => _showAllScenesModal(context),
        onSecondaryTap: () => _showAllScenesModal(context),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                          Theme.of(context).colorScheme.tertiary.withOpacity(0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.palette_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scenes',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'Quick ambiance',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const CardInteractionIndicator(
                    customTooltip: 'Hold or right-click to view all scenes',
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Scene badges
              Expanded(
                child: _buildSceneBadges(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSceneBadges(BuildContext context, WidgetRef ref) {
    final featuredScenesAsync = ref.watch(sceneManagementNotifierProvider);
    
    return featuredScenesAsync.when(
      data: (allScenes) {
        // Take first 5 scenes for featured display
        final featuredScenes = allScenes.take(5).toList();
        return Column(
        children: [
          // First row (3 scenes)
          Expanded(
            child: Row(
              children: featuredScenes.take(3).map((scene) => 
                Expanded(
                  child: _buildSceneBadge(context, ref, scene, isLarge: true),
                ),
              ).toList(),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Second row (2 scenes)
          Expanded(
            child: Row(
              children: [
                ...featuredScenes.skip(3).take(2).map((scene) => 
                  Expanded(
                    child: _buildSceneBadge(context, ref, scene, isLarge: false),
                  ),
                ).toList(),
                // Fill remaining space if less than 2 scenes
                if (featuredScenes.length < 5) const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ],
      );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error loading scenes: $error'),
      ),
    );
  }

  Widget _buildSceneBadge(BuildContext context, WidgetRef ref, LightingScene scene, {required bool isLarge}) {
    return Container(
      key: ValueKey('scene-badge-${scene.name}'),
      margin: const EdgeInsets.all(2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _applyScene(ref, scene, context),
          borderRadius: BorderRadius.circular(12),
          child: FutureBuilder<String>(
            future: scene.imageUrl,
            builder: (context, snapshot) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: snapshot.hasData 
                    ? DecorationImage(
                        image: NetworkImage(snapshot.data!),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.2),
                          BlendMode.darken,
                        ),
                      )
                    : null,
                  color: snapshot.hasData ? null : scene.primaryColor.withOpacity(0.3),
                  boxShadow: [
                    BoxShadow(
                      color: scene.primaryColor.withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        scene.primaryColor.withOpacity(0.7),
                        scene.primaryColor.withOpacity(0.5),
                        Colors.black.withOpacity(0.4),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        scene.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isLarge ? 12 : 9,
                          fontWeight: FontWeight.bold,
                          shadows: const [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 3,
                              color: Colors.black87,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _applyScene(WidgetRef ref, LightingScene scene, [BuildContext? context]) {
    if (lightDevices.isEmpty) return;
    
    // Apply scene colors to lights, looping if more lights than colors
    for (int i = 0; i < lightDevices.length; i++) {
      final device = lightDevices[i];
      final sceneLight = scene.lights[i % scene.lights.length]; // Loop through colors
      
      // Build state update
      final jsonState = <String, dynamic>{
        'state': 'ON', // Ensure light is on
        'brightness': sceneLight.brightness,
        'color': {
          'hue': sceneLight.hue,
          'saturation': sceneLight.saturation * 100, // Convert to 0-100 for Zigbee
        },
      };
      
      // Add transition for smooth color change
      jsonState['transition'] = 0.5;
      
      // Apply to device
      ref.read(devicesProvider.notifier).setDeviceState(
        device.friendlyName,
        jsonState,
      );
    }
    
    // Show feedback if context is provided
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${scene.name} scene applied to ${lightDevices.length} lights'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showAllScenesModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) => Consumer(
        builder: (context, ref, child) => SceneModal(
          lightDevices: lightDevices,
          onSceneSelected: (scene) => _applyScene(ref, scene),
        ),
      ),
    );
  }
}