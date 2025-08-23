import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'adaptive_lighting_controls.dart';
import 'adaptive_lighting_service.dart';

/// Test page for adaptive lighting functionality
class AdaptiveLightingTestPage extends ConsumerWidget {
  const AdaptiveLightingTestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adaptive Lighting Test'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Test color areas
            Container(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      color: Colors.red.shade300,
                      child: const Center(
                        child: Text('Red Area', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      color: Colors.blue.shade300,
                      child: const Center(
                        child: Text('Blue Area', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 100,
              color: Colors.green.shade300,
              child: const Center(
                child: Text('Center Green Area', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      color: Colors.purple.shade300,
                      child: const Center(
                        child: Text('Purple Area', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      color: Colors.orange.shade300,
                      child: const Center(
                        child: Text('Orange Area', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Adaptive lighting controls
            const AdaptiveLightingControls(),
            
            const SizedBox(height: 20),
            
            // Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Instructions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. Enable adaptive lighting using the toggle above\n'
                      '2. Make sure you have lights in the "living room" zone\n'
                      '3. Watch the color preview update as the screen changes\n'
                      '4. The lights should change to match the center green color\n'
                      '5. Try adjusting the frame rate to see different update speeds\n'
                      '6. Adjust brightness scale to control light intensity',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Note: The system extracts colors from 5 screen regions and uses the center color to control all lights in the living room zone.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}