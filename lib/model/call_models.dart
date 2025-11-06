// File: lib/models/call_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Call types - Voice or Video
enum CallType { voice, video }

/// Call status during lifecycle
enum CallStatus {
  pending,     // Waiting for recipient to answer
  accepted,    // Call accepted
  rejected,    // Call declined
  missed,      // Call not answered
  ended,       // Call completed
  cancelled    // Caller cancelled
}

/// User role in the app
enum UserRole { user, admin }

/// ============================================
/// VOICE & VIDEO CALL MODEL
/// ============================================
class CallModel {
  final String callId;
  final String callerId;
  final String callerName;
  final String receiverId;
  final String receiverName;
  final CallType callType;
  final CallStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final String agoraChannelId;
  final String? callInitiatorRole; // 'user' or 'admin'

  CallModel({
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.receiverId,
    required this.receiverName,
    required this.callType,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    this.durationSeconds = 0,
    required this.agoraChannelId,
    this.callInitiatorRole,
  });

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'callId': callId,
      'callerId': callerId,
      'callerName': callerName,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'callType': callType.toString().split('.').last,
      'status': status.toString().split('.').last,
      'createdAt': createdAt,
      'startedAt': startedAt,
      'endedAt': endedAt,
      'durationSeconds': durationSeconds,
      'agoraChannelId': agoraChannelId,
      'callInitiatorRole': callInitiatorRole,
    };
  }

  /// Create from Firestore document
  factory CallModel.fromFirestore(Map<String, dynamic> data) {
    return CallModel(
      callId: data['callId'] ?? '',
      callerId: data['callerId'] ?? '',
      callerName: data['callerName'] ?? 'Unknown',
      receiverId: data['receiverId'] ?? '',
      receiverName: data['receiverName'] ?? 'Unknown',
      callType: (data['callType'] ?? 'voice') == 'video'
          ? CallType.video
          : CallType.voice,
      status: _parseCallStatus(data['status']),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      startedAt: data['startedAt'] != null
          ? (data['startedAt'] as Timestamp).toDate()
          : null,
      endedAt: data['endedAt'] != null
          ? (data['endedAt'] as Timestamp).toDate()
          : null,
      durationSeconds: data['durationSeconds'] ?? 0,
      agoraChannelId: data['agoraChannelId'] ?? '',
      callInitiatorRole: data['callInitiatorRole'],
    );
  }

  /// Copy with modifications
  CallModel copyWith({
    String? callId,
    String? callerId,
    String? callerName,
    String? receiverId,
    String? receiverName,
    CallType? callType,
    CallStatus? status,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
    String? agoraChannelId,
    String? callInitiatorRole,
  }) {
    return CallModel(
      callId: callId ?? this.callId,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      agoraChannelId: agoraChannelId ?? this.agoraChannelId,
      callInitiatorRole: callInitiatorRole ?? this.callInitiatorRole,
    );
  }

  @override
  String toString() {
    return 'CallModel(id: $callId, from: $callerName, to: $receiverName, type: ${callType.toString()}, status: ${status.toString()})';
  }
}

/// ============================================
/// CALL HISTORY MODEL
/// ============================================
class CallHistoryModel {
  final String id;
  final String callerId;
  final String callerName;
  final String receiverId;
  final String receiverName;
  final CallType callType;
  final DateTime callTime;
  final int durationSeconds;
  final bool missedCall;
  final String? notes;

  CallHistoryModel({
    required this.id,
    required this.callerId,
    required this.callerName,
    required this.receiverId,
    required this.receiverName,
    required this.callType,
    required this.callTime,
    required this.durationSeconds,
    this.missedCall = false,
    this.notes,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'callerId': callerId,
      'callerName': callerName,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'callType': callType.toString().split('.').last,
      'callTime': callTime,
      'durationSeconds': durationSeconds,
      'missedCall': missedCall,
      'notes': notes,
    };
  }

  factory CallHistoryModel.fromFirestore(Map<String, dynamic> data) {
    return CallHistoryModel(
      id: data['id'] ?? '',
      callerId: data['callerId'] ?? '',
      callerName: data['callerName'] ?? 'Unknown',
      receiverId: data['receiverId'] ?? '',
      receiverName: data['receiverName'] ?? 'Unknown',
      callType: (data['callType'] ?? 'voice') == 'video'
          ? CallType.video
          : CallType.voice,
      callTime: (data['callTime'] as Timestamp).toDate(),
      durationSeconds: data['durationSeconds'] ?? 0,
      missedCall: data['missedCall'] ?? false,
      notes: data['notes'],
    );
  }

  String get formattedDuration {
    int minutes = durationSeconds ~/ 60;
    int seconds = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  String toString() {
    return 'CallHistory(from: $callerName, to: $receiverName, duration: ${formattedDuration}s, missed: $missedCall)';
  }
}

/// ============================================
/// HELPER FUNCTIONS
/// ============================================
CallStatus _parseCallStatus(String? status) {
  switch (status) {
    case 'pending':
      return CallStatus.pending;
    case 'accepted':
      return CallStatus.accepted;
    case 'rejected':
      return CallStatus.rejected;
    case 'missed':
      return CallStatus.missed;
    case 'ended':
      return CallStatus.ended;
    case 'cancelled':
      return CallStatus.cancelled;
    default:
      return CallStatus.pending;
  }
}

extension CallStatusExtension on CallStatus {
  String get displayName {
    switch (this) {
      case CallStatus.pending:
        return 'Ringing...';
      case CallStatus.accepted:
        return 'In Call';
      case CallStatus.rejected:
        return 'Declined';
      case CallStatus.missed:
        return 'Missed';
      case CallStatus.ended:
        return 'Ended';
      case CallStatus.cancelled:
        return 'Cancelled';
    }
  }
}

extension CallTypeExtension on CallType {
  String get displayName {
    return this == CallType.voice ? 'Voice Call' : 'Video Call';
  }

  IconData get icon {
    return this == CallType.voice ? Icons.call : Icons.videocam;
  }
}

