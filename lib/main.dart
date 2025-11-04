import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:todo/screens/chat/enhanced_chat_screen.dart';
import 'package:todo/screens/todo/todo_home_screen.dart';
import 'firebase_options.dart';
import 'screens/auth/biometric_login_screen.dart';
import 'theme/dark_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dual Access App',
      debugShowCheckedModeBanner: false,
      theme: darkTheme,
      home: const TodoHomeScreen(),
      // home: const EnhancedChatScreen(),
    );

  }
}