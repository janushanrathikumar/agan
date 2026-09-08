// lib/main.dart
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'package:restorant/startup page/signin_page.dart';
import 'package:restorant/startup page/privacy_policy_page.dart';
import 'package:restorant/startup page/start_page.dart';
import 'package:restorant/startup%20page/signup_page.dart';
import 'package:restorant/startup%20page/signupverify.dart';
import 'package:restorant/app_bar.dart'; // AppShell (customer)
import 'package:restorant/admin/adminhome.dart'; // AdminHome (admin)
import 'firebase_options.dart';
import 'secondary_firebase_options.dart';
import 'package:restorant/startup page/forgot_password_page.dart';

const kSplashBg = Color(0xFF112A18);
const kSplashSpinner = Color(0xFFE49024);

// 🟢 Central place for every named route string
class AppRoutes {
  static const start =
      '/start'; // Changed from '/' to prevent conflict with AuthGate
  static const signIn = '/signin';
  static const signUp = '/signup';
  static const user = '/user';
  static const admin = '/admin';
  static const privacy = '/privacy';
  static const forgotPassword = '/forgot-password';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Removes the '#' from web URLs. This must not run on Android/iOS.
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  final initialization = _initializeFirebase();
  runApp(FirebaseBootstrap(initialization: initialization));
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error, stackTrace) {
    debugPrint('Primary Firebase initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    rethrow;
  }

  // The secondary project is optional and must not delay the first web frame.
  unawaited(_initializeSecondaryFirebase());
}

Future<void> _initializeSecondaryFirebase() async {
  try {
    await Firebase.initializeApp(
      name: 'SecondaryDb',
      options: SecondaryFirebaseOptions.currentPlatform,
    );
  } catch (error, stackTrace) {
    debugPrint('Secondary Firebase initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class FirebaseBootstrap extends StatelessWidget {
  const FirebaseBootstrap({required this.initialization, super.key});

  final Future<void> initialization;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return StartupErrorApp(
            error: snapshot.error!,
            stackTrace: snapshot.stackTrace,
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: kSplashBg,
              body: Center(
                child: CircularProgressIndicator(color: kSplashSpinner),
              ),
            ),
          );
        }

        return const MyApp();
      },
    );
  }
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({required this.error, this.stackTrace, super.key});

  final Object error;
  final StackTrace? stackTrace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: kSplashBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: SelectableText(
                'The app could not start.\n\n$error',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Restaurant Kleefeld',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFE49024),
      ),
      // 🟢 '/' is the entry point (AuthGate). It will redirect to '/start', '/user', or '/admin'
      initialRoute: '/',
      routes: {
        '/': (_) => const AuthGate(),
        AppRoutes.start: (_) => const StartPage(),
        AppRoutes.signIn: (_) => const SignInPage(),
        AppRoutes.signUp: (_) => const SignUpPage(),
        AppRoutes.user: (_) => const AppShell(),
        AppRoutes.admin: (_) => const AdminHome(),
        AppRoutes.privacy: (_) => const PrivacyPolicyPage(),
        AppRoutes.forgotPassword: (_) => const ForgotPasswordPage(),
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// AuthGate: sits at '/'. Listens to auth state + Firestore role, then
// pushReplacementNamed's to wherever the user actually belongs.
// ─────────────────────────────────────────────────────────────────────────
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    unawaited(_listenForAuth());
  }

  Future<void> _listenForAuth() async {
    try {
      final user = await FirebaseAuth.instance.authStateChanges().first;
      await _resolve(user);
    } catch (error, stackTrace) {
      debugPrint('Firebase Auth startup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.start);
    }
  }

  Future<void> _resolve(User? user) async {
    if (!mounted) return;

    if (user == null) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.start);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('user')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (!doc.exists) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.start);
        return;
      }

      final data = doc.data() ?? {};
      final bool verified = data['verified'] == true;
      final String role =
          (data['role'] as String?)?.toLowerCase().trim() ?? 'customer';

      // 🟢 Unverified account (OTP started but never finished)
      if (!verified) {
        final phone = data['phone'] as String? ?? '';
        final userName = data['userName'] as String? ?? 'Guest';
        final email = data['email'] as String? ?? user.email ?? '';

        if (phone.isEmpty) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.start);
          return;
        }

        final formattedPhone = phone.startsWith('+') ? phone : '+$phone';

        // --- PLATFORM SPECIFIC AUTH FLOW FOR UNVERIFIED USERS ---
        if (kIsWeb) {
          try {
            ConfirmationResult confirmationResult = await FirebaseAuth.instance
                .signInWithPhoneNumber(formattedPhone);

            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => SignUpVerifyPage(
                  verificationId: null, // Null for Web
                  confirmationResult: confirmationResult, // Passed for Web
                  phoneNumber: formattedPhone,
                  userName: userName,
                  email: email,
                  password: '',
                ),
              ),
            );
          } catch (_) {
            if (!mounted) return;
            Navigator.of(context).pushReplacementNamed(AppRoutes.start);
          }
        } else {
          // Mobile Flow
          await FirebaseAuth.instance.verifyPhoneNumber(
            phoneNumber: formattedPhone,
            verificationCompleted: (_) {},
            verificationFailed: (_) {
              if (!mounted) return;
              Navigator.of(context).pushReplacementNamed(AppRoutes.start);
            },
            codeSent: (String verificationId, int? resendToken) {
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => SignUpVerifyPage(
                    verificationId: verificationId, // Passed for Mobile
                    confirmationResult: null, // Null for Mobile
                    phoneNumber: formattedPhone,
                    userName: userName,
                    email: email,
                    password: '',
                  ),
                ),
              );
            },
            codeAutoRetrievalTimeout: (_) {},
          );
        }
        return;
      }

      // 🟢 The actual URL-correcting step: named route, not a raw widget.
      Navigator.of(context).pushReplacementNamed(
        role == 'admin' ? AppRoutes.admin : AppRoutes.user,
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.start);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: kSplashBg,
      body: Center(child: CircularProgressIndicator(color: kSplashSpinner)),
    );
  }
}
