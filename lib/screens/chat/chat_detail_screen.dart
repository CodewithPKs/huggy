// File: lib/screens/chat/chat_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/chat_service.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatRoomId;
  final String otherUserId;
  final String otherUserName;

  const ChatDetailScreen({
    Key? key,
    required this.chatRoomId,
    required this.otherUserId,
    required this.otherUserName,
  }) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.currentUser?.uid ?? '';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    await _chatService.sendMessage(
      chatRoomId: widget.chatRoomId,
      userId: _currentUserId,
      messageText: message,
    );

    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      // Send image message
      await _chatService.sendImageMessage(
        chatRoomId: widget.chatRoomId,
        userId: _currentUserId,
        imagePath: image.path,
        fileName: image.name,
      );
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessagesStream(widget.chatRoomId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
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
                    final isMe = message['senderId'] == _currentUserId;
                    final messageType = message['type'] ?? 'text';

                    return _buildMessageBubble(
                      message: message,
                      isMe: isMe,
                      messageType: messageType,
                    );
                  },
                );
              },
            ),
          ),
          // Message Input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required DocumentSnapshot message,
    required bool isMe,
    required String messageType,
  }) {
    final timestamp = (message['timestamp'] as Timestamp).toDate();
    final formattedTime = DateFormat('HH:mm').format(timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              decoration: BoxDecoration(
                color: isMe
                    ? const Color(0xFF6366F1)
                    : const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: messageType == 'text'
                  ? Text(
                message['message'] ?? '',
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.white70,
                ),
              )
                  : messageType == 'image'
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  message['imageUrl'],
                  fit: BoxFit.cover,
                  height: 200,
                  width: 200,
                ),
              )
                  : const Text('📍 Location shared'),
            ),
            const SizedBox(height: 4),
            Text(
              formattedTime,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            onPressed: _pickImage,
          ),
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
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _sendMessage,
            mini: true,
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}