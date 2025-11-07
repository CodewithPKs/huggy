// File: lib/services/agora_call_service.dart
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';


/// Agora Configuration Constants
class AgoraConfig {
  // 🔴 IMPORTANT: Replace with your Agora App ID
  // Get your App ID from: https://console.agora.io
  static const String appId = '3a3b5601ce804feca23c1e502cecb3a0'; // REPLACE THIS

  // Token will be generated server-side in production
  // For development, you can use a temporary token from Agora Console
  static const String tempToken = '007eJxTYNiyt+GI+7PQaZwCV952Tpb7lPxL/hj3N+E1Qcu1KvKttPoUGIwTjZNMzQwMk1MtDEzSUpMTjYyTDVNNDYySU5OTjBMNjujwZTYEMjLcNQ1hZWSAQBCfnSEktbgkMy+dgQEA0/kgnw=='; // REPLACE THIS
}


class AgoraCallService {
  static final AgoraCallService _instance = AgoraCallService._internal();

  factory AgoraCallService() {
    return _instance;
  }

  AgoraCallService._internal();

  late RtcEngine rtcEngine;
  bool _isInitialized = false;
  String? _currentChannelId;
  bool _isLocalUserJoined = false;

  // Callbacks
  final List<Function(int)> _onUserJoinedCallbacks = [];
  final List<Function(int)> _onUserLeftCallbacks = [];
  final List<Function(String)> _onErrorCallbacks = [];

  /// ================================================
  /// INITIALIZATION
  /// ================================================

  /// Initialize Agora engine
  Future<bool> initializeAgora() async {
    try {
      if (_isInitialized) {
        print('✓ Agora already initialized');
        return true;
      }

      // Request permissions
      await _requestPermissions();

      // Create RTC engine
      rtcEngine = createAgoraRtcEngine();

      // Initialize engine
      await rtcEngine.initialize(RtcEngineContext(
        appId: AgoraConfig.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      // Register event handlers
      _setupEventHandlers();

      // Enable audio and video
      await rtcEngine.enableAudio();
      await rtcEngine.enableVideo();

      _isInitialized = true;
      print('✓ Agora initialized successfully');
      return true;
    } catch (e) {
      print('✗ Error initializing Agora: $e');
      _notifyError('Failed to initialize Agora: $e');
      return false;
    }
  }

  /// Request microphone and camera permissions
  Future<void> _requestPermissions() async {
    try {
      final micStatus = await Permission.microphone.request();
      final cameraStatus = await Permission.camera.request();

      print('Microphone: ${micStatus.isDenied ? 'Denied' : 'Granted'}');
      print('Camera: ${cameraStatus.isDenied ? 'Denied' : 'Granted'}');

      if (micStatus.isDenied || cameraStatus.isDenied) {
        print('⚠️ Permissions denied');
      }
    } catch (e) {
      print('✗ Error requesting permissions: $e');
    }
  }

  /// Setup event listeners for Agora
  void _setupEventHandlers() {
    rtcEngine.registerEventHandler(
      RtcEngineEventHandler(
        // User joined
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          print('✓ Remote user joined: $remoteUid');
          for (var callback in _onUserJoinedCallbacks) {
            callback(remoteUid);
          }
        },

        // User left
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          print('✓ Remote user left: $remoteUid');
          for (var callback in _onUserLeftCallbacks) {
            callback(remoteUid);
          }
        },

        // Local user joined
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          _isLocalUserJoined = true;
          print('✓ Local user joined channel: ${connection.channelId}');
        },

        // Error handler
        onError: (err, msg) {
          print('✗ Agora Error: $err - $msg');
          _notifyError('Agora Error: $msg');
        },

        // Connection state changed
        onConnectionStateChanged: (RtcConnection connection,
            ConnectionStateType state,
            ConnectionChangedReasonType reason) {
          print('Connection state: ${state.toString()}');
        },

        // Token will expire
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          print('⚠️ Token will expire');
        },
      ),
    );
  }

  /// ================================================
  /// VOICE CALL
  /// ================================================

  /// Join voice call channel
  Future<bool> joinVoiceCall({
    required String channelId,
    required int uid,
  }) async {
    try {
      if (!_isInitialized) {
        print('✗ Agora not initialized');
        return false;
      }

      _currentChannelId = channelId;

      // Set audio profile for voice quality
      await rtcEngine.setAudioProfile(
        profile: AudioProfileType.audioProfileDefault,
        scenario: AudioScenarioType.audioScenarioDefault,
      );

      // Join channel
      await rtcEngine.joinChannel(
        token: AgoraConfig.tempToken,
        channelId: channelId,
        uid: uid,
        options: ChannelMediaOptions(
          autoSubscribeAudio: true,
          autoSubscribeVideo: false,
          // publishAudioTrack: true,
        ),
      );


      print('✓ Joined voice channel: $channelId');
      return true;
    } catch (e) {
      print('✗ Error joining voice call: $e');
      _notifyError('Failed to join voice call: $e');
      return false;
    }
  }

  /// ================================================
  /// VIDEO CALL
  /// ================================================

  /// Join video call channel
  Future<bool> joinVideoCall({
    required String channelId,
    required int uid,
  }) async {
    try {
      if (!_isInitialized) {
        print('✗ Agora not initialized');
        return false;
      }

      _currentChannelId = channelId;

      // Set video profile for better quality
      await rtcEngine.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 720, height: 1280),
          frameRate: 30,
          bitrate: 2500,
          orientationMode: OrientationMode.orientationModeAdaptive,
        ),
      );

      // Enable video
      await rtcEngine.enableVideo();

      // Start preview
      await rtcEngine.startPreview();

      // Join channel
      await rtcEngine.joinChannel(
        token: AgoraConfig.tempToken,
        channelId: channelId,
        uid: uid,
        options: ChannelMediaOptions(
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          // publishAudioTrack: true,
          publishCameraTrack: true, // or publishVideoTrack depending on SDK version
        ),
      );


      print('✓ Joined video channel: $channelId');
      return true;
    } catch (e) {
      print('✗ Error joining video call: $e');
      _notifyError('Failed to join video call: $e');
      return false;
    }
  }

  /// Switch camera (front/back)
  Future<void> switchCamera() async {
    try {
      await rtcEngine.switchCamera();
      print('✓ Camera switched');
    } catch (e) {
      print('✗ Error switching camera: $e');
    }
  }

  /// ================================================
  /// AUDIO & VIDEO CONTROLS
  /// ================================================

  /// Mute audio
  Future<void> muteAudio(bool mute) async {
    try {
      await rtcEngine.muteLocalAudioStream(mute);
      print('${mute ? '✓ Audio muted' : '✓ Audio unmuted'}');
    } catch (e) {
      print('✗ Error muting audio: $e');
    }
  }

  /// Disable video
  Future<void> disableVideo(bool disable) async {
    try {
      await rtcEngine.enableLocalVideo(!disable);
      print('${disable ? '✓ Video disabled' : '✓ Video enabled'}');
    } catch (e) {
      print('✗ Error disabling video: $e');
    }
  }

  /// Enable speaker
  Future<void> enableSpeaker(bool enable) async {
    try {
      await rtcEngine.setEnableSpeakerphone(enable);
      print('${enable ? '✓ Speaker on' : '✓ Speakerphone off'}');
    } catch (e) {
      print('✗ Error enabling speaker: $e');
    }
  }

  /// Get video view for remote user
  Widget getRemoteVideoView({
    required int uid,
  }) {
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: rtcEngine,
        canvas: VideoCanvas(uid: uid),
        connection: RtcConnection(channelId: _currentChannelId),
      ),
    );
  }

  /// Get video view for local user
  Widget getLocalVideoView() {
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: rtcEngine,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  /// ================================================
  /// CALL STATE MANAGEMENT
  /// ================================================

  /// Leave current call
  Future<void> leaveCall() async {
    try {
      if (!_isInitialized) return;

      await rtcEngine.leaveChannel();
      _isLocalUserJoined = false;
      _currentChannelId = null;

      print('✓ Left call channel');
    } catch (e) {
      print('✗ Error leaving call: $e');
    }
  }

  /// Dispose Agora engine
  Future<void> dispose() async {
    try {
      await leaveCall();
      await rtcEngine.release();
      _isInitialized = false;

      print('✓ Agora disposed');
    } catch (e) {
      print('✗ Error disposing Agora: $e');
    }
  }

  /// ================================================
  /// CALLBACK MANAGEMENT
  /// ================================================

  /// Add callback for when user joins
  void onUserJoined(Function(int) callback) {
    _onUserJoinedCallbacks.add(callback);
  }

  /// Add callback for when user leaves
  void onUserLeft(Function(int) callback) {
    _onUserLeftCallbacks.add(callback);
  }

  /// Add callback for errors
  void onError(Function(String) callback) {
    _onErrorCallbacks.add(callback);
  }

  void _notifyError(String message) {
    for (var callback in _onErrorCallbacks) {
      callback(message);
    }
  }

  /// Clear all callbacks
  void clearCallbacks() {
    _onUserJoinedCallbacks.clear();
    _onUserLeftCallbacks.clear();
    _onErrorCallbacks.clear();
  }

  /// ================================================
  /// GETTERS
  /// ================================================

  bool get isInitialized => _isInitialized;
  bool get isLocalUserJoined => _isLocalUserJoined;
  String? get currentChannelId => _currentChannelId;
}