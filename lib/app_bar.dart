// lib/user/app_bar.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:restorant/startup%20page/signin_page.dart';

import 'package:restorant/user/home.dart';
import 'package:restorant/user/menu.dart';
import 'package:restorant/user/OrderDetails.dart';
import 'package:restorant/user/AccountPage.dart';
import 'package:restorant/startup%20page/signin_page.dart'; // Login page import

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
                // Navigate to Login Page and remove all previous routes
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
              Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kPrimary.withOpacity(0.3)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _toggleLanguage,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.language, color: kPrimary, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          AppLanguage.getText('lang_toggle').toUpperCase(),
                          style: const TextStyle(
                            color: kPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: kDiscount.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kDiscount.withOpacity(0.3)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _confirmLogout(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          color: kDiscount,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'LOGOUT',
                          style: TextStyle(
                            color: kDiscount,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
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
