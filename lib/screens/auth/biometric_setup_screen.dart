// File: lib/screens/auth/biometric_setup_screen.dart
import 'package:flutter/material.dart';
import '../../services/biometric_service.dart';
import '../../services/firebase_auth_service.dart';
import '../chat/chat_home_screen.dart';
import '../todo/todo_home_screen.dart';

class BiometricSetupScreen extends StatefulWidget {
  const BiometricSetupScreen({Key? key}) : super(key: key);

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen> {
  final BiometricService _biometricService = BiometricService();
  final FirebaseAuthService _authService = FirebaseAuthService();
  int _currentStep = 0;
  bool _isAuthenticating = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _statusMessage = 'Tap "Setup Fingerprint 1" to begin';
  }

  Future<void> _setupFingerprint(int fingerprintNumber) async {
    setState(() {
      _isAuthenticating = true;
      _statusMessage = 'Place your finger on the sensor...';
    });

    try {
      final isAuthenticated = await _biometricService.authenticate(
        reason:
        'Setup Fingerprint $fingerprintNumber for ${fingerprintNumber == 1 ? 'Chat' : 'To-Do'} access',
        stickyAuth: false,
      );

      if (isAuthenticated) {
        // Generate a unique ID for this fingerprint
        final fingerprintId =
            'fingerprint_${fingerprintNumber}_${DateTime.now().millisecondsSinceEpoch}';

        // Store in Firebase
        final stored = await _authService.storeBiometricId(
          fingerprintId: fingerprintId,
          fingerprintNumber: fingerprintNumber,
        );

        if (stored) {
          setState(() {
            _currentStep = fingerprintNumber;
            if (fingerprintNumber == 1) {
              _statusMessage = 'Fingerprint 1 saved! Set up Fingerprint 2 next.';
            } else {
              _statusMessage = 'All fingerprints configured! Ready to go.';
            }
          });

          if (fingerprintNumber == 2) {
            // Show completion dialog
            _showCompletionDialog();
          }
        } else {
          if (mounted) {
            setState(() {
              _statusMessage = 'Failed to save fingerprint. Try again.';
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _statusMessage = 'Fingerprint setup cancelled.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Setup Complete!'),
        content: const Text(
          'Both fingerprints are now configured.\n\n'
              'Fingerprint 1 → Chat App\n'
              'Fingerprint 2 → To-Do App',
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
            child: const Text('Continue to Chat'),
          ),
        ],
      ),
    );
  }

  void _skipSetup(int fingerprintNumber) {
    if (_currentStep < 2) {
      setState(() {
        _currentStep = fingerprintNumber;
        if (fingerprintNumber == 1) {
          _statusMessage = 'Skipped Fingerprint 1. Set up Fingerprint 2.';
        } else {
          _statusMessage = 'Setup skipped.';
          _showSkipConfirmDialog();
        }
      });
    }
  }

  void _showSkipConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Continue?'),
        content: const Text(
          'You can set up fingerprints later in settings.\n\n'
              'Would you like to access a module now?',
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
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),
                  Icon(
                    Icons.fingerprint,
                    size: 80,
                    color: const Color(0xFF6366F1),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Setup Biometric Access',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configure your fingerprints for each module',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 40),
                  // Status Box
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
                  // Fingerprint 1 Setup
                  _buildFingerprintSetupCard(
                    number: 1,
                    title: 'Chat Access',
                    description: 'Private encrypted chat space',
                    icon: Icons.chat,
                    isCompleted: _currentStep >= 1,
                    onTap: () => _setupFingerprint(1),
                    onSkip: () => _skipSetup(1),
                  ),
                  const SizedBox(height: 16),
                  // Progress Indicator
                  if (_currentStep >= 1) ...[
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(
                            color: Color(0xFF6366F1),
                            thickness: 2,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Icon(
                            Icons.check_circle,
                            color: const Color(0xFF6366F1),
                            size: 24,
                          ),
                        ),
                        const Expanded(
                          child: Divider(
                            color: Color(0xFF6366F1),
                            thickness: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    const SizedBox(height: 16),
                  ],
                  // Fingerprint 2 Setup
                  _buildFingerprintSetupCard(
                    number: 2,
                    title: 'To-Do Access',
                    description: 'Task management and planning',
                    icon: Icons.check_circle_outline,
                    isCompleted: _currentStep >= 2,
                    onTap: _currentStep >= 1 ? () => _setupFingerprint(2) : null,
                    onSkip: _currentStep >= 1 ? () => _skipSetup(2) : null,
                  ),
                  const SizedBox(height: 40),
                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Color(0xFF6366F1),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'How it works',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                  color: const Color(0xFF6366F1),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '• Each fingerprint provides access to a different module\n'
                              '• Use your assigned finger to unlock the appropriate app\n'
                              '• You can change fingerprints later in settings',
                          style: Theme.of(context).textTheme.bodySmall,
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

  Widget _buildFingerprintSetupCard({
    required int number,
    required String title,
    required String description,
    required IconData icon,
    required bool isCompleted,
    VoidCallback? onTap,
    VoidCallback? onSkip,
  }) {
    return Card(
      color: isCompleted
          ? const Color(0xFF6366F1).withOpacity(0.1)
          : const Color(0xFF2A2A2A),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: const Color(0xFF6366F1),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fingerprint $number',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (isCompleted)
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF6366F1),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isAuthenticating ? null : onTap,
                    icon: _isAuthenticating
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                        : const Icon(Icons.fingerprint),
                    label: Text(
                      isCompleted ? 'Completed' : 'Setup',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _isAuthenticating ? null : onSkip,
                  child: const Text('Skip'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}