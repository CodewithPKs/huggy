// File: lib/screens/chat/user_chat_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/advanced_chat_service.dart';

class UserChatScreen extends StatefulWidget {
  final String conversationId;
  final String userId;
  final String userName;

  const UserChatScreen({
    Key? key,
    required this.conversationId,
    required this.userId,
    required this.userName,
  }) : super(key: key);

  @override
  State<UserChatScreen> createState() => _UserChatScreenState();
}

class _UserChatScreenState extends State<UserChatScreen> {
  final AdvancedChatService _chatService = AdvancedChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isSending = false;
  String? _replyingToMessageId;
  Map<String, dynamic>? _replyingToData;

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
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
          userId: widget.userId,
          userName: widget.userName,
          messageText: message,
          replyToMessageId: _replyingToMessageId!,
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
        setState(() => _isSending = true);

        try {
          final success = await _chatService.sendImageMessage(
            conversationId: widget.conversationId,
            userId: widget.userId,
            userName: widget.userName,
            imagePath: image.path,
            fileName: image.name,
            role: UserRole.user,
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
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _pickAndSendCamera() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() => _isSending = true);

        try {
          final success = await _chatService.sendImageMessage(
            conversationId: widget.conversationId,
            userId: widget.userId,
            userName: widget.userName,
            imagePath: image.path,
            fileName: image.name,
            role: UserRole.user,
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
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _pickAndSendDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() => _isSending = true);

        try {
          final success = await _chatService.sendDocumentMessage(
            conversationId: widget.conversationId,
            userId: widget.userId,
            userName: widget.userName,
            docPath: file.path ?? '',
            fileName: file.name,
            role: UserRole.user,
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
        setState(() => _isSending = false);
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
        ],
      ),
      body: Column(
        children: [
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

                final messages = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _buildMessageBubble(message);
                  },
                );
              },
            ),
          ),
          // Reply preview
          if (_replyingToData != null) _buildReplyPreview(),
          // Message input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(DocumentSnapshot message) {
    final data = message.data() as Map<String, dynamic>;
    final type = data['type'] ?? 'text';
    final timestamp = (data['timestamp'] as Timestamp).toDate();
    final formattedTime = DateFormat('HH:mm').format(timestamp);
    final isUser = data['role'] == 'user';
    final replyTo = data['replyTo'] as Map<String, dynamic>?;

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
                  const SizedBox(width: 8),
                  if (isUser && data['isRead'] == true)
                    const Icon(Icons.done_all, size: 14, color: Colors.cyan),
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
      child: Row(
        children: [
          PopupMenuButton(
            icon: const Icon(Icons.attachment),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Row(
                  children: [Icon(Icons.camera_alt), SizedBox(width: 8), Text('Camera')],
                ),
                onTap: _isSending ? null : _pickAndSendCamera,
              ),
              PopupMenuItem(
                child: const Row(
                  children: [Icon(Icons.image), SizedBox(width: 8), Text('Gallery')],
                ),
                onTap: _isSending ? null : _pickAndSendImage,
              ),
              PopupMenuItem(
                child: const Row(
                  children: [Icon(Icons.description), SizedBox(width: 8), Text('Document')],
                ),
                onTap: _isSending ? null : _pickAndSendDocument,
              ),
            ],
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type your message...',
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
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
                : const Icon(Icons.send),
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
        content: const Text('Are you sure you want to delete this message?'),
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
            child: const Text('Delete'),
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

  void _showChatInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Chat Information'),
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
}