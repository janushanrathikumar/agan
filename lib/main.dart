// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // FirebaseAuth இணைக்கப்பட்டுள்ளது

import 'package:restorant/startup%20page/signin_page.dart';
import 'package:restorant/startup%20page/start_page.dart';
import 'package:restorant/userscreen/signup_page.dart'; // உங்களின் சரியான Path-ஐ உறுதிப்படுத்தவும்
import 'firebase_options.dart';
import 'secondary_firebase_options.dart';
import 'app_bar.dart'; // AppShell / Home Page இங்கே உள்ளதால் இது இணைக்கப்பட்டுள்ளது

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Firebase.initializeApp(
    name: 'SecondaryDb', // இந்த பெயர் PaymentPage-ல் நாம் பயன்படுத்தியது
    options: SecondaryFirebaseOptions.currentPlatform, // புதிய க்ளாஸை இங்கே அழைக்கிறோம்
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
        // உங்கள் லோகோவின் ஆரஞ்சு நிறத்தை Primary Color ஆக அமைத்துள்ளேன்
        colorSchemeSeed: const Color(0xFFE49024),
      ),

      // StreamBuilder மூலம் Login State-ஐ கண்காணிக்கிறோம்
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. Firebase இணைப்புக்காக காத்திருக்கும் போது லோடிங் திரையைக் காட்டுதல்
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF112A18), // லோகோ கரும்பச்சை
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFFE49024)),
              ),
            );
          }

          // 2. பயனர் ஏற்கனவே லாகின் செய்திருந்தால், நேரடியாக AppShell (Home) பக்கத்திற்குச் செல்லும்
          if (snapshot.hasData && snapshot.data != null) {
            return const AppShell();
          }

          // 3. பயனர் லாகின் செய்யவில்லை (அல்லது Logout செய்துவிட்டார்) என்றால் StartPage-க்குச் செல்லும்
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
