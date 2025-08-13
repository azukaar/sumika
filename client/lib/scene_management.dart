import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import './scene_management_service.dart';
import './supercard/scene_models.dart';
import './controls/custom_color_picker.dart';
import './zigbee-service.dart';
import 'dart:async';

class SceneManagementPage extends ConsumerStatefulWidget {
  const SceneManagementPage({super.key});

  @override
  ConsumerState<SceneManagementPage> createState() =>
      _SceneManagementPageState();
}

class _SceneManagementPageState extends ConsumerState<SceneManagementPage> {
  @override
  Widget build(BuildContext context) {
    final scenesAsync = ref.watch(sceneManagementNotifierProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Scene Management',
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
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withOpacity(0.1),
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
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              onPressed: () => _showCreateSceneDialog(context),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: scenesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text('Error: $error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ref
                          .read(sceneManagementNotifierProvider.notifier)
                          .loadScenes();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (scenes) => _buildScenesList(context, scenes),
          ),
        ),
      ),
    );
  }

  Widget _buildScenesList(BuildContext context, List<LightingScene> scenes) {
    if (scenes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.1),
                    Theme.of(context)
                        .colorScheme
                        .secondaryContainer
                        .withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.palette_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Scenes Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first custom lighting scene to get started',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 16,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () => _showCreateSceneDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'Create Your First Scene',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Scenes',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage and customize your lighting scenes',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: scenes.length,
            onReorder: _onReorderScenes,
            itemBuilder: (context, index) {
              final scene = scenes[index];
              return _buildSceneCard(context, scene, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSceneCard(BuildContext context, LightingScene scene, int index) {
    return Container(
      key: ValueKey(scene.id),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surface.withOpacity(0.8),
          ],
        ),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: scene.isCustom
              ? () => _showEditSceneDialog(context, scene)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Scene preview
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: scene.lights.isNotEmpty
                          ? [
                              HSVColor.fromAHSV(1.0, scene.lights.first.hue,
                                      scene.lights.first.saturation, 1.0)
                                  .toColor(),
                              HSVColor.fromAHSV(1.0, scene.lights.first.hue,
                                      scene.lights.first.saturation * 0.7, 0.8)
                                  .toColor(),
                            ]
                          : [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.secondary,
                            ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.palette_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Scene info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scene.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${scene.lights.length} color${scene.lights.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: scene.isCustom
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.1)
                                  : Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              scene.isCustom ? 'Custom' : 'Default',
                              style: TextStyle(
                                fontSize: 12,
                                color: scene.isCustom
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (scene.lights.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        // Color preview
                        Row(
                          children: scene.lights.take(5).map((light) {
                            return Container(
                              margin: const EdgeInsets.only(right: 6),
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: HSVColor.fromAHSV(
                                        1.0,
                                        light.hue,
                                        light.saturation,
                                        light.brightness / 254.0)
                                    .toColor(),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                // Actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                        size: 20,
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'duplicate':
                            _duplicateScene(scene);
                            break;
                          case 'delete':
                            _showDeleteConfirmation(context, scene);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'duplicate',
                          child: Row(
                            children: [
                              Icon(Icons.copy_outlined, size: 18),
                              SizedBox(width: 12),
                              Text('Duplicate'),
                            ],
                          ),
                        ),
                        if (scene.isCustom)
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline,
                                    size: 18, color: Colors.red),
                                SizedBox(width: 12),
                                Text('Delete',
                                    style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    Icon(
                      Icons.drag_handle_rounded,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.4),
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onReorderScenes(int oldIndex, int newIndex) {
    final scenes = ref.read(sceneManagementNotifierProvider).value;
    if (scenes == null) return;

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    // Create reorder data
    final reorderedScenes = List<LightingScene>.from(scenes);
    final item = reorderedScenes.removeAt(oldIndex);
    reorderedScenes.insert(newIndex, item);

    // Debug: Log the scenes we're reordering
    for (var i = 0; i < reorderedScenes.length; i++) {
      final scene = reorderedScenes[i];
    }

    // Update orders
    final sceneOrders = <Map<String, dynamic>>[];
    for (var i = 0; i < reorderedScenes.length; i++) {
      final scene = reorderedScenes[i];
      if (scene.id.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Scene "${scene.name}" has empty ID'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      sceneOrders.add({
        'id': scene.id,
        'order': i,
      });
    }

    // Send to server
    ref
        .read(sceneManagementNotifierProvider.notifier)
        .reorderScenes(sceneOrders);
  }

  void _showCreateSceneDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SceneEditorDialog(),
    );
  }

  void _showEditSceneDialog(BuildContext context, LightingScene scene) {
    showDialog(
      context: context,
      builder: (context) => SceneEditorDialog(scene: scene),
    );
  }

  void _duplicateScene(LightingScene scene) async {
    try {
      await ref
          .read(sceneManagementNotifierProvider.notifier)
          .duplicateScene(scene.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scene "${scene.name}" duplicated')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to duplicate scene: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmation(BuildContext context, LightingScene scene) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Scene'),
        content: Text(
            'Are you sure you want to delete "${scene.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.of(context).pop();
              ref
                  .read(sceneManagementNotifierProvider.notifier)
                  .deleteScene(scene.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Scene "${scene.name}" deleted')),
              );
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class SceneEditorDialog extends ConsumerStatefulWidget {
  final LightingScene? scene;

  const SceneEditorDialog({super.key, this.scene});

  @override
  ConsumerState<SceneEditorDialog> createState() => _SceneEditorDialogState();
}

class _SceneEditorDialogState extends ConsumerState<SceneEditorDialog> {
  late TextEditingController _nameController;
  List<SceneLight> _lights = [];
  String? _selectedTestZone;
  List<String> _availableZones = [];
  bool _isLoading = false;
  Timer? _testSceneTimer;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.scene?.name ?? '');
    _lights = widget.scene?.lights ??
        [SceneLight(hue: 200, saturation: 0.8, brightness: 180)];

    _loadAvailableZones();
  }

  Future<void> _loadAvailableZones() async {
    try {
      final zones = await ref.read(devicesProvider.notifier).getAllZones();
      setState(() {
        _availableZones = zones;
        if (_availableZones.isNotEmpty && _selectedTestZone == null) {
          _selectedTestZone = _availableZones.first;
        }
      });
    } catch (e) {
      print('Error loading zones: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _testSceneTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Text(
                    widget.scene == null ? 'Create Scene' : 'Edit Scene',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic info
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Scene Name',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Test zone selection
                    if (_availableZones.isNotEmpty) ...[
                      Text(
                        'Live Preview Zone',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select a zone to preview your scene changes in real-time',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedTestZone,
                        hint: Text('Select a zone for live preview'),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          prefixIcon: Icon(Icons.visibility, size: 20),
                        ),
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text('No preview',
                                style: TextStyle(fontStyle: FontStyle.italic)),
                          ),
                          ..._availableZones
                              .map((zone) => DropdownMenuItem(
                                    value: zone,
                                    child: Text(zone.replaceAll('_', ' ')),
                                  ))
                              .toList(),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedTestZone = value;
                          });
                          _scheduleTestScene();
                        },
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Colors section
                    Text(
                      'Colors (${_lights.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Color list
                    ..._lights.asMap().entries.map((entry) {
                      final index = entry.key;
                      final light = entry.value;
                      return _buildColorEditor(index, light);
                    }).toList(),

                    // Add color button
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _addColor,
                      icon: Icon(Icons.add),
                      label: Text('Add Color'),
                      style: OutlinedButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveScene,
                    child: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.scene == null ? 'Create' : 'Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorEditor(int index, SceneLight light) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HSVColor.fromAHSV(1.0, light.hue, light.saturation,
                          light.brightness / 254.0)
                      .toColor(),
                  border: Border.all(color: Colors.grey.shade300),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Color ${index + 1}',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (_lights.length > 1)
                IconButton(
                  onPressed: () => _removeColor(index),
                  icon: Icon(Icons.delete_outline, size: 20, color: Colors.red),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CustomColorPicker(
                hue: light.hue,
                saturation: light.saturation,
                onColorChanged: (hue, saturation) {
                  setState(() {
                    _lights[index] = SceneLight(
                      hue: hue,
                      saturation: saturation,
                      brightness: light.brightness,
                    );
                  });
                  _scheduleTestScene();
                },
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  Text('Brightness',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Slider(
                        value: light.brightness,
                        min: 1.0,
                        max: 254.0,
                        divisions: 253,
                        onChanged: (value) {
                          setState(() {
                            _lights[index] = SceneLight(
                              hue: light.hue,
                              saturation: light.saturation,
                              brightness: value,
                            );
                          });
                          _scheduleTestScene();
                        },
                      ),
                    ),
                  ),
                  Text('${light.brightness.round()}'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addColor() {
    setState(() {
      _lights.add(SceneLight(hue: 200, saturation: 0.8, brightness: 180));
    });
    _scheduleTestScene();
  }

  void _removeColor(int index) {
    if (_lights.length > 1) {
      setState(() {
        _lights.removeAt(index);
      });
      _scheduleTestScene();
    }
  }

  void _scheduleTestScene() {
    if (_selectedTestZone == null) return;

    // Cancel existing timer
    _testSceneTimer?.cancel();

    // Schedule new test with 200ms debounce
    _testSceneTimer = Timer(const Duration(milliseconds: 200), () {
      _testScene();
    });
  }

  Future<void> _testScene() async {
    if (_selectedTestZone == null) return;

    try {
      // Create temporary scene for testing
      final tempScene = LightingScene(
        id: 'temp_test',
        name: _nameController.text,
        lights: _lights,
        order: 0,
        isCustom: true,
      );

      final service = ref.read(sceneManagementServiceProvider);

      // First create the temp scene
      await service.createScene(tempScene);

      // Then test it in the selected zone
      await service.testSceneInZone('temp_test', _selectedTestZone!);

      // Clean up temp scene
      await service.deleteScene('temp_test');
    } catch (e) {
      // Silent fail for auto-testing - don't show snackbar for every failure
      print('Auto-test failed: $e');
    }
  }

  Future<void> _saveScene() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a scene name')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final scene = LightingScene(
        id: widget.scene?.id ?? '',
        name: _nameController.text,
        lights: _lights,
        order: widget.scene?.order ?? 0,
        isCustom: true,
        createdAt: widget.scene?.createdAt,
      );

      if (widget.scene == null) {
        await ref
            .read(sceneManagementNotifierProvider.notifier)
            .createScene(scene);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scene "${scene.name}" created')),
        );
      } else {
        await ref
            .read(sceneManagementNotifierProvider.notifier)
            .updateScene(widget.scene!.id, scene);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scene "${scene.name}" updated')),
        );
      }

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error saving scene: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
