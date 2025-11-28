// File: lib/screens/todo/todo_home_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/biometric_service.dart';
import '../../services/todo_service.dart';
import '../../services/voice_activation_service.dart';
import '../../services/advanced_chat_service.dart';
import '../chat/chat_home_screen.dart';
import '../chat/user_chat_screen.dart';
import '../chat/admin_chat_screen.dart';
import 'add_task_screen.dart';
import 'task_detail_screen.dart';

class TodoHomeScreen extends StatefulWidget {
  const TodoHomeScreen({Key? key}) : super(key: key);

  @override
  State<TodoHomeScreen> createState() => _TodoHomeScreenState();
}

class _TodoHomeScreenState extends State<TodoHomeScreen>
    with SingleTickerProviderStateMixin {
  final VoiceActivationService _voiceService = VoiceActivationService();
  final BiometricService _biometricService = BiometricService();
  final AdvancedChatService _chatService = AdvancedChatService();
  late final TodoService _todoService;

  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isListening = false;

  // Hardcoded user data for single-person app
  static const String USER_ID = 'personal_user_001';
  static const String USER_NAME = 'Praveen';
  static const String USER_EMAIL = 'praveen@example.com';
  static const String ADMIN_ID = 'admin_001';
  static const String ADMIN_NAME = 'Support Admin';

  @override
  void initState() {
    super.initState();
    _todoService = TodoService();
    _tabController = TabController(length: 3, vsync: this);
    _initializeVoiceActivation();
    _initializeChat();
  }

  /// Initialize chat room on app start
  Future<void> _initializeChat() async {
    try {
      await _chatService.createOrGetConversation(
        userId: USER_ID,
        userName: USER_NAME,
        userEmail: USER_EMAIL,
      );
      print('✓ Chat room initialized');
    } catch (e) {
      print('Error initializing chat: $e');
    }
  }

  Future<void> _initializeVoiceActivation() async {
    final available = await _voiceService.initializeSpeech();
    if (available) {
      print('✓ Voice activation ready');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  Future<void> _startVoiceListening() async {
    setState(() => _isListening = true);
    try {
      final recognizedText = await _voiceService.startListening();

      if (recognizedText != null) {
        final lowerText = recognizedText.toLowerCase();

        // Check for "open the praveen" - opens user chat
        if (lowerText.contains('open the praveen') ||
            lowerText.contains('open praveen')) {
          setState(() => _isListening = false);
          _openUserChat();
          return;
        }

        // Check for "open the admin" - opens admin chat with biometric
        if (lowerText.contains('open the admin') ||
            lowerText.contains('open admin')) {
          setState(() => _isListening = false);
          _authenticateAndOpenAdminChat();
          return;
        }

        // If no command detected
        setState(() => _isListening = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(''),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isListening = false);
      print('Error: $e');
      if (mounted) {
        _showErrorSnackBar('Voice recognition failed');
      }
    }
  }

  /// Check text input for commands
  void _checkTextInput(String text) {
    if (text.isEmpty) return;

    final lowerText = text.toLowerCase();

    // Check for "open the praveen" - opens user chat
    if (lowerText.contains('open the praveen') ||
        lowerText.contains('open praveen')) {
      _searchController.clear();
      setState(() => _searchQuery = '');
      _openUserChat();
      return;
    }

    // Check for "open the admin" - opens admin chat with biometric
    if (lowerText.contains('open the admin') ||
        lowerText.contains('open admin')) {
      _searchController.clear();
      setState(() => _searchQuery = '');
      _authenticateAndOpenAdminChat();
      return;
    }
  }

  /// Open user chat without authentication
  Future<void> _openUserChat() async {
    try {
      final conversationId = await _chatService.createOrGetConversation(
        userId: USER_ID,
        userName: USER_NAME,
        userEmail: USER_EMAIL,
      );

      if (conversationId != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EnhancedUserChatScreen(
              conversationId: conversationId,
              userId: USER_ID,
              userName: USER_NAME,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to open chat: $e');
      }
    }
  }

  /// Authenticate and open admin chat
  Future<void> _authenticateAndOpenAdminChat() async {
    try {
      final authenticated = await _biometricService.authenticate(
        reason: 'Authenticate to access admin panel',
        stickyAuth: true,
      );

      if (authenticated && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminChatScreen(),
          ),
        );
      } else if (mounted) {
        _showErrorSnackBar('Biometric authentication failed');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Authentication error: $e');
      }
    }
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
        title: const Text('Tasks'),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Completed'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isListening ? Colors.red : Colors.white,
            ),
            onPressed: _isListening ? null : _startVoiceListening,
            tooltip: 'Voice: "Open the Praveen" or "Open the Admin"',
          ),
          // PopupMenuButton(
          //   itemBuilder: (context) => [
          //     PopupMenuItem(
          //       child: const Text('Support Chat'),
          //       onTap: _openUserChat,
          //     ),
          //     PopupMenuItem(
          //       child: const Text('Admin Panel'),
          //       onTap: _authenticateAndOpenAdminChat,
          //     ),
          //     const PopupMenuDivider(),
          //     PopupMenuItem(
          //       child: const Text('Settings'),
          //       onTap: () => _navigateToSettings(),
          //     ),
          //   ],
          // ),
        ],
      ),
      body: Column(
        children: [
          // Search bar with command detection
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search ...',
                    // helperText:
                    // 'Commands: "Open the Praveen" (chat) | "Open the Admin" (admin panel)',
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
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                    _checkTextInput(value);
                  },
                ),
              ],
            ),
          ),
          // Task stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FutureBuilder<Map<String, int>>(
              future: _todoService.getTaskStats(_getCurrentUserId()),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final stats = snapshot.data ?? {};
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatCard('Total', stats['total']?.toString() ?? '0'),
                    _buildStatCard(
                        'Pending', stats['pending']?.toString() ?? '0'),
                    _buildStatCard(
                        'Completed', stats['completed']?.toString() ?? '0'),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Task lists
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTaskList(_todoService.getUserTasks(_getCurrentUserId())),
                _buildTaskList(
                    _todoService.getPendingTasks(_getCurrentUserId())),
                _buildTaskList(
                    _todoService.getCompletedTasks(_getCurrentUserId())),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'user_chat',
            mini: true,
            backgroundColor: Colors.green,
            onPressed: _openUserChat,
            tooltip: 'Open Support Chat',
            child: const Icon(Icons.chat),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'admin',
            mini: true,
            backgroundColor: Colors.purple,
            onPressed: _authenticateAndOpenAdminChat,
            tooltip: 'Admin Panel (Biometric Required)',
            child: const Icon(Icons.admin_panel_settings),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'voice',
            mini: true,
            backgroundColor: _isListening ? Colors.red : Colors.orange,
            onPressed: _isListening ? null : _startVoiceListening,
            tooltip: 'Voice Commands',
            child: Icon(_isListening ? Icons.stop : Icons.mic),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'add',
            onPressed: _navigateToAddTask,
            tooltip: 'Add task',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Card(
        color: const Color(0xFF2A2A2A),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF6366F1),
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskList(Stream<QuerySnapshot> tasksStream) {
    return StreamBuilder<QuerySnapshot>(
      stream: tasksStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.check_circle_outline,
                    size: 80, color: Colors.white24),
                SizedBox(height: 16),
                Text('No tasks'),
                SizedBox(height: 8),
                Text('Create a new task to get started'),
              ],
            ),
          );
        }

        final tasks = snapshot.data!.docs;
        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return _buildTaskTile(task);
          },
        );
      },
    );
  }

  Widget _buildTaskTile(DocumentSnapshot task) {
    final isCompleted = task['isCompleted'] ?? false;
    final priority = task['priority'] ?? 'medium';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: const Color(0xFF2A2A2A),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Checkbox(
                value: isCompleted,
                onChanged: (value) {
                  _todoService.markTaskCompleted(task.id, value ?? false);
                },
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TaskDetailScreen(
                          taskId: task.id,
                          taskData: task.data() as Map<String, dynamic>,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task['title'] ?? '',
                        style: TextStyle(
                          decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task['description'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              _buildPriorityBadge(priority),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    final colors = {
      'high': const Color(0xFFEF5350),
      'medium': const Color(0xFFFFA726),
      'low': const Color(0xFF66BB6A),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors[priority],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        priority,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _getCurrentUserId() => USER_ID;

  void _navigateToAddTask() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(userId: USER_ID),
      ),
    );
  }

  void _navigateToSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('App Version: 1.0.0'),
            const SizedBox(height: 12),
            const Text('User Information:'),
            const SizedBox(height: 8),
            Text('Name: $USER_NAME'),
            Text('Email: $USER_EMAIL'),
            Text('User ID: $USER_ID'),
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
}