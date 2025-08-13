import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Settings',
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
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
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
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        Theme.of(context).colorScheme.outline.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context).colorScheme.secondary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.home_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sumika Smart Home',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Manage your smart devices and zones',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Settings menu items
              Expanded(
                child: ListView(
                  children: [
                    _buildMenuTile(
                      context,
                      icon: Icons.devices_rounded,
                      iconColor: Colors.blue,
                      title: 'Devices',
                      subtitle: 'Manage your smart devices',
                      onTap: () => Navigator.pushNamed(context, '/zigbee'),
                    ),
                    const SizedBox(height: 12),
                    _buildMenuTile(
                      context,
                      icon: Icons.location_on_rounded,
                      iconColor: Colors.green,
                      title: 'Zones',
                      subtitle: 'Organize devices by rooms and areas',
                      onTap: () => Navigator.pushNamed(context, '/zones'),
                    ),
                    const SizedBox(height: 12),
                    _buildMenuTile(
                      context,
                      icon: Icons.palette_rounded,
                      iconColor: Colors.purple,
                      title: 'Scenes',
                      subtitle: 'Manage and customize your lighting scenes',
                      onTap: () => Navigator.pushNamed(context, '/scene-management'),
                      isDisabled: false,
                    ),
                    const SizedBox(height: 12),
                    _buildMenuTile(
                      context,
                      icon: Icons.rule_rounded,
                      iconColor: Colors.orange,
                      title: 'Automation',
                      subtitle: 'Create smart home rules and device links',
                      onTap: () => Navigator.pushNamed(context, '/automation'),
                      isDisabled: false,
                    ),
                    const SizedBox(height: 12),
                    _buildMenuTile(
                      context,
                      icon: Icons.settings_rounded,
                      iconColor: Colors.grey,
                      title: 'System Settings',
                      subtitle:
                          'Configure server connection and app preferences',
                      onTap: () =>
                          Navigator.pushNamed(context, '/system-settings'),
                      isDisabled: false,
                    ),
                  ],
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Version 1.0.0 - Sumika',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool isDisabled = false,
  }) {
    return Container(
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
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDisabled
                        ? Colors.grey.withOpacity(0.2)
                        : iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isDisabled ? Colors.grey : iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDisabled
                              ? Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.4)
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDisabled
                              ? Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.3)
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isDisabled
                      ? Icons.lock_outline_rounded
                      : Icons.chevron_right_rounded,
                  color: isDisabled
                      ? Theme.of(context).colorScheme.onSurface.withOpacity(0.3)
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.4),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
