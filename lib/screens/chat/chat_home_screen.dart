// File: lib/screens/chat/chat_home_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/chat_service.dart';
import 'chat_detail_screen.dart';

class ChatHomeScreen extends StatefulWidget {
  const ChatHomeScreen({Key? key}) : super(key: key);

  @override
  State<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final ChatService _chatService = ChatService();
  late String _currentUserId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.currentUser?.uid ?? '';
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
        title: const Text('Chat'),
        centerTitle: true,
        elevation: 0,
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Settings'),
                onTap: () => _navigateToSettings(),
              ),
              PopupMenuItem(
                child: const Text('Logout'),
                onTap: () => _handleLogout(),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search chats...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF404040),
                  ),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          // Chat List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chatRooms')
                  .where('participants', arrayContains: _currentUserId)
                  .orderBy('lastMessageTime', descending: true)
                  .snapshots(),
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
                          Icons.chat_outlined,
                          size: 80,
                          color: Colors.white24,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No chats yet',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a new conversation',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }

                final chats = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    final participants = List<String>.from(
                      chat['participants'] ?? [],
                    );
                    final otherUserId = participants.firstWhere(
                          (id) => id != _currentUserId,
                      orElse: () => '',
                    );

                    return _buildChatTile(
                      chatRoomId: chat.id,
                      otherUserId: otherUserId,
                      lastMessage: chat['lastMessage'] ?? '',
                      lastMessageTime: chat['lastMessageTime'] as Timestamp,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToNewChat(),
        child: const Icon(Icons.add_comment),
      ),
    );
  }

  Widget _buildChatTile({
    required String chatRoomId,
    required String otherUserId,
    required String lastMessage,
    required Timestamp lastMessageTime,
  }) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(otherUserId)
          .get()
          .then((doc) => doc.data()),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: CircularProgressIndicator(),
          );
        }

        final userData = snapshot.data ?? {};
        final name = userData['name'] ?? 'Unknown';
        final photoUrl = userData['photoUrl'];
        final time = lastMessageTime.toDate();
        final formattedTime = _formatTime(time);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF6366F1),
            child: photoUrl != null
                ? Image.network(photoUrl, fit: BoxFit.cover)
                : Text(name[0].toUpperCase()),
          ),
          title: Text(name),
          subtitle: Text(
            lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            formattedTime,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatDetailScreen(
                  chatRoomId: chatRoomId,
                  otherUserId: otherUserId,
                  otherUserName: name,
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${time.month}/${time.day}';
    }
  }

  void _navigateToNewChat() {
    // In a real app, show a list of users to start a new chat
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('New chat feature - select user to chat with'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            children: [
              ListTile(
                title: const Text('Change Password'),
                onTap: () {},
              ),
              ListTile(
                title: const Text('Privacy'),
                onTap: () {},
              ),
              const Divider(),
              ListTile(
                title: const Text('About'),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _authService.signOut();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                      (route) => false,
                );
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}