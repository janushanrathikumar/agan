// lib/user/app_bar.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:restorant/startup%20page/signin_page.dart';

import 'package:restorant/user/home.dart';
import 'package:restorant/user/menu.dart';
import 'package:restorant/user/OrderDetails.dart';
import 'package:restorant/user/AccountPage.dart';

import '../language.dart';

const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF112A18);
const kMuted = Color(0xFFA1B3A1);
const kWhite = Color(0xFFF7F7F2);
const kDarkBar = Color(0xFF0C1E11);
const kDiscount = Color(0xFFE0483E);

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _onBottomTap(int i) => setState(() => _index = i);

  void _toggleLanguage() {
    setState(() {
      AppLanguage.currentLanguage = AppLanguage.currentLanguage == 'de'
          ? 'en'
          : 'de';
    });
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: kWhite.withOpacity(0.2)),
        ),
        title: const Text(
          'Logout',
          style: TextStyle(color: kWhite, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: kMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: kMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kDiscount,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SignInPage()),
                  (route) => false,
                );
              }
            },
            child: const Text('Logout', style: TextStyle(color: kWhite)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final String uid = user.uid;

        // 1. Delete the user document from Firestore collection 'user'
        await FirebaseFirestore.instance.collection('user').doc(uid).delete();

        // 2. Delete the user from Firebase Auth
        await user.delete();

        if (context.mounted) {
          // Navigate to Login Page after successful deletion
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const SignInPage()),
            (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This action requires recent authentication. Please log out, log back in, and try again.',
              ),
              backgroundColor: kDiscount,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting account: ${e.message}'),
              backgroundColor: kDiscount,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An unexpected error occurred while deleting.'),
            backgroundColor: kDiscount,
          ),
        );
      }
    }
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: kDiscount.withOpacity(0.5)),
        ),
        title: const Text(
          'Delete Account',
          style: TextStyle(color: kDiscount, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to permanently delete your account? This will erase all your data and cannot be undone.',
          style: TextStyle(color: kMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: kMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kDiscount,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteAccount(context);
            },
            child: const Text('Delete', style: TextStyle(color: kWhite)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPasswordResetEmail(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null && user.email!.isNotEmpty) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password reset link sent to your email!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: kDiscount,
            ),
          );
        }
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No email associated with this account.'),
            backgroundColor: kDiscount,
          ),
        );
      }
    }
  }

  void _showChangePasswordDialog(BuildContext context) {
    final TextEditingController passwordController = TextEditingController();
    bool obscure = true;
    bool isUpdating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: kBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: kWhite.withOpacity(0.2)),
            ),
            title: const Text(
              'Change Password',
              style: TextStyle(color: kWhite, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: passwordController,
                  obscureText: obscure,
                  style: const TextStyle(color: kWhite),
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    labelStyle: const TextStyle(color: kMuted),
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: kMuted,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility : Icons.visibility_off,
                        color: kMuted,
                      ),
                      onPressed: () => setState(() => obscure = !obscure),
                    ),
                    filled: true,
                    fillColor: kWhite.withOpacity(0.06),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: kWhite.withOpacity(0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: kPrimary, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isUpdating ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: kMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isUpdating
                    ? null
                    : () async {
                        final newPassword = passwordController.text.trim();
                        if (newPassword.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Password must be at least 6 characters.',
                              ),
                              backgroundColor: kDiscount,
                            ),
                          );
                          return;
                        }

                        setState(() => isUpdating = true);
                        try {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            await user.updatePassword(newPassword);
                            if (context.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Password updated successfully!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        } on FirebaseAuthException catch (e) {
                          setState(() => isUpdating = false);
                          if (e.code == 'requires-recent-login') {
                            if (context.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'This action requires recent authentication. Please log out and log back in.',
                                  ),
                                  backgroundColor: kDiscount,
                                ),
                              );
                            }
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.message ?? 'Error updating password',
                                  ),
                                  backgroundColor: kDiscount,
                                ),
                              );
                            }
                          }
                        }
                      },
                child: isUpdating
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          color: kWhite,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Update', style: TextStyle(color: kWhite)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<_TabDef> tabs = [
      _TabDef(
        AppLanguage.getText('home'),
        Icons.home_rounded,
        const HomePage(),
      ),
      _TabDef(
        AppLanguage.getText('menu'),
        Icons.restaurant_menu_rounded,
        const MenuPage(),
      ),
      _TabDef(
        AppLanguage.getText('Orders'),
        Icons.receipt_long_rounded,
        const MyOrdersPage(),
      ),
      _TabDef(
        AppLanguage.getText('account'),
        Icons.person_rounded,
        const AccountPage(),
      ),
    ];

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snap) {
        final user = snap.data;
        final display = (user?.displayName?.trim().isNotEmpty ?? false)
            ? user!.displayName!.trim()
            : (user?.email?.split('@').first ?? 'Guest');

        return Scaffold(
          backgroundColor: kBg,
          appBar: AppBar(
            backgroundColor: kBg,
            foregroundColor: kWhite,
            elevation: 0,
            toolbarHeight: 70,
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/logo.jpeg',
                    height: 40,
                    width: 40,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppLanguage.getText('welcome'),
                        style: TextStyle(
                          color: kMuted.withOpacity(0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        display,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              // --- UPDATED: Glassmorphism Language Toggle (Matches Start Page) ---
              Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: kWhite.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kWhite.withOpacity(0.2)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _toggleLanguage,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.language, color: kWhite, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            AppLanguage.getText('lang_toggle'),
                            style: const TextStyle(
                              color: kWhite,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // --- Settings Menu ---
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: kDiscount.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kDiscount.withOpacity(0.3)),
                  ),
                  child: PopupMenuButton<String>(
                    color: kBg,
                    icon: const Icon(
                      Icons.settings,
                      color: kDiscount,
                      size: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: kWhite.withOpacity(0.2)),
                    ),
                    onSelected: (value) {
                      if (value == 'logout') {
                        _confirmLogout(context);
                      } else if (value == 'delete') {
                        _confirmDeleteAccount(context);
                      } else if (value == 'change_password') {
                        _showChangePasswordDialog(context);
                      } else if (value == 'reset_email') {
                        _sendPasswordResetEmail(context);
                      }
                    },
                    itemBuilder: (context) => [
                      // const PopupMenuItem(
                      //   value: 'change_password',
                      //   child: Row(
                      //     children: [
                      //       Icon(Icons.lock_reset, color: kWhite, size: 20),
                      //       SizedBox(width: 8),
                      //       Text(
                      //         'Change Password',
                      //         style: TextStyle(color: kWhite),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                      // const PopupMenuItem(
                      //   value: 'reset_email',
                      //   child: Row(
                      //     children: [
                      //       Icon(
                      //         Icons.mark_email_read,
                      //         color: kWhite,
                      //         size: 20,
                      //       ),
                      //       SizedBox(width: 8),
                      //       Text(
                      //         'Send Reset Email',
                      //         style: TextStyle(color: kWhite),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                      // const PopupMenuDivider(height: 1),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, color: kWhite, size: 20),
                            SizedBox(width: 8),
                            Text('Logout', style: TextStyle(color: kWhite)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_forever,
                              color: kDiscount,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Delete Account',
                              style: TextStyle(color: kDiscount),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: tabs[_index].page,
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: kDarkBar,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  height: 65,
                  backgroundColor: Colors.transparent,
                  indicatorColor: kPrimary.withOpacity(0.25),
                  iconTheme: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const IconThemeData(color: kPrimary, size: 26);
                    }
                    return const IconThemeData(color: kMuted, size: 24);
                  }),
                  labelTextStyle: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const TextStyle(
                        color: kPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      );
                    }
                    return const TextStyle(
                      color: kMuted,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    );
                  }),
                ),
                child: NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: _onBottomTap,
                  destinations: tabs
                      .map(
                        (t) => NavigationDestination(
                          icon: Icon(t.icon),
                          label: t.title,
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TabDef {
  final String title;
  final IconData icon;
  final Widget page;
  _TabDef(this.title, this.icon, this.page);
}
