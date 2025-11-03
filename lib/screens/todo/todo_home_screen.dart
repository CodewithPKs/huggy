// File: lib/screens/todo/todo_home_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/todo_service.dart';
import 'add_task_screen.dart';
import 'task_detail_screen.dart';

class TodoHomeScreen extends StatefulWidget {
  const TodoHomeScreen({Key? key}) : super(key: key);

  @override
  State<TodoHomeScreen> createState() => _TodoHomeScreenState();
}

class _TodoHomeScreenState extends State<TodoHomeScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final TodoService _todoService = TodoService();
  late String _currentUserId;
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.currentUser?.uid ?? '';
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
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
                hintText: 'Search tasks...',
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
              },
            ),
          ),
          // Task Statistics
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FutureBuilder<Map<String, int>>(
              future: _todoService.getTaskStats(_currentUserId),
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
                      'Pending',
                      stats['pending']?.toString() ?? '0',
                    ),
                    _buildStatCard(
                      'Completed',
                      stats['completed']?.toString() ?? '0',
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Task Lists
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTaskList(_todoService.getUserTasks(_currentUserId)),
                _buildTaskList(_todoService.getPendingTasks(_currentUserId)),
                _buildTaskList(_todoService.getCompletedTasks(_currentUserId)),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddTask(),
        child: const Icon(Icons.add),
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
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
                  Icons.check_circle_outline,
                  size: 80,
                  color: Colors.white24,
                ),
                const SizedBox(height: 16),
                Text(
                  'No tasks',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a new task to get started',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
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
    final dueDate = (task['dueDate'] as Timestamp).toDate();
    final isOverdue = !isCompleted && dueDate.isBefore(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: isOverdue && !isCompleted
            ? const Color(0xFF6366F1).withOpacity(0.1)
            : const Color(0xFF2A2A2A),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
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
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(width: 32),
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: isOverdue && !isCompleted
                        ? Colors.red
                        : Colors.white54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(dueDate),
                    style: TextStyle(
                      color: isOverdue && !isCompleted
                          ? Colors.red
                          : Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () {
                      _todoService.deleteTask(task.id);
                    },
                  ),
                ],
              ),
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

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  void _navigateToAddTask() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(userId: _currentUserId),
      ),
    ).then((_) {
      setState(() {});
    });
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
                title: const Text('Sort By'),
                onTap: () {},
              ),
              ListTile(
                title: const Text('Filter Tasks'),
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