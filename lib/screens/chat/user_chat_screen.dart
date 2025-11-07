
import 'dart:developer';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:todo/screens/calls/active_voice_call_screen.dart';
import '../../model/call_models.dart';
import '../../provider/call_manager_provider.dart';
import '../../services/advanced_chat_service.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:provider/provider.dart';

import '../../services/incoming_call_screen.dart';
import '../calls/ActiveVideoCallScreen.dart';


class EnhancedUserChatScreen extends StatefulWidget {
  final String conversationId;
  final String userId;
  final String userName;

  const EnhancedUserChatScreen({
    Key? key,
    required this.conversationId,
    required this.userId,
    required this.userName,
  }) : super(key: key);

  @override
  State<EnhancedUserChatScreen> createState() => _EnhancedUserChatScreenState();
}

class _EnhancedUserChatScreenState extends State<EnhancedUserChatScreen> {
  late final AdvancedChatService _chatService = AdvancedChatService();
  late final TextEditingController _messageController = TextEditingController();
  late final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'huggy');

  late CallManagerProvider _callManager;

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
    // Initialize providers
    _initializeProviders();
    _setupCallManager();
  }

  ///Calls

  void _setupCallManager() {
    _callManager = Provider.of<CallManagerProvider>(context, listen: false);

    // Listen for incoming calls
    _callManager.listenForIncomingCalls(
      userId: widget.userId,
      onIncomingCall: (call) {
        _showIncomingCallScreen(call);
      },
    );
  }

  void _showIncomingCallScreen(CallModel call) {
    showDialog(
      context: context,


      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => IncomingCallScreen(
        incomingCall: call,
        onAnswer: () => _acceptCall(context),
        onReject: () => _rejectCall(context),
        onTimeout: () => _missedCall(context),
      ),
    );
  }

  void _acceptCall(BuildContext context) {
    Navigator.pop(context);
    _callManager.acceptIncomingCall().then((success) {
      if (success) {
        _showActiveCallScreen();
      }
    });
  }

  void _rejectCall(BuildContext context) {
    Navigator.pop(context);
    _callManager.rejectIncomingCall();
  }

  void _missedCall(BuildContext context) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Call missed')),
    );
  }

  void _showActiveCallScreen() {
    final call = _callManager.currentCall;
    if (call == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => call.callType == CallType.voice
            ? ActiveVoiceCallScreen(
          callModel: call,
          onMuteToggle: (_) => _callManager.toggleMute(),
          onSpeakerToggle: (_) => _callManager.toggleSpeaker(),
          onEndCall: () => _endCall(),
          isMuted: _callManager.isMuted,
          isSpeakerOn: _callManager.isSpeakerOn,
        )
            : ActiveVideoCallScreen(
          callModel: call,
          agoraService: _callManager.agoraService,
          remoteUid: _callManager.remoteUid,
          onMuteToggle: (_) => _callManager.toggleMute(),
          onCameraToggle: (_) => _callManager.toggleCamera(),
          onSwitchCamera: () => _callManager.switchCamera(),
          onEndCall: () => _endCall(),
          isMuted: _callManager.isMuted,
          isCameraOn: _callManager.isCameraOn,
        ),
      ),
    );
  }

  void _endCall() {
    _callManager.endCall().then((_) {
      Navigator.pop(context);
    });
  }

  Future<void> _initiateVoiceCall() async {
    final success = await _callManager.initiateVoiceCall(
      receiverId: 'admin',
      receiverName: 'Admin',
    );

    if (success && mounted) {
      _showActiveCallScreen();
    }
  }

  Future<void> _initiateVideoCall() async {
    final success = await _callManager.initiateVideoCall(
      receiverId: 'admin',
      receiverName: 'Admin',
    );

    if (success && mounted) {
      _showActiveCallScreen();
    }
  }


  ///------------------

  void _initializeProviders() {
    // Listen to text changes WITHOUT triggering full rebuild
    _messageController.addListener(() {
      context.read<TextInputProvider>().setText(_messageController.text);
    });
  }

  @override
  void dispose() {
    _messageController.removeListener(() {});
    _messageController.dispose();
    _scrollController.dispose();
    context.read<VideoControllerProvider>().disposeAll();
    super.dispose();
  }

  Future<void> _markMessagesAsRead() async {
    try {
      await _chatService.markAllMessagesAsRead(
        conversationId: widget.conversationId,
      );
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Enhanced send message with Provider state management
  Future<void> _sendMessage() async {
    final textProvider = context.read<TextInputProvider>();
    final chatStateProvider = context.read<ChatStateProvider>();

    if (textProvider.text.trim().isEmpty) return;

    final message = textProvider.text.trim();
    textProvider.clear();
    _messageController.clear();

    chatStateProvider.setSending(true);

    try {
      bool success;

      if (chatStateProvider.replyingToMessageId != null) {
        success = await _chatService.replyToMessage(
          conversationId: widget.conversationId,
          userId: widget.userId,
          userName: widget.userName,
          messageText: message,
          replyToMessageId: chatStateProvider.replyingToMessageId!,
          role: UserRole.user,
        );
      } else {
        success = await _chatService.sendMessage(
          conversationId: widget.conversationId,
          userId: widget.userId,
          userName: widget.userName,
          messageText: message,
          role: UserRole.user,
        );
      }

      if (success && mounted) {
        chatStateProvider.clearReply();
        _scrollToBottom();
      } else if (mounted) {
        _showErrorSnackBar('Failed to send message');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        chatStateProvider.setSending(false);
      }
    }
  }

  // Image picking with Provider
  Future<void> _pickAndSendImage() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        await _uploadMedia(image.path, image.name, MediaType.image);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error picking image: ${e.toString()}');
      }
    }
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Clear Chat?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will delete all messages in this chat. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearChat();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearChat() async {
    try {
      _showInfoSnackBar('Clearing chat...');

      // Get all messages
      final messagesSnapshot = await _firestore
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .get();

      // Delete all messages
      final batch = _firestore.batch();
      for (var doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Update conversation
      await _firestore
          .collection('conversations')
          .doc(widget.conversationId)
          .update({
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSuccessSnackBar('Chat cleared successfully');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error clearing chat: ${e.toString()}');
      }
    }
  }

  Future<void> _backupAndClearMessages() async {
    try {
      _showInfoSnackBar('Backing up and clearing messages...');

      final convRef = _firestore.collection('conversations').doc(widget.conversationId);
      final convDoc = await convRef.get();

      if (!convDoc.exists) {
        _showErrorSnackBar('Conversation not found');
        return;
      }

      final convData = convDoc.data() as Map<String, dynamic>;

      // Create a backup ID with timestamp for uniqueness
      final backupId = '${widget.conversationId}';
      final backupRef = _firestore.collection('backup_chats').doc(backupId);

      // Backup the conversation data
      await backupRef.set({
        ...convData,
        'backedUpAt': FieldValue.serverTimestamp(),
        'originalId': widget.conversationId,
      });

      // Get all messages in the conversation
      final messagesSnapshot = await convRef.collection('messages').get();

      if (messagesSnapshot.docs.isEmpty) {
        _showInfoSnackBar('No messages to backup.');
        return;
      }

      // Backup all messages and delete them
      final batch = _firestore.batch();
      for (var msgDoc in messagesSnapshot.docs) {
        // Copy message to backup
        batch.set(
          backupRef.collection('messages').doc(msgDoc.id),
          msgDoc.data() as Map<String, dynamic>,
        );
        // Delete message from original
        batch.delete(msgDoc.reference);
      }

      await batch.commit();

      if (mounted) {
        _showSuccessSnackBar('Chat backed up and messages cleared successfully');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error during backup & clear: ${e.toString()}');
      }
    }
  }


  Future<void> _pickAndSendCamera() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image != null) {
        await _uploadMedia(image.path, image.name, MediaType.image);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error taking photo: ${e.toString()}');
      }
    }
  }

  Future<void> _pickAndSendVideo() async {
    try {
      final video = await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        await _uploadMedia(video.path, video.name, MediaType.video);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error picking video: ${e.toString()}');
      }
    }
  }

  Future<void> _pickAndSendDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          await _uploadMedia(file.path!, file.name, MediaType.document);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error picking document: ${e.toString()}');
      }
    }
  }

  // Unified media upload with Provider state management
  Future<void> _uploadMedia(String path, String fileName, MediaType type) async {
    final tempMessageId = const Uuid().v4();
    final file = File(path);
    final chatStateProvider = context.read<ChatStateProvider>();
    final messagesProvider = context.read<MessagesProvider>();

    if (!file.existsSync()) {
      _showErrorSnackBar('File not found');
      return;
    }

    // Add pending message through Provider
    chatStateProvider.addPendingMessage(tempMessageId, fileName);
    messagesProvider.addPendingMessage(
      PendingMessage(id: tempMessageId, fileName: fileName, progress: 0.0),
    );

    try {
      final uniqueFileName = '${const Uuid().v4()}_$fileName';
      final uploadPath = 'conversations/${widget.conversationId}/${type.folder}/$uniqueFileName';

      final uploadTask = _storage.ref().child(uploadPath).putFile(file);
      chatStateProvider.storeUploadTask(tempMessageId, uploadTask);

      // Listen to upload progress
      uploadTask.snapshotEvents.listen(
            (TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          if (mounted) {
            chatStateProvider.updateUploadProgress(tempMessageId, progress);
            messagesProvider.updatePendingMessageProgress(tempMessageId, progress);
          }
        },
        onError: (error) {
          if (mounted) {
            chatStateProvider.removePendingMessage(tempMessageId);
            messagesProvider.removePendingMessage(tempMessageId);
            _showErrorSnackBar('Upload failed: ${error.toString()}');
          }
        },
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();


      log("type.name  : ${type.name}");

      final messageId = const Uuid().v4();
      await _firestore
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .doc(messageId)
          .set({
        'messageId': messageId,
        'senderId': widget.userId,
        'senderName': widget.userName,
        'role': 'user',
        'type': type.name,
        '${type.name}Url': downloadUrl,
        'fileName': fileName,
        'filePath': uploadPath,
        'fileSize': file.lengthSync(),
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'status': 'sent',
      });

      // Update conversation last message
      await _firestore.collection('conversations').doc(widget.conversationId).update({
        'lastMessage': type.emoji + ' ' + type.displayName,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        // Remove from pending through Provider
        chatStateProvider.removePendingMessage(tempMessageId);
        messagesProvider.removePendingMessage(tempMessageId);
        _scrollToBottom();
        _showSuccessSnackBar('${type.displayName} sent successfully');
      }
    } catch (e) {
      if (mounted) {
        chatStateProvider.removePendingMessage(tempMessageId);
        messagesProvider.removePendingMessage(tempMessageId);
        _showErrorSnackBar('Error uploading ${type.displayName}: ${e.toString()}');
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Helper method to check if we should show date separator
  bool _shouldShowDateSeparator(DateTime current, DateTime? previous) {
    if (previous == null) return true;
    return current.day != previous.day ||
        current.month != previous.month ||
        current.year != previous.year;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Chat'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showChatInfo(),
          ),

          IconButton(
            icon: Icon(Icons.call),
            onPressed: () => _initiateVoiceCall(),
          ),

          IconButton(
            icon: Icon(Icons.videocam),
            onPressed: () => _initiateVideoCall(),
          ),

          PopupMenuButton<String>(
            onSelected: (String value) {
              switch (value) {
                case 'clear':
                  _backupAndClearMessages();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [

              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, size: 20),
                    SizedBox(width: 12),
                    Text('Clear Chat'),
                  ],
                ),
              ),

            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list with pending messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessagesStream(
                conversationId: widget.conversationId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: SizedBox.shrink(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final messages = snapshot.data?.docs ?? [];

                return Consumer2<MessagesProvider, ChatStateProvider>(
                  builder: (context, messagesProvider, chatStateProvider, _) {
                    // Combine real messages with pending uploads
                    final allMessages = [
                      ...messagesProvider.pendingMessages,
                      ...messages,
                    ];

                    if (allMessages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.message_outlined,
                              size: 80,
                              color: Colors.white24,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start a conversation with support',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      reverse: true,
                      controller: _scrollController,
                      itemCount: allMessages.length,
                      itemBuilder: (context, index) {
                        final current = allMessages[index];

                        // Check if this is a pending message
                        if (current is PendingMessage) {
                          return _buildPendingMessageBubble(current);
                        }

                        // Regular message
                        final message = current as DocumentSnapshot;
                        final messageData = message.data() as Map<String, dynamic>;
                        final currentTimestamp = (messageData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

                        // Check if we need to show date separator
                        DateTime? previousTimestamp;
                        if (index < allMessages.length - 1 && allMessages[index + 1] is DocumentSnapshot) {
                          final prevMessage = allMessages[index + 1] as DocumentSnapshot;
                          final prevData = prevMessage.data() as Map<String, dynamic>;
                          previousTimestamp = (prevData['timestamp'] as Timestamp?)?.toDate();
                        }

                        final showDateSeparator = _shouldShowDateSeparator(
                          currentTimestamp,
                          previousTimestamp,
                        );

                        return Column(
                          children: [
                            if (showDateSeparator) _buildDateSeparator(currentTimestamp),
                            _buildMessageBubble(message),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          // Reply preview - Only rebuilds when reply changes
          Consumer<ChatStateProvider>(
            builder: (context, chatStateProvider, _) {
              if (chatStateProvider.replyingToData != null) {
                return _buildReplyPreview(chatStateProvider);
              }
              return const SizedBox.shrink();
            },
          ),
          // Message input - Only rebuilds when text changes
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white12,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _formatDate(date),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingMessageBubble(PendingMessage pending) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.upload_file, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      pending.fileName,
                      style: const TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Progress indicator - rebuild only this widget
              Consumer<MessagesProvider>(
                builder: (context, messagesProvider, _) {
                  final currentMessage = messagesProvider.pendingMessages
                      .firstWhere((m) => m.id == pending.id, orElse: () => pending);
                  return Column(
                    children: [
                      LinearProgressIndicator(
                        value: currentMessage.progress,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(currentMessage.progress * 100).toInt()}%',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          InkWell(
                            onTap: () {
                              context.read<ChatStateProvider>().cancelUpload(pending.id);
                              context.read<MessagesProvider>().removePendingMessage(pending.id);
                              _showInfoSnackBar('Upload cancelled');
                            },
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(DocumentSnapshot message) {
    final data = message.data() as Map<String, dynamic>;
    final type = data['type'] ?? 'text';
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final formattedTime = DateFormat('HH:mm').format(timestamp);
    final isUser = data['role'] == 'user';
    final replyTo = data['replyTo'] as Map<String, dynamic>?;
    final status = data['status'] ?? 'sent';

    return GestureDetector(
      onLongPress: isUser
          ? () => _showMessageOptions(message.id, data)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color: isUser ? const Color(0xFF6366F1) : const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (!isUser)
                      Text(
                        data['senderName'] ?? 'Support',
                        style: const TextStyle(
                          color: Color(0xFF6366F1),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    if (replyTo != null) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: isUser ? Colors.white : const Color(0xFF6366F1),
                              width: 3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              replyTo['senderName'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              replyTo['message'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    _buildMessageContent(type, data),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formattedTime,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 4),
                  if (isUser) _buildMessageStatus(status, data['isRead'] ?? false),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageStatus(String status, bool isRead) {
    if (status == 'sending') {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation(Colors.white54),
        ),
      );
    } else if (status == 'failed') {
      return const Icon(Icons.error_outline, size: 14, color: Colors.red);
    } else if (isRead) {
      return const Icon(Icons.done_all, size: 14, color: Colors.cyan);
    } else {
      return const Icon(Icons.done, size: 14, color: Colors.white54);
    }
  }

  Widget _buildMessageContent(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'text':
        return Text(
          data['message'] ?? '',
          style: const TextStyle(color: Colors.white),
        );

      case 'image':
        return GestureDetector(
          onTap: () => _showImagePreview(data['imageUrl']),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 200,
              width: 200,
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
              ),
              child: Consumer<ImageCacheProvider>(
                builder: (context, imageCacheProvider, _) {
                  return Image(
                    image: imageCacheProvider.getCachedImageProvider(data['imageUrl']),
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                          height: 200,
                          width: 200,
                          color: const Color(0xFF1E1E1E),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          )
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      width: 200,
                      color: const Color(0xFF1E1E1E),
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 40, color: Colors.white54),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );

      case 'video':
        return _buildVideoMessage(data);

      case 'document':
        return InkWell(
          onTap: () => _openDocument(data['documentUrl']),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getDocumentIcon(data['fileName'] ?? ''),
                  color: Colors.white70,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['fileName'] ?? 'Document',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (data['fileSize'] != null)
                        Text(
                          _formatFileSize(data['fileSize']),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

      default:
        return const Text('Unknown message type');
    }
  }

  Widget _buildVideoMessage(Map<String, dynamic> data) {
    final videoUrl = data['videoUrl'];
    final messageId = data['messageId'] ?? const Uuid().v4();

    return Consumer<VideoControllerProvider>(
      builder: (context, videoControllerProvider, _) {
        // Initialize video controller if not exists
        if (!videoControllerProvider.videoControllers.containsKey(messageId) && videoUrl != null) {
          final controller = VideoPlayerController.network(videoUrl);
          videoControllerProvider.addController(messageId, controller);
          controller.initialize().then((_) {
            if (mounted) {
              videoControllerProvider.addController(messageId, controller);
            }
          });
        }

        final controller = videoControllerProvider.videoControllers[messageId];

        return GestureDetector(
          onTap: () {
            videoControllerProvider.togglePlayPause(messageId);
          },
          child: Container(
            height: 200,
            width: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (controller != null && controller.value.isInitialized)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  )
                else
                  const CircularProgressIndicator(),
                if (controller == null || !controller.value.isPlaying)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getDocumentIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.article;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _openDocument(String? url) {
    if (url != null) {
      _showInfoSnackBar('Opening document...');
    }
  }

  Widget _buildReplyPreview(ChatStateProvider chatStateProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF2A2A2A),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
                border: const Border(
                  left: BorderSide(
                    color: Color(0xFF6366F1),
                    width: 3,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Replying to:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          chatStateProvider.replyingToData?['senderName'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6366F1),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chatStateProvider.replyingToData?['message'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => chatStateProvider.clearReply(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Consumer2<TextInputProvider, ChatStateProvider>(
      builder: (context, textInputProvider, chatStateProvider, _) {
        final hasText = textInputProvider.hasText;
        final isSending = chatStateProvider.isSending;

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attachment button
                PopupMenuButton(
                  icon: Icon(
                    Icons.attachment,
                    color: isSending ? Colors.white38 : Colors.white70,
                  ),
                  enabled: !isSending,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: const Row(
                        children: [
                          Icon(Icons.camera_alt),
                          SizedBox(width: 12),
                          Text('Camera'),
                        ],
                      ),
                      onTap: isSending ? null : _pickAndSendCamera,
                    ),
                    PopupMenuItem(
                      child: const Row(
                        children: [
                          Icon(Icons.image),
                          SizedBox(width: 12),
                          Text('Gallery'),
                        ],
                      ),
                      onTap: isSending ? null : _pickAndSendImage,
                    ),
                    PopupMenuItem(
                      child: const Row(
                        children: [
                          Icon(Icons.videocam),
                          SizedBox(width: 12),
                          Text('Video'),
                        ],
                      ),
                      onTap: isSending ? null : _pickAndSendVideo,
                    ),
                    PopupMenuItem(
                      child: const Row(
                        children: [
                          Icon(Icons.description),
                          SizedBox(width: 12),
                          Text('Document'),
                        ],
                      ),
                      onTap: isSending ? null : _pickAndSendDocument,
                    ),
                  ],
                ),
                // Message text field
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFF404040)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFF404040)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: Color(0xFF6366F1),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF2A2A2A),
                      ),
                      style: const TextStyle(color: Colors.white),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      enabled: !isSending,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Send button
                Material(
                  color: hasText && !isSending
                      ? const Color(0xFF6366F1)
                      : const Color(0xFF404040),
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: hasText && !isSending ? _sendMessage : null,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: isSending
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white54),
                        ),
                      )
                          : Icon(
                        Icons.send,
                        color: hasText ? Colors.white : Colors.white38,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessageOptions(String messageId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply, color: Colors.white70),
              title: const Text('Reply', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                context.read<ChatStateProvider>().setReply(messageId, data);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.white70),
              title: const Text('Copy', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showInfoSnackBar('Message copied');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(messageId);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteMessage(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Delete Message', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this message?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _chatService.deleteMessage(
                  conversationId: widget.conversationId,
                  messageId: messageId,
                );
                if (mounted) {
                  _showSuccessSnackBar('Message deleted');
                }
              } catch (e) {
                if (mounted) {
                  _showErrorSnackBar('Error deleting message');
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Hero(
              tag: imageUrl,
              child: Consumer<ImageCacheProvider>(
                builder: (context, imageCacheProvider, _) {
                  return InteractiveViewer(
                    child: Image(
                      image: imageCacheProvider.getCachedImageProvider(imageUrl),
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const CircularProgressIndicator();
                      },
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.broken_image,
                        size: 80,
                        color: Colors.white54,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showChatInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Chat Information', style: TextStyle(color: Colors.white)),
        content: FutureBuilder<Map<String, dynamic>>(
          future: _chatService.getConversationStats(
            conversationId: widget.conversationId,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return const Text('Error loading stats', style: TextStyle(color: Colors.white70));
            }

            final stats = snapshot.data ?? {};
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatRow('Total Messages:', '${stats['totalMessages'] ?? 0}'),
                _buildStatRow('Unread Messages:', '${stats['unreadMessages'] ?? 0}'),
                _buildStatRow('Your Messages:', '${stats['userMessages'] ?? 0}'),
                _buildStatRow('Support Messages:', '${stats['adminMessages'] ?? 0}'),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF6366F1),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF6366F1),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// Helper classes
enum MediaType {
  image('image', 'images', '📷', 'Image'),
  video('video', 'videos', '🎥', 'Video'),
  document('document', 'documents', '📄', 'Document');

  final String name;
  final String folder;
  final String emoji;
  final String displayName;

  const MediaType(this.name, this.folder, this.emoji, this.displayName);
}

class PendingMessage {
  final String id;
  final String fileName;
  final double progress;

  PendingMessage({
    required this.id,
    required this.fileName,
    required this.progress,
  });
}


// Chat State Provider
class ChatStateProvider extends ChangeNotifier {
  String? _replyingToMessageId;
  Map<String, dynamic>? _replyingToData;
  bool _isSending = false;

  // Upload tracking
  final Map<String, UploadTask> _activeUploads = {};
  final Map<String, double> _uploadProgress = {};
  final Map<String, String> _pendingMessages = {};

  // Getters
  String? get replyingToMessageId => _replyingToMessageId;
  Map<String, dynamic>? get replyingToData => _replyingToData;
  bool get isSending => _isSending;
  Map<String, UploadTask> get activeUploads => _activeUploads;
  Map<String, double> get uploadProgress => _uploadProgress;
  Map<String, String> get pendingMessages => _pendingMessages;

  void setReply(String messageId, Map<String, dynamic> messageData) {
    _replyingToMessageId = messageId;
    _replyingToData = messageData;
    notifyListeners();
  }

  void clearReply() {
    _replyingToMessageId = null;
    _replyingToData = null;
    notifyListeners();
  }

  void setSending(bool value) {
    _isSending = value;
    notifyListeners();
  }

  void addPendingMessage(String messageId, String fileName) {
    _pendingMessages[messageId] = fileName;
    _uploadProgress[messageId] = 0.0;
    notifyListeners();
  }

  void updateUploadProgress(String messageId, double progress) {
    _uploadProgress[messageId] = progress;
    notifyListeners();
  }

  void removePendingMessage(String messageId) {
    _activeUploads.remove(messageId);
    _uploadProgress.remove(messageId);
    _pendingMessages.remove(messageId);
    notifyListeners();
  }

  void storeUploadTask(String messageId, UploadTask task) {
    _activeUploads[messageId] = task;
    notifyListeners();
  }

  void cancelUpload(String messageId) {
    final uploadTask = _activeUploads[messageId];
    if (uploadTask != null) {
      uploadTask.cancel();
    }
    removePendingMessage(messageId);
  }
}

// Messages Provider
class MessagesProvider extends ChangeNotifier {
  List<DocumentSnapshot> _messages = [];
  List<PendingMessage> _pendingMessages = [];
  bool _isLoading = false;
  String? _error;

  List<DocumentSnapshot> get messages => _messages;
  List<PendingMessage> get pendingMessages => _pendingMessages;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Combined list for UI
  List<dynamic> get allMessages {
    final combined = [..._pendingMessages, ..._messages];
    return combined;
  }

  void setMessages(List<DocumentSnapshot> messages) {
    _messages = messages;
    _error = null;
    notifyListeners();
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void addPendingMessage(PendingMessage message) {
    _pendingMessages.add(message);
    notifyListeners();
  }

  void removePendingMessage(String messageId) {
    _pendingMessages.removeWhere((m) => m.id == messageId);
    notifyListeners();
  }

  void updatePendingMessageProgress(String messageId, double progress) {
    final index = _pendingMessages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      _pendingMessages[index] = PendingMessage(
        id: _pendingMessages[index].id,
        fileName: _pendingMessages[index].fileName,
        progress: progress,
      );
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

// Text Input Provider
class TextInputProvider extends ChangeNotifier {
  String _text = '';

  String get text => _text;
  bool get hasText => _text.trim().isNotEmpty;

  void setText(String value) {
    _text = value;
    notifyListeners();
  }

  void clear() {
    _text = '';
    notifyListeners();
  }
}

// Image Cache Provider
class ImageCacheProvider extends ChangeNotifier {
  final Map<String, ImageProvider> _imageCache = {};

  Map<String, ImageProvider> get imageCache => _imageCache;

  ImageProvider getCachedImageProvider(String imageUrl) {
    if (!_imageCache.containsKey(imageUrl)) {
      _imageCache[imageUrl] = CachedNetworkImageProvider(
        imageUrl,
        cacheManager: DefaultCacheManager(),
      );
    }
    return _imageCache[imageUrl]!;
  }

  void clearCache() {
    _imageCache.clear();
    notifyListeners();
  }
}

// Video Controllers Provider
class VideoControllerProvider extends ChangeNotifier {
  final Map<String, VideoPlayerController> _videoControllers = {};

  Map<String, VideoPlayerController> get videoControllers => _videoControllers;

  void addController(String messageId, VideoPlayerController controller) {
    _videoControllers[messageId] = controller;
    notifyListeners();
  }

  void togglePlayPause(String messageId) {
    final controller = _videoControllers[messageId];
    if (controller != null && controller.value.isInitialized) {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
      notifyListeners();
    }
  }

  void disposeAll() {
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
    notifyListeners();
  }
}

