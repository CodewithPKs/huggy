// File: lib/services/advanced_chat_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class AdvancedChatService {
  static final AdvancedChatService _instance = AdvancedChatService._internal();

  factory AdvancedChatService() {
    return _instance;
  }

  AdvancedChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Collection paths
  static const String _conversationsPath = 'conversations';
  static const String _messagesPath = 'messages';
  static const String _usersPath = 'users';

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
      final conversationId = _generateConversationId(userId);
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
          'adminId': null,
          'adminName': null,
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

      await _firestore
          .collection(_conversationsPath)
          .doc(conversationId)
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
      await _firestore.collection(_conversationsPath).doc(conversationId).update({
        'lastMessage': messageText,
        'lastMessageTime': DateTime.now(),
      });

      print('✓ Message sent: $messageId');
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
      final uploadPath = 'conversations/$conversationId/images/$uniqueFileName';

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
          .doc(conversationId)
          .collection(_messagesPath)
          .doc(messageId)
          .set({
        'messageId': messageId,
        'senderId': userId,
        'senderName': userName,
        'role': role.toString().split('.').last,
        'type': 'image',
        'imageUrl': imageUrl,
        'fileName': fileName,
        'filePath': uploadPath,
        'fileSize': file.lengthSync(),
        'timestamp': DateTime.now(),
        'isRead': false,
        'replyTo': null,
        'reactions': {},
      });

      await _firestore.collection(_conversationsPath).doc(conversationId).update({
        'lastMessage': '📷 Image',
        'lastMessageTime': DateTime.now(),
      });

      print('✓ Image message sent: $imageUrl');
      return true;
    } catch (e) {
      print('Error sending image: $e');
      rethrow;
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
      final uploadPath = 'conversations/$conversationId/documents/$uniqueFileName';

      final uploadTask = _storage.ref().child(uploadPath).putFile(file);
      final snapshot = await uploadTask;
      final docUrl = await snapshot.ref.getDownloadURL();

      final messageId = const Uuid().v4();

      await _firestore
          .collection(_conversationsPath)
          .doc(conversationId)
          .collection(_messagesPath)
          .doc(messageId)
          .set({
        'messageId': messageId,
        'senderId': userId,
        'senderName': userName,
        'role': role.toString().split('.').last,
        'type': 'document',
        'documentUrl': docUrl,
        'fileName': fileName,
        'filePath': uploadPath,
        'fileSize': file.lengthSync(),
        'timestamp': DateTime.now(),
        'isRead': false,
        'replyTo': null,
        'reactions': {},
      });

      await _firestore.collection(_conversationsPath).doc(conversationId).update({
        'lastMessage': '📄 $fileName',
        'lastMessageTime': DateTime.now(),
      });

      print('✓ Document message sent');
      return true;
    } catch (e) {
      print('Error sending document: $e');
      rethrow;
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
      if (conversationId.isEmpty || replyToMessageId.isEmpty) {
        throw Exception('Invalid reply parameters');
      }

      // Verify the original message exists
      final originalMessage = await _firestore
          .collection(_conversationsPath)
          .doc(conversationId)
          .collection(_messagesPath)
          .doc(replyToMessageId)
          .get();

      if (!originalMessage.exists) {
        throw Exception('Original message not found');
      }

      final messageId = const Uuid().v4();
      final replyData = originalMessage.data() as Map<String, dynamic>;

      await _firestore
          .collection(_conversationsPath)
          .doc(conversationId)
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
          'senderName': replyData['senderName'],
          'message': replyData['message'] ?? (replyData['type'] == 'image' ? '📷 Image' : '📄 Document'),
        },
        'reactions': {},
      });

      print('✓ Reply sent to message: $replyToMessageId');
      return true;
    } catch (e) {
      print('Error replying to message: $e');
      return false;
    }
  }

  /// Mark message as read
  Future<bool> markMessageAsRead({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      if (conversationId.isEmpty || messageId.isEmpty) {
        throw Exception(errorInvalidUser);
      }

      await _firestore
          .collection(_conversationsPath)
          .doc(conversationId)
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

  /// Mark all messages as read for a conversation
  Future<bool> markAllMessagesAsRead({
    required String conversationId,
  }) async {
    try {
      if (conversationId.isEmpty) {
        throw Exception(errorConversationNotFound);
      }

      final snapshot = await _firestore
          .collection(_conversationsPath)
          .doc(conversationId)
          .collection(_messagesPath)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.update({'isRead': true});
      }

      print('✓ All messages marked as read for conversation: $conversationId');
      return true;
    } catch (e) {
      print('Error marking all messages as read: $e');
      return false;
    }
  }

  /// Get messages stream for a conversation
  Stream<QuerySnapshot> getMessagesStream({
    required String conversationId,
  }) {
    if (conversationId.isEmpty) {
      throw Exception(errorConversationNotFound);
    }

    return _firestore
        .collection(_conversationsPath)
        .doc(conversationId)
        .collection(_messagesPath)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Delete a message
  Future<bool> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      if (conversationId.isEmpty || messageId.isEmpty) {
        throw Exception(errorInvalidUser);
      }

      final messageDoc = await _firestore
          .collection(_conversationsPath)
          .doc(conversationId)
          .collection(_messagesPath)
          .doc(messageId)
          .get();

      if (!messageDoc.exists) {
        throw Exception('Message not found');
      }

      final data = messageDoc.data() as Map<String, dynamic>;
      final type = data['type'];
      final filePath = data['filePath'];

      // Delete from storage if it's a media file
      if (filePath != null && (type == 'image' || type == 'document')) {
        try {
          await _storage.ref().child(filePath).delete();
        } catch (e) {
          print('Warning: Could not delete file from storage: $e');
        }
      }

      // Delete from Firestore
      await messageDoc.reference.delete();
      print('✓ Message deleted: $messageId');
      return true;
    } catch (e) {
      print('Error deleting message: $e');
      return false;
    }
  }

  /// Edit a message
  Future<bool> editMessage({
    required String conversationId,
    required String messageId,
    required String newMessage,
  }) async {
    try {
      if (conversationId.isEmpty || messageId.isEmpty) {
        throw Exception(errorInvalidUser);
      }

      await _firestore
          .collection(_conversationsPath)
          .doc(conversationId)
          .collection(_messagesPath)
          .doc(messageId)
          .update({
        'message': newMessage,
        'editedAt': DateTime.now(),
      });

      print('✓ Message edited: $messageId');
      return true;
    } catch (e) {
      print('Error editing message: $e');
      return false;
    }
  }

  /// Add reaction to message
  Future<bool> addReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    try {
      if (conversationId.isEmpty || messageId.isEmpty) {
        throw Exception(errorInvalidUser);
      }

      final messageRef = _firestore
          .collection(_conversationsPath)
          .doc(conversationId)
          .collection(_messagesPath)
          .doc(messageId);

      await messageRef.update({
        'reactions.$emoji': FieldValue.increment(1),
      });

      print('✓ Reaction added: $emoji');
      return true;
    } catch (e) {
      print('Error adding reaction: $e');
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

      final snapshot = await _firestore
          .collection(_conversationsPath)
          .doc(conversationId)
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

      await _firestore
          .collection(_conversationsPath)
          .doc(conversationId)
          .update({'status': status});

      print('✓ Conversation status updated to: $status');
      return true;
    } catch (e) {
      print('Error updating conversation status: $e');
      return false;
    }
  }

  /// Assign admin to conversation
  Future<bool> assignAdminToConversation({
    required String conversationId,
    required String adminId,
    required String adminName,
  }) async {
    try {
      if (conversationId.isEmpty || adminId.isEmpty) {
        throw Exception(errorInvalidUser);
      }

      await _firestore
          .collection(_conversationsPath)
          .doc(conversationId)
          .update({
        'adminId': adminId,
        'adminName': adminName,
        'status': 'active',
        'assignedAt': DateTime.now(),
      });

      print('✓ Admin assigned to conversation: $conversationId');
      return true;
    } catch (e) {
      print('Error assigning admin: $e');
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

      final snapshot = await _firestore
          .collection(_conversationsPath)
          .doc(conversationId)
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

  /// Generate conversation ID
  String _generateConversationId(String userId) {
    return 'conv_${userId}_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Get unread count for conversation
  Future<int> getUnreadCount({required String conversationId}) async {
    try {
      if (conversationId.isEmpty) {
        throw Exception(errorConversationNotFound);
      }

      final snapshot = await _firestore
          .collection(_conversationsPath)
          .doc(conversationId)
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