import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:anzioworkshopapp/screens/main/login_page.dart';
import 'package:anzioworkshopapp/screens/main/register_page.dart';
import 'package:anzioworkshopapp/screens/main/menu_page.dart';
import 'package:anzioworkshopapp/screens/main/history_page.dart';
import 'package:anzioworkshopapp/screens/main/profile_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

String? _supabaseInitError;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    _supabaseInitError = 'Failed to load .env file: $e';
  }

  if (_supabaseInitError == null) {
    try {
      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL']!,
        anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
      );
    } catch (e) {
      _supabaseInitError = 'Supabase initialization failed: $e';
    }
  }

  runApp(MyApp(initError: _supabaseInitError));
}

class MyApp extends StatelessWidget {
  final String? initError;

  const MyApp({super.key, this.initError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Coba-Coba Flutter',
      home: initError != null
          ? ErrorScreen(message: initError!)
          : const LoginPage(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomeScaffold(),
        '/history': (context) => const HistoryPage(),
        '/profile': (context) => const ProfilePage(),
      },
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final String message;

  const ErrorScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Initialization Error')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Supabase initialization failed.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }
}
