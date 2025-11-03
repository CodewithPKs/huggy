// File: lib/services/firebase_auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();

  factory FirebaseAuthService() {
    return _instance;
  }

  FirebaseAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => _auth.currentUser != null;

  /// Register user with email and password
  Future<UserCredential?> registerUser({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await credential.user?.updateDisplayName(name);

      // Store user data in Firestore
      await _firestore.collection('users').doc(credential.user?.uid).set({
        'name': name,
        'email': email,
        'createdAt': DateTime.now(),
        'biometricId': null,
      });

      return credential;
    } on FirebaseAuthException catch (e) {
      print('Registration error: ${e.message}');
      return null;
    }
  }

  /// Login user with email and password
  Future<UserCredential?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      print('Login error: ${e.message}');
      return null;
    }
  }

  /// Create anonymous user for biometric fallback
  Future<UserCredential?> signInAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      print('Anonymous sign-in error: ${e.message}');
      return null;
    }
  }

  /// Store biometric fingerprint identifier
  Future<bool> storeBiometricId({
    required String fingerprintId,
    required int fingerprintNumber, // 1 or 2
  }) async {
    try {
      final userId = currentUser?.uid;
      if (userId == null) return false;

      await _firestore.collection('users').doc(userId).update({
        'fingerprint_$fingerprintNumber': fingerprintId,
        'lastBiometricUpdate': DateTime.now(),
      });
      return true;
    } catch (e) {
      print('Error storing biometric ID: $e');
      return false;
    }
  }

  /// Get stored biometric IDs
  Future<Map<String, dynamic>?> getBiometricIds() async {
    try {
      final userId = currentUser?.uid;
      if (userId == null) return null;

      final doc = await _firestore.collection('users').doc(userId).get();
      return {
        'fingerprint_1': doc.data()?['fingerprint_1'],
        'fingerprint_2': doc.data()?['fingerprint_2'],
      };
    } catch (e) {
      print('Error retrieving biometric IDs: $e');
      return null;
    }
  }

  /// Sign out user
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  /// Reset password
  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      print('Password reset error: ${e.message}');
      return false;
    }
  }

  /// Get user profile data
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final userId = currentUser?.uid;
      if (userId == null) return null;

      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  /// Update user profile
  Future<bool> updateUserProfile({
    required String name,
    String? photoUrl,
  }) async {
    try {
      final userId = currentUser?.uid;
      if (userId == null) return false;

      await _firestore.collection('users').doc(userId).update({
        'name': name,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'updatedAt': DateTime.now(),
      });

      if (photoUrl != null) {
        await currentUser?.updatePhotoURL(photoUrl);
      }
      await currentUser?.updateDisplayName(name);

      return true;
    } catch (e) {
      print('Error updating user profile: $e');
      return false;
    }
  }
}