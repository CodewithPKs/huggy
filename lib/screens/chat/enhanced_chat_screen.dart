// File: lib/screens/chat/enhanced_chat_screen.dart (UPDATED VERSION 2)
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../../services/enhanced_chat_service.dart';

class EnhancedChatScreen extends StatefulWidget {
  const EnhancedChatScreen({Key? key}) : super(key: key);

  @override
  State<EnhancedChatScreen> createState() => _EnhancedChatScreenState();
}

class _EnhancedChatScreenState extends State<EnhancedChatScreen> {
  final EnhancedChatService _chatService = EnhancedChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = false;
  bool _isSending = false;
  bool _showEmojiPicker = false;
  String _selectedFilter = 'all';
  Map<String, VideoPlayerController> _videoControllers = {};
  Map<String, double> _uploadProgress = {}; // Track upload progress by messageId

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    setState(() => _isLoading = true);
    try {
      await _chatService.initializePersonalChatRoom();
    } catch (e) {
      print('Error initializing chat: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear();
    setState(() => _showEmojiPicker = false);

    setState(() => _isSending = true);

    try {
      await _chatService.sendTextMessage(messageText: message);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error sending message: $e');
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
          await _chatService.sendImageMessage(
            imagePath: image.path,
            fileName: image.name,
          );
          _scrollToBottom();
          if (mounted) _showSnackBar('Image sent successfully');
        } finally {
          if (mounted) {
            setState(() {
              _uploadProgress.remove('image');
            });
          }
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error sending image: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
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
          await _chatService.sendImageMessage(
            imagePath: image.path,
            fileName: image.name,
          );
          _scrollToBottom();
          if (mounted) _showSnackBar('Photo sent successfully');
        } finally {
          if (mounted) {
            setState(() {
              _uploadProgress.remove('camera');
            });
          }
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error sending photo: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendVideo() async {
    try {
      final video = await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        setState(() {
          _isSending = true;
          _uploadProgress['video'] = 0.0;
        });

        try {
          final controller = VideoPlayerController.file(
            _parseFilePath(video.path),
          );
          await controller.initialize();
          final duration = controller.value.duration;
          controller.dispose();

          await _chatService.sendVideoMessage(
            videoPath: video.path,
            fileName: video.name,
            duration: duration,
          );
          _scrollToBottom();
          if (mounted) _showSnackBar('Video sent successfully');
        } finally {
          if (mounted) {
            setState(() {
              _uploadProgress.remove('video');
            });
          }
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error sending video: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'zip'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _isSending = true;
          _uploadProgress['document'] = 0.0;
        });

        try {
          await _chatService.sendDocumentMessage(
            docPath: file.path ?? '',
            fileName: file.name,
            mimeType: file.extension ?? 'bin',
          );
          _scrollToBottom();
          if (mounted) _showSnackBar('Document sent successfully');
        } finally {
          if (mounted) {
            setState(() {
              _uploadProgress.remove('document');
            });
          }
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error sending document: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendVoiceMessage() async {
    // TODO: Implement voice message recording
    // For now, show a placeholder
    _showSnackBar('Voice message feature coming soon!');
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    _messageController.text += emoji.emoji;
    if (mounted) {
      setState(() {});
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Help'),
        centerTitle: true,
        elevation: 0,
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Chat Stats'),
                onTap: () => _showChatStats(),
              ),
              PopupMenuItem(
                child: const Text('Clear All'),
                onTap: () => _showClearConfirmDialog(),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All'),
                  _buildFilterChip('text', 'Text'),
                  _buildFilterChip('image', 'Images'),
                  _buildFilterChip('video', 'Videos'),
                  _buildFilterChip('document', 'Docs'),
                ],
              ),
            ),
          ),
          // Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessagesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
                  return const Center(child: CircularProgressIndicator());
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
                          'Start a conversation!',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!.docs;
                final filteredMessages = _filterMessages(messages);

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  itemCount: filteredMessages.length,
                  itemBuilder: (context, index) {
                    final message = filteredMessages[index];
                    return _buildMessageBubble(message);
                  },
                );
              },
            ),
          ),
          // Upload progress indicator
          if (_uploadProgress.isNotEmpty)
            _buildUploadProgressBar(),
          // Message input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildUploadProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF2A2A2A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Uploading...',
            style: Theme.of(context).textTheme.bodySmall,
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
                          minHeight: 6,
                          backgroundColor: const Color(0xFF404040),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF6366F1),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(entry.value * 100).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodySmall,
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

  List<DocumentSnapshot> _filterMessages(List<DocumentSnapshot> messages) {
    if (_selectedFilter == 'all') return messages;
    return messages
        .where((msg) => msg['type'] == _selectedFilter)
        .toList();
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedFilter = selected ? value : 'all');
        },
        backgroundColor: const Color(0xFF2A2A2A),
        selectedColor: const Color(0xFF6366F1),
      ),
    );
  }

  Widget _buildMessageBubble(DocumentSnapshot message) {
    final data = message.data() as Map<String, dynamic>;
    final type = data['type'] as String;
    final timestamp = (data['timestamp'] as Timestamp).toDate();
    final formattedTime = DateFormat('HH:mm').format(timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _buildMessageContent(type, data, message.id),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  formattedTime,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                if (data['isRead'] == true)
                  const Icon(Icons.done_all, size: 14, color: Colors.cyan),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(String type, Map<String, dynamic> data, String messageId) {
    switch (type) {
      case 'text':
        return Text(
          data['message'] ?? '',
          style: const TextStyle(color: Colors.white),
        );

      case 'image':
        return GestureDetector(
          onLongPress: () => _showMessageOptions(messageId),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ClipRRect(
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
                      color: const Color(0xFF2A2A2A),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  },
                ),
              ),
              // const SizedBox(height: 4),
              // Text(
              //   data['fileName'] ?? 'Image',
              //   style: const TextStyle(fontSize: 12, color: Colors.white70),
              // ),
            ],
          ),
        );

      case 'video':
        return GestureDetector(
          onLongPress: () => _showMessageOptions(messageId),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildVideoPreview(data['videoUrl'], messageId),
              // const SizedBox(height: 4),
              // Text(
              //   '${data['fileName']} (${_formatDuration(data['duration'] ?? 0)})',
              //   style: const TextStyle(fontSize: 12, color: Colors.white70),
              // ),
            ],
          ),
        );

      case 'document':
        return GestureDetector(
          onLongPress: () => _showMessageOptions(messageId),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getFileIcon(data['fileName']),
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      data['fileName'] ?? 'Document',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _formatFileSize(data['fileSize'] ?? 0),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

      default:
        return const Text('Unknown message type');
    }
  }

  Widget _buildVideoPreview(String videoUrl, String messageId) {
    return GestureDetector(
      onTap: () => _showVideoPlayer(videoUrl),
      child: Container(
        height: 200,
        width: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 200,
              width: 200,
              color: Colors.black,
              child: Image.network(
                videoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.videocam, size: 60, color: Colors.white30),
                  );
                },
              ),
            ),
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoPlayer(String videoUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Video Player'),
        content: SizedBox(
          height: 400,
          child: _VideoPlayerWidget(videoUrl: videoUrl),
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

  void _showMessageOptions(String messageId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: const Color(0xFF1E1E1E),
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(messageId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Message Info'),
              onTap: () {
                Navigator.pop(context);
                _showMessageInfo(messageId);
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
                await _chatService.deleteMessage(messageId);
                if (mounted) {
                  _showSnackBar('Message deleted');
                }
              } catch (e) {
                if (mounted) {
                  _showSnackBar('Error deleting message: $e');
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showMessageInfo(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Message Info'),
        content: const Text('Message details will be shown here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showChatStats() async {
    final stats = await _chatService.getChatStats();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Chat Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('Total Messages:', '${stats['totalMessages'] ?? 0}'),
            _buildStatRow('Text Messages:', '${stats['textMessages'] ?? 0}'),
            _buildStatRow('Images:', '${stats['imageMessages'] ?? 0}'),
            _buildStatRow('Videos:', '${stats['videoMessages'] ?? 0}'),
            _buildStatRow('Documents:', '${stats['documentMessages'] ?? 0}'),
            const Divider(),
            _buildStatRow('Storage Used:', '${stats['totalStorageMB'] ?? 0} MB'),
          ],
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
          Text(value, style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showClearConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Clear All Messages'),
        content: const Text(
          'This will permanently delete all messages, images, videos, and documents. This action cannot be undone.',
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
                await _chatService.clearAllMessages();
                if (mounted) {
                  _showSnackBar('All messages cleared');
                }
              } catch (e) {
                if (mounted) {
                  _showSnackBar('Error clearing messages: $e');
                }
              }
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          // Media buttons row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildMediaIconButton(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    onPressed: _isSending ? null : _pickAndSendCamera,
                  ),
                  _buildMediaIconButton(
                    icon: Icons.image_outlined,
                    label: 'Gallery',
                    onPressed: _isSending ? null : _pickAndSendImage,
                  ),
                  _buildMediaIconButton(
                    icon: Icons.videocam_outlined,
                    label: 'Video',
                    onPressed: _isSending ? null : _pickAndSendVideo,
                  ),
                  _buildMediaIconButton(
                    icon: Icons.description_outlined,
                    label: 'Document',
                    onPressed: _isSending ? null : _pickAndSendDocument,
                  ),
                  _buildMediaIconButton(
                    icon: Icons.mic_outlined,
                    label: 'Voice',
                    onPressed: _isSending ? null : _sendVoiceMessage,
                  ),
                ],
              ),
            ),
          ),
          // Text input field with emoji button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Emoji button
                IconButton(
                  icon: const Icon(Icons.emoji_emotions_outlined),
                  onPressed: () {
                    setState(() => _showEmojiPicker = !_showEmojiPicker);
                  },
                ),
                // Text field
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                          color: Color(0xFF404040),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                          color: Color(0xFF404040),
                        ),
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
                      suffixIcon: _messageController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _messageController.clear();
                          setState(() {});
                        },
                      )
                          : null,
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _isSending ? null : _sendMessage(),
                    enabled: !_isSending,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                // Send button
                FloatingActionButton(
                  onPressed: _isSending || _messageController.text.trim().isEmpty
                      ? null
                      : _sendMessage,
                  mini: true,
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
          ),
          // Emoji picker
          if (_showEmojiPicker)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: _onEmojiSelected,
                onBackspacePressed: () {
                  if (_messageController.text.isNotEmpty) {
                    _messageController.text = _messageController.text
                        .substring(0, _messageController.text.length - 1);
                    setState(() {});
                  }
                },
                config: Config(
                  // columns: 7,
                  // emojiSizeMax: 32,
                  // verticalSpacing: 0,
                  // horizontalSpacing: 0,
                  // gridPadding: EdgeInsets.zero,
                  // initCategory: Category.RECENT,
                  // bgColor: const Color(0xFF2A2A2A),
                  // indicatorColor: const Color(0xFF6366F1),
                  // iconColor: Colors.white,
                  // iconColorSelected: const Color(0xFF6366F1),
                  // backspaceColor: const Color(0xFF6366F1),
                  // skinToneIndicatorColor: const Color(0xFF6366F1),
                  categoryViewConfig: const CategoryViewConfig(
                    backgroundColor: Color(0xFF2A2A2A),
                    indicatorColor: Color(0xFF6366F1),
                    iconColorSelected: Color(0xFF6366F1),
                    // categoryIcon: CategoryIcon.CATEGORY,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaIconButton({
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
    };
    return iconMap[extension] ?? '📎';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  _parseFilePath(String path) {
    return File(path);
  }
}

class _VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const _VideoPlayerWidget({required this.videoUrl});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    )..initialize().then((_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? Column(
      children: [
        AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
        const SizedBox(height: 16),
        VideoProgressIndicator(
          _controller,
          allowScrubbing: true,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FloatingActionButton(
              mini: true,
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              child: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            ),
          ],
        ),
      ],
    )
        : const Center(child: CircularProgressIndicator());
  }
}