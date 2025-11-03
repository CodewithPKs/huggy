// File: lib/services/biometric_service.dart
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();

  factory BiometricService() {
    return _instance;
  }

  BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Check if device supports biometric authentication
  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } on PlatformException catch (e) {
      print('Error checking biometrics: $e');
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      print('Error getting available biometrics: $e');
      return [];
    }
  }

  /// Authenticate using biometrics
  Future<bool> authenticate({
    required String reason,
    bool stickyAuth = false,
  }) async {
    try {
      bool authenticated = await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: stickyAuth,
          biometricOnly: true,
        ),
      );
      return authenticated;
    } on PlatformException catch (e) {
      print('Authentication error: $e');
      return false;
    }
  }

  /// Get enrolled biometrics count
  Future<int> getEnrolledBiometricsCount() async {
    try {
      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.length;
    } catch (e) {
      print('Error getting enrolled biometrics: $e');
      return 0;
    }
  }

  /// Checsk if device supports biometric and ha biometrics enrolled
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck || isDeviceSupported;
    } on PlatformException catch (e) {
      print('Error checking biometric availability: $e');
      return false;
    }
  }
}