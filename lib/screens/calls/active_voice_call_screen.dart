// File: lib/screens/calls/active_voice_call_screen.dart
import 'package:flutter/material.dart';
import '../../model/call_models.dart';


class ActiveVoiceCallScreen extends StatefulWidget {
  final CallModel callModel;
  final Function(bool) onMuteToggle;
  final Function(bool) onSpeakerToggle;
  final VoidCallback onEndCall;
  final bool isMuted;
  final bool isSpeakerOn;

  const ActiveVoiceCallScreen({
    Key? key,
    required this.callModel,
    required this.onMuteToggle,
    required this.onSpeakerToggle,
    required this.onEndCall,
    required this.isMuted,
    required this.isSpeakerOn,
  }) : super(key: key);

  @override
  State<ActiveVoiceCallScreen> createState() => _ActiveVoiceCallScreenState();
}

class _ActiveVoiceCallScreenState extends State<ActiveVoiceCallScreen> {
  late DateTime _callStartTime;
  int _callDurationSeconds = 0;
  late Future<void> Function() _timerCallback;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Header with receiver info
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Text(
                    widget.callModel.receiverName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'In Call • ${_formatDuration(_callDurationSeconds)}',
                          style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.green[300],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Center icon
            Expanded(
              child: Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.green.withOpacity(0.3),
                        Colors.green.withOpacity(0.1),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.call,
                    size: 60,
                    color: Colors.green[300],
                  ),
                ),
              ),
            ),

            // Control buttons
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  // Main controls row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Mute button
                      _buildControlButton(
                        icon: widget.isMuted ? Icons.mic_off : Icons.mic,
                        label: widget.isMuted ? 'Unmute' : 'Mute',
                        isActive: widget.isMuted,
                        onPressed: () =>
                            widget.onMuteToggle(!widget.isMuted),
                        color: Colors.blue,
                      ),

                      // Speaker button
                      _buildControlButton(
                        icon: widget.isSpeakerOn
                            ? Icons.speaker_phone
                            : Icons.phone,
                        label: widget.isSpeakerOn ? 'Speaker' : 'Earpiece',
                        isActive: widget.isSpeakerOn,
                        onPressed: () =>
                            widget.onSpeakerToggle(!widget.isSpeakerOn),
                        color: Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // End call button
                  FloatingActionButton(
                    onPressed: widget.onEndCall,
                    backgroundColor: Colors.red[600],
                    heroTag: 'end_call_btn',
                    child: const Icon(
                      Icons.call_end,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 60,
            height: 60,
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
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: isActive ? color : Colors.grey[400],
          ),
        ),
      ],
    );
  }
}