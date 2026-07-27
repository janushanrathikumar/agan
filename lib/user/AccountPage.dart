import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'menu.dart';
import 'OrderDetails.dart';
// உங்கள் சைன்-இன் பக்கத்தின் பாத் (Path) சரியானதுதானா என சரிபார்க்கவும்
import '../startup page/signin_page.dart';

// --- Palette ---
const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);
const kCardBg = Color(0xFF383735);

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  Future<void> _signOut(BuildContext context) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('Logout', style: TextStyle(color: kWhite)),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: kMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: kMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: kWhite, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged out successfully.'),
            backgroundColor: kPrimary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // 🟢 லாக்-இன் செய்யவில்லை என்றால் Guest User
    final bool isGuest = (user == null || user.isAnonymous);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kWhite,
        title: const Text(
          'Account',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 🟢 Profile Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: kPrimary.withOpacity(0.2),
                    child: Icon(
                      isGuest ? Icons.person_outline : Icons.person,
                      size: 50,
                      color: kPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isGuest ? 'Guest User' : (user?.displayName ?? 'User'),
                    style: const TextStyle(
                      color: kWhite,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!isGuest)
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(color: kMuted, fontSize: 14),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // 🟢 Navigation List
            _buildListTile(
              context,
              icon: Icons.receipt_long,
              title: 'My Orders',
              subtitle: 'View your order history',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyOrdersPage()),
              ),
            ),

            const SizedBox(height: 12),

            _buildListTile(
              context,
              icon: Icons.restaurant_menu,
              title: 'Manage Menu',
              subtitle: 'View items',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MenuPage()),
              ),
            ),

            const SizedBox(height: 30),
            const Divider(color: kCardBg, thickness: 2),
            const SizedBox(height: 16),

            // 🟢 Conditional Logout / Sign In Button
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tileColor: isGuest
                  ? kPrimary.withOpacity(0.1)
                  : Colors.redAccent.withOpacity(0.1),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isGuest
                      ? kPrimary.withOpacity(0.2)
                      : Colors.redAccent.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isGuest ? Icons.login : Icons.logout,
                  color: isGuest ? kPrimary : Colors.redAccent,
                ),
              ),
              title: Text(
                isGuest ? 'Sign In' : 'Logout',
                style: TextStyle(
                  color: isGuest ? kPrimary : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                if (isGuest) {
                  Navigator.pushNamed(
                    context,
                    '/signin',
                  ); // உங்கள் SignIn Route-ஐ இங்கே கொடுக்கவும்
                } else {
                  _signOut(context);
                }
              },
            ),

            const SizedBox(height: 40),
            const Text(
              'App Version 1.0.0',
              style: TextStyle(color: kMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: kCardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: kBg, shape: BoxShape.circle),
        child: Icon(icon, color: kPrimary),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: kWhite,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: kMuted, fontSize: 13),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, color: kMuted, size: 16),
      onTap: onTap,
    );
  }
}
