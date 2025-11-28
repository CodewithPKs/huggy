// File: lib/services/firebase_call_signaling_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';
import '../model/call_models.dart';


class FirebaseCallSignalingService {
  static final FirebaseCallSignalingService _instance =
  FirebaseCallSignalingService._internal();

  factory FirebaseCallSignalingService() {
    return _instance;
  }

  FirebaseCallSignalingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(app : Firebase.app(), databaseId: 'huggy');

  // Collection paths
  static const String _callsCollection = 'calls';
  static const String _callHistoryCollection = 'call_history';
  static const String _callMetricsCollection = 'call_metrics';

  /// ================================================
  /// CALL INITIATION & MANAGEMENT
  /// ================================================

  /// Create a new call and send notification to receiver
  Future<String?> initiateCall({
    required String callerId,
    required String callerName,
    required String receiverId,
    required String receiverName,
    required CallType callType,
    required String userRole,
  }) async {
    try {
      final callId = const Uuid().v4();
      final agoraChannelId = 'Calling'; // 🔴 Use fixed channel name

      // 🔴 Create call data with "ringing" status
      final callData = {
        'callId': callId,
        'callerId': callerId,
        'callerName': callerName,
        'receiverId': receiverId,
        'receiverName': receiverName,
        'callType': callType == CallType.voice ? 'voice' : 'video',
        'status': 'ringing', // 🔴 IMPORTANT: Changed from "pending" to "ringing"
        'agoraChannelId': agoraChannelId,
        'createdAt': DateTime.now().toIso8601String(),
        'timestamp': FieldValue.serverTimestamp(),
        'callInitiatorRole': userRole,
        'durationSeconds': 0,
        'startedAt': null,
        'endedAt': null,
      };

      // Save call to Firestore
      await _firestore.collection(_callsCollection).doc(callId).set(callData);

      print('✓ Call initiated: $callId');
      print('✓ Caller: $callerId → Receiver: $receiverId');
      print('✓ Status: ringing');

      return callId;
    } catch (e) {
      print('✗ Error initiating call: $e');
      return null;
    }
  }
  /// Accept incoming call
  Future<bool> acceptCall(String callId) async {
    try {
      await _firestore.collection(_callsCollection).doc(callId).update({
        'status': 'accepted',
        'startedAt': DateTime.now(),
      });
      print('✓ Call accepted: $callId');
      return true;
    } catch (e) {
      print('✗ Error accepting call: $e');
      return false;
    }
  }

  /// Reject/Decline incoming call
  Future<bool> rejectCall(String callId) async {
    try {
      await _firestore.collection(_callsCollection).doc(callId).update({
        'status': 'rejected',
        'endedAt': DateTime.now(),
      });
      print('✓ Call rejected: $callId');
      return true;
    } catch (e) {
      print('✗ Error rejecting call: $e');
      return false;
    }
  }

  /// End call and save to history
  Future<bool> endCall({
    required String callId,
    required int durationSeconds,
    required bool wasMissed,
  }) async {
    try {
      final callRef = _firestore.collection(_callsCollection).doc(callId);
      final callDoc = await callRef.get();

      if (!callDoc.exists) {
        print('✗ Call document not found: $callId');
        return false;
      }

      final callData = CallModel.fromFirestore(
        callDoc.data() as Map<String, dynamic>,
      );

      // Update call status
      await callRef.update({
        'status': wasMissed ? 'missed' : 'ended',
        'endedAt': DateTime.now(),
        'durationSeconds': durationSeconds,
      });

      // Save to call history
      await _saveToCallHistory(
        callModel: callData,
        durationSeconds: durationSeconds,
        wasMissed: wasMissed,
      );

      // Save call metrics
      await _saveCallMetrics(
        callId: callId,
        durationSeconds: durationSeconds,
      );

      print('✓ Call ended: $callId (${durationSeconds}s)');
      return true;
    } catch (e) {
      print('✗ Error ending call: $e');
      return false;
    }
  }

  /// Cancel call (caller cancels before answer)
  Future<bool> cancelCall(String callId) async {
    try {
      await _firestore.collection(_callsCollection).doc(callId).update({
        'status': 'cancelled',
        'endedAt': DateTime.now(),
      });
      print('✓ Call cancelled: $callId');
      return true;
    } catch (e) {
      print('✗ Error cancelling call: $e');
      return false;
    }
  }

  /// ================================================
  /// REAL-TIME LISTENERS
  /// ================================================

  /// Listen for incoming calls for a specific user
  // Stream<List<CallModel>> getIncomingCallsStream(String userId) {
  //   return _firestore
  //       .collection(_callsCollection)
  //       .where('receiverId', isEqualTo: userId)
  //       .where('status', isEqualTo: 'pending')
  //       .snapshots()
  //       .map((snapshot) {
  //     return snapshot.docs
  //         .map((doc) => CallModel.fromFirestore(
  //       doc.data() as Map<String, dynamic>,
  //     ))
  //         .toList();
  //   });
  // }

  Stream<CallStatus?> watchCallEndStatus(String callId) {
    return _firestore
        .collection(_callsCollection)
        .doc(callId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;

      final data = snapshot.data() as Map<String, dynamic>;
      final status = data['status'] as String?;

      // Return status if call has ended
      if (status == 'ended' || status == 'rejected' || status == 'cancelled' || status == 'missed') {
        return _parseCallStatus(status);
      }

      return null;
    });
  }

  CallStatus _parseCallStatus(String? status) {
    switch (status) {
      case 'pending':
        return CallStatus.pending;
      case 'ringing':
        return CallStatus.pending;
      case 'accepted':
        return CallStatus.accepted;
      case 'rejected':
        return CallStatus.rejected;
      case 'ended':
        return CallStatus.ended;
      case 'cancelled':
        return CallStatus.cancelled;
      case 'missed':
        return CallStatus.missed;
      default:
        return CallStatus.pending;
    }
  }

  Stream<List<CallModel>> getIncomingCallsStream(String userId) {
    print('👂 [FIREBASE] Listening for calls where receiverId == $userId');

    return _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: userId)
        .where('status', whereIn: ['ringing'])
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      print('📞 [FIREBASE] Found ${snapshot.docs.length} incoming calls');

      if (snapshot.docs.isNotEmpty) {
        for (var doc in snapshot.docs) {
          print('📞 [FIREBASE] Call data: ${doc.data()}');
        }
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return CallModel(
          callId: data['callId'] ?? '',
          callerId: data['callerId'] ?? '',
          callerName: data['callerName'] ?? 'Unknown',
          receiverId: data['receiverId'] ?? '',
          receiverName: data['receiverName'] ?? 'Unknown',
          callType: data['callType'] == 'voice' ? CallType.voice : CallType.video,
          status: CallStatus.pending,
          createdAt: DateTime.parse(data['createdAt'] ?? DateTime.now().toIso8601String()),
          agoraChannelId: data['agoraChannelId'] ?? 'Calling',
        );
      }).toList();
    });
  }

  /// Listen to a specific call for status updates
  Stream<CallModel?> watchCall(String callId) {
    return _firestore
        .collection(_callsCollection)
        .doc(callId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return CallModel.fromFirestore(
        snapshot.data() as Map<String, dynamic>,
      );
    });
  }

  /// Get all active calls (pending or accepted)
  Stream<List<CallModel>> getActiveCallsStream() {
    return _firestore
        .collection(_callsCollection)
        .where('status', whereIn: ['pending', 'accepted'])
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CallModel.fromFirestore(
        doc.data() as Map<String, dynamic>,
      ))
          .toList();
    });
  }

  /// ================================================
  /// CALL HISTORY
  /// ================================================

  /// Save call to history after it ends
  Future<void> _saveToCallHistory({
    required CallModel callModel,
    required int durationSeconds,
    required bool wasMissed,
  }) async {
    try {
      final historyId = const Uuid().v4();

      final historyData = CallHistoryModel(
        id: historyId,
        callerId: callModel.callerId,
        callerName: callModel.callerName,
        receiverId: callModel.receiverId,
        receiverName: callModel.receiverName,
        callType: callModel.callType,
        callTime: callModel.createdAt,
        durationSeconds: durationSeconds,
        missedCall: wasMissed,
      );

      await _firestore
          .collection(_callHistoryCollection)
          .doc(historyId)
          .set(historyData.toFirestore());

      print('✓ Call saved to history: $historyId');
    } catch (e) {
      print('✗ Error saving to history: $e');
    }
  }

  /// Get call history for a user
  Future<List<CallHistoryModel>> getCallHistory({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_callHistoryCollection)
          .where('callerId', isEqualTo: userId)
          .orderBy('callTime', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => CallHistoryModel.fromFirestore(
        doc.data() as Map<String, dynamic>,
      ))
          .toList();
    } catch (e) {
      print('✗ Error fetching call history: $e');
      return [];
    }
  }

  /// Get missed calls for a user
  Future<List<CallHistoryModel>> getMissedCalls({
    required String userId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_callHistoryCollection)
          .where('receiverId', isEqualTo: userId)
          .where('missedCall', isEqualTo: true)
          .orderBy('callTime', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => CallHistoryModel.fromFirestore(
        doc.data() as Map<String, dynamic>,
      ))
          .toList();
    } catch (e) {
      print('✗ Error fetching missed calls: $e');
      return [];
    }
  }

  /// Stream of call history for real-time updates
  Stream<List<CallHistoryModel>> getCallHistoryStream({
    required String userId,
    int limit = 50,
  }) {
    return _firestore
        .collection(_callHistoryCollection)
        .where('callerId', isEqualTo: userId)
        .orderBy('callTime', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CallHistoryModel.fromFirestore(
        doc.data() as Map<String, dynamic>,
      ))
          .toList();
    });
  }

  /// Get call statistics for dashboard
  Future<Map<String, dynamic>> getCallStats({
    required String userId,
  }) async {
    try {
      final history = await getCallHistory(userId: userId, limit: 1000);

      int totalCalls = history.length;
      int missedCalls = history.where((h) => h.missedCall).length;
      int totalDuration =
      history.fold(0, (sum, h) => sum + h.durationSeconds);
      int avgDuration =
      totalCalls > 0 ? totalDuration ~/ totalCalls : 0;

      final lastCall = history.isNotEmpty ? history.first : null;

      return {
        'totalCalls': totalCalls,
        'missedCalls': missedCalls,
        'totalDuration': totalDuration,
        'averageDuration': avgDuration,
        'lastCallTime': lastCall?.callTime,
      };
    } catch (e) {
      print('✗ Error fetching call stats: $e');
      return {
        'totalCalls': 0,
        'missedCalls': 0,
        'totalDuration': 0,
        'averageDuration': 0,
        'lastCallTime': null,
      };
    }
  }

  /// ================================================
  /// CALL METRICS
  /// ================================================

  /// Save call quality metrics
  Future<void> _saveCallMetrics({
    required String callId,
    required int durationSeconds,
  }) async {
    try {
      await _firestore.collection(_callMetricsCollection).doc(callId).set({
        'callId': callId,
        'durationSeconds': durationSeconds,
        'timestamp': DateTime.now(),
        'platform': 'agora',
      });
    } catch (e) {
      print('✗ Error saving metrics: $e');
    }
  }

  /// Delete old call records (cleanup)
  Future<void> deleteOldCalls({ int daysOld = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));

      final snapshot = await _firestore
          .collection(_callsCollection)
          .where('endedAt', isLessThan: cutoffDate)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      print('✓ Deleted ${snapshot.docs.length} old call records');
    } catch (e) {
      print('✗ Error deleting old calls: $e');
    }
  }

  /// Get call status by ID
  Future<CallStatus?> getCallStatus(String callId) async {
    try {
      final doc = await _firestore.collection(_callsCollection).doc(callId).get();

      if (!doc.exists) return null;

      final callModel = CallModel.fromFirestore(
        doc.data() as Map<String, dynamic>,
      );

      return callModel.status;
    } catch (e) {
      print('✗ Error getting call status: $e');
      return null;
    }
  }

  /// Check if a user is currently in a call
  Future<bool> isUserInCall(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_callsCollection)
          .where('status', whereIn: ['pending', 'accepted'])
          .where('callerId', isEqualTo: userId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('✗ Error checking call status: $e');
      return false;
    }
  }
}