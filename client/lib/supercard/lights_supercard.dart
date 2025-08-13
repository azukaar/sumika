import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../types.dart';
import '../controls/master_control.dart';
import './lights_modal.dart';

class LightsSupercard extends StatelessWidget {
  final List<Device> lightDevices;

  const LightsSupercard({
    super.key,
    required this.lightDevices,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
            Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
        onSecondaryTap: () => _showLightsControlModal(context, lightDevices), // Right click
        onLongPress: () => _showLightsControlModal(context, lightDevices),    // Long press
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with lights count
              Row(
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
                      size: 20,
                      color: Colors.amber[700],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lights',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '${lightDevices.length} device${lightDevices.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Master brightness control for all lights
              Expanded(
                child: _buildMasterBrightnessControl(context, lightDevices),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMasterBrightnessControl(BuildContext context, List<Device> lightDevices) {
    if (lightDevices.isEmpty) {
      return const Center(child: Text('No lights'));
    }
    
    return MasterControlWidget(
      devices: lightDevices,
      compactMode: true,
    );
  }

  void _showLightsControlModal(BuildContext context, List<Device> lightDevices) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => LightsModal(lightDevices: lightDevices),
    );
  }
}