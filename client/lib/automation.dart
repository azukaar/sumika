import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import './automation_types.dart';
import './automation_service.dart';
import './automation_create.dart';
import './types.dart';
import './zigbee-service.dart';
import './utils/device_utils.dart';

class AutomationPage extends ConsumerStatefulWidget {
  const AutomationPage({super.key});

  @override
  ConsumerState<AutomationPage> createState() => _AutomationPageState();
}

class _AutomationPageState extends ConsumerState<AutomationPage> {
  @override
  Widget build(BuildContext context) {
    final automationsAsyncValue = ref.watch(automationNotifierProvider);
    final devicesAsyncValue = ref.watch(devicesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Automation',
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
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
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
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(automationNotifierProvider);
        },
        child: automationsAsyncValue.when(
          data: (automations) => _buildAutomationsList(context, automations),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _buildErrorView(context, error.toString()),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToCreateAutomation(context),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create Automation'),
      ),
    );
  }

  Widget _buildAutomationsList(BuildContext context, List<Automation> automations) {
    if (automations.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: automations.length,
      itemBuilder: (context, index) {
        final automation = automations[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildAutomationCard(context, automation),
        );
      },
    );
  }

  Widget _buildAutomationCard(BuildContext context, Automation automation) {
    final devicesAsyncValue = ref.watch(devicesProvider);
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showAutomationDetails(context, automation),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: automation.enabled 
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                          : Theme.of(context).colorScheme.outline.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      automation.type == AutomationTypes.ifttt 
                          ? Icons.rule_rounded
                          : Icons.link_rounded,
                      color: automation.enabled 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          automation.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: automation.enabled 
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                        if (automation.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              automation.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Switch(
                    value: automation.enabled,
                    onChanged: (value) => _toggleAutomation(automation.id, value),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: Theme.of(context).colorScheme.outline,
                      size: 18,
                    ),
                    onSelected: (value) => _handleMenuAction(context, automation, value),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'run',
                        child: Row(
                          children: [
                            Icon(Icons.play_arrow_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Run Now'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: devicesAsyncValue.when(
                  data: (devices) => Column(
                    children: [
                      _buildTriggerActionRow(context, 'When', 
                          DeviceUtils.getDeviceDisplayNameByFriendlyName(devices, automation.trigger.deviceName), 
                          '${_getPropertyDisplayName(automation.trigger.property)} ${AutomationConditions.getDisplayName(automation.trigger.condition).toLowerCase()} ${_formatValue(automation.trigger.value)}'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_downward_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Divider(
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildTriggerActionRow(context, 'Then', 
                          _getActionTargetName(automation.action, devices), 
                          _getActionDescription(automation.action)),
                    ],
                  ),
                  loading: () => Column(
                    children: [
                      _buildTriggerActionRow(context, 'When', automation.trigger.deviceName, 
                          '${_getPropertyDisplayName(automation.trigger.property)} ${AutomationConditions.getDisplayName(automation.trigger.condition).toLowerCase()} ${_formatValue(automation.trigger.value)}'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_downward_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Divider(
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildTriggerActionRow(context, 'Then', _getActionTargetName(automation.action, []), 
                          _getActionDescription(automation.action)),
                    ],
                  ),
                  error: (error, stack) => Column(
                    children: [
                      _buildTriggerActionRow(context, 'When', automation.trigger.deviceName, 
                          '${_getPropertyDisplayName(automation.trigger.property)} ${AutomationConditions.getDisplayName(automation.trigger.condition).toLowerCase()} ${_formatValue(automation.trigger.value)}'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_downward_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Divider(
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildTriggerActionRow(context, 'Then', _getActionTargetName(automation.action, []), 
                          _getActionDescription(automation.action)),
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

  Widget _buildTriggerActionRow(BuildContext context, String label, String deviceName, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                deviceName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
                    Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
                    Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.rule_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Automations Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first automation to make your smart home work automatically',
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
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () => _navigateToCreateAutomation(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'Create First Automation',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Automations',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(automationNotifierProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCreateAutomation(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AutomationCreatePage()),
    );
  }

  void _showAutomationDetails(BuildContext context, Automation automation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AutomationCreatePage(automationToEdit: automation),
      ),
    );
  }

  Future<void> _toggleAutomation(String id, bool enabled) async {
    try {
      await ref.read(automationNotifierProvider.notifier).toggleAutomationEnabled(id, enabled);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${enabled ? 'enable' : 'disable'} automation: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _runAutomation(Automation automation) async {
    try {
      await ref.read(automationNotifierProvider.notifier).runAutomation(automation.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Automation "${automation.name}" executed successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to run automation: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _handleMenuAction(BuildContext context, Automation automation, String action) {
    switch (action) {
      case 'run':
        _runAutomation(automation);
        break;
      case 'edit':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AutomationCreatePage(automationToEdit: automation),
          ),
        );
        break;
      case 'delete':
        _confirmDeleteAutomation(context, automation);
        break;
    }
  }

  Future<void> _confirmDeleteAutomation(BuildContext context, Automation automation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Automation'),
        content: Text('Are you sure you want to delete "${automation.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(automationNotifierProvider.notifier).deleteAutomation(automation.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted "${automation.name}"')),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete automation: $error'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  String _getPropertyDisplayName(String property) {
    switch (property) {
      case 'state':
        return 'State';
      case 'brightness':
        return 'Brightness';
      case 'color':
        return 'Color';
      case 'color_temp':
        return 'Color Temperature';
      case 'temperature':
        return 'Temperature';
      case 'humidity':
        return 'Humidity';
      case 'contact':
        return 'Contact';
      case 'occupancy':
        return 'Occupancy';
      case 'motion':
        return 'Motion';
      case 'illuminance':
        return 'Light Level';
      case 'battery':
        return 'Battery Level';
      default:
        return property.replaceAll('_', ' ').split(' ').map((word) => 
            word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : word
        ).join(' ');
    }
  }

  String _formatValue(dynamic value) {
    if (value == null) {
      return 'any value';
    }
    if (value == 'TOGGLE') {
      return 'TOGGLE';
    }
    return value.toString();
  }

  String _getActionTargetName(AutomationAction action, List<Device> devices) {
    // Scene action
    if (action.sceneZone != null && action.sceneName != null) {
      return '${action.sceneZone} Zone';
    }
    
    // Device action
    if (action.deviceName != null) {
      return DeviceUtils.getDeviceDisplayNameByFriendlyName(devices, action.deviceName!);
    }
    
    // Zone action
    if (action.zone != null && action.category != null) {
      return '${action.zone} (${action.category})';
    }
    
    return 'Unknown target';
  }

  String _getActionDescription(AutomationAction action) {
    // Scene action
    if (action.sceneZone != null && action.sceneName != null) {
      return 'Apply ${action.sceneName} scene';
    }
    
    // Device or zone action
    if (action.property != null) {
      return 'Set ${_getPropertyDisplayName(action.property!).toLowerCase()} to ${_formatValue(action.value)}';
    }
    
    return 'Unknown action';
  }
}