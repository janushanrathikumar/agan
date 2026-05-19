import 'package:flutter/material.dart';
import 'drinkmenu/add_drinks_menu.dart';
import 'add_food_menu.dart';
import 'add_category.dart';
import 'admin_app_bar.dart';

// Import the new SalesDashboard
import 'sales_dashboard.dart';

const kPrimary = Color(0xFFA26334);
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
// NOTE: I reverted kWhite to pure white for better contrast as standard practice
const kWhite = Color(0xFFFFFFFF);

// Placeholder for your actual Admin Home Page
class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    // Renders the new comprehensive Sales Dashboard
    return const Scaffold(
      // Use the modified AdminAppBar
      appBar: AdminAppBar(),

      // Add the new Drawer to the Scaffold
      drawer: AdminDrawer(),

      backgroundColor: kBg,
      body: SalesDashboard(),
    );
  }
}

// Minimal Drawer implementation assumed to be missing
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
            decoration: BoxDecoration(color: kPrimary),
            child: Text('Admin Tools',
                style: TextStyle(color: kWhite, fontSize: 24)),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard, color: kWhite),
            title: const Text('Dashboard', style: TextStyle(color: kWhite)),
            onTap: () {
              Navigator.pop(context); // Close drawer
            },
          ),
          ListTile(
            leading: const Icon(Icons.category, color: kMuted),
            title: const Text('Manage Categories',
                style: TextStyle(color: kMuted)),
            onTap: () {
              // Assumed: Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddCategory()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.local_cafe, color: kMuted),
            title: const Text('Manage Drinks', style: TextStyle(color: kMuted)),
            onTap: () {
              // Assumed: Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddDrinksMenu()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.fastfood, color: kMuted),
            title: const Text('Manage Food', style: TextStyle(color: kMuted)),
            onTap: () {
              // Assumed: Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddFoodMenu()));
            },
          ),
        ],
      ),
    );
  }
}
