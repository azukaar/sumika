import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import './types.dart';
import './zigbee-service.dart';
import './device-widget.dart';

class ZigbeeDevicesPage extends ConsumerStatefulWidget {
  const ZigbeeDevicesPage({super.key});

  @override
  ConsumerState<ZigbeeDevicesPage> createState() => _ZigbeeDevicesPageState();
}

class _ZigbeeDevicesPageState extends ConsumerState<ZigbeeDevicesPage> {
  String _responseData = 'No data yet';

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload devices when returning to this page
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(devicesProvider.notifier).loadDevices();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final devicesState = ref.watch(devicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zigbee Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(devicesProvider.notifier).loadDevices(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                ref.read(devicesProvider.notifier).pair();
              },
              child: const Text('Pair Devices'),
            ),
            Expanded(
              child: devicesState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
                data: (devices) => ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    
                    return DeviceWidget(
                      device: device,
                      mode: DeviceWidgetMode.full,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/zigbee/device',
                          arguments: device,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}