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

const kSplashBg = Color(0xFF112A18);
const kSplashSpinner = Color(0xFFE49024);

// 🟢 Central place for every named route string, so nothing typos '/uesr'
// somewhere and silently 404s.
class AppRoutes {
  static const start = '/';
  static const signIn = '/signin';
  static const signUp = '/signup';
  static const user = '/user';
  static const admin = '/admin';
  static const privacy = '/privacy';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🟢 Removes the '#' from web URLs, so the address bar shows
  // e.g. localhost:3000/user or localhost:3000/admin instead of
  // localhost:3000/#/user. No-op on mobile/desktop.
  usePathUrlStrategy();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Firebase.initializeApp(
    name: 'SecondaryDb',
    options: SecondaryFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
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
      // 🟢 '/' is the entry point every time the app is opened/refreshed.
      // AuthGate figures out signed-in state + role, then REPLACES itself
      // with the correct named route so the URL bar actually updates to
      // /user or /admin (instead of just swapping the widget in place).
      initialRoute: '/',
      routes: {
        '/': (_) => const AuthGate(),
        AppRoutes.start: (_) => const StartPage(),
        AppRoutes.signIn: (_) => const SignInPage(),
        AppRoutes.signUp: (_) => const SignUpPage(),
        AppRoutes.user: (_) => const AppShell(),
        AppRoutes.admin: (_) => const AdminHome(),
        AppRoutes.privacy: (_) => const PrivacyPolicyPage(),
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// AuthGate: sits at '/'. Listens to auth state + Firestore role, then
// pushReplacementNamed's to wherever the user actually belongs. This runs
// on: first launch, every full page refresh (F5) on web, and after
// sign-out redirects back to '/'.
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
    FirebaseAuth.instance.authStateChanges().first.then(_resolve);
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

      final data = doc.data() as Map<String, dynamic>? ?? {};
      final bool verified = data['verified'] == true;
      final String role =
          (data['role'] as String?)?.toLowerCase().trim() ?? 'customer';

      // 🟢 Unverified account (OTP started but never finished) — resend
      // the code and drop them back into the verify screen instead of
      // routing them to a home page they shouldn't see yet.
      if (!verified) {
        final phone = data['phone'] as String? ?? '';
        final userName = data['userName'] as String? ?? 'Guest';
        final email = data['email'] as String? ?? user.email ?? '';

        if (phone.isEmpty) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.start);
          return;
        }

        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: phone.startsWith('+') ? phone : '+$phone',
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
                  verificationId: verificationId,
                  phoneNumber: phone,
                  userName: userName,
                  email: email,
                  password: '',
                ),
              ),
            );
          },
          codeAutoRetrievalTimeout: (_) {},
        );
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
