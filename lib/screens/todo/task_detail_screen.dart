// File: lib/screens/todo/task_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/todo_service.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  final Map<String, dynamic> taskData;

  const TaskDetailScreen({
    Key? key,
    required this.taskId,
    required this.taskData,
  }) : super(key: key);

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final TodoService _todoService = TodoService();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  late String _selectedPriority;
  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.taskData['title']);
    _descriptionController =
        TextEditingController(text: widget.taskData['description']);
    _selectedDate = (widget.taskData['dueDate'] as Timestamp).toDate();
    _selectedPriority = widget.taskData['priority'] ?? 'medium';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _updateTask() async {
    if (_titleController.text.trim().isEmpty) {
      _showErrorDialog('Please enter a task title');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await _todoService.updateTask(
        docId: widget.taskId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dueDate: _selectedDate,
        priority: _selectedPriority,
      );

      if (success && mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task updated successfully')),
        );
      } else if (mounted) {
        _showErrorDialog('Failed to update task');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteTask() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _todoService.deleteTask(widget.taskId);
              if (success && mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Task deleted')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteTask,
          ),
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: () {
              setState(() => _isEditing = !_isEditing);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Field
              Text(
                'Title',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Enter task title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 1,
                enabled: _isEditing && !_isLoading,
              ),
              const SizedBox(height: 24),
              // Description Field
              Text(
                'Description',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  hintText: 'Enter task description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 4,
                enabled: _isEditing && !_isLoading,
              ),
              const SizedBox(height: 24),
              // Priority Selection
              Text(
                'Priority',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF404040)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<String>(
                  value: _selectedPriority,
                  isExpanded: true,
                  underline: const SizedBox(),
                  onChanged: (_isEditing && !_isLoading)
                      ? (value) {
                    setState(
                          () => _selectedPriority = value ?? 'medium',
                    );
                  }
                      : null,
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Due Date Selection
              Text(
                'Due Date',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: (_isEditing && !_isLoading) ? _selectDate : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF404040)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('MMMM dd, yyyy').format(_selectedDate),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Status
              Text(
                'Status',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.taskData['isCompleted'] == true
                          ? 'Completed'
                          : 'Pending',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Switch(
                      value: widget.taskData['isCompleted'] ?? false,
                      onChanged: (value) {
                        _todoService.markTaskCompleted(widget.taskId, value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Update Button (only show when editing)
              if (_isEditing)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateTask,
                    child: _isLoading
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                        : const Text('Update Task'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}