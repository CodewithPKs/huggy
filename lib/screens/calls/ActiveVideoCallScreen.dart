
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
  int? _remoteUid; // Track remote user
  bool _isCallConnected = false;

  @override
  void initState() {
    super.initState();
    _setupCallbacks();
    // Initialize with passed remoteUid if available
    if (widget.remoteUid > 0) {
      _remoteUid = widget.remoteUid;
      _isCallConnected = true;
    }
  }

  void _setupCallbacks() {
    // Listen for remote user joining
    widget.agoraService.onUserJoined((uid) {
      if (mounted) {
        setState(() {
          _remoteUid = uid;
          _isCallConnected = true;
        });
        print('✓ Remote user joined video call: $uid');
      }
    });

    // Listen for remote user leaving
    widget.agoraService.onUserLeft((uid) {
      if (mounted && _remoteUid == uid) {
        setState(() {
          _remoteUid = null;
          _isCallConnected = false;
        });
        print('✓ Remote user left video call: $uid');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video (full screen)
          _buildRemoteVideoWidget(),

          // Local video (small preview)
          Positioned(
            top: 60,
            right: 16,
            child: _buildLocalVideoWidget(),
          ),

          // Call info overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildCallInfoOverlay(),
          ),

          // Controls at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildCallControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteVideoWidget() {
    // 🔴 Check if remote user has joined
    if (_remoteUid == null || _remoteUid == 0) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFF6366F1),
                child: Text(
                  widget.callModel.receiverName[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.callModel.receiverName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isCallConnected ? 'Connecting...' : 'Calling...',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              ),
            ],
          ),
        ),
      );
    }

    // Remote user has joined - show their video
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: widget.agoraService.rtcEngine,
        canvas: VideoCanvas(uid: _remoteUid!),
        connection: RtcConnection(
          channelId: widget.callModel.agoraChannelId,
        ),
      ),
    );
  }

  Widget _buildLocalVideoWidget() {
    if (!widget.isCameraOn) {
      return Container(
        width: 120,
        height: 160,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: const Center(
          child: Icon(
            Icons.videocam_off,
            color: Colors.white70,
            size: 40,
          ),
        ),
      );
    }

    return Container(
      width: 120,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: widget.agoraService.rtcEngine,
            canvas: const VideoCanvas(uid: 0),
          ),
        ),
      ),
    );
  }

  Widget _buildCallInfoOverlay() {
    return Container(
      padding: const EdgeInsets.only(top: 50, left: 16, right: 16, bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.callModel.receiverName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isCallConnected ? 'Connected' : 'Connecting...',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.videocam, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Video Call',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallControls() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Mute button
            _buildControlButton(
              icon: widget.isMuted ? Icons.mic_off : Icons.mic,
              label: widget.isMuted ? 'Unmute' : 'Mute',
              onPressed: () => widget.onMuteToggle(!widget.isMuted),
              backgroundColor: widget.isMuted
                  ? Colors.white.withOpacity(0.3)
                  : Colors.white.withOpacity(0.2),
            ),

            // Camera toggle button
            _buildControlButton(
              icon: widget.isCameraOn ? Icons.videocam : Icons.videocam_off,
              label: widget.isCameraOn ? 'Camera Off' : 'Camera On',
              onPressed: () => widget.onCameraToggle(!widget.isCameraOn),
              backgroundColor: widget.isCameraOn
                  ? Colors.white.withOpacity(0.2)
                  : Colors.white.withOpacity(0.3),
            ),

            // Switch camera button
            _buildControlButton(
              icon: Icons.flip_camera_ios,
              label: 'Flip',
              onPressed: widget.onSwitchCamera,
              backgroundColor: Colors.white.withOpacity(0.2),
            ),

            // End call button
            _buildControlButton(
              icon: Icons.call_end,
              label: 'End',
              onPressed: widget.onEndCall,
              backgroundColor: Colors.red,
              iconSize: 32,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
    double iconSize = 24,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: backgroundColor,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Icon(
                icon,
                color: Colors.white,
                size: iconSize,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    widget.agoraService.clearCallbacks();
    super.dispose();
  }
}

// class ActiveVideoCallScreen extends StatefulWidget {
//   final CallModel callModel;
//   final AgoraCallService agoraService;
//   final int remoteUid;
//   final Function(bool) onMuteToggle;
//   final Function(bool) onCameraToggle;
//   final VoidCallback onSwitchCamera;
//   final VoidCallback onEndCall;
//   final bool isMuted;
//   final bool isCameraOn;
//
//   const ActiveVideoCallScreen({
//     Key? key,
//     required this.callModel,
//     required this.agoraService,
//     required this.remoteUid,
//     required this.onMuteToggle,
//     required this.onCameraToggle,
//     required this.onSwitchCamera,
//     required this.onEndCall,
//     required this.isMuted,
//     required this.isCameraOn,
//   }) : super(key: key);
//
//   @override
//   State<ActiveVideoCallScreen> createState() => _ActiveVideoCallScreenState();
// }
//
// class _ActiveVideoCallScreenState extends State<ActiveVideoCallScreen> {
//   late DateTime _callStartTime;
//   int _callDurationSeconds = 0;
//   bool _showControls = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _callStartTime = DateTime.now();
//     _startTimer();
//   }
//
//   void _startTimer() {
//     Future.delayed(Duration.zero, () async {
//       while (mounted) {
//         await Future.delayed(const Duration(seconds: 1));
//         if (mounted) {
//           setState(() {
//             _callDurationSeconds =
//                 DateTime.now().difference(_callStartTime).inSeconds;
//           });
//         }
//       }
//     });
//   }
//
//   String _formatDuration(int seconds) {
//     int minutes = seconds ~/ 60;
//     int secs = seconds % 60;
//     return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
//   }
//
//   void _toggleControls() {
//     setState(() {
//       _showControls = !_showControls;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF000000),
//       body: GestureDetector(
//         onTap: _toggleControls,
//         child: Stack(
//           children: [
//             // Main video (remote user)
//             _buildRemoteVideoWidget(),
//
//             // Local video (small, bottom-right)
//             Positioned(
//               bottom: 80,
//               right: 16,
//               child: Container(
//                 width: 100,
//                 height: 120,
//                 decoration: BoxDecoration(
//                   border: Border.all(color: Colors.white, width: 2),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: _buildLocalVideoWidget(),
//               ),
//             ),
//
//             // Header with call info
//             if (_showControls)
//               Positioned(
//                 top: 0,
//                 left: 0,
//                 right: 0,
//                 child: _buildHeaderInfo(),
//               ),
//
//             // Bottom controls
//             if (_showControls)
//               Positioned(
//                 bottom: 0,
//                 left: 0,
//                 right: 0,
//                 child: _buildControlPanel(),
//               ),
//
//             // Floating timer
//             if (!_showControls)
//               Positioned(
//                 top: 40,
//                 left: 20,
//                 child: Container(
//                   padding:
//                   const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                   decoration: BoxDecoration(
//                     color: Colors.black.withOpacity(0.7),
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   child: Text(
//                     _formatDuration(_callDurationSeconds),
//                     style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//                       color: Colors.white,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildRemoteVideoWidget() {
//     return Container(
//       color: Colors.black,
//       child: Center(
//         child: AgoraVideoView(
//           controller: VideoViewController.remote(
//             rtcEngine: widget.agoraService.rtcEngine,
//             canvas: VideoCanvas(uid: widget.remoteUid),
//             connection: RtcConnection(
//               channelId: widget.callModel.agoraChannelId,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildLocalVideoWidget() {
//     return ClipRRect(
//       borderRadius: BorderRadius.circular(6),
//       child: AgoraVideoView(
//         controller: VideoViewController(
//           rtcEngine: widget.agoraService.rtcEngine,
//           canvas: const VideoCanvas(uid: 0),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildHeaderInfo() {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topCenter,
//           end: Alignment.bottomCenter,
//           colors: [
//             Colors.black.withOpacity(0.6),
//             Colors.black.withOpacity(0.0),
//           ],
//         ),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 widget.callModel.receiverName,
//                 style: Theme.of(context).textTheme.titleMedium?.copyWith(
//                   color: Colors.white,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 4),
//               Text(
//                 _formatDuration(_callDurationSeconds),
//                 style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                   color: Colors.grey[300],
//                 ),
//               ),
//             ],
//           ),
//           GestureDetector(
//             onTap: () => Navigator.pop(context),
//             child: Container(
//               padding: const EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: Colors.red.withOpacity(0.3),
//                 shape: BoxShape.circle,
//               ),
//               child: const Icon(
//                 Icons.close,
//                 color: Colors.red,
//                 size: 20,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildControlPanel() {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.bottomCenter,
//           end: Alignment.topCenter,
//           colors: [
//             Colors.black.withOpacity(0.8),
//             Colors.black.withOpacity(0.0),
//           ],
//         ),
//       ),
//       child: Column(
//         children: [
//           // Main controls
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//             children: [
//               // Mute button
//               _buildVideoControlButton(
//                 icon: widget.isMuted ? Icons.mic_off : Icons.mic,
//                 label: 'Mute',
//                 isActive: widget.isMuted,
//                 onPressed: () =>
//                     widget.onMuteToggle(!widget.isMuted),
//                 color: Colors.blue,
//               ),
//
//               // Camera off button
//               _buildVideoControlButton(
//                 icon: widget.isCameraOn ? Icons.videocam : Icons.videocam_off,
//                 label: 'Camera',
//                 isActive: !widget.isCameraOn,
//                 onPressed: () =>
//                     widget.onCameraToggle(!widget.isCameraOn),
//                 color: Colors.purple,
//               ),
//
//               // Switch camera button
//               _buildVideoControlButton(
//                 icon: Icons.flip_to_front,
//                 label: 'Switch',
//                 isActive: false,
//                 onPressed: widget.onSwitchCamera,
//                 color: Colors.orange,
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),
//
//           // End call button (full width)
//           SizedBox(
//             width: double.infinity,
//             child: ElevatedButton.icon(
//               onPressed: widget.onEndCall,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.red[600],
//                 padding: const EdgeInsets.symmetric(vertical: 12),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//               ),
//               icon: const Icon(Icons.call_end),
//               label: const Text('End Call'),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildVideoControlButton({
//     required IconData icon,
//     required String label,
//     required bool isActive,
//     required VoidCallback onPressed,
//     required Color color,
//   }) {
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         GestureDetector(
//           onTap: onPressed,
//           child: Container(
//             width: 50,
//             height: 50,
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               color: isActive ? color.withOpacity(0.3) : Colors.grey[800],
//               border: Border.all(
//                 color: isActive ? color : Colors.grey[700]!,
//                 width: 2,
//               ),
//             ),
//             child: Icon(
//               icon,
//               color: isActive ? color : Colors.grey[400],
//               size: 24,
//             ),
//           ),
//         ),
//         const SizedBox(height: 6),
//         Text(
//           label,
//           style: Theme.of(context).textTheme.labelSmall?.copyWith(
//             color: Colors.white,
//             fontSize: 11,
//           ),
//         ),
//       ],
//     );
//   }
// }