import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'url_config_service.dart';
import 'api_config.dart';
import 'zigbee-service.dart';
import 'scene_management_service.dart';
import 'automation_service.dart';
import 'device_metadata_service.dart';
import 'websocket_service.dart';

class SystemSettingsPage extends ConsumerStatefulWidget {
  const SystemSettingsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends ConsumerState<SystemSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  bool _isLoading = false;
  bool _isTesting = false;
  String? _errorMessage;
  String? _successMessage;
  String? _currentUrl;

  @override
  void initState() {
    super.initState();
    _loadCurrentUrl();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUrl() async {
    final url = await UrlConfigService.getServerUrl();
    setState(() {
      _currentUrl = url;
      _urlController.text = url ?? '';
    });
  }

  void _clearGlobalState() {
    // Clear all cached provider data when disconnecting
    ref.invalidate(devicesProvider);
    ref.invalidate(sceneManagementNotifierProvider);
    ref.invalidate(automationNotifierProvider);
    ref.invalidate(deviceMetadataNotifierProvider);
    ref.invalidate(webSocketServiceProvider);
    ref.invalidate(allZonesProvider);
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isTesting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final url = UrlConfigService.formatUrl(_urlController.text);
      
      // Test the URL by making a simple API call
      final response = await http.get(
        Uri.parse('$url/api'),
      ).timeout(const Duration(seconds: 10));
      
      // Any response (even 404) means server is reachable
      if (response.statusCode < 500) {
        setState(() {
          _successMessage = 'Connection successful! Server is reachable.';
        });
      } else {
        throw Exception('Server returned error ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final inputUrl = _urlController.text.trim();
      
      if (inputUrl.isEmpty) {
        // Handle disconnect (empty URL)
        await UrlConfigService.clearServerUrl();
        ApiConfig.clearCache();
        _clearGlobalState();
        
        setState(() {
          _currentUrl = null;
          _successMessage = 'Disconnected from server successfully!';
        });

        // Navigate back to home page after successful disconnect
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/', 
            (route) => false,
          );
        }
      } else {
        // Handle regular URL setting
        final url = UrlConfigService.formatUrl(inputUrl);
        await UrlConfigService.setServerUrl(url);
        ApiConfig.clearCache(); // Clear the cache to use new URL
        
        setState(() {
          _currentUrl = url;
          _successMessage = 'Settings saved successfully!';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save settings: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _disconnectFromServer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await UrlConfigService.clearServerUrl();
      ApiConfig.clearCache();
      _clearGlobalState();
      
      setState(() {
        _currentUrl = null;
        _urlController.clear();
        _successMessage = 'Disconnected from server successfully!';
      });

      // Navigate back to home page after successful disconnect
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/', 
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to disconnect: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'System Settings',
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
                      Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
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
                            Icons.settings_rounded,
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
                                'System Configuration',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Configure your server connection',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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

              // Current URL Display
              if (_currentUrl != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.link_rounded,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Current Server URL',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentUrl!,
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'monospace',
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Settings Form
              Expanded(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Server Configuration',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _urlController,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          labelText: 'Server URL',
                          hintText: 'http://192.168.1.100:8081',
                          prefixIcon: Icon(Icons.link_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          helperText: 'Enter the IP address and port of your Sumika server, or leave empty to disconnect',
                        ),
                        validator: (value) {
                          // Allow empty values for disconnect functionality
                          if (value == null || value.isEmpty) {
                            return null; // Empty is valid for disconnect
                          }
                          final formattedUrl = UrlConfigService.formatUrl(value);
                          if (!UrlConfigService.isValidUrl(formattedUrl)) {
                            return 'Please enter a valid URL';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          setState(() {
                            _errorMessage = null;
                            _successMessage = null;
                          });
                        },
                      ),

                      const SizedBox(height: 24),

                      // Test Connection Button
                      OutlinedButton(
                        onPressed: _isTesting ? null : _testConnection,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isTesting
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 12),
                                  Text('Testing connection...'),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.wifi_find_rounded),
                                  const SizedBox(width: 8),
                                  Text('Test Connection'),
                                ],
                              ),
                      ),

                      const SizedBox(height: 16),

                      // Buttons Row
                      Row(
                        children: [
                          // Disconnect Button (only show if connected)
                          if (_currentUrl != null && _currentUrl!.isNotEmpty)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isLoading ? null : _disconnectFromServer,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  foregroundColor: Colors.red.shade600,
                                  side: BorderSide(color: Colors.red.shade300),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.link_off_rounded),
                                    const SizedBox(width: 8),
                                    Text('Disconnect'),
                                  ],
                                ),
                              ),
                            ),
                          
                          // Spacing between buttons
                          if (_currentUrl != null && _currentUrl!.isNotEmpty)
                            const SizedBox(width: 12),
                          
                          // Save Button
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveSettings,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text('Saving...'),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.save_rounded),
                                        const SizedBox(width: 8),
                                        Text('Save Settings'),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),

                      // Messages
                      if (_errorMessage != null || _successMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _errorMessage != null 
                                ? Colors.red.shade50 
                                : Colors.green.shade50,
                            border: Border.all(
                              color: _errorMessage != null 
                                  ? Colors.red.shade200 
                                  : Colors.green.shade200,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _errorMessage != null 
                                    ? Icons.error_outline 
                                    : Icons.check_circle_outline,
                                color: _errorMessage != null 
                                    ? Colors.red.shade700 
                                    : Colors.green.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage ?? _successMessage!,
                                  style: TextStyle(
                                    color: _errorMessage != null 
                                        ? Colors.red.shade700 
                                        : Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const Spacer(),

                      // Info footer
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Changes will take effect immediately. Make sure your device is connected to the same network as your Sumika server.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
}