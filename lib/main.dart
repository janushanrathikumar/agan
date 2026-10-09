// lib/main.dart
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:restorant/kitchen/bar.dart';
import 'package:restorant/kitchen/kitchen.dart';
import 'package:restorant/user/scan_landing_page.dart';

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
import 'package:restorant/shared/startup_views.dart';
import 'package:restorant/shared/table_registry.dart' show fetchUserRole;

// 🟢 Central place for every named route string
class AppRoutes {
  static const start = '/start';
  static const signIn = '/signin';
  static const signUp = '/signup';
  static const user = '/user';
  static const admin = '/admin';
  static const privacy = '/privacy';
  static const forgotPassword = '/forgot-password';

  // 🟢 புதிதாக சேர்க்கப்பட்ட Routes
  static const kitchen = '/kitchen';
  static const bar = '/bar';

  // 🟢 Chair QR codes point here: /scan?t=<tableId>&c=<chairId>
  static const scan = '/scan';
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
  Widget build(BuildContext context) => MyApp(initialization: initialization);
}

class MyApp extends StatelessWidget {
  const MyApp({required this.initialization, super.key});

  final Future<void> initialization;

  /// The customer app is open to guests: the menu can be browsed without an
  /// account, and [requireLogin] puts the sign in popup in front of the actions
  /// that actually need one. The admin panel stays behind [RouteGuard], so a
  /// link shared to another device shows the start page until someone signs in.
  /// Kitchen and Bar carry their own station login.
  static final Map<String, WidgetBuilder> appRoutes = {
    '/': (_) => const AuthGate(),
    AppRoutes.start: (_) => const StartPage(),
    AppRoutes.signIn: (_) => const SignInPage(),
    AppRoutes.signUp: (_) => const SignUpPage(),
    AppRoutes.user: (_) => const AppShell(),
    AppRoutes.admin: (_) =>
        const RouteGuard(requiredRole: 'admin', child: AdminHome()),
    AppRoutes.privacy: (_) => const PrivacyPolicyPage(),
    AppRoutes.forgotPassword: (_) => const ForgotPasswordPage(),
    AppRoutes.kitchen: (_) => const KitchenPage(),
    AppRoutes.bar: (_) => const BarPage(),
  };

  /// Resolves a route name that may carry a query string.
  ///
  /// With `usePathUrlStrategy()` the route name a web deep link arrives with is
  /// the full `path + query` (e.g. `/scan?t=x&c=y`), which never matches an
  /// entry in [appRoutes] by string equality — so match on the parsed path and
  /// hand the query parameters to the page that needs them.
  static Route<void>? _routeFor(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? '/');

    if (uri.path == AppRoutes.scan) {
      return MaterialPageRoute<void>(
        builder: (_) => ScanLandingPage(
          tableId: uri.queryParameters['t'],
          chairId: uri.queryParameters['c'],
          chairNo: int.tryParse(uri.queryParameters['n'] ?? ''),
        ),
        settings: settings,
      );
    }

    final builder = appRoutes[uri.path];
    if (builder == null) return null;
    return MaterialPageRoute<void>(builder: builder, settings: settings);
  }

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
      routes: appRoutes,
      // 🟢 A deep link such as '/kitchen' opens that page on its own, instead
      // of stacking it on top of the AuthGate (whose job is only to decide
      // where a bare '/' visit should land).
      onGenerateInitialRoutes: (initialRouteName) {
        return [
          _routeFor(RouteSettings(name: initialRouteName)) ??
              MaterialPageRoute<void>(
                builder: (_) => const AuthGate(),
                settings: const RouteSettings(name: '/'),
              ),
        ];
      },
      // 🟢 Needed for '/scan?t=…&c=…': the `routes` map can only match a route
      // name exactly, so a URL carrying a query string never matches it.
      onGenerateRoute: _routeFor,
      // An address that matches nothing goes through the AuthGate, which sends
      // signed-out visitors to the start page.
      onUnknownRoute: (settings) => MaterialPageRoute<void>(
        builder: (_) => const AuthGate(),
        settings: const RouteSettings(name: '/'),
      ),
      // 🔴 Firebase must be ready before any page touches Auth or Firestore.
      // Gating here — rather than swapping in a second MaterialApp — keeps a
      // single Navigator alive, so the browser URL the user opened (e.g.
      // '/kitchen') is never overwritten while the app is still starting up.
      builder: (context, child) {
        return FutureBuilder<void>(
          future: initialization,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return StartupErrorView(error: snapshot.error!);
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const SplashView();
            }
            return child ?? const SplashView();
          },
        );
      },
    );
  }
}

/// Where each role belongs after signing in. Kitchen and Bar staff land
/// straight on their station board.
String homeRouteForRole(String role) {
  switch (role.toLowerCase().trim()) {
    case 'admin':
      return AppRoutes.admin;
    case 'kitchen':
      return AppRoutes.kitchen;
    case 'bar':
      return AppRoutes.bar;
    default:
      return AppRoutes.user;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// RouteGuard: keeps a pasted link from opening a page it should not.
//
// Only the Kitchen and Bar boards are meant to be opened straight from a URL
// (they carry their own station login). Every other protected page goes
// through here, so pasting '/user' or '/admin' into a browser on another
// device lands on the start page until somebody actually signs in.
// ─────────────────────────────────────────────────────────────────────────
class RouteGuard extends StatefulWidget {
  const RouteGuard({required this.child, this.requiredRole, super.key});

  final Widget child;

  /// When set, the signed-in account must hold this exact role.
  final String? requiredRole;

  @override
  State<RouteGuard> createState() => _RouteGuardState();
}

class _RouteGuardState extends State<RouteGuard> {
  bool _allowed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    try {
      // On a cold page load Firebase restores the session asynchronously, so
      // waiting for the first auth event is what stops a signed-in user from
      // being bounced out of their own link.
      var user = FirebaseAuth.instance.currentUser;
      user ??= await FirebaseAuth.instance.authStateChanges().first;

      if (!mounted) return;

      if (user == null) {
        _redirect(AppRoutes.start);
        return;
      }

      final required = widget.requiredRole;
      if (required != null) {
        final role = await fetchUserRole(user.uid);
        if (!mounted) return;
        if (role != required.toLowerCase()) {
          // Signed in, but not for this page - send them to their own home
          // rather than stranding them.
          _redirect(homeRouteForRole(role));
          return;
        }
      }

      setState(() => _allowed = true);
    } catch (error, stackTrace) {
      debugPrint('RouteGuard failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) _redirect(AppRoutes.start);
    }
  }

  void _redirect(String route) {
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return _allowed ? widget.child : const SplashView();
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
      if (!mounted || !_canRedirect) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.start);
    }
  }

  // 🟢 பயனர் நேரடியாக /kitchen அல்லது /bar URL-ஐ உள்ளிடும்போது AuthGate
  // அவர்களை /start-க்கு மாற்றுவதைத் தடுக்கும் சோதனை.
  // pushReplacement always replaces the *topmost* route, so the AuthGate must
  // never redirect while some other page is on screen above it.
  bool get _canRedirect =>
      mounted && (ModalRoute.of(context)?.isCurrent ?? false);

  String _homeRouteFor(String role) => homeRouteForRole(role);

  Future<void> _resolve(User? user) async {
    if (!_canRedirect) return;

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
      Navigator.of(context).pushReplacementNamed(_homeRouteFor(role));
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
