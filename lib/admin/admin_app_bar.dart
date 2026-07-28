import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Assuming these files exist relative to this one
import 'add_category.dart';
import 'add_food_menu.dart';
import 'admin_order.dart';
import 'add_menu_chocie.dart';
import 'promotion.dart';
import 'manage_additional_options.dart';
import 'package:restorant/startup%20page/signin_page.dart';

const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF1E1E1E);
const kWhite = Color(0xFFFFFFFF);
const kMuted = Color(0xFF9E9E9E);

class AdminAppBar extends StatefulWidget implements PreferredSizeWidget {
  const AdminAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(75);

  @override
  State<AdminAppBar> createState() => _AdminAppBarState();
}

class _AdminAppBarState extends State<AdminAppBar> {
  bool _loggingOut = false;

  Widget _buildMenuItemChild(IconData icon, String title) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: kPrimary, size: 22),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: kWhite,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Confirm Logout", style: TextStyle(color: kWhite)),
        content: const Text(
          "Are you sure you want to sign out?",
          style: TextStyle(color: kMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: kMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: kWhite,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Log Out",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    setState(() => _loggingOut = true);

    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;

      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil(SignInPage.route, (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2C2B2A), Color(0xFF121212)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              PopupMenuButton<String>(
                tooltip: "Menu Navigation",
                icon: const Icon(Icons.menu_rounded, color: kPrimary, size: 30),
                color: kBg,
                elevation: 12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: kMuted, width: 0.5),
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'home':
                      Navigator.popUntil(context, (route) => route.isFirst);
                      break;
                    case 'Order':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminOrdersListPage(),
                        ),
                      );
                      break;
                    case 'add_food':
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddMenuPage()),
                      );
                      break;
                    case 'add_category':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddCategoryPage(),
                        ),
                      );
                      break;
                    case 'add_menu_choice':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddMenuChoicePage(),
                        ),
                      );
                      break;
                    case 'add_promotion':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminPromotionsPage(),
                        ),
                      );
                      break;
                    case 'add_additional_option':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ManageAdditionalOptionsPage(),
                        ),
                      );
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'home',
                    child: _buildMenuItemChild(Icons.home_rounded, 'Home'),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'add_food',
                    child: _buildMenuItemChild(
                      Icons.fastfood_rounded,
                      'Add Menu',
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'Order',
                    child: _buildMenuItemChild(
                      Icons.receipt_long_rounded,
                      'View Orders',
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'add_category',
                    child: _buildMenuItemChild(
                      Icons.category_rounded,
                      'Add Category',
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'add_menu_choice',
                    child: _buildMenuItemChild(
                      Icons.select_all_rounded,
                      'Add Choice',
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'add_promotion',
                    child: _buildMenuItemChild(
                      Icons.local_offer_rounded,
                      'Add Promotion',
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'add_additional_option',
                    child: _buildMenuItemChild(
                      Icons.add_circle_outline_rounded,
                      'Manage Options',
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      "Admin Dashboard",
                      style: TextStyle(
                        color: kWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "Manage menus, categories & promotions",
                      style: TextStyle(color: kMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              _loggingOut
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: kPrimary,
                      ),
                    )
                  : IconButton(
                      tooltip: "Log out",
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: kPrimary,
                        size: 28,
                      ),
                      onPressed: _handleLogout,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
