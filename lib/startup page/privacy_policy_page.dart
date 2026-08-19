// lib/privacy_policy_page.dart
import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF112A18), // kSplashBg
      appBar: AppBar(
        backgroundColor: const Color(0xFF112A18),
        foregroundColor: Colors.white,
        title: const Text('Privacy Policy'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: const Text(
          '''Privacy Policy for Restaurant Kleefeld

Last updated: August 2026

1. Information We Collect
We collect information you provide directly to us when you create an account, such as your name, phone number, and email address.

2. How We Use Your Information
We use the information we collect to process your orders, manage your account, and improve our services.

3. Data Security
We implement standard security measures to protect your personal information...

(Paste your full privacy policy text here)
''',
          style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
        ),
      ),
    );
  }
}