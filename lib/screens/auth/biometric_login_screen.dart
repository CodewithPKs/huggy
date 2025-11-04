// File: lib/screens/auth/biometric_login_screen.dart
import 'package:flutter/material.dart';
import '../../services/biometric_service.dart';
import '../chat/chat_home_screen.dart';
import '../todo/todo_home_screen.dart';
import 'biometric_setup_screen.dart';

class BiometricLoginScreen extends StatefulWidget {
  const BiometricLoginScreen({Key? key}) : super(key: key);

  @override
  State<BiometricLoginScreen> createState() => _BiometricLoginScreenState();
}

class _BiometricLoginScreenState extends State<BiometricLoginScreen> {
  final BiometricService _biometricService = BiometricService();
  bool _isBiometricAvailable = false;
  bool _isAuthenticating = false;
  String _statusMessage = 'Initializing biometric...';
  bool _fingerprintsConfigured = false;

  @override
  void initState() {
    super.initState();
    _initializeBiometric();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoAuthenticate();
    });
  }

  Future<void> _initializeBiometric() async {
    final isAvailable = await _biometricService.isBiometricAvailable();
    final biometrics = await _biometricService.getAvailableBiometrics();
    final configured = await _biometricService.areFingerprintsConfigured();

    setState(() {
      _isBiometricAvailable = isAvailable;
      _fingerprintsConfigured = configured;

      if (!isAvailable) {
        _statusMessage = 'Biometric not available on this device';
      } else if (!configured) {
        _statusMessage = 'Fingerprints not configured. Please setup first.';
      } else {
        _statusMessage =
        'Available: ${biometrics.map((b) => b.name).join(", ")}';
      }
    });
  }

  Future<void> _autoAuthenticate() async {
    // Wait until biometrics are checked
    await Future.delayed(const Duration(milliseconds: 300));

    if (_isBiometricAvailable && _fingerprintsConfigured) {
      // Auto-trigger fingerprint scan
      _authenticateWithBiometric();
    }
  }

  /// Enhanced authentication with fingerprint detection
  Future<void> _authenticateWithBiometric() async {
    if (!_isBiometricAvailable) {
      _showErrorDialog(
        'Biometric authentication is not available on this device.',
      );
      return;
    }

    if (!_fingerprintsConfigured) {
      _showErrorDialog(
        'Fingerprints are not configured. Please setup first.',
      );
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _statusMessage = 'Place your finger on the sensor...';
    });

    try {
      // Use enhanced authentication that detects which fingerprint
      final result = await _biometricService.authenticateAndDetectFingerprint(
        reason: 'Authenticate to access your app',
        stickyAuth: true,
      );

      if (!mounted) return;

      if (result != null && result['success'] == true) {
        final fingerprintNumber = result['fingerprintNumber'] as int;
        final responseTime = result['responseTime'] as int;

        print('Authentication successful');
        print('Fingerprint: $fingerprintNumber');
        print('Response time: ${responseTime}ms');

        // Route to module based on fingerprint number
        _routeToModuleByFingerprint(fingerprintNumber);
      } else {
        setState(() {
          _statusMessage = 'Authentication failed or cancelled';
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Authentication error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  /// Route to the appropriate module based on fingerprint number
  void _routeToModuleByFingerprint(int fingerprintNumber) {
    if (!mounted) return;

    // Fingerprint 1 -> Chat
    // Fingerprint 2 -> To-Do

    if (fingerprintNumber == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChatHomeScreen()),
      );
    } else if (fingerprintNumber == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TodoHomeScreen()),
      );
    } else {
      _showErrorDialog('Unknown fingerprint. Please try again.');
    }
  }

  /// Manual module selection (fallback)
  void _navigateToManualSelection() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Select Module'),
        content: const Text(
          'Biometric detection failed. Please select your module:',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ChatHomeScreen()),
              );
            },
            child: const Text('Chat (Fingerprint 1)'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const TodoHomeScreen()),
              );
            },
            child: const Text('To-Do (Fingerprint 2)'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF121212),
              const Color(0xFF1E1E1E),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    Icon(
                      Icons.fingerprint,
                      size: 80,
                      color: const Color(0xFF6366F1),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Dual Access App',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chat & To-Do Management',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              // Status and Actions
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Status Message
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF6366F1).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Biometric Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isAuthenticating
                              ? null
                              : _fingerprintsConfigured
                              ? _authenticateWithBiometric
                              : null,
                          icon: _isAuthenticating
                              ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                Colors.white,
                              ),
                            ),
                          )
                              : const Icon(Icons.fingerprint),
                          label: Text(
                            _isAuthenticating
                                ? 'Authenticating...'
                                : _fingerprintsConfigured
                                ? 'Use Fingerprint'
                                : 'Biometric Not Ready',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      if (_fingerprintsConfigured) ...[
                        const SizedBox(height: 16),
                        // Manual selection button (fallback)
                        OutlinedButton(
                          onPressed: _isAuthenticating
                              ? null
                              : _navigateToManualSelection,
                          child: const Text('Manual Selection'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Footer
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    if (!_fingerprintsConfigured)
                      ElevatedButton(
                        onPressed: () {
                          // Navigate to setup screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BiometricSetupScreen(),
                            ),
                          );
                        },
                        child: const Text('Setup Fingerprints'),
                      )
                    else
                      Text(
                        'Fingerprints configured ✓',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: const Color(0xFF6366F1)),
                        textAlign: TextAlign.center,
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
}
