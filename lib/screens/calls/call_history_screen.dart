// File: lib/screens/calls/call_history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../model/call_models.dart';
import '../../services/firebase_call_signaling_service.dart';

class CallHistoryScreen extends StatefulWidget {
  final String userId;

  const CallHistoryScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen>
    with SingleTickerProviderStateMixin {
  late FirebaseCallSignalingService _callService;
  late TabController _tabController;
  List<CallHistoryModel> _allCalls = [];
  List<CallHistoryModel> _missedCalls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _callService = FirebaseCallSignalingService();
    _tabController = TabController(length: 2, vsync: this);
    _loadCallHistory();
  }

  Future<void> _loadCallHistory() async {
    setState(() => _isLoading = true);

    try {
      final all = await _callService.getCallHistory(userId: widget.userId);
      final missed = await _callService.getMissedCalls(userId: widget.userId);

      setState(() {
        _allCalls = all;
        _missedCalls = missed;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading call history: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: const Text('Call History'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCallHistory,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.call),
                  const SizedBox(width: 8),
                  const Text('All Calls'),
                  if (_allCalls.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _allCalls.length.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.missed_video_call),
                  const SizedBox(width: 8),
                  const Text('Missed'),
                  if (_missedCalls.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _missedCalls.length.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : TabBarView(
        controller: _tabController,
        children: [
          // All calls tab
          _buildCallsList(_allCalls),
          // Missed calls tab
          _buildCallsList(_missedCalls),
        ],
      ),
    );
  }

  Widget _buildCallsList(List<CallHistoryModel> calls) {
    if (calls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.phone_missed,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No calls',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: calls.length,
      itemBuilder: (context, index) {
        final call = calls[index];
        return _buildCallHistoryItem(call);
      },
    );
  }

  Widget _buildCallHistoryItem(CallHistoryModel call) {
    final isOutgoing = call.callerId == widget.userId;
    final contactName = isOutgoing ? call.receiverName : call.callerName;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[800]!,
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: call.missedCall
                  ? [Colors.red.withOpacity(0.3), Colors.red.withOpacity(0.1)]
                  : call.callType == CallType.video
                  ? [
                Colors.blue.withOpacity(0.3),
                Colors.blue.withOpacity(0.1)
              ]
                  : [
                Colors.green.withOpacity(0.3),
                Colors.green.withOpacity(0.1)
              ],
            ),
          ),
          child: Icon(
            call.missedCall
                ? Icons.phone_missed
                : isOutgoing
                ? Icons.call_made
                : Icons.call_received,
            color: call.missedCall
                ? Colors.red
                : isOutgoing
                ? Colors.blue
                : Colors.green,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                contactName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: call.callType == CallType.video
                    ? Colors.blue.withOpacity(0.2)
                    : Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                call.callType.icon,
                size: 12,
                color: call.callType == CallType.video
                    ? Colors.blue
                    : Colors.green,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _formatCallTime(call.callTime),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.grey[500],
              ),
            ),
            if (call.missedCall)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Missed call',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.red[400],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        trailing: Text(
          call.missedCall ? '—' : call.formattedDuration,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: call.missedCall ? Colors.red[400] : Colors.grey[400],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _formatCallTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd').format(time);
    }
  }
}