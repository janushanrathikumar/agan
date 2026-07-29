// lib/user/account_page.dart
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'menu.dart';
import 'OrderDetails.dart';
import '../startup page/signin_page.dart';

const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF112A18);
const kMuted = Color(0xFFA1B3A1);
const kWhite = Color(0xFFF7F7F2);

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  Future<void> _signOut(BuildContext context) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: kBg.withOpacity(0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: kWhite.withOpacity(0.15)),
            ),
            title: const Text(
              'Logout',
              style: TextStyle(color: kWhite, fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'Are you sure you want to logout from your account?',
              style: TextStyle(color: kMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: kMuted)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Logout',
                  style: TextStyle(color: kWhite, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pushNamedAndRemoveUntil(SignInPage.route, (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final bool isGuest = (user == null || user.isAnonymous);

    return Scaffold(
      backgroundColor: kBg,
      // 🟢 AppBar முற்றிலும் நீக்கப்பட்டுவிட்டது (இப்போது Back Arrow வராது)
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF194D25), Color(0xFF0C1E11)],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Account',
                        style: TextStyle(
                          color: kWhite,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kWhite.withOpacity(0.08),
                          shape: BoxShape.circle,
                          border: Border.all(color: kWhite.withOpacity(0.15)),
                        ),
                        child: const Icon(
                          Icons.settings_outlined,
                          color: kWhite,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Profile Header
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: kWhite.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: kWhite.withOpacity(0.15),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: kPrimary, width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 45,
                                backgroundColor: kPrimary.withOpacity(0.2),
                                child: Icon(
                                  isGuest ? Icons.person_outline : Icons.person,
                                  size: 45,
                                  color: kPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isGuest
                                  ? 'Guest User'
                                  : (user?.displayName ?? 'User'),
                              style: const TextStyle(
                                color: kWhite,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isGuest
                                  ? 'Sign in to sync your data'
                                  : (user?.email ?? ''),
                              style: TextStyle(
                                color: kMuted.withOpacity(0.9),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Navigation Cards
                  _buildGlassListTile(
                    context,
                    icon: Icons.receipt_long_rounded,
                    title: 'My Orders',
                    subtitle: 'View your active & past order history',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MyOrdersPage()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildGlassListTile(
                    context,
                    icon: Icons.restaurant_menu_rounded,
                    title: 'Manage Menu',
                    subtitle: 'Browse food items & categories',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MenuPage()),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Logout / Sign In Button
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isGuest
                              ? kPrimary.withOpacity(0.15)
                              : Colors.redAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isGuest
                                ? kPrimary.withOpacity(0.3)
                                : Colors.redAccent.withOpacity(0.3),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 6,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isGuest
                                  ? kPrimary.withOpacity(0.2)
                                  : Colors.redAccent.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isGuest
                                  ? Icons.login_rounded
                                  : Icons.logout_rounded,
                              color: isGuest ? kPrimary : Colors.redAccent,
                            ),
                          ),
                          title: Text(
                            isGuest ? 'Sign In' : 'Logout',
                            style: TextStyle(
                              color: isGuest ? kPrimary : Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: isGuest ? kPrimary : Colors.redAccent,
                            size: 16,
                          ),
                          onTap: () {
                            if (isGuest) {
                              Navigator.pushNamed(context, SignInPage.route);
                            } else {
                              _signOut(context);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: kWhite.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kWhite.withOpacity(0.1), width: 1),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: kPrimary, size: 22),
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
              style: TextStyle(color: kMuted.withOpacity(0.8), fontSize: 12.5),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios_rounded,
              color: kMuted.withOpacity(0.5),
              size: 16,
            ),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}
