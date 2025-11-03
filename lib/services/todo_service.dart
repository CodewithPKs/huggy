// File: lib/services/todo_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class TodoService {
  static final TodoService _instance = TodoService._internal();

  factory TodoService() {
    return _instance;
  }

  TodoService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Add a new task
  Future<String?> addTask({
    required String userId,
    required String title,
    required String description,
    required DateTime dueDate,
    String priority = 'medium',
  }) async {
    try {
      final docRef = await _firestore.collection('tasks').add({
        'userId': userId,
        'taskId': const Uuid().v4(),
        'title': title,
        'description': description,
        'dueDate': dueDate,
        'priority': priority,
        'isCompleted': false,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      });
      return docRef.id;
    } catch (e) {
      print('Error adding task: $e');
      return null;
    }
  }

  /// Get all tasks for user
  Stream<QuerySnapshot> getUserTasks(String userId) {
    return _firestore
        .collection('tasks')
        .where('userId', isEqualTo: userId)
        .orderBy('dueDate', descending: false)
        .snapshots();
  }

  /// Get completed tasks
  Stream<QuerySnapshot> getCompletedTasks(String userId) {
    return _firestore
        .collection('tasks')
        .where('userId', isEqualTo: userId)
        .where('isCompleted', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  /// Get pending tasks
  Stream<QuerySnapshot> getPendingTasks(String userId) {
    return _firestore
        .collection('tasks')
        .where('userId', isEqualTo: userId)
        .where('isCompleted', isEqualTo: false)
        .orderBy('dueDate', descending: false)
        .snapshots();
  }

  /// Get high priority tasks
  Stream<QuerySnapshot> getHighPriorityTasks(String userId) {
    return _firestore
        .collection('tasks')
        .where('userId', isEqualTo: userId)
        .where('priority', isEqualTo: 'high')
        .where('isCompleted', isEqualTo: false)
        .orderBy('dueDate', descending: false)
        .snapshots();
  }

  /// Update task
  Future<bool> updateTask({
    required String docId,
    required String title,
    required String description,
    required DateTime dueDate,
    required String priority,
  }) async {
    try {
      await _firestore.collection('tasks').doc(docId).update({
        'title': title,
        'description': description,
        'dueDate': dueDate,
        'priority': priority,
        'updatedAt': DateTime.now(),
      });
      return true;
    } catch (e) {
      print('Error updating task: $e');
      return false;
    }
  }

  /// Mark task as completed
  Future<bool> markTaskCompleted(String docId, bool isCompleted) async {
    try {
      await _firestore.collection('tasks').doc(docId).update({
        'isCompleted': isCompleted,
        'updatedAt': DateTime.now(),
      });
      return true;
    } catch (e) {
      print('Error updating task completion: $e');
      return false;
    }
  }

  /// Delete task
  Future<bool> deleteTask(String docId) async {
    try {
      await _firestore.collection('tasks').doc(docId).delete();
      return true;
    } catch (e) {
      print('Error deleting task: $e');
      return false;
    }
  }

  /// Get task statistics
  Future<Map<String, int>> getTaskStats(String userId) async {
    try {
      final allTasks = await _firestore
          .collection('tasks')
          .where('userId', isEqualTo: userId)
          .get();

      int totalTasks = allTasks.docs.length;
      int completedTasks = allTasks.docs
          .where((doc) => doc['isCompleted'] == true)
          .length;
      int pendingTasks = totalTasks - completedTasks;
      int highPriorityTasks = allTasks.docs
          .where((doc) => doc['priority'] == 'high' && doc['isCompleted'] == false)
          .length;

      return {
        'total': totalTasks,
        'completed': completedTasks,
        'pending': pendingTasks,
        'highPriority': highPriorityTasks,
      };
    } catch (e) {
      print('Error getting task stats: $e');
      return {
        'total': 0,
        'completed': 0,
        'pending': 0,
        'highPriority': 0,
      };
    }
  }

  /// Search tasks
  Future<QuerySnapshot> searchTasks(String userId, String searchQuery) async {
    try {
      return await _firestore
          .collection('tasks')
          .where('userId', isEqualTo: userId)
          .where('title', isGreaterThanOrEqualTo: searchQuery)
          .where('title', isLessThan: '${searchQuery}z')
          .get();
    } catch (e) {
      print('Error searching tasks: $e');
      rethrow;
    }
  }
}