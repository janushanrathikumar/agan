// lib/user/home_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:restorant/user/menu.dart'; // Ensure this points to your MenuPage
import 'package:restorant/user/qr_scanner_page.dart';
import '../language.dart';

// --- Shared palette ---
const kPrimary = Color(0xFFE49024); // Orange
const kBg = Color(0xFF112A18); // Dark Green
const kMuted = Color(0xFFA1B3A1); // Muted Green
const kWhite = Color(0xFFF7F7F2); // Cream White

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // Handle Take Away Flow
  Future<void> _handleTakeAway(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Save initial state to Firestore
    await FirebaseFirestore.instance
        .collection('food_delivery')
        .doc(user.uid)
        .set({
          'delivery_method': 'Take_Away',
          'table_no': 'no',
          'timestamp': FieldValue.serverTimestamp(),
        });

    if (!context.mounted) return;

    // Navigate to MenuPage with tableNo = null (Take-Away)
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MenuPage(tableNo: null)),
    );
  }

  // Handle Dine In Flow
  Future<void> _handleDineIn(BuildContext context) async {
    // 1. Open Scanner and wait for the result (Table Number)
    final tableNo = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );

    // 2. If we got a table number, go to MenuPage
    if (tableNo != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MenuPage(tableNo: tableNo)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Image.asset('assets/logo.jpeg', height: 45),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Shortcuts
              Row(
                children: [
                  Expanded(
                    child: _TopCard(
                      label: AppLanguage.getText('rewards'),
                      icon: Icons.loyalty,
                      color: kPrimary,
                      onTap: () {},
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
                      onTap: () => _handleDineIn(context),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Advertisement
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: kWhite.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text("Promo Banner", style: TextStyle(color: kMuted)),
                ),
              ),

              const SizedBox(height: 24),

              // Main Actions
              Row(
                children: [
                  Expanded(
                    child: _BigActionButton(
                      label: AppLanguage.getText('dine_in'),
                      icon: Icons.restaurant,
                      color: kPrimary,
                      onTap: () => _handleDineIn(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BigActionButton(
                      label: AppLanguage.getText('take_away'),
                      icon: Icons.shopping_bag,
                      color: kPrimary,
                      onTap: () => _handleTakeAway(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper widgets
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
      color: kWhite.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
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
                maxLines: 1,
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
