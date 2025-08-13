import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../types.dart';
import '../zigbee-service.dart';
import '../controls/master_control.dart';

class LightsModal extends ConsumerWidget {
  final List<Device> lightDevices;
  
  const LightsModal({
    Key? key,
    required this.lightDevices,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      key: ValueKey('lights-modal-${lightDevices.map((d) => d.friendlyName).join("-")}'),
      child: _buildModalContent(context, lightDevices),
    );
  }
  
  Widget _buildModalContent(BuildContext context, List<Device> lightDevices) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
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
                        Colors.amber.withOpacity(0.2),
                        Colors.orange.withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.lightbulb_rounded,
                    color: Colors.amber[700],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lights Control',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${lightDevices.length} device${lightDevices.length != 1 ? 's' : ''}',
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
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: LightsModalContent(lightDevices: lightDevices),
            ),
          ),
        ],
      ),
    );
  }
}

class LightsModalContent extends ConsumerWidget {
  final List<Device> lightDevices;
  
  const LightsModalContent({
    Key? key,
    required this.lightDevices,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the devicesProvider for real-time updates
    final devicesState = ref.watch(devicesProvider);
    
    return devicesState.when(
      data: (allDevices) {
        // Get updated light devices with current state
        final currentLightDevices = lightDevices.map((light) {
          return allDevices.firstWhere(
            (d) => d.friendlyName == light.friendlyName,
            orElse: () => light,
          );
        }).toList();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Master controls (includes individual controls)
            MasterControlWidget(
              devices: currentLightDevices,
              showIndividualControls: true,
              compactMode: false,
            ),
          ],
        );
      },
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 16),
          MasterControlWidget(
            devices: lightDevices,
            showIndividualControls: true,
            compactMode: false,
          ),
        ],
      ),
      error: (error, stack) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'Error loading device states: $error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          const SizedBox(height: 16),
          MasterControlWidget(
            devices: lightDevices,
            showIndividualControls: true,
            compactMode: false,
          ),
        ],
      ),
    );
  }
}