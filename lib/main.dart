import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:todo/provider/call_manager_provider.dart';
import 'package:todo/screens/chat/enhanced_chat_screen.dart';
import 'package:todo/screens/chat/user_chat_screen.dart';
import 'package:todo/screens/todo/todo_home_screen.dart';
import 'firebase_options.dart';
import 'screens/auth/biometric_login_screen.dart';
import 'theme/dark_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(providers: [
      ChangeNotifierProvider(
        create: (_) => TextInputProvider(),
      ),

      // Chat state (reply, sending, uploads) - Granular updates
      ChangeNotifierProvider(
        create: (_) => ChatStateProvider(),
      ),



      // Messages list - Rebuilds only message list
      ChangeNotifierProvider(
        create: (_) => MessagesProvider(),
      ),

      // Image cache - Rebuilds only image widgets
      ChangeNotifierProvider(
        create: (_) => ImageCacheProvider(),
      ),

      // Video controllers - Rebuilds only video widgets
      ChangeNotifierProvider(
        create: (_) => VideoControllerProvider(),
      ),

      ChangeNotifierProvider(
        create: (_) => CallManagerProvider()
          ..initialize(userId: 'personal_chat_001'), // Initialize with user ID
      ),

      // ChangeNotifierProvider(
      //   create: (_) => CallManagerProvider()
      //     ..initialize(userId: 'admin'), // Initialize with user ID
      // ),
    ], child: const MyApp(),)

      );


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