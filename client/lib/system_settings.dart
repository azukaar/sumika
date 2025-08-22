import 'dart:convert';
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
  bool _isRestarting = false;
  bool _isLoadingVoice = false;
  String? _errorMessage;
  String? _successMessage;
  String? _currentUrl;
  
  // Voice configuration
  Map<String, dynamic>? _voiceConfig;
  List<dynamic>? _inputDevices;
  List<dynamic>? _outputDevices;
  List<dynamic>? _voiceHistory;
  bool _hasVoiceChanges = false;

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
    
    // Load voice configuration if connected
    if (url != null && url.isNotEmpty) {
      _loadVoiceConfiguration();
    }
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
        final hasUrlChanged = _currentUrl != url;
        
        await UrlConfigService.setServerUrl(url);
        ApiConfig.clearCache(); // Clear the cache to use new URL
        
        // If URL changed, clear state like disconnect
        if (hasUrlChanged) {
          _clearGlobalState();
        }
        
        setState(() {
          _currentUrl = url;
          _successMessage = 'Settings saved successfully!';
        });

        // Navigate to home if URL changed to refresh everything
        if (hasUrlChanged && mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/', 
            (route) => false,
          );
        }
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

  Future<void> _restartServer() async {
    if (_currentUrl == null || _currentUrl!.isEmpty) {
      setState(() {
        _errorMessage = 'No server connected to restart';
      });
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restart Server'),
        content: Text('Are you sure you want to restart the Sumika server? This will temporarily disconnect all clients.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Restart'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isRestarting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('${_currentUrl}/api/restart'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() {
          _successMessage = 'Server restart initiated successfully! Please wait a moment for the server to come back online.';
        });
      } else {
        throw Exception('Server returned error ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to restart server: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isRestarting = false;
      });
    }
  }

  Future<void> _loadVoiceConfiguration() async {
    if (_currentUrl == null || _currentUrl!.isEmpty) return;
    
    setState(() {
      _isLoadingVoice = true;
    });

    try {
      // Load voice config, devices, and history in parallel
      final futures = await Future.wait([
        http.get(Uri.parse('${_currentUrl}/api/voice/config')),
        http.get(Uri.parse('${_currentUrl}/api/voice/devices')),
        http.get(Uri.parse('${_currentUrl}/api/voice/history?limit=20')),
      ]);

      final configResponse = futures[0];
      final devicesResponse = futures[1];
      final historyResponse = futures[2];

      if (configResponse.statusCode == 200) {
        _voiceConfig = json.decode(configResponse.body);
        _hasVoiceChanges = false;
      }

      if (devicesResponse.statusCode == 200) {
        final devicesData = json.decode(devicesResponse.body);
        _inputDevices = devicesData['input'] ?? [];
        _outputDevices = devicesData['output'] ?? [];
      }

      if (historyResponse.statusCode == 200) {
        final historyData = json.decode(historyResponse.body);
        _voiceHistory = historyData['history'] ?? [];
      }

      setState(() {});
    } catch (e) {
      print('Failed to load voice configuration: $e');
    } finally {
      setState(() {
        _isLoadingVoice = false;
      });
    }
  }

  void _toggleVoice(bool enabled) {
    if (_voiceConfig == null) return;

    setState(() {
      _voiceConfig!['enabled'] = enabled;
      _hasVoiceChanges = true;
      _errorMessage = null;
      _successMessage = null;
    });
  }

  void _updateVoiceDevice(String deviceType, String deviceId) {
    if (_voiceConfig == null) return;

    setState(() {
      if (deviceType == 'input') {
        _voiceConfig!['input_device'] = deviceId;
      } else {
        _voiceConfig!['output_device'] = deviceId;
      }
      _hasVoiceChanges = true;
      _errorMessage = null;
      _successMessage = null;
    });
  }

  Future<void> _saveVoiceConfig() async {
    if (_currentUrl == null || _voiceConfig == null) return;

    setState(() {
      _isLoadingVoice = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${_currentUrl}/api/voice/config'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(_voiceConfig),
      );

      if (response.statusCode == 200) {
        setState(() {
          _hasVoiceChanges = false;
          _successMessage = 'Voice configuration saved successfully';
          _errorMessage = null;
        });
      } else {
        throw Exception('Server returned error ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save voice configuration: $e';
      });
    } finally {
      setState(() {
        _isLoadingVoice = false;
      });
    }
  }


  Widget _buildVoiceConfigSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Voice Recognition',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),

        if (_isLoadingVoice) ...[
          Container(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Loading voice configuration...'),
                ],
              ),
            ),
          ),
        ] else if (_voiceConfig != null) ...[
          // Voice On/Off Toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.mic_rounded,
                  color: _voiceConfig!['enabled'] == true
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voice Recognition',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        _voiceConfig!['enabled'] == true ? 'Active' : 'Disabled',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _voiceConfig!['enabled'] == true,
                  onChanged: _toggleVoice,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Device Selection
          if (_inputDevices != null && _outputDevices != null) ...[
            // Input Device
            _buildDeviceSelector(
              'Microphone',
              Icons.mic_rounded,
              _inputDevices!,
              _voiceConfig!['input_device'] ?? 'default',
              'input',
            ),
            const SizedBox(height: 12),
            
            // Output Device
            _buildDeviceSelector(
              'Speaker',
              Icons.volume_up_rounded,
              _outputDevices!,
              _voiceConfig!['output_device'] ?? 'default',
              'output',
            ),
          ],

          const SizedBox(height: 16),

          // Voice History
          if (_voiceHistory != null && _voiceHistory!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
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
                        Icons.history_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Recent Voice Commands',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...(_voiceHistory!.take(5).map((entry) => _buildHistoryEntry(entry))),
                  if (_voiceHistory!.length > 5) ...[
                    const SizedBox(height: 8),
                    Text(
                      'And ${_voiceHistory!.length - 5} more...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Save Voice Configuration Button
          if (_hasVoiceChanges) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoadingVoice ? null : _saveVoiceConfig,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoadingVoice
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
                        Text('Save Voice Settings'),
                      ],
                    ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildDeviceSelector(String label, IconData icon, List<dynamic> devices, String currentDevice, String deviceType) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
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
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: currentDevice,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: devices.map<DropdownMenuItem<String>>((device) {
              final deviceId = device['id']?.toString() ?? 'unknown';
              final deviceName = device['name']?.toString() ?? 'Unknown Device';
              final isDefault = device['is_default'] == true;
              
              return DropdownMenuItem<String>(
                value: deviceId,
                child: Text(
                  isDefault ? '$deviceName (Default)' : deviceName,
                  style: TextStyle(fontSize: 14),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null && newValue != currentDevice) {
                _updateVoiceDevice(deviceType, newValue);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryEntry(Map<String, dynamic> entry) {
    final transcription = entry['transcription']?.toString() ?? '';
    final success = entry['success'] == true;
    final timestamp = entry['timestamp']?.toString() ?? '';
    final command = entry['command']?.toString() ?? '';
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            success ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 16,
            color: success ? Colors.green.shade600 : Colors.red.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transcription,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (command.isNotEmpty)
                  Text(
                    command,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
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
              Form(
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

                      // Restart Server Button (only show if connected)
                      if (_currentUrl != null && _currentUrl!.isNotEmpty) ...[
                        OutlinedButton(
                          onPressed: _isRestarting ? null : _restartServer,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            foregroundColor: Colors.orange.shade700,
                            side: BorderSide(color: Colors.orange.shade300),
                          ),
                          child: _isRestarting
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text('Restarting server...'),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.restart_alt_rounded),
                                    const SizedBox(width: 8),
                                    Text('Restart Server'),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 16),
                      ],

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

                      // Voice Configuration Section (only show if connected)
                      if (_currentUrl != null && _currentUrl!.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        _buildVoiceConfigSection(),
                      ],

                      const SizedBox(height: 32),

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
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}