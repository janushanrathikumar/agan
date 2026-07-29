// lib/admin/admin_app_bar.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:restorant/admin/manage_menu_items.dart';
import 'add_category.dart';
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
  Size get preferredSize => const Size.fromHeight(70);

  @override
  State<AdminAppBar> createState() => _AdminAppBarState();
}

class _AdminAppBarState extends State<AdminAppBar> {
  bool _loggingOut = false;

  Widget _buildMenuItemChild(IconData icon, String title) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: kPrimary, size: 20),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: kWhite,
            fontSize: 14,
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
        backgroundColor: const Color(0xFF2A2A2A),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
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
        color: Color(0xFF222222),
        boxShadow: [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
        border: Border(bottom: BorderSide(color: Colors.white10, width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              PopupMenuButton<String>(
                tooltip: "Menu Navigation",
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kPrimary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.grid_view_rounded,
                    color: kPrimary,
                    size: 24,
                  ),
                ),
                color: const Color(0xFF2A2A2A),
                elevation: 12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.white10),
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
                    case 'manage_menu_items':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ManageMenuItemsPage(),
                        ),
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
                    case 'add_additional_option':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ManageAdditionalOptionsPage(),
                        ),
                      );
                      break;
                    // case 'add_promotion':
                    //   Navigator.push(
                    //     context,
                    //     MaterialPageRoute(
                    //       builder: (_) => const AdminPromotionsPage(),
                    //     ),
                    //   );
                    //   break;
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'home',
                    child: _buildMenuItemChild(Icons.home_rounded, 'Dashboard'),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'Order',
                    child: _buildMenuItemChild(
                      Icons.receipt_long_rounded,
                      'Orders',
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'manage_menu_items',
                    child: _buildMenuItemChild(
                      Icons.menu_book_rounded,
                      'Manage Menu Items',
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
                      'Menu Choice',
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'add_additional_option',
                    child: _buildMenuItemChild(
                      Icons.add_circle_outline_rounded,
                      'Menu Additional Options',
                    ),
                  ),
                  // PopupMenuItem<String>(
                  //   value: 'add_promotion',
                  //   child: _buildMenuItemChild(
                  //     Icons.local_offer_rounded,
                  //     'Add Promotion',
                  //   ),
                  // ),
                ],
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Admin Panel",
                      style: TextStyle(
                        color: kWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      "Manage your restaurant",
                      style: TextStyle(color: kMuted, fontSize: 12),
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
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.logout_rounded,
                          color: Colors.redAccent,
                          size: 22,
                        ),
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
