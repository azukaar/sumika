import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import './types.dart';
import './zigbee-service.dart';
import './websocket_service.dart';
import './device-widget.dart';
import './utils/device_utils.dart';
import './supercard/lights_supercard.dart';
import './supercard/scene_supercard.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  List<String> zones = [];
  Map<String, List<Device>> zoneDevices = {};
  String? selectedZone;
  bool isLoading = true;
  late PageController _pageController;
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadDashboardData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload data when returning to this page
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Force reload devices from server
        ref.read(devicesProvider.notifier).loadDevices();
      });
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Load all zones and devices
      final allZones = await ref.read(devicesProvider.notifier).getAllZones();
      final devicesAsyncValue = ref.read(devicesProvider);

      await devicesAsyncValue.when(
        data: (devicesList) async {
          await _loadDashboardDataWithDevices(devicesList);
        },
        loading: () {
          setState(() {
            isLoading = true;
          });
        },
        error: (error, stackTrace) {
          setState(() {
            isLoading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadDashboardDataWithDevices(List<Device> devicesList) async {
    try {
      // Load all zones (reuse if already loaded in _loadDashboardData)
      final allZones = await ref.read(devicesProvider.notifier).getAllZones();
      Map<String, List<Device>> newZoneDevices = {};
      Set<String> assignedDevices = {};

      // Process regular zones
      for (String zone in allZones) {
        List<Device> zoneDevicesList = [];
        final deviceNames =
            await ref.read(devicesProvider.notifier).getDevicesByZone(zone);

        for (String deviceName in deviceNames) {
          assignedDevices.add(deviceName); // Track assigned devices
          final deviceIndex = devicesList.indexWhere((d) => d.friendlyName == deviceName);
          if (deviceIndex != -1) {
            zoneDevicesList.add(devicesList[deviceIndex]);
          }
        }
        newZoneDevices[zone] = zoneDevicesList;
      }

      // Add "Others" zone for unassigned devices
      List<Device> unassignedDevices = [];
      for (Device device in devicesList) {
        if (!assignedDevices.contains(device.friendlyName)) {
          unassignedDevices.add(device);
        }
      }

      // Create final zones list with "Others" if there are unassigned devices
      List<String> finalZones = [...allZones];
      if (unassignedDevices.isNotEmpty) {
        finalZones.add("Others");
        newZoneDevices["Others"] = unassignedDevices;
      }

      setState(() {
        zones = finalZones;
        zoneDevices = newZoneDevices;
        selectedZone = finalZones.isNotEmpty ? finalZones.first : null;
        _currentPageIndex = 0;
        isLoading = false;
      });
      
      // Ensure PageController is synchronized with the reset state
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncPageController();
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch for devices provider changes and reload dashboard data
    ref.listen<AsyncValue<List<Device>>>(devicesProvider, (previous, next) {
      next.whenData((devices) {
        if (mounted && !isLoading) {  // Prevent reloading during initial load
          _loadDashboardDataWithDevices(devices);
        }
      });
    });

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (zones.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Dashboard',
            style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
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
                    Icons.settings_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                onPressed: () => Navigator.pushNamed(context, '/settings'),
              ),
            ),
          ],
        ),
        body: Center(
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
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.home_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Welcome to Sumika',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Create zones to organize your smart home devices',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
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
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/zones'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text(
                      'Create Your First Zone',
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
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good ${_getTimeOfDay()}',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.normal,
              ),
            ),
            Text(
              selectedZone?.replaceAll('_', ' ') ?? 'Dashboard',
              style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          ],
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
                  Icons.settings_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Zone navigation header
          if (zones.length > 1)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left arrow
                  GestureDetector(
                    onTap: _currentPageIndex > 0
                        ? () => _animateToPage(_currentPageIndex - 1)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _currentPageIndex > 0
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        color: _currentPageIndex > 0
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.3),
                        size: 20,
                      ),
                    ),
                  ),

                  // Zone name and indicators
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          selectedZone?.replaceAll('_', ' ') ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Page indicators (dots)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(zones.length, (index) {
                            return AnimatedContainer(
                              key: ValueKey(
                                  'zone-indicator-$index-${zones[index]}'),
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: index == _currentPageIndex ? 20 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: index == _currentPageIndex
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.3),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),

                  // Right arrow
                  GestureDetector(
                    onTap: _currentPageIndex < zones.length - 1
                        ? () => _animateToPage(_currentPageIndex + 1)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _currentPageIndex < zones.length - 1
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: _currentPageIndex < zones.length - 1
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.3),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // PageView with zones
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics:
                  const AlwaysScrollableScrollPhysics(), // Force scrollability
              onPageChanged: (index) {
                if (index < zones.length) {  // Safety check
                  setState(() {
                    _currentPageIndex = index;
                    selectedZone = zones[index];
                  });
                }
              },
              itemCount: zones.length,
              itemBuilder: (context, index) {
                final zone = zones[index];
                return NotificationListener<ScrollNotification>(
                  key: ValueKey('zone-page-$zone'),
                  onNotification: (scrollNotification) {
                    // Allow horizontal gestures to pass through to PageView
                    if (scrollNotification is ScrollStartNotification) {
                      final metrics = scrollNotification.metrics;
                      if (metrics.axis == Axis.horizontal) {
                        return false; // Let PageView handle horizontal scrolling
                      }
                    }
                    return false;
                  },
                  child: _buildZoneDevicesGrid(zone),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _animateToPage(int index) {
    if (index >= 0 && index < zones.length) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  void _syncPageController() {
    // Ensure PageController is in sync with current state
    if (_pageController.hasClients && _currentPageIndex < zones.length) {
      final currentPage = _pageController.page?.round() ?? 0;
      if (currentPage != _currentPageIndex) {
        _pageController.animateToPage(
          _currentPageIndex,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Widget _buildZoneDevicesGrid(String zone) {
    final devices = zoneDevices[zone] ?? [];

    // Separate lights from other devices
    final lightDevices = <Device>[];
    final otherDevices = <Device>[];

    for (var device in devices) {
      final deviceType = DeviceUtils.getDeviceType(device);
      if (deviceType == 'light') {
        lightDevices.add(device);
      } else {
        otherDevices.add(device);
      }
    }

    // Sort lights by display name
    lightDevices.sort((a, b) => DeviceUtils.getDeviceDisplayName(a)
        .compareTo(DeviceUtils.getDeviceDisplayName(b)));

    // Sort other devices by type then name (with custom order)
    otherDevices.sort((a, b) {
      final typeA = DeviceUtils.getDeviceType(a);
      final typeB = DeviceUtils.getDeviceType(b);

      // Define type priority order
      const typePriority = {
        'sensor': 0,
        'switch': 1,
        'door_window': 2,
        'thermostat': 3,
        'unknown': 4,
      };

      final priorityA = typePriority[typeA] ?? 4;
      final priorityB = typePriority[typeB] ?? 4;

      // First sort by type priority
      final typeComparison = priorityA.compareTo(priorityB);
      if (typeComparison != 0) {
        return typeComparison;
      }

      // Then sort by display name
      return DeviceUtils.getDeviceDisplayName(a)
          .compareTo(DeviceUtils.getDeviceDisplayName(b));
    });

    if (devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
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
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.device_hub_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              zone == "Others"
                  ? 'All devices are assigned'
                  : 'No devices in ${zone.replaceAll('_', ' ')}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                zone == "Others"
                    ? 'Devices without zone assignments will appear here'
                    : 'Add devices to this zone to control them from the dashboard',
                style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 16,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      key: ValueKey('layout-builder-$zone'),
      builder: (context, constraints) {
        // Calculate responsive grid
        final width = constraints.maxWidth;
        int crossAxisCount = 2; // Default for mobile
        double minCardHeight = 200.0; // Minimum card height

        if (width > 1200) {
          crossAxisCount = 5; // Very wide screens
          minCardHeight = 220.0; // Taller cards for wide screens
        } else if (width > 900) {
          crossAxisCount = 4; // Desktop
          minCardHeight = 210.0;
        } else if (width > 600) {
          crossAxisCount = 3; // Tablet landscape
          minCardHeight = 200.0;
        } else if (width > 400) {
          crossAxisCount = 2; // Tablet portrait / large phone
          minCardHeight = 190.0;
        } else {
          crossAxisCount = 1; // Small phone
          minCardHeight = 180.0;
        }

        // Calculate card width and ensure aspect ratio doesn't make cards too short
        final availableWidth =
            math.min(width, 1200.0) - 32; // Account for padding and max width
        final cardWidth =
            (availableWidth - (crossAxisCount - 1) * 16) / crossAxisCount;
        final aspectRatio = math.max(cardWidth / minCardHeight,
            0.8); // Prevent cards from being too tall

        // Calculate total items (lights super card + scene super card + other devices)
        final hasLights = lightDevices.isNotEmpty;
        final superCardCount = hasLights ? 2 : 0; // Lights + Scene supercards
        final totalItems = superCardCount + otherDevices.length;

        return SingleChildScrollView(
          key: ValueKey('scroll-view-$zone'),
          physics: const ClampingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: math.min(width, 1200), // Max 1200px width
                minHeight: constraints.maxHeight -
                    100, // Ensure minimum height for centering
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.builder(
                  key: ValueKey('grid-view-$zone-$crossAxisCount-$totalItems'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: aspectRatio,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: totalItems,
                  itemBuilder: (context, index) {
                    // Handle supercards if lights exist
                    if (hasLights) {
                      if (index == 0) {
                        return LightsSupercard(
                          key: ValueKey('lights-supercard-$zone'),
                          lightDevices: lightDevices,
                        );
                      } else if (index == 1) {
                        return SceneSupercard(
                          key: ValueKey('scene-supercard-$zone'),
                          lightDevices: lightDevices,
                        );
                      }
                    }

                    // Other devices (adjust index for supercards)
                    final deviceIndex = index - superCardCount;
                    if (deviceIndex >= 0 && deviceIndex < otherDevices.length) {
                      final device = otherDevices[deviceIndex];

                      return DeviceWidget(
                        key: ValueKey('device-${device.friendlyName}'),
                        device: device,
                        mode: DeviceWidgetMode.mini,
                        onTap: () {
                          Navigator.pushNamed(context, '/zigbee/device',
                              arguments: device);
                        },
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Morning';
    } else if (hour < 17) {
      return 'Afternoon';
    } else {
      return 'Evening';
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
