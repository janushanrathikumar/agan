import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:restorant/startup%20page/signin_page.dart';

import 'package:restorant/user/home.dart';
import 'package:restorant/user/menu.dart';

import 'userscreen/signin_page.dart';
import 'userscreen/signup_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  late final List<_TabDef> _tabs = [
    _TabDef('Home', Icons.home, const HomePage()),
    _TabDef('Menu', Icons.restaurant_menu, const MenuPage()),
    _TabDef('Reward', Icons.card_giftcard, const _CenterLabel('Reward')),
    _TabDef('Account', Icons.person, const _CenterLabel('Account')),
  ];

  void _onBottomTap(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snap) {
        final user = snap.data;
        final display = (user?.displayName?.trim().isNotEmpty ?? false)
            ? user!.displayName!.trim()
            : (user?.email ?? 'Guest');

        return Scaffold(
          appBar: AppBar(
            title: Text('Welcome, $display'),
            actions: [
              PopupMenuButton<String>(
                icon: const CircleAvatar(child: Icon(Icons.person)),
                onSelected: (v) async {
                  if (v == 'signin')
                    Navigator.pushNamed(context, SignInPage.route);
                  if (v == 'signup')
                    Navigator.pushNamed(context, SignUpPage.route);
                  if (v == 'logout') {
                    await FirebaseAuth.instance.signOut();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Logged out')));
                  }
                },
                itemBuilder: (context) {
                  if (user == null) {
                    return const [
                      PopupMenuItem(value: 'signin', child: Text('Sign in')),
                      PopupMenuItem(value: 'signup', child: Text('Sign up')),
                    ];
                  }
                  return const [
                    PopupMenuItem(value: 'logout', child: Text('Log out')),
                  ];
                },
              ),
            ],
          ),
          body: _tabs[_index].page,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _onBottomTap,
            destinations: _tabs
                .map(
                  (t) =>
                      NavigationDestination(icon: Icon(t.icon), label: t.title),
                )
                .toList(),
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
  Widget build(BuildContext context) =>
      Center(child: Text(text, style: const TextStyle(fontSize: 22)));
}
