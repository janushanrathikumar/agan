import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:restorant/app_bar.dart';
import 'package:restorant/user/qr_scanner_page.dart';

// --- Shared palette (same as StartPage / AppShell) ---
const kPrimary = Color(0xFFA26334);
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);

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
      const SnackBar(
        content: Text('Take Away selected'),
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

  // NEW: Function to navigate to the Rewards tab in AppShell
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
      // MODIFIED: AppBar now shows a logo on the left instead of a text title
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        automaticallyImplyLeading: false, // Ensures no back arrow appears
        title: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Image.asset(
            'assets/logo.jpeg', // Path to your logo
            height: 35, // Adjust size as needed
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.userChanges(),
          builder: (context, snap) {
            // REMOVED: No longer need the user's name for a greeting
            // final u = snap.data;
            // final name = ...

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // REMOVED: "Hi, $name" text and the SizedBox below it are gone

                  // Top shortcuts: Rewards | Balance | QR
                  Row(
                    children: [
                      Expanded(
                        child: _TopCard(
                          label: 'Rewards',
                          icon: Icons.loyalty,
                          color: kPrimary,
                          // MODIFIED: onTap now navigates to the rewards tab
                          onTap: () => _navigateToRewardsTab(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TopCard(
                          label: 'Balance',
                          icon: Icons.account_balance_wallet,
                          color: kPrimary,
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TopCard(
                          label: 'QR Scanner',
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
                      color: kWhite.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kWhite.withOpacity(0.1)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
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
                          label: 'Dine In',
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
                          label: 'Take Away',
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

// Unchanged helper widgets below...

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
      color: kWhite.withOpacity(0.05),
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
      color: color,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
