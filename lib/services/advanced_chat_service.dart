// File: lib/services/advanced_chat_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import 'fcm_notification_service.dart';

class AdvancedChatService {
  static final AdvancedChatService _instance = AdvancedChatService._internal();

  factory AdvancedChatService() {
    return _instance;
  }

  AdvancedChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'huggy');
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FCMNotificationService _fcmService = FCMNotificationService();

  // Collection paths
  static const String _conversationsPath = 'conversations';
  static const String _messagesPath = 'messages';
  static const String _usersPath = 'users';

  // Fixed conversation ID for single-person app (Praveen <-> Admin chat)
  static const String PERSONAL_CHAT_ID = 'personal_chat_001';

  // Error messages
  static const String errorFailedToSend = 'Failed to send message';
  static const String errorFailedToUpdate = 'Failed to update message';
  static const String errorFailedToDelete = 'Failed to delete message';
  static const String errorFailedToMarkRead = 'Failed to mark message as read';
  static const String errorInvalidUser = 'Invalid user information';
  static const String errorConversationNotFound = 'Conversation not found';

  /// Create or get a conversation between user and admin
  Future<String?> createOrGetConversation({
    required String userId,
    required String userName,
    required String userEmail,
  }) async {
    try {
      // Use fixed conversation ID for single-person app
      final conversationId = PERSONAL_CHAT_ID;
      final docRef = _firestore.collection(_conversationsPath).doc(conversationId);
      final doc = await docRef.get();

      if (!doc.exists) {
        await docRef.set({
          'conversationId': conversationId,
          'userId': userId,
          'userName': userName,
          'userEmail': userEmail,
          'status': 'active', // active, closed, pending
          'createdAt': DateTime.now(),
          'lastMessageTime': DateTime.now(),
          'lastMessage': '',
          'unreadCount': 0,
          'adminId': 'admin_001',
          'adminName': 'Admin',
        });
        print('✓ Conversation created: $conversationId');
      }
      return conversationId;
    } catch (e) {
      print('Error creating conversation: $e');
      rethrow;
    }
  }

  /// Send a message
  Future<bool> sendMessage({
    required String conversationId,
    required String userId,
    required String userName,
    required String messageText,
    required UserRole role,
  }) async {
    try {
      if (conversationId.isEmpty || userId.isEmpty || messageText.isEmpty) {
        throw Exception(errorInvalidUser);
      }

      final messageId = const Uuid().v4();

      // Ensure we're using the personal chat ID
      final chatId = conversationId.isEmpty ? PERSONAL_CHAT_ID : conversationId;

      await _firestore
          .collection(_conversationsPath)
          .doc(chatId)
          .collection(_messagesPath)
          .doc(messageId)
          .set({
        'messageId': messageId,
        'senderId': userId,
        'senderName': userName,
        'role': role.toString().split('.').last,
        'message': messageText,
        'type': 'text',
        'timestamp': DateTime.now(),
        'isRead': false,
        'replyTo': null,
        'reactions': {},
      });

      // Update conversation last message
      await _firestore.collection(_conversationsPath).doc(chatId).update({
        'lastMessage': messageText,
        'lastMessageTime': DateTime.now(),
      });

      if (role == UserRole.admin) {
        // Admin sends message → Fixed "EDUCATIONAL" content to user
        await _fcmService.sendAdminToUserNotification();
        print('✓ Educational notification sent to user');
      } else if (role == UserRole.user) {
        // User sends message → Trigger FCM to admin with message content
        await _fcmService.sendUserToAdminNotification(
          messageText: messageText,
          userName: userName,
        );
        print('✓ Message notification sent to admin');
      }

      print('✓ Message sent: $messageId in conversation: $chatId');
      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  /// Send image message
  Future<bool> sendImageMessage({
    required String conversationId,
    required String userId,
    required String userName,
    required String imagePath,
    required String fileName,
    required UserRole role,
  }) async {
    try {
      if (conversationId.isEmpty) {
        throw Exception(errorConversationNotFound);
      }

      final file = File(imagePath);
      final uniqueFileName = '${const Uuid().v4()}_$fileName';
      final chatId = conversationId.isEmpty ? PERSONAL_CHAT_ID : conversationId;
      final uploadPath = 'conversations/$chatId/images/$uniqueFileName';

      // Upload to Firebase Storage with error handling
      final uploadTask = _storage.ref().child(uploadPath).putFile(file);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        print('Upload progress: ${(snapshot.bytesTransferred / snapshot.totalBytes) * 100}%');
      });

      final snapshot = await uploadTask;
      final imageUrl = await snapshot.ref.getDownloadURL();

      final messageId = const Uuid().v4();

      await _firestore
          .collection(_conversationsPath)
          .doc(chatId)
          .collection(_messagesPath)
          .doc(messageId)
          .set({
        'messageId': messageId,
        'senderId': userId,
        'senderName': userName,
        'role': role.toString().split('.').last,
        'message': '[Image]',
        'type': 'image',
        'imageUrl': imageUrl,
        'fileName': fileName,
        'timestamp': DateTime.now(),
        'isRead': false,
        'replyTo': null,
      });

      // Update conversation last message
      await _firestore.collection(_conversationsPath).doc(chatId).update({
        'lastMessage': '📷 Image',
        'lastMessageTime': DateTime.now(),
      });

      if (role == UserRole.admin) {
        await _fcmService.sendAdminToUserNotification();
      } else if (role == UserRole.user) {
        await _fcmService.sendUserToAdminNotification(
          messageText: '📷 Sent an image',
          userName: userName,
        );
      }

      print('✓ Image message sent: $messageId');
      return true;
    } catch (e) {
      print('Error sending image: $e');
      return false;
    }
  }

  /// Send document message
  Future<bool> sendDocumentMessage({
    required String conversationId,
    required String userId,
    required String userName,
    required String docPath,
    required String fileName,
    required UserRole role,
  }) async {
    try {
      if (conversationId.isEmpty) {
        throw Exception(errorConversationNotFound);
      }

      final file = File(docPath);
      final uniqueFileName = '${const Uuid().v4()}_$fileName';
      final chatId = conversationId.isEmpty ? PERSONAL_CHAT_ID : conversationId;
      final uploadPath = 'conversations/$chatId/documents/$uniqueFileName';

      final uploadTask = _storage.ref().child(uploadPath).putFile(file);
      final snapshot = await uploadTask;
      final docUrl = await snapshot.ref.getDownloadURL();

      final messageId = const Uuid().v4();

      await _firestore
          .collection(_conversationsPath)
          .doc(chatId)
          .collection(_messagesPath)
          .doc(messageId)
          .set({
        'messageId': messageId,
        'senderId': userId,
        'senderName': userName,
        'role': role.toString().split('.').last,
        'message': '[Document]',
        'type': 'document',
        'docUrl': docUrl,
        'fileName': fileName,
        'timestamp': DateTime.now(),
        'isRead': false,
        'replyTo': null,
      });

      // Update conversation
      await _firestore.collection(_conversationsPath).doc(chatId).update({
        'lastMessage': '📎 Document: $fileName',
        'lastMessageTime': DateTime.now(),
      });

      if (role == UserRole.admin) {
        await _fcmService.sendAdminToUserNotification();
      } else if (role == UserRole.user) {
        await _fcmService.sendUserToAdminNotification(
          messageText: '🎥 Sent a video',
          userName: userName,
        );
      }

      print('✓ Document sent: $messageId');
      return true;
    } catch (e) {
      print('Error sending document: $e');
      return false;
    }
  }

  /// Reply to a message
  Future<bool> replyToMessage({
    required String conversationId,
    required String userId,
    required String userName,
    required String messageText,
    required String replyToMessageId,
    required UserRole role,
  }) async {
    try {
      if (conversationId.isEmpty || userId.isEmpty || messageText.isEmpty) {
        throw Exception(errorInvalidUser);
      }

      final chatId = conversationId.isEmpty ? PERSONAL_CHAT_ID : conversationId;

      // Get the original message being replied to
      final replyToDoc = await _firestore
          .collection(_conversationsPath)
          .doc(chatId)
          .collection(_messagesPath)
          .doc(replyToMessageId)
          .get();

      if (!replyToDoc.exists) {
        throw Exception('Original message not found');
      }

      final replyToData = replyToDoc.data();
      final messageId = const Uuid().v4();

      await _firestore
          .collection(_conversationsPath)
          .doc(chatId)
          .collection(_messagesPath)
          .doc(messageId)
          .set({
        'messageId': messageId,
        'senderId': userId,
        'senderName': userName,
        'role': role.toString().split('.').last,
        'message': messageText,
        'type': 'text',
        'timestamp': DateTime.now(),
        'isRead': false,
        'replyTo': {
          'messageId': replyToMessageId,
          'message': replyToData?['message'] ?? '',
          'senderName': replyToData?['senderName'] ?? 'Unknown',
          'senderId': replyToData?['senderId'] ?? '',
        },
      });

      // Update conversation
      await _firestore.collection(_conversationsPath).doc(chatId).update({
        'lastMessage': messageText,
        'lastMessageTime': DateTime.now(),
      });

      if (role == UserRole.admin) {
        await _fcmService.sendAdminToUserNotification();
      } else if (role == UserRole.user) {
        await _fcmService.sendUserToAdminNotification(
          messageText: '🎥 Sent a video',
          userName: userName,
        );
      }

      print('✓ Reply sent: $messageId');
      return true;
    } catch (e) {
      print('Error sending reply: $e');
      return false;
    }
  }

  /// Get messages stream
  Stream<QuerySnapshot> getMessagesStream({
    required String conversationId,
  }) {
    final chatId = conversationId.isEmpty ? PERSONAL_CHAT_ID : conversationId;

    return _firestore
        .collection(_conversationsPath)
        .doc(chatId)
        .collection(_messagesPath)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Mark message as read
  Future<bool> markMessageAsRead({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      if (conversationId.isEmpty || messageId.isEmpty) {
        return false;
      }

      final chatId = conversationId.isEmpty ? PERSONAL_CHAT_ID : conversationId;

      await _firestore
          .collection(_conversationsPath)
          .doc(chatId)
          .collection(_messagesPath)
          .doc(messageId)
          .update({'isRead': true});

      print('✓ Message marked as read: $messageId');
      return true;
    } catch (e) {
      print('Error marking message as read: $e');
      return false;
    }
  }

  /// Mark all messages as read
  Future<bool> markAllMessagesAsRead({
    required String conversationId,
  }) async {
    try {
      if (conversationId.isEmpty) {
        throw Exception(errorConversationNotFound);
      }

      final chatId = conversationId.isEmpty ? PERSONAL_CHAT_ID : conversationId;

      final unreadMessages = await _firestore
          .collection(_conversationsPath)
          .doc(chatId)
          .collection(_messagesPath)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();

      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      print('✓ All messages marked as read');
      return true;
    } catch (e) {
      print('Error marking all messages as read: $e');
      return false;
    }
  }

  /// Delete message
  Future<bool> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      if (conversationId.isEmpty || messageId.isEmpty) {
        throw Exception(errorInvalidUser);
      }

      final chatId = conversationId.isEmpty ? PERSONAL_CHAT_ID : conversationId;

      await _firestore
          .collection(_conversationsPath)
          .doc(chatId)
          .collection(_messagesPath)
          .doc(messageId)
          .delete();

      print('✓ Message deleted: $messageId');
      return true;
    } catch (e) {
      print('Error deleting message: $e');
      return false;
    }
  }

  /// Edit message
  Future<bool> editMessage({
    required String conversationId,
    required String messageId,
    required String newText,
  }) async {
    try {
      if (conversationId.isEmpty || messageId.isEmpty || newText.isEmpty) {
        throw Exception(errorInvalidUser);
      }

      final chatId = conversationId.isEmpty ? PERSONAL_CHAT_ID : conversationId;

      await _firestore
          .collection(_conversationsPath)
          .doc(chatId)
          .collection(_messagesPath)
          .doc(messageId)
          .update({
        'message': newText,
        'isEdited': true,
        'editedAt': DateTime.now(),
      });

      print('✓ Message edited: $messageId');
      return true;
    } catch (e) {
      print('Error editing message: $e');
      return false;
    }
  }

  /// Get conversation statistics
  Future<Map<String, dynamic>> getConversationStats({
    required String conversationId,
  }) async {
    try {
      if (conversationId.isEmpty) {
        throw Exception(errorConversationNotFound);
      }

      final chatId = conversationId.isEmpty ? PERSONAL_CHAT_ID : conversationId;

      final snapshot = await _firestore
          .collection(_conversationsPath)
          .doc(chatId)
          .collection(_messagesPath)
          .get();

      int totalMessages = snapshot.docs.length;
      int unreadMessages = snapshot.docs.where((doc) => doc['isRead'] == false).length;
      int userMessages = snapshot.docs.where((doc) => doc['role'] == 'user').length;
      int adminMessages = snapshot.docs.where((doc) => doc['role'] == 'admin').length;

      return {
        'totalMessages': totalMessages,
        'unreadMessages': unreadMessages,
        'userMessages': userMessages,
        'adminMessages': adminMessages,
      };
    } catch (e) {
      print('Error getting conversation stats: $e');
      return {};
    }
  }

  /// Get all conversations for admin
  Stream<QuerySnapshot> getAdminConversationsStream() {
    return _firestore
        .collection(_conversationsPath)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  /// Update conversation status
  Future<bool> updateConversationStatus({
    required String conversationId,
    required String status, // active, closed, pending
  }) async {
    try {
      if (conversationId.isEmpty) {
        throw Exception(errorConversationNotFound);
      }

      final chatId = conversationId.isEmpty ? PERSONAL_CHAT_ID : conversationId;

      await _firestore
          .collection(_conversationsPath)
          .doc(chatId)
          .update({'status': status});

      print('✓ Conversation status updated to: $status');
      return true;
    } catch (e) {
      print('Error updating conversation status: $e');
      return false;
    }
  }

  /// Search messages in a conversation
  Future<List<DocumentSnapshot>> searchMessages({
    required String conversationId,
    required String query,
  }) async {
    try {
      if (conversationId.isEmpty || query.isEmpty) {
        return [];
      }

      final chatId = conversationId.isEmpty ? PERSONAL_CHAT_ID : conversationId;

      final snapshot = await _firestore
          .collection(_conversationsPath)
          .doc(chatId)
          .collection(_messagesPath)
          .get();

      return snapshot.docs.where((doc) {
        final message = doc['message']?.toString().toLowerCase() ?? '';
        final fileName = doc['fileName']?.toString().toLowerCase() ?? '';
        return message.contains(query.toLowerCase()) ||
            fileName.contains(query.toLowerCase());
      }).toList();
    } catch (e) {
      print('Error searching messages: $e');
      return [];
    }
  }

  /// Get unread count for conversation
  Future<int> getUnreadCount({required String conversationId}) async {
    try {
      if (conversationId.isEmpty) {
        throw Exception(errorConversationNotFound);
      }

      final chatId = conversationId.isEmpty ? PERSONAL_CHAT_ID : conversationId;

      final snapshot = await _firestore
          .collection(_conversationsPath)
          .doc(chatId)
          .collection(_messagesPath)
          .where('isRead', isEqualTo: false)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }
}

enum UserRole { user, admin }