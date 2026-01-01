import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:futaba_ai_live/src/data/hive_chat_repository.dart';
import 'package:futaba_ai_live/src/domain/message.dart';
import 'package:futaba_ai_live/src/state/chat_provider.dart';
import 'package:futaba_ai_live/src/presentation/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load connection strings and settings
  await dotenv.load();
  
  // Hive Initialization
  await Hive.initFlutter();
  Hive.registerAdapter(MessageAdapter());
  
  // Open Box
  final messageBox = await Hive.openBox<Message>('messages');
  final chatRepository = HiveChatRepository(messageBox);

  runApp(
    ProviderScope(
      overrides: [
        chatRepositoryProvider.overrideWithValue(chatRepository),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '双葉トーク',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFA8D3C4), // Character Hair Color (Mint Green)
          primary: const Color(0xFF8DB8A8),
          secondary: const Color(0xFF4FA8E5), // Character Eye Color (Cyan Blue)
          surface: const Color(0xFFF0F4F2),
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.notoSansJpTextTheme(
          Theme.of(context).textTheme,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF0F4F2),
          centerTitle: false,
          elevation: 0,
        ),
      ),
      home: const ChatScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
