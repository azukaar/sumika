import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'url_config_service.dart';
import 'api_config.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _urlController.text = 'http://192.168.1.100:8081'; // Default suggestion
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = UrlConfigService.formatUrl(_urlController.text);

      // Test the URL by making a simple API call
      await _testConnection(url);

      // If successful, save the URL
      await UrlConfigService.setServerUrl(url);
      ApiConfig.clearCache(); // Clear the cache to use new URL

      // Navigate to main app
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testConnection(String url) async {
    // Simple test - try to reach the server
    try {
      final response = await http
          .get(
            Uri.parse('$url/api'),
          )
          .timeout(const Duration(seconds: 10));

      // Any response (even 404) means server is reachable
      if (response.statusCode < 500) {
        return; // Success
      }
      throw Exception('Server returned error ${response.statusCode}');
    } catch (e) {
      throw Exception('Cannot reach server: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show onboarding for mobile apps
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/images/logo2.png',
                height: 80,
              ),
              const SizedBox(height: 32),
              const Text(
                'Welcome to Sumika',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'To get started, please enter your Sumika server URL',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _urlController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Server URL',
                        hintText: 'http://192.168.1.100:8081',
                        prefixIcon: Icon(Icons.link),
                        border: OutlineInputBorder(),
                        helperText:
                            'Enter the IP address and port of your Sumika server',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a server URL';
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
                        });
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveAndContinue,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 12),
                                Text('Testing connection...'),
                              ],
                            )
                          : const Text(
                              'Connect to Server',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Make sure your device is connected to the same network as your Sumika server',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
