// lib/user/home_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:restorant/app_bar.dart';
import 'package:restorant/user/qr_scanner_page.dart';
import '../language.dart'; // Language file இணைக்கப்பட்டுள்ளது (path-ஐ உங்கள் ப்ராஜெக்டிற்கு ஏற்ப சரிபார்க்கவும்)

// --- Shared palette (லோகோ நிறங்கள்) ---
const kPrimary = Color(0xFFE49024); // Orange
const kBg = Color(0xFF112A18); // Dark Green
const kMuted = Color(0xFFA1B3A1); // Muted Green
const kWhite = Color(0xFFF7F7F2); // Cream White

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _saveTakeAway(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('food_delivery')
        .doc(user.uid)
        .set({
          'delivery_method': 'Take_Away',
          'table_no': 'no',
          'timestamp': FieldValue.serverTimestamp(),
        });

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLanguage.getText('take_away_selected'),
          style: const TextStyle(color: kWhite, fontWeight: FontWeight.bold),
        ),
        backgroundColor: kPrimary,
      ),
    );

    // Navigate to AppShell Menu tab (index 1)
    Navigator.popUntil(context, (route) => route.isFirst);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AppShell()),
    );
  }

  // Function to navigate to the Rewards tab in AppShell
  void _navigateToRewardsTab(BuildContext context) {
    // Navigate to AppShell Reward tab (index 2)
    Navigator.popUntil(context, (route) => route.isFirst);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AppShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg, // கரும்பச்சை பின்னணி
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Image.asset(
            'assets/logo.jpeg', // உங்களின் லோகோ Path
            height: 45, // லோகோ தெளிவாக தெரிய அளவை சற்று அதிகரித்துள்ளேன்
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.userChanges(),
          builder: (context, snap) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top shortcuts: Rewards | Balance | QR
                  Row(
                    children: [
                      Expanded(
                        child: _TopCard(
                          label: AppLanguage.getText('rewards'),
                          icon: Icons.loyalty,
                          color: kPrimary,
                          onTap: () => _navigateToRewardsTab(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TopCard(
                          label: AppLanguage.getText('balance'),
                          icon: Icons.account_balance_wallet,
                          color: kPrimary,
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TopCard(
                          label: AppLanguage.getText('qr_scanner'),
                          icon: Icons.qr_code_scanner,
                          color: kPrimary,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const QrScannerPage(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Advertisement poster
                  Container(
                    decoration: BoxDecoration(
                      color: kWhite.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kWhite.withOpacity(0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Ink.image(
                          image: const NetworkImage(
                            'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=1200',
                          ),
                          fit: BoxFit.cover,
                          child: InkWell(onTap: () {}),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Dine In / Take Away
                  Row(
                    children: [
                      Expanded(
                        child: _BigActionButton(
                          label: AppLanguage.getText('dine_in'),
                          icon: Icons.restaurant,
                          color: kPrimary,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const QrScannerPage(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BigActionButton(
                          label: AppLanguage.getText('take_away'),
                          icon: Icons.shopping_bag,
                          color: kPrimary,
                          onTap: () => _saveTakeAway(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// Helper widgets...

class _TopCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _TopCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kWhite.withOpacity(0.08), // பட்டன்களின் பின்னணி நிறம்
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: kWhite,
                ),
                textAlign: TextAlign.center,
                maxLines:
                    1, // எழுத்துக்கள் நீளமாக இருந்தால் அடுத்த வரிக்கு செல்லாமல் தடுக்க
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _BigActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color, // ஆரஞ்சு நிறம்
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Icon(icon, color: kWhite, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: kWhite,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
