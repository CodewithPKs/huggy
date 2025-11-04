// File: lib/services/voice_activation_service.dart
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/services.dart';
import '../../services/biometric_service.dart';

class VoiceActivationService {
  static final VoiceActivationService _instance =
  VoiceActivationService._internal();

  factory VoiceActivationService() {
    return _instance;
  }

  VoiceActivationService._internal();

  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final BiometricService _biometricService = BiometricService();

  // Activation keywords (case-insensitive)
  static const String activationKeyword = 'open the praveen';
  static const String activationKeywordAlt = 'open praveen';

  /// Initialize speech recognition
  Future<bool> initializeSpeech() async {
    try {
      final available = await _speechToText.initialize(
        onError: (error) => print('Speech error: $error'),
        onStatus: (status) => print('Speech status: $status'),
      );
      print('Speech recognition available: $available');
      return available;
    } catch (e) {
      print('Error initializing speech: $e');
      return false;
    }
  }

  /// Check if speech recognition is available
  Future<bool> isSpeechAvailable() async {
    return await _speechToText.initialize();
  }

  /// Start listening for voice activation
  Future<String?> startListening() async {
    if (!_speechToText.isAvailable) {
      print('Speech recognition not available');
      return null;
    }

    try {
      if (_speechToText.isListening) {
        return null;
      }

      String recognizedText = '';

      await _speechToText.listen(
        onResult: (result) {
          recognizedText = result.recognizedWords.toLowerCase();
          print('Recognized: $recognizedText');

          // Check if activation phrase detected
          if (recognizedText.contains(activationKeyword) ||
              recognizedText.contains(activationKeywordAlt)) {
            print('✓ Activation keyword detected!');
            stopListening();
          }
        },
        listenMode: stt.ListenMode.search,
        // pauseDuration: const Duration(seconds: 3),
        cancelOnError: true,
        pauseFor: const Duration(seconds: 3)
      );

      // Wait for listening to complete
      await Future.delayed(const Duration(seconds: 30));
      stopListening();

      return recognizedText;
    } catch (e) {
      print('Error listening: $e');
      return null;
    }
  }

  /// Stop listening
  void stopListening() {
    if (_speechToText.isListening) {
      _speechToText.stop();
      print('Stopped listening');
    }
  }

  /// Check if text contains activation keyword
  bool isActivationKeywordDetected(String text) {
    final lowerText = text.toLowerCase();
    return lowerText.contains(activationKeyword) ||
        lowerText.contains(activationKeywordAlt);
  }

  /// Get activation status
  bool get isListening => _speechToText.isListening;

  /// Dispose
  void dispose() {
    _speechToText.cancel();
  }
}