import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import './zigbee.dart';
import './zigbee-device.dart';
import './zones.dart';
import './dashboard.dart';
import './settings.dart';
import './automation.dart';
import './onboarding_screen.dart';
import './system_settings.dart';
import './scene_management.dart';
import 'url_config_service.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sumika',
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: const AppRouter(),
      routes: {
        '/dashboard': (context) => const DashboardPage(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/zigbee': (context) => const ZigbeeDevicesPage(),
        '/zigbee/device': (context) => const ZigbeeDevicePage(),
        '/zones': (context) => const ZonesPage(),
        '/settings': (context) => const SettingsPage(),
        '/system-settings': (context) => const SystemSettingsPage(),
        '/scene-management': (context) => const SceneManagementPage(),
        '/automation': (context) => const AutomationPage(),
        '/old-home': (context) => const Home(),
      },
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6366F1), // Modern indigo
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF6366F1),
        secondary: const Color(0xFF8B5CF6),
        tertiary: const Color(0xFFEC4899),
        surface: const Color(0xFFFAFAFA),
        surfaceContainerHighest: const Color(0xFFE5E5E5),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1F2937),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6366F1),
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFF8B5CF6),
        secondary: const Color(0xFFEC4899),
        tertiary: const Color(0xFF06B6D4),
        surface: const Color(0xFF1F2937),
        surfaceContainerHighest: const Color(0xFF374151),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Color(0xFFF9FAFB),
        ),
      ),
    );
  }
}

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: UrlConfigService.isServerUrlConfigured(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show loading screen while checking configuration
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/onboarding');
                    },
                    child: const Text('Go to Setup'),
                  ),
                ],
              ),
            ),
          );
        }
        
        final isConfigured = snapshot.data ?? false;
        if (isConfigured) {
          // User has configured the server URL, go to dashboard
          return const DashboardPage();
        } else {
          // User needs to configure server URL, show onboarding
          return const OnboardingScreen();
        }
      },
    );
  }
}

class Home extends StatelessWidget {
  const Home({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sumika'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/zigbee');
              },
              child: const Text('Zigbee Devices'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/zones');
              },
              child: const Text('Zones'),
            ),
          ],
        ),
      ),
    );
  }
}