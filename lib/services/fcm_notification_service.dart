// File: lib/services/fcm_notification_service.dart
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

class FCMNotificationService {
  static final FCMNotificationService _instance = FCMNotificationService._internal();

  factory FCMNotificationService() {
    return _instance;
  }

  FCMNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'huggy'
  );

  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  // Your Firebase Cloud Messaging Server Key
  // Get this from Firebase Console -> Project Settings -> Cloud Messaging -> Server Key
  static const String _serverKey = 'YOUR_FCM_SERVER_KEY_HERE';

  // Fixed IDs for single-person app
  static const String ADMIN_ID = 'admin_001';
  static const String USER_ID = 'personal_user_001';

  /// Initialize FCM
  Future<void> initialize() async {
    try {
      // Request notification permissions
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('✓ FCM permission status: ${settings.authorizationStatus}');

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('✓ FCM Token: $token');
        // Store token in Firestore for both users
        await _saveTokenToFirestore(USER_ID, token);
        await _saveTokenToFirestore(ADMIN_ID, token);
      }

      // Handle token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('✓ FCM Token refreshed: $newToken');
        _saveTokenToFirestore(USER_ID, newToken);
        _saveTokenToFirestore(ADMIN_ID, newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

      // Handle notification taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      print('✓ FCM Notification Service initialized');
    } catch (e) {
      print('✗ Error initializing FCM: $e');
    }
  }

  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        print('Local notification tapped: ${details.payload}');
      },
    );

    // Create notification channel for Android
    const channel = AndroidNotificationChannel(
      'chat_messages', // id
      'Chat Messages', // name
      description: 'Notifications for new chat messages',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Save FCM token to Firestore
  Future<void> _saveTokenToFirestore(String userId, String token) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'fcmToken': token,
        'lastTokenUpdate': DateTime.now(),
      }, SetOptions(merge: true));
      print('✓ FCM token saved for user: $userId');
    } catch (e) {
      print('✗ Error saving FCM token: $e');
    }
  }

  /// Get FCM token for a specific user
  Future<String?> _getFCMToken(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['fcmToken'] as String?;
    } catch (e) {
      print('✗ Error getting FCM token: $e');
      return null;
    }
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📨 Foreground message received: ${message.messageId}');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
    print('Data: ${message.data}');

    // Show local notification
    await _showLocalNotification(message);
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    print('🔔 Notification tapped: ${message.messageId}');
    // Navigate to chat screen if needed
    // You can use a global navigator key or callback
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      channelDescription: 'Notifications for new chat messages',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'New Message',
      message.notification?.body ?? 'You have a new message',
      details,
      payload: jsonEncode(message.data),
    );
  }

  /// ================================================
  /// SEND NOTIFICATIONS
  /// ================================================

  /// Send notification when ADMIN sends message to USER
  /// Shows FIXED "EDUCATIONAL" content
  Future<bool> sendAdminToUserNotification() async {
    try {
      final userToken = await _getFCMToken(USER_ID);

      if (userToken == null) {
        print('✗ User FCM token not found');
        return false;
      }

      // 🔴 FIXED EDUCATIONAL CONTENT
      final payload = {
        'notification': {
          'title': 'Educational Update',
          'body': 'New educational content is available. Check it out now!',
          'sound': 'default',
        },
        'priority': 'high',
        'data': {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'type': 'educational',
          'senderId': ADMIN_ID,
          'timestamp': DateTime.now().toIso8601String(),
        },
        'to': userToken,
      };

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_serverKey',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        print('✓ Admin notification sent to user');
        return true;
      } else {
        print('✗ Failed to send notification: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('✗ Error sending admin notification: $e');
      return false;
    }
  }

  /// Send notification when USER sends message to ADMIN
  /// Triggers on EACH message
  Future<bool> sendUserToAdminNotification({
    required String messageText,
    required String userName,
  }) async {
    try {
      final adminToken = await _getFCMToken(ADMIN_ID);

      if (adminToken == null) {
        print('✗ Admin FCM token not found');
        return false;
      }

      // Show actual message content to admin
      final payload = {
        'notification': {
          'title': 'New message from $userName',
          'body': messageText.length > 100
              ? '${messageText.substring(0, 100)}...'
              : messageText,
          'sound': 'default',
        },
        'priority': 'high',
        'data': {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'type': 'user_message',
          'senderId': USER_ID,
          'senderName': userName,
          'messageText': messageText,
          'timestamp': DateTime.now().toIso8601String(),
        },
        'to': adminToken,
      };

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_serverKey',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        print('✓ User notification sent to admin');
        return true;
      } else {
        print('✗ Failed to send notification: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('✗ Error sending user notification: $e');
      return false;
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📨 Background message: ${message.messageId}');
}