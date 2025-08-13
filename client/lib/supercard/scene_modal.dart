import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../types.dart';
import '../scene_management_service.dart';
import './scene_models.dart';

class SceneModal extends ConsumerWidget {
  final List<Device> lightDevices;
  final Function(LightingScene) onSceneSelected;
  
  const SceneModal({
    Key? key,
    required this.lightDevices,
    required this.onSceneSelected,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
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
                    color: Theme.of(context).colorScheme.secondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lighting Scenes',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'Apply to ${lightDevices.length} light${lightDevices.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
          
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          
          // Scenes grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildScenesGrid(context, ref),
            ),
          ),
          
          // Footer info
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 8),
                Text(
                  'Tap any scene to apply instantly',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenesGrid(BuildContext context, WidgetRef ref) {
    final allScenesAsync = ref.watch(sceneManagementNotifierProvider);
    
    return allScenesAsync.when(
      data: (scenes) => GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: scenes.length,
        itemBuilder: (context, index) {
          final scene = scenes[index];
          return _buildSceneCard(context, scene);
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load scenes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSceneCard(BuildContext context, LightingScene scene) {
    return Container(
      key: ValueKey('scene-card-${scene.name}'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scene.primaryColor.withOpacity(0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: scene.primaryColor.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            onSceneSelected(scene);
            // Navigator.of(context).pop();
          },
          borderRadius: BorderRadius.circular(20),
          child: FutureBuilder<String>(
            future: scene.imageUrl,
            builder: (context, snapshot) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  image: snapshot.hasData 
                    ? DecorationImage(
                        image: NetworkImage(snapshot.data!),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.3),
                          BlendMode.darken,
                        ),
                      )
                    : null,
                  color: snapshot.hasData ? null : scene.primaryColor.withOpacity(0.3),
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        scene.primaryColor.withOpacity(0.3),
                        scene.primaryColor.withOpacity(0.5),
                        Colors.black.withOpacity(0.8),
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Color preview dots (moved to top)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: scene.lights.take(4).map((light) {
                          final color = HSVColor.fromAHSV(
                            1.0,
                            light.hue,
                            light.saturation,
                            1.0,
                          ).toColor();
                          
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.8), 
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.shadow.withOpacity(0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      
                      // Show "+" if more than 4 colors
                      if (scene.lights.length > 4)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '+${scene.lights.length - 4} more',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        
                      const SizedBox(height: 12),
                      
                      // Scene name (moved to bottom, larger)
                      Text(
                        scene.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 2),
                              blurRadius: 6,
                              color: Colors.black87,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
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
}