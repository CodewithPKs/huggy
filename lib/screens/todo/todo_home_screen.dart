// File: lib/screens/todo/todo_home_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/biometric_service.dart';
import '../../services/todo_service.dart';
import '../../services/voice_activation_service.dart';
import '../chat/chat_home_screen.dart';
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
  late final TodoService _todoService; // ✅ non-nullable and initialized

  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _todoService = TodoService(); // ✅ Initialize service here
    _tabController = TabController(length: 3, vsync: this);
    _initializeVoiceActivation();
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

      if (recognizedText != null &&
          _voiceService.isActivationKeywordDetected(recognizedText)) {
        _authenticateAndOpenChat();
      } else {
        setState(() => _isListening = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Say "Open the Praveen" to access chat'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isListening = false);
      print('Error: $e');
    }
  }

  Future<void> _authenticateAndOpenChat() async {
    try {
      final authenticated = await _biometricService.authenticate(
        reason: 'Authenticate to access chat',
        stickyAuth: true,
      );

      if (authenticated && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ChatHomeScreen()),
        );
      }
    } catch (e) {
      print('Authentication error: $e');
      setState(() => _isListening = false);
    }
  }

  void _checkTextInput(String text) {
    if (_voiceService.isActivationKeywordDetected(text)) {
      _authenticateAndOpenChat();
    }
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
            tooltip: 'Voice activation: Say "Open the Praveen"',
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Settings'),
                onTap: () => _navigateToSettings(),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search tasks... (or say "Open the Praveen")',
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
                    _buildStatCard('Pending', stats['pending']?.toString() ?? '0'),
                    _buildStatCard('Completed', stats['completed']?.toString() ?? '0'),
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
                _buildTaskList(_todoService.getPendingTasks(_getCurrentUserId())),
                _buildTaskList(_todoService.getCompletedTasks(_getCurrentUserId())),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'voice',
            mini: true,
            backgroundColor: _isListening ? Colors.red : Colors.orange,
            onPressed: _isListening ? null : _startVoiceListening,
            tooltip: 'Voice: "Open the Praveen"',
            child: Icon(_isListening ? Icons.stop : Icons.mic),
          ),
          const SizedBox(height: 16),
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
                Icon(Icons.check_circle_outline, size: 80, color: Colors.white24),
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
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
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

  String _getCurrentUserId() => 'personal_user';

  void _navigateToAddTask() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTaskScreen(userId: '',)),
    );
  }

  void _navigateToSettings() {
    // Add settings navigation here
  }
}
