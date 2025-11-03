// File: lib/screens/auth/biometric_login_screen.dart
import 'package:flutter/material.dart';
import '../../services/biometric_service.dart';
import '../../services/firebase_auth_service.dart';
import '../chat/chat_home_screen.dart';
import '../todo/todo_home_screen.dart';
import 'email_login_screen.dart';

class BiometricLoginScreen extends StatefulWidget {
  const BiometricLoginScreen({Key? key}) : super(key: key);

  @override
  State<BiometricLoginScreen> createState() => _BiometricLoginScreenState();
}

class _BiometricLoginScreenState extends State<BiometricLoginScreen> {
  final BiometricService _biometricService = BiometricService();
  final FirebaseAuthService _authService = FirebaseAuthService();
  bool _isBiometricAvailable = false;
  bool _isAuthenticating = false;
  String _statusMessage = 'Initialize biometric';

  @override
  void initState() {
    super.initState();
    _initializeBiometric();
    _checkUserAuthStatus();
  }

  Future<void> _initializeBiometric() async {
    final isAvailable = await _biometricService.isBiometricAvailable();
    final biometrics = await _biometricService.getAvailableBiometrics();

    setState(() {
      _isBiometricAvailable = isAvailable;
      if (!isAvailable) {
        _statusMessage = 'Biometric not available';
      } else {
        _statusMessage =
        'Available: ${biometrics.map((b) => b.name).join(", ")}';
      }
    });
  }

  Future<void> _checkUserAuthStatus() async {
    // if (_authService.isAuthenticated) {
      // User already authenticated, but we need biometric for module selection
      setState(() {
        _statusMessage = 'User authenticated. Use biometric to select module.';
      });
    // }
  }

  Future<void> _authenticateWithBiometric() async {
    if (!_isBiometricAvailable) {
      _showErrorDialog('Biometric authentication is not available on this device.');
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _statusMessage = 'Authenticating...';
    });

    try {
      final isAuthenticated = await _biometricService.authenticate(
        reason: 'Authenticate to access your app',
        stickyAuth: true,
      );

      if (isAuthenticated) {
        // In a real app, you would:
        // 1. Get the fingerprint ID
        // 2. Check which fingerprint it is (1 or 2)
        // 3. Route to appropriate module

        // For this implementation, we'll use a simple approach:
        // Odd authentication attempts -> Chat, Even -> ToDo
        // In production, use fingerprint identification system

        if (!mounted) return;

        // Simulate fingerprint detection
        _routeToModule();
      } else {
        if (!mounted) return;
        setState(() {
          _statusMessage = 'Authentication failed or cancelled';
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Authentication error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  void _routeToModule() {
    // In production: determine which fingerprint was used
    // For demo: use random assignment or user preference
    // You could also use SharedPreferences to remember user's choice

    // For this demo, let's navigate based on user authentication state
    // if (_authService.isAuthenticated) {
      // Route based on fingerprint detection
      // Using a simple approach: alternate between modules
      _navigateToRandomModule();
    // } else {
    //   _navigateToEmailLogin();
    // }
  }

  void _navigateToRandomModule() {
    // In production, this would detect actual fingerprint
    // For demo, we'll let user choose
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Select Module'),
        content: const Text('Which module would you like to access?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ChatHomeScreen()),
              );
            },
            child: const Text('Chat'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const TodoHomeScreen()),
              );
            },
            child: const Text('To-Do'),
          ),
        ],
      ),
    );
  }

  void _navigateToEmailLogin() {
    // Navigator.pushReplacement(
    //   context,
    //   MaterialPageRoute(builder: (_) => const EmailLoginScreen()),
    // );
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
                          onPressed:
                          _isAuthenticating ? null : _authenticateWithBiometric,
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
                                : 'Use Fingerprint',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Footer
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    TextButton(
                      onPressed: _navigateToEmailLogin,
                      child: Text(
                        'Login with Email',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'First time? Use email login to set up biometrics',
                      style: Theme.of(context).textTheme.bodySmall,
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