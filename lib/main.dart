import 'package:flutter/material.dart';
import 'package:anzioworkshopapp/screens/main/login_page.dart';
import 'package:anzioworkshopapp/screens/main/register_page.dart';
import 'package:anzioworkshopapp/screens/main/menu_page.dart';
import 'package:anzioworkshopapp/screens/main/history_page.dart';
import 'package:anzioworkshopapp/screens/main/profile_page.dart';
import 'package:anzioworkshopapp/screens/main/session_verification_page.dart';
import 'package:anzioworkshopapp/screens/main/listtiket_page.dart';
import 'package:anzioworkshopapp/screens/main/sps_page.dart';
import 'package:anzioworkshopapp/screens/main/kesanpesan_page.dart';
import 'package:anzioworkshopapp/screens/operation/askme_page.dart';
import 'package:anzioworkshopapp/screens/operation/minigame/game_screen.dart';
import 'package:anzioworkshopapp/screens/operation/minigame/minigame_page.dart';
import 'package:anzioworkshopapp/screens/utils/biometric_help.dart';
import 'package:anzioworkshopapp/services/backend_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

String? _initError;

Future<bool> _isSecurityEnabledForCurrentUser() async {
  final technicianId =
      await BackendService.getTechnicianIdWithoutSessionCheck();
  if (technicianId == null) return false;

  final pinSet = await BiometricHelper.isPINSet(technicianId);
  final fingerprintEnabled = await BiometricHelper.isFingerPrintEnabled(
    technicianId,
  );
  final faceIdEnabled = await BiometricHelper.isFaceIdEnabled(technicianId);
  final genericBiometricEnabled = await BiometricHelper.isBiometricEnabled(
    technicianId,
  );

  return pinSet ||
      fingerprintEnabled ||
      faceIdEnabled ||
      genericBiometricEnabled;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
    await BackendService.initialize();
  } catch (e) {
    _initError = 'Failed to load .env file: $e';
  }

  runApp(MyApp(initError: _initError));
}

class MyApp extends StatefulWidget {
  final String? initError;

  const MyApp({super.key, this.initError});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _handleAppLifecycleState(state);
  }

  Future<void> _handleAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      final hasPersistent = await BackendService.hasPersistentLogin;
      final securityEnabled = await _isSecurityEnabled();

      if (hasPersistent && securityEnabled) {
        await BackendService.setAppLockRequired(true);
      } else {
        await BackendService.setAppLockRequired(false);
      }
    }
  }

  Future<bool> _isSecurityEnabled() async {
    final technicianId =
        await BackendService.getTechnicianIdWithoutSessionCheck();
    if (technicianId == null) return false;

    final pinSet = await BiometricHelper.isPINSet(technicianId);
    final fingerprintEnabled = await BiometricHelper.isFingerPrintEnabled(
      technicianId,
    );
    final faceIdEnabled = await BiometricHelper.isFaceIdEnabled(technicianId);
    final genericBiometricEnabled = await BiometricHelper.isBiometricEnabled(
      technicianId,
    );

    return pinSet ||
        fingerprintEnabled ||
        faceIdEnabled ||
        genericBiometricEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Coba-Coba Flutter',
      home: widget.initError != null
          ? ErrorScreen(message: widget.initError!)
          : const StartupPage(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomeScaffold(),
        '/history': (context) => const HistoryPage(),
        '/profile': (context) => const ProfilePage(),
        '/verify': (context) => const SessionVerificationPage(),
        '/list-tiket': (context) => const ListTiketPage(),
        '/sps-locator': (context) => const SpsPage(),
        '/askme': (context) => const AskMe(),
        '/kesan-pesan': (context) => const KesanPesanPage(),
        '/minigame': (context) => const MiniGamePage(),
        '/space-shooter': (context) => const GameScreen(),
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
                'Environment initialization failed.',
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

class StartupPage extends StatefulWidget {
  const StartupPage({super.key});

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  late Future<String?> _routeFuture;

  @override
  void initState() {
    super.initState();
    _routeFuture = _determineRoute();
  }

  Future<String?> _determineRoute() async {
    // If app was locked because it was closed/backgrounded, request verification
    final appLocked = await BackendService.isAppLockRequired;
    if (appLocked) {
      if (await _isSecurityEnabledForCurrentUser()) {
        return '/verify';
      }
      await BackendService.setAppLockRequired(false);
    }

    // Check if user is logged in with valid session
    final isLoggedIn = await BackendService.isLoggedIn;
    if (isLoggedIn) {
      return '/home';
    }

    // Check if session expired but user has persistent login
    final isSessionExpired = await BackendService.isSessionExpired;
    if (isSessionExpired) {
      if (await _isSecurityEnabledForCurrentUser()) {
        return '/verify';
      }
      await BackendService.refreshSession();
      return '/home';
    }

    // Check if just checking session expired flag
    final sessionExpiredFlag = await BackendService.checkSessionExpired();
    if (sessionExpiredFlag) {
      if (await _isSecurityEnabledForCurrentUser()) {
        return '/verify';
      }
      await BackendService.refreshSession();
      return '/home';
    }

    // No persistent login, go to login page
    return '/login';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _routeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, snapshot.data!);
          });
        }

        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
