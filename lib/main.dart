import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:restorant/startup page/signin_page.dart';
import 'package:restorant/startup page/start_page.dart';
import 'package:restorant/startup%20page/signup_page.dart';
import 'package:restorant/app_bar.dart'; // Ensure this points to your AppShell file
import 'firebase_options.dart';
import 'secondary_firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      // StreamBuilder handles auth state changes globally
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF112A18),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFFE49024)),
              ),
            );
          }
          if (snapshot.hasData && snapshot.data != null) {
            return const AppShell();
          }
          return const StartPage();
        },
      ),
      routes: {
        SignInPage.route: (_) => const SignInPage(),
        SignUpPage.route: (_) => const SignUpPage(),
      },
    );
  }
}
