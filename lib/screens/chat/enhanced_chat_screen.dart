// File: lib/screens/chat/enhanced_chat_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
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
  String _selectedFilter = 'all';
  Map<String, VideoPlayerController> _videoControllers = {};

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
        setState(() => _isSending = true);
        await _chatService.sendImageMessage(
          imagePath: image.path,
          fileName: image.name,
        );
        _scrollToBottom();
        if (mounted) _showSnackBar('Image sent successfully');
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error sending image: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendVideo() async {
    try {
      final video = await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        setState(() => _isSending = true);

        // Get video duration
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
        setState(() => _isSending = true);

        await _chatService.sendDocumentMessage(
          docPath: file.path ?? '',
          fileName: file.name,
          mimeType: file.extension ?? 'bin',
        );
        _scrollToBottom();
        if (mounted) _showSnackBar('Document sent successfully');
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error sending document: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
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
        title: const Text('Personal Chat'),
        centerTitle: true,
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
          // Message input
          _buildMessageInput(),
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
              const SizedBox(height: 4),
              Text(
                data['fileName'] ?? 'Image',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
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
              const SizedBox(height: 4),
              Text(
                '${data['fileName']} (${_formatDuration(data['duration'] ?? 0)})',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Media buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMediaButton(
                  icon: Icons.image_outlined,
                  label: 'Image',
                  onPressed: _pickAndSendImage,
                ),
                _buildMediaButton(
                  icon: Icons.videocam_outlined,
                  label: 'Video',
                  onPressed: _pickAndSendVideo,
                ),
                _buildMediaButton(
                  icon: Icons.description_outlined,
                  label: 'Document',
                  onPressed: _pickAndSendDocument,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Text input and send
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _isSending ? null : _sendMessage(),
                  enabled: !_isSending,
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton(
                onPressed: _isSending ? null : _sendMessage,
                mini: true,
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
        ],
      ),
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ElevatedButton.icon(
        onPressed: _isSending ? null : onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2A2A2A),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
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
    // Helper to convert file path to File object
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