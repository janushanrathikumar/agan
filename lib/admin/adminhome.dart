// lib/admin/adminhome.dart
import 'package:flutter/material.dart';
import 'admin_app_bar.dart';
import 'sales_dashboard.dart'; // கீழே உள்ள புதிய Dashboard

const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF1E1E1E);
const kMuted = Color(0xFF9E9E9E);
const kWhite = Color(0xFFFFFFFF);

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AdminAppBar(), // உங்களின் பழைய Popup Menu AppBar
      drawer: AdminDrawer(), // உங்களின் பழைய Drawer
      backgroundColor: kBg,
      body: SalesDashboard(), // நேர்த்தியான புதிய Dashboard
    );
  }
}

class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: kBg,
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF2C2B2A)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant_menu, color: kPrimary, size: 40),
                SizedBox(height: 10),
                Text(
                  'Admin Tools',
                  style: TextStyle(
                    color: kWhite,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard, color: kPrimary),
            title: const Text(
              'Dashboard',
              style: TextStyle(color: kWhite, fontWeight: FontWeight.bold),
            ),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.category, color: kMuted),
            title: const Text(
              'Manage Categories',
              style: TextStyle(color: kMuted),
            ),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.local_cafe, color: kMuted),
            title: const Text('Manage Drinks', style: TextStyle(color: kMuted)),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.fastfood, color: kMuted),
            title: const Text('Manage Food', style: TextStyle(color: kMuted)),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
