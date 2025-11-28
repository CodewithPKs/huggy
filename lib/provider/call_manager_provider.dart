// File: lib/providers/call_manager_provider.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../model/call_models.dart';

import '../services/agora_call_service.dart';
import '../services/firebase_call_signaling_service.dart';

class CallManagerProvider extends ChangeNotifier {
  final FirebaseCallSignalingService _signaling =
  FirebaseCallSignalingService();
  final AgoraCallService _agoraService = AgoraCallService();

  StreamSubscription<CallStatus?>? _callEndSubscription;


  void listenForCallEnd({
    required String callId,
    required VoidCallback onCallEnded,
  }) {
    _callEndSubscription?.cancel(); // Cancel previous subscription

    _callEndSubscription = _signaling.watchCallEndStatus(callId).listen((status) {
      if (status != null) {
        print('🔴 Call ended with status: $status');

        // Cleanup and trigger callback
        _currentCall = null;
        _currentCallStatus = CallStatus.ended;
        _isMuted = false;
        _isCameraOn = true;
        _remoteUid = 0;

        notifyListeners();

        // Trigger callback to navigate back
        onCallEnded();

        // Cancel subscription after call ends
        _callEndSubscription?.cancel();
        _callEndSubscription = null;
      }
    });
  }

  /// Cancel call end listener
  void cancelCallEndListener() {
    _callEndSubscription?.cancel();
    _callEndSubscription = null;
  }


  // Current call state
  CallModel? _currentCall;
  CallStatus _currentCallStatus = CallStatus.pending;
  bool _isMuted = false;
  bool _isCameraOn = true;
  bool _isSpeakerOn = false;
  int _remoteUid = 0;
  String _currentUserId = 'user'; // 'user' or 'admin'

  // Incoming call state
  CallModel? _incomingCall;
  bool _hasIncomingCall = false;

  // Error state
  String? _errorMessage;

  /// ================================================
  /// GETTERS
  /// ================================================
  CallModel? get currentCall => _currentCall;
  CallStatus get currentCallStatus => _currentCallStatus;
  bool get isMuted => _isMuted;
  bool get isCameraOn => _isCameraOn;
  bool get isSpeakerOn => _isSpeakerOn;
  int get remoteUid => _remoteUid;
  CallModel? get incomingCall => _incomingCall;
  bool get hasIncomingCall => _hasIncomingCall;
  String? get errorMessage => _errorMessage;
  bool get isInCall => _currentCall != null &&
      (_currentCallStatus == CallStatus.pending ||
          _currentCallStatus == CallStatus.accepted);
  bool get isCallActive => _currentCallStatus == CallStatus.accepted;

  AgoraCallService get agoraService => _agoraService;
  FirebaseCallSignalingService get signaling => _signaling;

  /// ================================================
  /// INITIALIZATION
  /// ================================================

  Future<void> initialize({required String userId}) async {
    try {
      _currentUserId = userId;

      // Initialize Agora
      final agoraInit = await _agoraService.initializeAgora();
      if (!agoraInit) {
        throw Exception('Failed to initialize Agora');
      }

      // Setup callbacks
      _setupAgoraCallbacks();

      print('✓ CallManager initialized');
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Initialization failed: $e';
      print('✗ $_errorMessage');
      notifyListeners();
    }
  }

  void _setupAgoraCallbacks() {
    _agoraService.onUserJoined((uid) {
      _remoteUid = uid;
      print('Remote user joined: $uid');
      notifyListeners();
    });

    _agoraService.onUserLeft((uid) {
      if (_remoteUid == uid) {
        _remoteUid = 0;
        print('Remote user left: $uid');
      }
      notifyListeners();
    });

    _agoraService.onError((error) {
      _errorMessage = error;
      print('Agora error: $error');
      notifyListeners();
    });
  }

  /// ================================================
  /// INITIATING CALLS
  /// ================================================

  /// Initiate a voice call
  // Future<bool> initiateVoiceCall({
  //   required String receiverId,
  //   required String receiverName,
  // }) async {
  //   try {
  //     _errorMessage = null;
  //
  //     // Create call in Firebase
  //     final callId = await _signaling.initiateCall(
  //       callerId: _currentUserId,
  //       callerName: 'Me',
  //       receiverId: receiverId,
  //       receiverName: receiverName,
  //       callType: CallType.voice,
  //       userRole: _currentUserId,
  //     );
  //
  //     if (callId == null) {
  //       throw Exception('Failed to create call');
  //     }
  //
  //     // Create call model
  //     _currentCall = CallModel(
  //       callId: callId,
  //       callerId: _currentUserId,
  //       callerName: 'Me',
  //       receiverId: receiverId,
  //       receiverName: receiverName,
  //       callType: CallType.voice,
  //       status: CallStatus.pending,
  //       createdAt: DateTime.now(),
  //       agoraChannelId: 'Calling',
  //     );
  //
  //     // Join Agora channel
  //     final joined = await _agoraService.joinVoiceCall(
  //       channelId: 'Calling',
  //       uid: _generateUid(),
  //     );
  //
  //     if (!joined) {
  //       throw Exception('Failed to join voice channel');
  //     }
  //
  //     _currentCallStatus = CallStatus.pending;
  //     print('✓ Voice call initiated: $callId');
  //     notifyListeners();
  //     return true;
  //   } catch (e) {
  //     _errorMessage = 'Failed to initiate call: $e';
  //     print('✗ $_errorMessage');
  //     notifyListeners();
  //     return false;
  //   }
  // }
  Future<bool> initiateVoiceCall({
    required String receiverId,
    required String receiverName,
  }) async {
    try {
      _errorMessage = null;

      // Create call in Firebase
      final callId = await _signaling.initiateCall(
        callerId: _currentUserId,
        callerName: 'Me',
        receiverId: receiverId,
        receiverName: receiverName,
        callType: CallType.voice,
        userRole: _currentUserId,
      );

      if (callId == null) {
        throw Exception('Failed to create call');
      }

      // Create call model - 🔴 Use fixed channel name
      _currentCall = CallModel(
        callId: callId,
        callerId: _currentUserId,
        callerName: 'Me',
        receiverId: receiverId,
        receiverName: receiverName,
        callType: CallType.voice,
        status: CallStatus.pending,
        createdAt: DateTime.now(),
        agoraChannelId: AgoraConfig.fixedChannelName, // 🔴 Changed
      );

      // Join Agora channel - 🔴 Pass fixed channel (though it's ignored now)
      final joined = await _agoraService.joinVoiceCall(
        channelId: AgoraConfig.fixedChannelName,
        uid: _generateUid(),
      );

      if (!joined) {
        throw Exception('Failed to join voice channel');
      }

      _currentCallStatus = CallStatus.pending;
      print('✓ Voice call initiated: $callId');
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to initiate call: $e';
      print('✗ $_errorMessage');
      notifyListeners();
      return false;
    }
  }

  /// Initiate a video call
  Future<bool> initiateVideoCall({
    required String receiverId,
    required String receiverName,
  }) async {
    try {
      _errorMessage = null;

      // Create call in Firebase
      final callId = await _signaling.initiateCall(
        callerId: _currentUserId,
        callerName: 'Me',
        receiverId: receiverId,
        receiverName: receiverName,
        callType: CallType.video,
        userRole: _currentUserId,
      );

      if (callId == null) {
        throw Exception('Failed to create call');
      }

      // Create call model - 🔴 Use fixed channel name
      _currentCall = CallModel(
        callId: callId,
        callerId: _currentUserId,
        callerName: 'Me',
        receiverId: receiverId,
        receiverName: receiverName,
        callType: CallType.video,
        status: CallStatus.pending,
        createdAt: DateTime.now(),
        agoraChannelId: AgoraConfig.fixedChannelName, // 🔴 Changed
      );

      // Join Agora channel
      final joined = await _agoraService.joinVideoCall(
        channelId: AgoraConfig.fixedChannelName,
        uid: _generateUid(),
      );

      if (!joined) {
        throw Exception('Failed to join video channel');
      }

      _currentCallStatus = CallStatus.pending;
      _isCameraOn = true;
      print('✓ Video call initiated: $callId');
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to initiate call: $e';
      print('✗ $_errorMessage');
      notifyListeners();
      return false;
    }
  }


  /// Initiate a video call
  // Future<bool> initiateVideoCall({
  //   required String receiverId,
  //   required String receiverName,
  // }) async {
  //   try {
  //     _errorMessage = null;
  //
  //     // Create call in Firebase
  //     final callId = await _signaling.initiateCall(
  //       callerId: _currentUserId,
  //       callerName: 'Me',
  //       receiverId: receiverId,
  //       receiverName: receiverName,
  //       callType: CallType.video,
  //       userRole: _currentUserId,
  //     );
  //
  //     if (callId == null) {
  //       throw Exception('Failed to create call');
  //     }
  //
  //     // Create call model
  //     _currentCall = CallModel(
  //       callId: callId,
  //       callerId: _currentUserId,
  //       callerName: 'Me',
  //       receiverId: receiverId,
  //       receiverName: receiverName,
  //       callType: CallType.video,
  //       status: CallStatus.pending,
  //       createdAt: DateTime.now(),
  //       agoraChannelId: 'call_$callId',
  //     );
  //
  //     // Join Agora channel
  //     final joined = await _agoraService.joinVideoCall(
  //       channelId: 'call_$callId',
  //       uid: _generateUid(),
  //     );
  //
  //     if (!joined) {
  //       throw Exception('Failed to join video channel');
  //     }
  //
  //     _currentCallStatus = CallStatus.pending;
  //     _isCameraOn = true;
  //     print('✓ Video call initiated: $callId');
  //     notifyListeners();
  //     return true;
  //   } catch (e) {
  //     _errorMessage = 'Failed to initiate call: $e';
  //     print('✗ $_errorMessage');
  //     notifyListeners();
  //     return false;
  //   }
  // }

  /// ================================================
  /// ACCEPTING & REJECTING CALLS
  /// ================================================

  /// Accept incoming call
  Future<bool> acceptIncomingCall() async {
    try {
      if (_incomingCall == null) {
        throw Exception('No incoming call');
      }

      _errorMessage = null;

      // Update Firebase
      await _signaling.acceptCall(_incomingCall!.callId);

      // Join Agora channel
      final joined = _incomingCall!.callType == CallType.voice
          ? await _agoraService.joinVoiceCall(
        channelId: _incomingCall!.agoraChannelId,
        uid: _generateUid(),
      )
          : await _agoraService.joinVideoCall(
        channelId: _incomingCall!.agoraChannelId,
        uid: _generateUid(),
      );

      if (!joined) {
        throw Exception('Failed to join call');
      }

      _currentCall = _incomingCall;
      _currentCallStatus = CallStatus.accepted;
      _hasIncomingCall = false;
      _incomingCall = null;

      print('✓ Call accepted');
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to accept call: $e';
      print('✗ $_errorMessage');
      notifyListeners();
      return false;
    }
  }

  /// Reject incoming call
  Future<bool> rejectIncomingCall() async {
    try {
      if (_incomingCall == null) {
        throw Exception('No incoming call');
      }

      await _signaling.rejectCall(_incomingCall!.callId);

      _hasIncomingCall = false;
      _incomingCall = null;

      print('✓ Call rejected');
      notifyListeners();
      return true;
    } catch (e) {
      print('✗ Error rejecting call: $e');
      notifyListeners();
      return false;
    }
  }

  /// ================================================
  /// CALL CONTROLS
  /// ================================================

  /// Toggle mute
  Future<void> toggleMute() async {
    try {
      _isMuted = !_isMuted;
      await _agoraService.muteAudio(_isMuted);
      notifyListeners();
    } catch (e) {
      print('✗ Error toggling mute: $e');
    }
  }

  /// Toggle camera
  Future<void> toggleCamera() async {
    try {
      _isCameraOn = !_isCameraOn;
      await _agoraService.disableVideo(!_isCameraOn);
      notifyListeners();
    } catch (e) {
      print('✗ Error toggling camera: $e');
    }
  }

  /// Toggle speaker
  Future<void> toggleSpeaker() async {
    try {
      _isSpeakerOn = !_isSpeakerOn;
      await _agoraService.enableSpeaker(_isSpeakerOn);
      notifyListeners();
    } catch (e) {
      print('✗ Error toggling speaker: $e');
    }
  }

  /// Switch camera
  Future<void> switchCamera() async {
    try {
      await _agoraService.switchCamera();
      notifyListeners();
    } catch (e) {
      print('✗ Error switching camera: $e');
    }
  }

  /// ================================================
  /// ENDING CALLS
  /// ================================================

  /// End current call
  Future<bool> endCall({bool missed = false}) async {
    try {
      if (_currentCall == null) {
        throw Exception('No active call');
      }

      final duration =
          DateTime.now().difference(_currentCall!.createdAt).inSeconds;

      // Update Firebase
      await _signaling.endCall(
        callId: _currentCall!.callId,
        durationSeconds: duration,
        wasMissed: missed,
      );

      // Leave Agora
      await _agoraService.leaveCall();

      // Reset state
      _currentCall = null;
      _currentCallStatus = CallStatus.ended;
      _isMuted = false;
      _isCameraOn = true;
      _remoteUid = 0;

      print('✓ Call ended');
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to end call: $e';
      print('✗ $_errorMessage');
      notifyListeners();
      return false;
    }
  }

  /// ================================================
  /// INCOMING CALL LISTENER
  /// ================================================

  /// Listen for incoming calls
  void listenForIncomingCalls({
    required String userId,
    required Function(CallModel) onIncomingCall,
  }) {
    _signaling.getIncomingCallsStream(userId).listen((calls) {
      if (calls.isNotEmpty) {
        for (var call in calls) {
          if (call.callId != _currentCall?.callId) {
            _incomingCall = call;
            _hasIncomingCall = true;
            onIncomingCall(call);
            notifyListeners();
          }
        }
      }
    });
  }

  /// ================================================
  /// UTILITIES
  /// ================================================

  int _generateUid() {
    // Generate a semi-unique UID based on timestamp
    return Random().nextInt(4000000000);
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }


  /// Update dispose method
  @override
  void dispose() {
    _callEndSubscription?.cancel();
    _agoraService.clearCallbacks();
    super.dispose();
  }

}