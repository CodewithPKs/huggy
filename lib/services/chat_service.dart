// File: lib/services/chat_service.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();

  factory ChatService() {
    return _instance;
  }

  ChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Create or get a chat room
  Future<String> createOrGetChatRoom(String userId, String otherUserId) async {
    try {
      final chatRoomId = _generateChatRoomId(userId, otherUserId);
      final doc = await _firestore.collection('chatRooms').doc(chatRoomId).get();

      if (!doc.exists) {
        await _firestore.collection('chatRooms').doc(chatRoomId).set({
          'participants': [userId, otherUserId],
          'createdAt': DateTime.now(),
          'lastMessage': '',
          'lastMessageTime': DateTime.now(),
        });
      }
      return chatRoomId;
    } catch (e) {
      print('Error creating chat room: $e');
      rethrow;
    }
  }

  /// Send a text message
  Future<bool> sendMessage({
    required String chatRoomId,
    required String userId,
    required String messageText,
  }) async {
    try {
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .add({
        'senderId': userId,
        'message': messageText,
        'timestamp': DateTime.now(),
        'type': 'text',
        'isRead': false,
      });

      // Update last message in chat room
      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'lastMessage': messageText,
        'lastMessageTime': DateTime.now(),
      });

      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  /// Send image message
  Future<bool> sendImageMessage({
    required String chatRoomId,
    required String userId,
    required String imagePath,
    required String fileName,
  }) async {
    try {
      final uploadTask = _storage
          .ref()
          .child('chat_images/${const Uuid().v4()}_$fileName')
          .putFile(imagePath as File);

      final snapshot = await uploadTask;
      final imageUrl = await snapshot.ref.getDownloadURL();

      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .add({
        'senderId': userId,
        'imageUrl': imageUrl,
        'timestamp': DateTime.now(),
        'type': 'image',
        'fileName': fileName,
        'isRead': false,
      });

      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'lastMessage': '📷 Image',
        'lastMessageTime': DateTime.now(),
      });

      return true;
    } catch (e) {
      print('Error sending image: $e');
      return false;
    }
  }

  /// Send location message
  Future<bool> sendLocationMessage({
    required String chatRoomId,
    required String userId,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    try {
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .add({
        'senderId': userId,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'timestamp': DateTime.now(),
        'type': 'location',
        'isRead': false,
      });

      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'lastMessage': '📍 Location',
        'lastMessageTime': DateTime.now(),
      });

      return true;
    } catch (e) {
      print('Error sending location: $e');
      return false;
    }
  }

  /// Get messages stream
  Stream<QuerySnapshot> getMessagesStream(String chatRoomId) {
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Mark message as read
  Future<void> markMessageAsRead(
      String chatRoomId,
      String messageId,
      ) async {
    try {
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  /// Delete message
  Future<bool> deleteMessage(
      String chatRoomId,
      String messageId,
      ) async {
    try {
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .delete();
      return true;
    } catch (e) {
      print('Error deleting message: $e');
      return false;
    }
  }

  /// Get unread message count
  Future<int> getUnreadCount(String chatRoomId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .where('senderId', isNotEqualTo: userId)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  /// Generate chat room ID
  String _generateChatRoomId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }
}