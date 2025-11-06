// File: lib/screens/calls/active_video_call_screen.dart
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import '../../model/call_models.dart';
import '../../services/agora_call_service.dart';

class ActiveVideoCallScreen extends StatefulWidget {
  final CallModel callModel;
  final AgoraCallService agoraService;
  final int remoteUid;
  final Function(bool) onMuteToggle;
  final Function(bool) onCameraToggle;
  final VoidCallback onSwitchCamera;
  final VoidCallback onEndCall;
  final bool isMuted;
  final bool isCameraOn;

  const ActiveVideoCallScreen({
    Key? key,
    required this.callModel,
    required this.agoraService,
    required this.remoteUid,
    required this.onMuteToggle,
    required this.onCameraToggle,
    required this.onSwitchCamera,
    required this.onEndCall,
    required this.isMuted,
    required this.isCameraOn,
  }) : super(key: key);

  @override
  State<ActiveVideoCallScreen> createState() => _ActiveVideoCallScreenState();
}

class _ActiveVideoCallScreenState extends State<ActiveVideoCallScreen> {
  late DateTime _callStartTime;
  int _callDurationSeconds = 0;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _callStartTime = DateTime.now();
    _startTimer();
  }

  void _startTimer() {
    Future.delayed(Duration.zero, () async {
      while (mounted) {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          setState(() {
            _callDurationSeconds =
                DateTime.now().difference(_callStartTime).inSeconds;
          });
        }
      }
    });
  }

  String _formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Main video (remote user)
            _buildRemoteVideoWidget(),

            // Local video (small, bottom-right)
            Positioned(
              bottom: 80,
              right: 16,
              child: Container(
                width: 100,
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildLocalVideoWidget(),
              ),
            ),

            // Header with call info
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildHeaderInfo(),
              ),

            // Bottom controls
            if (_showControls)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildControlPanel(),
              ),

            // Floating timer
            if (!_showControls)
              Positioned(
                top: 40,
                left: 20,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _formatDuration(_callDurationSeconds),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteVideoWidget() {
    return Container(
      color: Colors.black,
      child: Center(
        child: AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: widget.agoraService.rtcEngine,
            canvas: VideoCanvas(uid: widget.remoteUid),
            connection: RtcConnection(
              channelId: widget.callModel.agoraChannelId,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocalVideoWidget() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: widget.agoraService.rtcEngine,
          canvas: const VideoCanvas(uid: 0),
        ),
      ),
    );
  }

  Widget _buildHeaderInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.6),
            Colors.black.withOpacity(0.0),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.callModel.receiverName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDuration(_callDurationSeconds),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[300],
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.red,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.0),
          ],
        ),
      ),
      child: Column(
        children: [
          // Main controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Mute button
              _buildVideoControlButton(
                icon: widget.isMuted ? Icons.mic_off : Icons.mic,
                label: 'Mute',
                isActive: widget.isMuted,
                onPressed: () =>
                    widget.onMuteToggle(!widget.isMuted),
                color: Colors.blue,
              ),

              // Camera off button
              _buildVideoControlButton(
                icon: widget.isCameraOn ? Icons.videocam : Icons.videocam_off,
                label: 'Camera',
                isActive: !widget.isCameraOn,
                onPressed: () =>
                    widget.onCameraToggle(!widget.isCameraOn),
                color: Colors.purple,
              ),

              // Switch camera button
              _buildVideoControlButton(
                icon: Icons.flip_to_front,
                label: 'Switch',
                isActive: false,
                onPressed: widget.onSwitchCamera,
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // End call button (full width)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onEndCall,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.call_end),
              label: const Text('End Call'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? color.withOpacity(0.3) : Colors.grey[800],
              border: Border.all(
                color: isActive ? color : Colors.grey[700]!,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? color : Colors.grey[400],
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}