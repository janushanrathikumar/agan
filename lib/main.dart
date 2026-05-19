import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:restorant/startup%20page/signin_page.dart';
import 'package:restorant/startup%20page/start_page.dart';
import 'package:restorant/userscreen/signup_page.dart';
import 'firebase_options.dart';
import 'app_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const StartPage(),
      routes: {
        SignInPage.route: (_) => const SignInPage(),
        SignUpPage.route: (_) => const SignUpPage(),
      },
    );
  }
}
