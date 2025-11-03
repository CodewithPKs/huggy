// File: lib/screens/todo/add_task_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/todo_service.dart';

class AddTaskScreen extends StatefulWidget {
  final String userId;

  const AddTaskScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final TodoService _todoService = TodoService();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedPriority = 'medium';
  bool _isLoading = false;

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
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _addTask() async {
    if (_titleController.text.trim().isEmpty) {
      _showErrorDialog('Please enter a task title');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final taskId = await _todoService.addTask(
        userId: widget.userId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dueDate: _selectedDate,
        priority: _selectedPriority,
      );

      if (taskId != null && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task created successfully')),
        );
      } else if (mounted) {
        _showErrorDialog('Failed to create task');
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
        title: const Text('Add Task'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Field
              Text(
                'Task Title',
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
                enabled: !_isLoading,
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
                enabled: !_isLoading,
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
                  onChanged: _isLoading
                      ? null
                      : (value) {
                    setState(() => _selectedPriority = value ?? 'medium');
                  },
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
                onTap: _isLoading ? null : _selectDate,
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
              const SizedBox(height: 32),
              // Add Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addTask,
                  child: _isLoading
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                      : const Text('Add Task'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}