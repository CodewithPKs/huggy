// File: lib/screens/chat/admin_chat_screen.dart (UPDATED - FEATURE COMPLETE)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../model/call_models.dart';
import '../../provider/call_manager_provider.dart';
import '../../services/advanced_chat_service.dart';
import '../../services/incoming_call_screen.dart';
import '../calls/ActiveVideoCallScreen.dart';
import '../calls/active_voice_call_screen.dart';

class AdminChatScreen extends StatefulWidget {
  const AdminChatScreen({Key? key}) : super(key: key);

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  final AdvancedChatService _chatService = AdvancedChatService();
  String? _selectedConversationId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Hardcoded user data for this single-person app
  static const String USER_ID = 'personal_user_001';
  static const String USER_NAME = 'User';
  static const String USER_EMAIL = 'user@example.com';

  late CallManagerProvider _callManager;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadConversation();
    _setupCallManager();
  }

  void _setupCallManager() {
    _callManager = Provider.of<CallManagerProvider>(context, listen: false);

    // Listen for incoming calls
    _callManager.listenForIncomingCalls(
      userId: USER_ID,
      onIncomingCall: (call) {
        _showIncomingCallScreen(call);
      },
    );

    // ✅ Listen for active call status changes
    _listenForActiveCallChanges();
  }

// Add this new method
  void _listenForActiveCallChanges() {
    // This listens for changes in the current active call
    _callManager.addListener(() {
      // If call was active but now ended
      if (_callManager.currentCallStatus == CallStatus.ended &&
          Navigator.canPop(context)) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        // _showInfoSnackBar('Call ended by other user');/**/
      }
    });
  }
  // void _setupCallManager() {
  //   _callManager = Provider.of<CallManagerProvider>(context, listen: false);
  //
  //   // Initialize call manager with admin user ID
  //   _callManager.initialize(userId: 'admin').then((_) {
  //     print('✓ Admin call manager initialized');
  //
  //     // Listen for incoming calls
  //     _callManager.listenForIncomingCalls(
  //       userId: 'admin',
  //       onIncomingCall: (call) {
  //         print('📞 ADMIN: Incoming call from ${call.callerName}');
  //         _showIncomingCallScreen(call);
  //       },
  //     );
  //
  //     print('✓ Admin listening for incoming calls');
  //   });
  // }

  // 🔴 ADD THIS METHOD
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

  // 🔴 ADD THIS METHOD
  void _acceptCall(BuildContext context) {
    Navigator.pop(context);
    _callManager.acceptIncomingCall().then((success) {
      if (success) {
        _showActiveCallScreen();
      }
    });
  }

  // 🔴 ADD THIS METHOD
  void _rejectCall(BuildContext context) {
    Navigator.pop(context);
    _callManager.rejectIncomingCall();
  }

  // 🔴 ADD THIS METHOD
  void _missedCall(BuildContext context) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Call missed')),
    );
  }

  // 🔴 ADD THIS METHOD
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

  // 🔴 ADD THIS METHOD
  void _endCall() {
    _callManager.endCall().then((_) {
      Navigator.pop(context);
    });
  }

  Future<void> _initializeAndLoadConversation() async {
    try {
      final conversationId = await _chatService.createOrGetConversation(
        userId: USER_ID,
        userName: USER_NAME,
        userEmail: USER_EMAIL,
      );

      if (conversationId != null && mounted) {
        setState(() => _selectedConversationId = conversationId);
      }
    } catch (e) {
      print('Error loading conversation: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Support Panel'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _selectedConversationId != null
          ? _AdminConversationView(
        conversationId: _selectedConversationId!,
        onClose: () {
          setState(() => _selectedConversationId = null);
        },
      )
          : const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _AdminConversationView extends StatefulWidget {
  final String conversationId;
  final VoidCallback onClose;

  const _AdminConversationView({
    required this.conversationId,
    required this.onClose,
  });

  @override
  State<_AdminConversationView> createState() => _AdminConversationViewState();
}

class _AdminConversationViewState extends State<_AdminConversationView> {
  final AdvancedChatService _chatService = AdvancedChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isSending = false;
  String? _replyingToMessageId;
  Map<String, dynamic>? _replyingToData;
  Map<String, dynamic>? _conversationData;
  Map<String, double> _uploadProgress = {}; // Track upload progress

  // Hardcoded admin data
  static const String ADMIN_ID = 'admin_001';
  static const String ADMIN_NAME = 'Praveen';

  @override
  void initState() {
    super.initState();
    _loadConversationData();
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversationData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .get();

      if (doc.exists) {
        setState(() => _conversationData = doc.data());
      }
    } catch (e) {
      print('Error loading conversation data: $e');
    }
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

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    setState(() => _isSending = true);

    try {
      bool success;

      if (_replyingToMessageId != null) {
        success = await _chatService.replyToMessage(
          conversationId: widget.conversationId,
          userId: ADMIN_ID,
          userName: ADMIN_NAME,
          messageText: message,
          replyToMessageId: _replyingToMessageId!,
          role: UserRole.admin,
        );
      } else {
        success = await _chatService.sendMessage(
          conversationId: widget.conversationId,
          userId: ADMIN_ID,
          userName: ADMIN_NAME,
          messageText: message,
          role: UserRole.admin,
        );
      }

      if (success && mounted) {
        setState(() {
          _replyingToMessageId = null;
          _replyingToData = null;
        });
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
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _isSending = true;
          _uploadProgress['image'] = 0.0;
        });

        try {
          final success = await _chatService.sendImageMessage(
            conversationId: widget.conversationId,
            userId: ADMIN_ID,
            userName: ADMIN_NAME,
            imagePath: image.path,
            fileName: image.name,
            role: UserRole.admin,
          );

          if (success && mounted) {
            _scrollToBottom();
            _showSuccessSnackBar('Image sent successfully');
          } else if (mounted) {
            _showErrorSnackBar('Failed to send image');
          }
        } catch (e) {
          if (mounted) {
            _showErrorSnackBar('Error sending image: ${e.toString()}');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error picking image: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadProgress.remove('image');
          _isSending = false;
        });
      }
    }
  }

  Future<void> _pickAndSendCamera() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _isSending = true;
          _uploadProgress['camera'] = 0.0;
        });

        try {
          final success = await _chatService.sendImageMessage(
            conversationId: widget.conversationId,
            userId: ADMIN_ID,
            userName: ADMIN_NAME,
            imagePath: image.path,
            fileName: image.name,
            role: UserRole.admin,
          );

          if (success && mounted) {
            _scrollToBottom();
            _showSuccessSnackBar('Photo sent successfully');
          } else if (mounted) {
            _showErrorSnackBar('Failed to send photo');
          }
        } catch (e) {
          if (mounted) {
            _showErrorSnackBar('Error sending photo: ${e.toString()}');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error taking photo: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadProgress.remove('camera');
          _isSending = false;
        });
      }
    }
  }

  Future<void> _pickAndSendDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _isSending = true;
          _uploadProgress['document'] = 0.0;
        });

        try {
          final success = await _chatService.sendDocumentMessage(
            conversationId: widget.conversationId,
            userId: ADMIN_ID,
            userName: ADMIN_NAME,
            docPath: file.path ?? '',
            fileName: file.name,
            role: UserRole.admin,
          );

          if (success && mounted) {
            _scrollToBottom();
            _showSuccessSnackBar('Document sent successfully');
          } else if (mounted) {
            _showErrorSnackBar('Failed to send document');
          }
        } catch (e) {
          if (mounted) {
            _showErrorSnackBar('Error sending document: ${e.toString()}');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error picking document: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadProgress.remove('document');
          _isSending = false;
        });
      }
    }
  }

  void _setReply(String messageId, Map<String, dynamic> messageData) {
    setState(() {
      _replyingToMessageId = messageId;
      _replyingToData = messageData;
    });
  }

  void _clearReply() {
    setState(() {
      _replyingToMessageId = null;
      _replyingToData = null;
    });
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with user info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF2A2A2A),
            border: Border(
              bottom: BorderSide(color: Color(0xFF404040)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    (_conversationData?['userName'] ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _conversationData?['userName'] ?? 'User',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _conversationData?['userEmail'] ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const Text('Chat Stats'),
                    onTap: () => _showChatStats(),
                  ),
                  PopupMenuItem(
                    child: const Text('View Details'),
                    onTap: () => _showConversationDetails(),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Messages
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _chatService.getMessagesStream(
              conversationId: widget.conversationId,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                      const Text('No messages in this conversation'),
                      const SizedBox(height: 8),
                      const Text(
                        'Start replying to messages from the user',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                );
              }

              final messages = snapshot.data!.docs;
              return ListView.builder(
                reverse: true,
                controller: _scrollController,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  // Mark as read when displayed
                  if (message['isRead'] == false &&
                      message['role'] != 'admin') {
                    _chatService.markMessageAsRead(
                      conversationId: widget.conversationId,
                      messageId: message.id,
                    );
                  }
                  return _buildMessageBubble(message);
                },
              );
            },
          ),
        ),
        // Upload progress indicator
        if (_uploadProgress.isNotEmpty) _buildUploadProgressBar(),
        // Reply preview
        if (_replyingToData != null) _buildReplyPreview(),
        // Message input
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildUploadProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF2A2A2A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_upload, size: 16, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Text(
                'Uploading...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._uploadProgress.entries.map((entry) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: entry.value,
                          minHeight: 8,
                          backgroundColor: const Color(0xFF404040),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF6366F1),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(entry.value * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(DocumentSnapshot message) {
    final data = message.data() as Map<String, dynamic>;
    final type = data['type'] ?? 'text';
    final timestamp = (data['timestamp'] as Timestamp).toDate();
    final formattedTime = DateFormat('HH:mm').format(timestamp);
    final isAdmin = data['role'] == 'admin';
    final replyTo = data['replyTo'] as Map<String, dynamic>?;
    final isRead = data['isRead'] ?? false;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message.id, data),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Align(
          alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment:
            isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                decoration: BoxDecoration(
                  color: isAdmin
                      ? const Color(0xFF6366F1)
                      : const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: isAdmin
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (!isAdmin)
                      Text(
                        data['senderName'] ?? 'User',
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
                              color: isAdmin
                                  ? Colors.white
                                  : const Color(0xFF6366F1),
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
                  const SizedBox(width: 8),
                  if (isAdmin && isRead)
                    const Icon(Icons.done_all, size: 14, color: Colors.cyan),
                  if (isAdmin && !isRead)
                    const Icon(Icons.done, size: 14, color: Colors.white54),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
            child: Image.network(
              data['imageUrl'],
              fit: BoxFit.cover,
              height: 200,
              width: 200,
              loadingBuilder: (context, child, progress) {
                return progress == null
                    ? child
                    : Container(
                  height: 200,
                  width: 200,
                  color: const Color(0xFF1E1E1E),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  width: 200,
                  color: const Color(0xFF1E1E1E),
                  child: const Center(
                    child: Icon(Icons.image_not_supported, size: 40),
                  ),
                );
              },
            ),
          ),
        );

      case 'document':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.description, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                data['fileName'] ?? 'Document',
                style: const TextStyle(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );

      default:
        return const Text('Unknown message type');
    }
  }

  Widget _buildReplyPreview() {
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
                          _replyingToData?['senderName'] ?? 'Unknown',
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
                    _replyingToData?['message'] ?? '',
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
            onPressed: _clearReply,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          // Media buttons row
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildMediaButton(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    onPressed: _isSending ? null : _pickAndSendCamera,
                  ),
                  _buildMediaButton(
                    icon: Icons.image_outlined,
                    label: 'Gallery',
                    onPressed: _isSending ? null : _pickAndSendImage,
                  ),
                  _buildMediaButton(
                    icon: Icons.description_outlined,
                    label: 'Document',
                    onPressed: _isSending ? null : _pickAndSendDocument,
                  ),
                ],
              ),
            ),
          ),
          // Text input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type your response...',
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
                  ),
                  maxLines: null,
                  enabled: !_isSending,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _isSending ? null : _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton(
                mini: true,
                onPressed: _isSending || _messageController.text.trim().isEmpty
                    ? null
                    : _sendMessage,
                backgroundColor: _messageController.text.trim().isEmpty
                    ? Colors.grey
                    : const Color(0xFF6366F1),
                child: _isSending
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                    AlwaysStoppedAnimation(Colors.white),
                  ),
                )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: onPressed == null
                    ? Colors.grey
                    : const Color(0xFF6366F1).withOpacity(0.3),
              ),
            ),
            child: IconButton(
              icon: Icon(icon),
              onPressed: onPressed,
              iconSize: 20,
              constraints: const BoxConstraints(
                minHeight: 44,
                minWidth: 44,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: onPressed == null ? Colors.grey : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(String messageId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: const Color(0xFF1E1E1E),
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                _setReply(messageId, data);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(messageId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                if (data['type'] == 'text') {
                  // Copy to clipboard functionality
                }
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
        title: const Text('Delete Message'),
        content:
        const Text('Are you sure you want to delete this message?'),
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
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        content: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox(
              height: 300,
              child: Center(
                child: Icon(Icons.image_not_supported, size: 80),
              ),
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

  void _showChatStats() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Chat Statistics'),
        content: FutureBuilder<Map<String, dynamic>>(
          future: _chatService.getConversationStats(
            conversationId: widget.conversationId,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }

            if (snapshot.hasError) {
              return const Text('Error loading stats');
            }

            final stats = snapshot.data ?? {};
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatRow('Total Messages:',
                    '${stats['totalMessages'] ?? 0}'),
                _buildStatRow('Unread Messages:',
                    '${stats['unreadMessages'] ?? 0}'),
                _buildStatRow(
                    'User Messages:', '${stats['userMessages'] ?? 0}'),
                _buildStatRow(
                    'Admin Messages:', '${stats['adminMessages'] ?? 0}'),
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

  void _showConversationDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Conversation Details'),
        content: FutureBuilder<Map<String, dynamic>>(
          future: _chatService.getConversationStats(
            conversationId: widget.conversationId,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }

            if (snapshot.hasError) {
              return const Text('Error loading details');
            }

            final stats = snapshot.data ?? {};
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('User:',
                    _conversationData?['userName'] ?? 'Unknown'),
                _buildDetailRow(
                    'Email:', _conversationData?['userEmail'] ?? 'N/A'),
                _buildDetailRow(
                    'Status:', _conversationData?['status'] ?? 'active'),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                _buildDetailRow('Total Messages:',
                    '${stats['totalMessages'] ?? 0}'),
                _buildDetailRow(
                    'User Messages:', '${stats['userMessages'] ?? 0}'),
                _buildDetailRow(
                    'Admin Messages:', '${stats['adminMessages'] ?? 0}'),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF6366F1),
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}