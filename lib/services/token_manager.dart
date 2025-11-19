import 'dart:convert';
import 'dart:developer';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'agora_call_service.dart';

class TokenManager {
  static const String _tokenServerUrl = 'https://jiifto.onrender.com/rtc';
  static FirebaseFirestore _firebase = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'huggy');

  /// Fetch token from your backend
  static Future<String> fetchNewToken(int uid) async {

    final url = Uri.parse('$_tokenServerUrl/${AgoraConfig.fixedChannelName}/$uid');

    log("tokan : $url");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['token'];
    } else {
      throw Exception('Failed to fetch Agora token: ${response.statusCode} and ${response.body}');
    }
  }

  /// Update token in AgoraConfig and save to Firebase
  static Future<void> refreshTokenAndSave(int uid) async {
    try {
      final newToken = await fetchNewToken(uid);

      AgoraConfig.tempToken = newToken;

      print('✅ Agora token updated locally');

      // Save to Firebase Firestore
      await _firebase
          .collection('agora')
          .doc('config')
          .set({'token': newToken, 'timestamp': DateTime.now()});

      print('🔥 Token saved to Firebase');
    } catch (e) {
      print('❌ Failed to refresh token: $e');
    }
  }
}
