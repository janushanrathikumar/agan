import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:restorant/startup%20page/signin_page.dart';

import 'package:restorant/user/home.dart';
import 'package:restorant/user/menu.dart';
import 'package:restorant/user/OrderDetails.dart';
import 'package:restorant/user/AccountPage.dart';

import 'startup page/signin_page.dart';
import 'startup page/signup_page.dart';
import '../language.dart';

const kPrimary = Color(0xFFE49024);
const kBg = Color(0xFF112A18);
const kMuted = Color(0xFFA1B3A1);
const kWhite = Color(0xFFF7F7F2);
const kDarkBar = Color(0xFF0C1E11);

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
          // ── Unified, Beautiful App Bar ─────────────────────────────────────
          appBar: AppBar(
            backgroundColor: kBg,
            foregroundColor: kWhite,
            elevation: 0,
            toolbarHeight: 70,
            title: Row(
              children: [
                // Displaying the logo right in the main App Bar
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
              // Stylish Language Toggle Pill
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

              // Profile / Logout Menu
              PopupMenuButton<String>(
                color: kDarkBar, // from home_page colors
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                offset: const Offset(0, 50),
                icon: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: kPrimary.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const CircleAvatar(
                    backgroundColor: kPrimary,
                    radius: 18,
                    child: Icon(Icons.person, color: kWhite, size: 22),
                  ),
                ),
                onSelected: (v) async {
                  if (v == 'signin') {
                    Navigator.pushNamed(context, SignInPage.route);
                  } else if (v == 'signup') {
                    Navigator.pushNamed(context, SignUpPage.route);
                  } else if (v == 'logout') {
                    // FULL LOGOUT: Sign out and clear the entire navigation stack
                    await FirebaseAuth.instance.signOut();
                    if (!context.mounted) return;

                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      SignInPage.route,
                      (route) =>
                          false, // This guarantees the user cannot swipe back to the app
                    );
                  }
                },
                itemBuilder: (context) {
                  if (user == null) {
                    return [
                      _buildMenuItem(
                        'signin',
                        AppLanguage.getText('sign_in'),
                        Icons.login,
                      ),
                      _buildMenuItem(
                        'signup',
                        AppLanguage.getText('sign_up'),
                        Icons.person_add,
                      ),
                    ];
                  }
                  return [
                    _buildMenuItem(
                      'logout',
                      AppLanguage.getText('log_out'),
                      Icons.logout,
                      isDestructive: true,
                    ),
                  ];
                },
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: tabs[_index].page,

          // ── Modern Floating Bottom Navigation ──────────────────────────────
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

  PopupMenuItem<String> _buildMenuItem(
    String value,
    String text,
    IconData icon, {
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.redAccent : kWhite;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _TabDef {
  final String title;
  final IconData icon;
  final Widget page;
  _TabDef(this.title, this.icon, this.page);
}
