// File: lib/screens/calls/incoming_call_screen.dart
import 'package:flutter/material.dart';
import 'package:avatar_glow/avatar_glow.dart';

import '../model/call_models.dart';

class IncomingCallScreen extends StatefulWidget {
  final CallModel incomingCall;
  final Function() onAnswer;
  final Function() onReject;
  final VoidCallback onTimeout;

  const IncomingCallScreen({
    Key? key,
    required this.incomingCall,
    required this.onAnswer,
    required this.onReject,
    required this.onTimeout,
  }) : super(key: key);

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  int _timeoutSeconds = 30; // Auto-reject after 30 seconds
  late Future<void> _timeoutFuture;

  @override
  void initState() {
    super.initState();

    // Setup scale animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Setup auto-reject timeout
    _startTimeout();
  }

  void _startTimeout() {
    Future.delayed(Duration(seconds: _timeoutSeconds), () {
      if (mounted) {
        widget.onTimeout();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1E1E1E),
                const Color(0xFF0F0F0F),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header with call type
              Padding(
                padding:
                const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                child: Column(
                  children: [
                    Text(
                      'Incoming ${widget.incomingCall.callType.displayName}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Caller info with avatar
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Avatar with glow effect
                      AvatarGlow(
                        glowColor: widget.incomingCall.callType == CallType.video
                            ? Colors.blue
                            : Colors.green,
                        // endRadius: 100,
                        duration: const Duration(milliseconds: 2000),
                        repeat: true,
                        // repeatPauseDuration:
                        // const Duration(milliseconds: 100),
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.incomingCall.callType ==
                                  CallType.video
                                  ? Colors.blue.withOpacity(0.3)
                                  : Colors.green.withOpacity(0.3),
                              border: Border.all(
                                color: widget.incomingCall.callType ==
                                    CallType.video
                                    ? Colors.blue
                                    : Colors.green,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                widget.incomingCall.callType.icon,
                                size: 50,
                                color: widget.incomingCall.callType ==
                                    CallType.video
                                    ? Colors.blue
                                    : Colors.green,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Caller name
                      Text(
                        widget.incomingCall.callerName,
                        style:
                        Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Call duration/status
                      Text(
                        'Ringing...',
                        style:
                        Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action buttons
              Padding(
                padding:
                const EdgeInsets.symmetric(vertical: 40, horizontal: 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Reject button
                    FloatingActionButton(
                      onPressed: widget.onReject,
                      backgroundColor: Colors.red[600],
                      heroTag: 'reject_btn',
                      child: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    // Answer button
                    FloatingActionButton(
                      onPressed: widget.onAnswer,
                      backgroundColor: Colors.green[600],
                      heroTag: 'answer_btn',
                      child: Icon(
                        widget.incomingCall.callType == CallType.video
                            ? Icons.videocam
                            : Icons.call,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}