// File: lib/screens/chat/chat_screen_with_calls.dart
// This is an example of how to integrate calls into your existing chat screen

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../model/call_models.dart';

import '../../provider/call_manager_provider.dart';

import '../../services/enhanced_chat_service.dart';
import '../../services/incoming_call_screen.dart';
import '../calls/ActiveVideoCallScreen.dart';

import '../calls/active_voice_call_screen.dart';
import '../calls/call_history_screen.dart';

/// Example of adding call functionality to your existing chat screen
class ChatScreenWithCalls extends StatefulWidget {
  final String conversationId;
  final String userId;
  final String userName;

  const ChatScreenWithCalls({
    Key? key,
    required this.conversationId,
    required this.userId,
    required this.userName,
  }) : super(key: key);

  @override
  State<ChatScreenWithCalls> createState() => _ChatScreenWithCallsState();
}

class _ChatScreenWithCallsState extends State<ChatScreenWithCalls> {
  late CallManagerProvider _callManager;

  @override
  void initState() {
    super.initState();
    _setupCallManager();
  }

  void _setupCallManager() {
    _callManager = Provider.of<CallManagerProvider>(context, listen: false);

    // Listen for incoming calls
    _callManager.listenForIncomingCalls(
      userId: widget.userId,
      onIncomingCall: (call) {
        _showIncomingCallScreen(call);
      },
    );
  }

  void _showIncomingCallScreen(CallModel call) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => IncomingCallScreen(
        incomingCall: call,
        onAnswer: () => _acceptCall(context),
        onReject: () => _rejectCall(context),
        onTimeout: () => _missedCall(context),
      ),
    );
  }

  void _acceptCall(BuildContext context) {
    Navigator.pop(context);
    _callManager.acceptIncomingCall().then((success) {
      if (success) {
        _showActiveCallScreen();
      }
    });
  }

  void _rejectCall(BuildContext context) {
    Navigator.pop(context);
    _callManager.rejectIncomingCall();
  }

  void _missedCall(BuildContext context) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Call missed')),
    );
  }

  void _showActiveCallScreen() {
    final call = _callManager.currentCall;
    if (call == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => call.callType == CallType.voice
            ? ActiveVoiceCallScreen(
          callModel: call,
          onMuteToggle: (_) => _callManager.toggleMute(),
          onSpeakerToggle: (_) => _callManager.toggleSpeaker(),
          onEndCall: () => _endCall(),
          isMuted: _callManager.isMuted,
          isSpeakerOn: _callManager.isSpeakerOn,
        )
            : ActiveVideoCallScreen(
          callModel: call,
          agoraService: _callManager.agoraService,
          remoteUid: _callManager.remoteUid,
          onMuteToggle: (_) => _callManager.toggleMute(),
          onCameraToggle: (_) => _callManager.toggleCamera(),
          onSwitchCamera: () => _callManager.switchCamera(),
          onEndCall: () => _endCall(),
          isMuted: _callManager.isMuted,
          isCameraOn: _callManager.isCameraOn,
        ),
      ),
    );
  }

  void _endCall() {
    _callManager.endCall().then((_) {
      Navigator.pop(context);
    });
  }

  Future<void> _initiateVoiceCall() async {
    final success = await _callManager.initiateVoiceCall(
      receiverId: 'admin',
      receiverName: 'Admin',
    );

    if (success && mounted) {
      _showActiveCallScreen();
    }
  }

  Future<void> _initiateVideoCall() async {
    final success = await _callManager.initiateVideoCall(
      receiverId: 'admin',
      receiverName: 'Admin',
    );

    if (success && mounted) {
      _showActiveCallScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Chat'),
        centerTitle: true,
        elevation: 0,
        actions: [
          // Voice call button
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: _initiateVoiceCall,
            tooltip: 'Start Voice Call',
          ),
          // Video call button
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: _initiateVideoCall,
            tooltip: 'Start Video Call',
          ),
          // Info button
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // Show chat info
            },
          ),
          // More options
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'history':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CallHistoryScreen(userId: widget.userId),
                    ),
                  );
                  break;
                case 'clear':
                // Clear chat
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history, size: 20),
                    SizedBox(width: 12),
                    Text('Call History'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, size: 20),
                    SizedBox(width: 12),
                    Text('Clear Chat'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Text(
                'Chat content here',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }
}