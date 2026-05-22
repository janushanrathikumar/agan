import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:restorant/startup%20page/signin_page.dart';

import 'package:restorant/user/home.dart';
import 'package:restorant/user/menu.dart';

import 'userscreen/signin_page.dart';
import 'userscreen/signup_page.dart';
import '../language.dart'; // Language file இணைக்கப்பட்டுள்ளது (path-ஐ சரிபார்க்கவும்)

// --- லோகோ நிறங்கள் ---
const kPrimary = Color(0xFFE49024); // Orange
const kBg = Color(0xFF112A18); // Dark Green
const kMuted = Color(0xFFA1B3A1); // Muted Green
const kWhite = Color(0xFFF7F7F2); // Cream White
const kDarkBar = Color(
  0xFF0C1E11,
); // Navigation Bar-க்கான சற்று அடர்த்தியான கரும்பச்சை

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _onBottomTap(int i) => setState(() => _index = i);

  // மொழியை மாற்றும் Function
  void _toggleLanguage() {
    setState(() {
      if (AppLanguage.currentLanguage == 'de') {
        AppLanguage.currentLanguage = 'en';
      } else {
        AppLanguage.currentLanguage = 'de';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // build முறைக்குள் tabs-ஐ வைப்பதன் மூலம், மொழி மாறும்போது பெயர்களும் மாறும்
    final List<_TabDef> _tabs = [
      _TabDef(AppLanguage.getText('home'), Icons.home, const HomePage()),
      _TabDef(
        AppLanguage.getText('menu'),
        Icons.restaurant_menu,
        const MenuPage(),
      ),
      _TabDef(
        AppLanguage.getText('reward'),
        Icons.card_giftcard,
        _CenterLabel(AppLanguage.getText('reward')),
      ),
      _TabDef(
        AppLanguage.getText('account'),
        Icons.person,
        _CenterLabel(AppLanguage.getText('account')),
      ),
    ];

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snap) {
        final user = snap.data;
        final display = (user?.displayName?.trim().isNotEmpty ?? false)
            ? user!.displayName!.trim()
            : (user?.email ?? 'Guest');

        return Scaffold(
          backgroundColor: kBg,
          appBar: AppBar(
            backgroundColor: kBg,
            foregroundColor: kWhite,
            elevation: 0,
            title: Text(
              '${AppLanguage.getText('welcome')}, $display',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            actions: [
              // Language Toggle Button (புதிதாக சேர்க்கப்பட்டது)
              TextButton.icon(
                onPressed: _toggleLanguage,
                icon: const Icon(Icons.language, color: kWhite, size: 20),
                label: Text(
                  AppLanguage.getText('lang_toggle'),
                  style: const TextStyle(
                    color: kWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Profile Popup Menu
              PopupMenuButton<String>(
                color: kDarkBar, // பாப்-அப் மெனுவின் அடர் பச்சை நிறம்
                icon: const CircleAvatar(
                  backgroundColor: kPrimary, // ஆரஞ்சு நிற அவதார்
                  radius: 16,
                  child: Icon(Icons.person, color: kWhite, size: 20),
                ),
                onSelected: (v) async {
                  if (v == 'signin') {
                    Navigator.pushNamed(context, SignInPage.route);
                  }
                  if (v == 'signup') {
                    Navigator.pushNamed(context, SignUpPage.route);
                  }
                  if (v == 'logout') {
                    await FirebaseAuth.instance.signOut();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLanguage.getText('logged_out')),
                        backgroundColor: kPrimary,
                      ),
                    );
                  }
                },
                itemBuilder: (context) {
                  if (user == null) {
                    return [
                      PopupMenuItem(
                        value: 'signin',
                        child: Text(
                          AppLanguage.getText('sign_in'),
                          style: const TextStyle(color: kWhite),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'signup',
                        child: Text(
                          AppLanguage.getText('sign_up'),
                          style: const TextStyle(color: kWhite),
                        ),
                      ),
                    ];
                  }
                  return [
                    PopupMenuItem(
                      value: 'logout',
                      child: Text(
                        AppLanguage.getText('log_out'),
                        style: const TextStyle(color: kWhite),
                      ),
                    ),
                  ];
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: _tabs[_index].page,

          // Bottom Navigation Bar
          bottomNavigationBar: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: kDarkBar, // அடர் பச்சை
              indicatorColor: kPrimary.withOpacity(0.3), // ஆரஞ்சு செலக்சன்
              iconTheme: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const IconThemeData(color: kPrimary);
                }
                return const IconThemeData(color: kMuted); // சாம்பல்/பச்சை
              }),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(
                    color: kPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  );
                }
                return const TextStyle(
                  color: kMuted,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                );
              }),
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _onBottomTap,
              destinations: _tabs
                  .map(
                    (t) => NavigationDestination(
                      icon: Icon(t.icon),
                      label: t.title,
                    ),
                  )
                  .toList(),
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

class _CenterLabel extends StatelessWidget {
  final String text;
  const _CenterLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Text(text, style: const TextStyle(fontSize: 22, color: kWhite)),
  );
}
