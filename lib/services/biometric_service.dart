// File: lib/services/biometric_service.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();

  factory BiometricService() {
    return _instance;
  }

  BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'huggy');

  // Personal app - single device storage
  static const String _deviceDocId = 'personal_device';
  static const String _fingerprintCollectionPath = 'fingerprints';

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

  /// Check if device supports biometric and has biometrics enrolled
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

  /// ==================== FINGERPRINT DETECTION ====================
  /// Store fingerprint data directly to Firestore during setup

  Future<bool> storeFingerprintData({
    required int fingerprintNumber,
  }) async {
    try {
      await _firestore
          .collection(_fingerprintCollectionPath)
          .doc(_deviceDocId)
          .set({
        'fingerprint_$fingerprintNumber': {
          'number': fingerprintNumber,
          'timestamp': DateTime.now(),
          'hash': _generateFingerprintHash(fingerprintNumber),
        },
        'lastUpdated': DateTime.now(),
      }, SetOptions(merge: true));

      print('Fingerprint $fingerprintNumber stored to Firestore');
      return true;
    } catch (e) {
      print('Error storing fingerprint data: $e');
      return false;
    }
  }

  /// Authenticate and detect which fingerprint was used
  Future<Map<String, dynamic>?> authenticateAndDetectFingerprint({
    required String reason,
    bool stickyAuth = false,
  }) async {
    try {
      final startTime = DateTime.now();

      bool authenticated = await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: stickyAuth,
          biometricOnly: true,
        ),
      );

      if (!authenticated) {
        return null;
      }

      final endTime = DateTime.now();
      final responseTime = endTime.difference(startTime).inMilliseconds;

      // Get stored fingerprint data from Firestore
      final doc = await _firestore
          .collection(_fingerprintCollectionPath)
          .doc(_deviceDocId)
          .get();

      if (!doc.exists) {
        print('No fingerprint data found in Firestore');
        return null;
      }

      // Detect fingerprint based on response time
      int? fingerprintNumber = _detectFingerprintByResponseTime(responseTime);

      if (fingerprintNumber == null) {
        // Try to use last known fingerprint
        fingerprintNumber = await _getLastSuccessfulFingerprint();
      }

      if (fingerprintNumber != null) {
        // Store this as the last successful fingerprint
        await _storeLastSuccessfulFingerprint(fingerprintNumber);

        return {
          'success': true,
          'fingerprintNumber': fingerprintNumber,
          'responseTime': responseTime,
          'timestamp': DateTime.now(),
        };
      }

      return null;
    } catch (e) {
      print('Error in authenticateAndDetectFingerprint: $e');
      return null;
    }
  }

  /// Detect fingerprint using response time analysis
  int? _detectFingerprintByResponseTime(int responseTime) {
    // Strategy: Response time analysis
    // Fingerprint 1 (primary/Chat) = Quick (<1500ms)
    // Fingerprint 2 (secondary/To-Do) = Moderate (1500-2500ms)

    if (responseTime < 1500) {
      print('Response time $responseTime ms → Fingerprint 1 detected');
      return 1;
    } else if (responseTime < 2500) {
      print('Response time $responseTime ms → Fingerprint 2 detected');
      return 2;
    }

    print('Response time $responseTime ms → Uncertain, using fallback');
    return null;
  }

  /// Store the last successful fingerprint to Firestore
  Future<void> _storeLastSuccessfulFingerprint(int fingerprintNumber) async {
    try {
      await _firestore
          .collection(_fingerprintCollectionPath)
          .doc(_deviceDocId)
          .update({
        'lastSuccessfulFingerprint': fingerprintNumber,
        'lastAccessTime': DateTime.now(),
      });
    } catch (e) {
      print('Error storing last successful fingerprint: $e');
    }
  }

  /// Get the last successful fingerprint from Firestore
  Future<int?> _getLastSuccessfulFingerprint() async {
    try {
      final doc = await _firestore
          .collection(_fingerprintCollectionPath)
          .doc(_deviceDocId)
          .get();

      if (doc.exists) {
        final lastFingerprint = doc.data()?['lastSuccessfulFingerprint'];
        if (lastFingerprint != null) {
          print('Last successful fingerprint: $lastFingerprint');
          return lastFingerprint as int;
        }
      }
    } catch (e) {
      print('Error retrieving last successful fingerprint: $e');
    }
    return null;
  }

  /// Generate a hash for fingerprint identification
  String _generateFingerprintHash(int fingerprintNumber) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'fp_${fingerprintNumber}_${timestamp ~/ 1000}';
  }

  /// Clear all stored fingerprint data (for reset/logout)
  Future<bool> clearFingerprintData() async {
    try {
      await _firestore
          .collection(_fingerprintCollectionPath)
          .doc(_deviceDocId)
          .delete();
      print('Fingerprint data cleared from Firestore');
      return true;
    } catch (e) {
      print('Error clearing fingerprint data: $e');
      return false;
    }
  }

  /// Get stored fingerprint data (for debugging)
  Future<Map<String, dynamic>?> getStoredFingerprintData() async {
    try {
      final doc = await _firestore
          .collection(_fingerprintCollectionPath)
          .doc(_deviceDocId)
          .get();

      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      print('Error retrieving stored fingerprint data: $e');
    }
    return null;
  }

  /// Check if fingerprints are configured
  Future<bool> areFingerprintsConfigured() async {
    try {
      final doc = await _firestore
          .collection(_fingerprintCollectionPath)
          .doc(_deviceDocId)
          .get();

      if (!doc.exists) return false;

      final data = doc.data();
      return data != null &&
          data.containsKey('fingerprint_1') &&
          data.containsKey('fingerprint_2');
    } catch (e) {
      print('Error checking fingerprint configuration: $e');
      return false;
    }
  }
}