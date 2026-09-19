// lib/shared/startup_views.dart
//
// The splash and fatal-error screens shown while Firebase starts up.
//
// These live outside main.dart so the per-station apps (lib/main_kitchen.dart,
// lib/main_bar.dart) can reuse them without importing main.dart, which would
// pull AuthGate, AdminHome and the customer AppShell into those builds.
import 'package:flutter/material.dart';

const kSplashBg = Color(0xFF112A18);
const kSplashSpinner = Color(0xFFE49024);

class StartupErrorView extends StatelessWidget {
  const StartupErrorView({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }
}

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: kSplashBg,
      body: Center(child: CircularProgressIndicator(color: kSplashSpinner)),
    );
  }
}
