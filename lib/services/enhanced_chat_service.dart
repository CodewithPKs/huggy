// File: lib/services/enhanced_chat_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class EnhancedChatService {
  static final EnhancedChatService _instance = EnhancedChatService._internal();

  factory EnhancedChatService() {
    return _instance;
  }

  EnhancedChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Personal app - single chat room (self-to-self)
  static const String _chatRoomId = 'personal_chat_room';
  static const String _messagesCollectionPath = 'personalMessages';
  static const String _storageFolder = 'personal_chat_media';

  /// Initialize personal chat room (runs once)
  Future<void> initializePersonalChatRoom() async {
    try {
      final docRef = _firestore.collection('personalChats').doc(_chatRoomId);
      final doc = await docRef.get();

      if (!doc.exists) {
        await docRef.set({
          'chatRoomId': _chatRoomId,
          'createdAt': DateTime.now(),
          'lastMessage': '',
          'lastMessageTime': DateTime.now(),
          'messageCount': 0,
        });
        print('✓ Personal chat room initialized');
      }
    } catch (e) {
      print('Error initializing chat room: $e');
    }
  }

  /// Send text message
  Future<bool> sendTextMessage({
    required String messageText,
  }) async {
    try {
      await _firestore
          .collection('personalChats')
          .doc(_chatRoomId)
          .collection(_messagesCollectionPath)
          .add({
        'messageId': const Uuid().v4(),
        'type': 'text',
        'message': messageText,
        'timestamp': DateTime.now(),
        'isRead': false,
      });

      // Update last message
      await _firestore.collection('personalChats').doc(_chatRoomId).update({
        'lastMessage': messageText,
        'lastMessageTime': DateTime.now(),
      });

      print('✓ Text message sent');
      return true;
    } catch (e) {
      print('Error sending text message: $e');
      return false;
    }
  }

  /// Send image message
  Future<bool> sendImageMessage({
    required String imagePath,
    required String fileName,
  }) async {
    try {
      final file = File(imagePath);
      final fileName_unique = '${const Uuid().v4()}_$fileName';
      final uploadPath = '$_storageFolder/images/$fileName_unique';

      // Upload to Firebase Storage
      final uploadTask = _storage.ref().child(uploadPath).putFile(file);
      final snapshot = await uploadTask;
      final imageUrl = await snapshot.ref.getDownloadURL();

      // Save message metadata to Firestore
      await _firestore
          .collection('personalChats')
          .doc(_chatRoomId)
          .collection(_messagesCollectionPath)
          .add({
        'messageId': const Uuid().v4(),
        'type': 'image',
        'imageUrl': imageUrl,
        'fileName': fileName,
        'filePath': uploadPath,
        'fileSize': file.lengthSync(),
        'timestamp': DateTime.now(),
        'isRead': false,
      });

      // Update last message
      await _firestore.collection('personalChats').doc(_chatRoomId).update({
        'lastMessage': '📷 Image',
        'lastMessageTime': DateTime.now(),
      });

      print('✓ Image message sent: $imageUrl');
      return true;
    } catch (e) {
      print('Error sending image: $e');
      return false;
    }
  }

  /// Send video message
  Future<bool> sendVideoMessage({
    required String videoPath,
    required String fileName,
    required Duration duration,
  }) async {
    try {
      final file = File(videoPath);
      final fileName_unique = '${const Uuid().v4()}_$fileName';
      final uploadPath = '$_storageFolder/videos/$fileName_unique';

      // Upload to Firebase Storage
      final uploadTask = _storage.ref().child(uploadPath).putFile(file);
      final snapshot = await uploadTask;
      final videoUrl = await snapshot.ref.getDownloadURL();

      // Save message metadata to Firestore
      await _firestore
          .collection('personalChats')
          .doc(_chatRoomId)
          .collection(_messagesCollectionPath)
          .add({
        'messageId': const Uuid().v4(),
        'type': 'video',
        'videoUrl': videoUrl,
        'fileName': fileName,
        'filePath': uploadPath,
        'fileSize': file.lengthSync(),
        'duration': duration.inSeconds,
        'timestamp': DateTime.now(),
        'isRead': false,
      });

      // Update last message
      await _firestore.collection('personalChats').doc(_chatRoomId).update({
        'lastMessage': '🎥 Video',
        'lastMessageTime': DateTime.now(),
      });

      print('✓ Video message sent: $videoUrl');
      return true;
    } catch (e) {
      print('Error sending video: $e');
      return false;
    }
  }

  /// Send document message
  Future<bool> sendDocumentMessage({
    required String docPath,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      final file = File(docPath);
      final fileName_unique = '${const Uuid().v4()}_$fileName';
      final uploadPath = '$_storageFolder/documents/$fileName_unique';

      // Upload to Firebase Storage
      final uploadTask = _storage.ref().child(uploadPath).putFile(file);
      final snapshot = await uploadTask;
      final docUrl = await snapshot.ref.getDownloadURL();

      // Save message metadata to Firestore
      await _firestore
          .collection('personalChats')
          .doc(_chatRoomId)
          .collection(_messagesCollectionPath)
          .add({
        'messageId': const Uuid().v4(),
        'type': 'document',
        'documentUrl': docUrl,
        'fileName': fileName,
        'filePath': uploadPath,
        'fileSize': file.lengthSync(),
        'mimeType': mimeType,
        'timestamp': DateTime.now(),
        'isRead': false,
      });

      // Update last message
      await _firestore.collection('personalChats').doc(_chatRoomId).update({
        'lastMessage': '📄 ${_getFileIcon(fileName)} $fileName',
        'lastMessageTime': DateTime.now(),
      });

      print('✓ Document message sent: $docUrl');
      return true;
    } catch (e) {
      print('Error sending document: $e');
      return false;
    }
  }

  /// Get messages stream (real-time)
  Stream<QuerySnapshot> getMessagesStream() {
    return _firestore
        .collection('personalChats')
        .doc(_chatRoomId)
        .collection(_messagesCollectionPath)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Mark message as read
  Future<void> markMessageAsRead(String messageId) async {
    try {
      await _firestore
          .collection('personalChats')
          .doc(_chatRoomId)
          .collection(_messagesCollectionPath)
          .where('messageId', isEqualTo: messageId)
          .get()
          .then((snapshot) {
        for (var doc in snapshot.docs) {
          doc.reference.update({'isRead': true});
        }
      });
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  /// Delete message
  Future<bool> deleteMessage(String docId) async {
    try {
      // Get message data first
      final messageDoc = await _firestore
          .collection('personalChats')
          .doc(_chatRoomId)
          .collection(_messagesCollectionPath)
          .doc(docId)
          .get();

      if (messageDoc.exists) {
        final data = messageDoc.data();
        final type = data?['type'];

        // Delete from storage if it's a media file
        if (type == 'image' && data?['filePath'] != null) {
          await _storage.ref().child(data!['filePath']).delete();
        } else if (type == 'video' && data?['filePath'] != null) {
          await _storage.ref().child(data!['filePath']).delete();
        } else if (type == 'document' && data?['filePath'] != null) {
          await _storage.ref().child(data!['filePath']).delete();
        }

        // Delete from Firestore
        await messageDoc.reference.delete();
        print('✓ Message deleted');
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting message: $e');
      return false;
    }
  }

  /// Get unread message count
  Future<int> getUnreadMessageCount() async {
    try {
      final snapshot = await _firestore
          .collection('personalChats')
          .doc(_chatRoomId)
          .collection(_messagesCollectionPath)
          .where('isRead', isEqualTo: false)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  /// Get chat statistics
  Future<Map<String, dynamic>> getChatStats() async {
    try {
      final allMessages = await _firestore
          .collection('personalChats')
          .doc(_chatRoomId)
          .collection(_messagesCollectionPath)
          .get();

      int totalMessages = allMessages.docs.length;
      int textMessages = allMessages.docs.where((doc) => doc['type'] == 'text').length;
      int imageMessages = allMessages.docs.where((doc) => doc['type'] == 'image').length;
      int videoMessages = allMessages.docs.where((doc) => doc['type'] == 'video').length;
      int documentMessages = allMessages.docs.where((doc) => doc['type'] == 'document').length;

      // Calculate total storage used
      int totalStorage = 0;
      for (var doc in allMessages.docs) {
        totalStorage += (doc['fileSize'] ?? 0) as int;
      }

      return {
        'totalMessages': totalMessages,
        'textMessages': textMessages,
        'imageMessages': imageMessages,
        'videoMessages': videoMessages,
        'documentMessages': documentMessages,
        'totalStorageBytes': totalStorage,
        'totalStorageMB': (totalStorage / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      print('Error getting chat stats: $e');
      return {};
    }
  }

  /// Search messages
  Future<List<DocumentSnapshot>> searchMessages(String query) async {
    try {
      final snapshot = await _firestore
          .collection('personalChats')
          .doc(_chatRoomId)
          .collection(_messagesCollectionPath)
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

  /// Clear all messages and media (with confirmation)
  Future<bool> clearAllMessages() async {
    try {
      final messages = await _firestore
          .collection('personalChats')
          .doc(_chatRoomId)
          .collection(_messagesCollectionPath)
          .get();

      // Delete all files from storage
      for (var doc in messages.docs) {
        final data = doc.data();
        if (data['filePath'] != null) {
          await _storage.ref().child(data['filePath']).delete();
        }
      }

      // Delete all documents from Firestore
      for (var doc in messages.docs) {
        await doc.reference.delete();
      }

      // Reset chat room
      await _firestore.collection('personalChats').doc(_chatRoomId).update({
        'lastMessage': '',
        'lastMessageTime': DateTime.now(),
        'messageCount': 0,
      });

      print('✓ All messages cleared');
      return true;
    } catch (e) {
      print('Error clearing messages: $e');
      return false;
    }
  }

  /// Export chat as JSON
  Future<String?> exportChatAsJson() async {
    try {
      final messages = await _firestore
          .collection('personalChats')
          .doc(_chatRoomId)
          .collection(_messagesCollectionPath)
          .orderBy('timestamp', descending: false)
          .get();

      final chatData = {
        'exportedAt': DateTime.now().toIso8601String(),
        'totalMessages': messages.docs.length,
        'messages': messages.docs.map((doc) => doc.data()).toList(),
      };

      return chatData.toString();
    } catch (e) {
      print('Error exporting chat: $e');
      return null;
    }
  }

  /// Get file icon emoji based on file extension
  String _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    const iconMap = {
      'pdf': '📕',
      'doc': '📘',
      'docx': '📘',
      'xls': '📗',
      'xlsx': '📗',
      'ppt': '📙',
      'pptx': '📙',
      'txt': '📄',
      'zip': '📦',
      'rar': '📦',
      'json': '⚙️',
    };
    return iconMap[extension] ?? '📎';
  }
}