import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Assuming these files exist relative to this one, based on your project structure
import 'add_category.dart';
import 'add_food_menu.dart';
import 'admin_order.dart';
import 'add_menu_chocie.dart';
import 'promotion.dart';
import 'package:restorant/startup%20page/signin_page.dart';

const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF2A2928);
const kWhite = Color(0xFFFFFFFF);
const kMuted = Color(0xFFB7B7B6);
// ---

class AdminAppBar extends StatefulWidget implements PreferredSizeWidget {
  const AdminAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  State<AdminAppBar> createState() => _AdminAppBarState();
}

class _AdminAppBarState extends State<AdminAppBar> {
  bool _loggingOut = false;

  // Helper widget to build visually appealing menu items
  Widget _buildMenuItemChild(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: kPrimary, size: 20),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: kWhite,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // 🟢 FIX: logout was silently failing.
  // Your app uses NAMED routes (SignInPage.route is registered in
  // MaterialApp.routes), and there's no root-level auth listener that
  // automatically swaps to the sign-in screen when the user becomes null.
  // The old code called Navigator.popUntil(context, (route) => route.isFirst)
  // after signOut() — but "the first route" is just whatever was pushed
  // first (usually the Admin Home), NOT the sign-in page. So signOut()
  // was actually succeeding, but the UI never left the admin screen,
  // making it look like logout "wasn't working."
  //
  // Fix: after signOut(), explicitly navigate to SignInPage.route with
  // pushNamedAndRemoveUntil, which also clears the whole navigation
  // stack so the back button can't return into the admin area. Wrapped
  // in try/catch with a `mounted` guard so any real error is surfaced
  // instead of failing silently, and a loading state prevents double-taps.
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
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: kWhite,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

      // Use the ROOT navigator so this works no matter how deep the
      // current screen is nested, and clear the entire stack so the
      // user can't navigate back into the admin area after logging out.
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
      // Custom styling for the AppBar background
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2C2B2A), Color(0xFF1F1E1D)],
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Menu Icon - Now opens the nicely styled pop-up
              PopupMenuButton<String>(
                tooltip: "Menu Navigation",
                icon: const Icon(Icons.menu_rounded, color: kPrimary, size: 28),

                // Styling the pop-up container
                color: kBg,
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: kMuted, width: 0.5),
                ),

                onSelected: (value) {
                  switch (value) {
                    case 'home':
                      // Navigates back to the first route in the stack (AdminHome)
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
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  // Enhanced Menu Item: Home
                  PopupMenuItem<String>(
                    value: 'home',
                    child: _buildMenuItemChild(Icons.home_rounded, 'Home'),
                  ),
                  const PopupMenuDivider(height: 1),
                  // Enhanced Menu Item: Add Food Menu
                  PopupMenuItem<String>(
                    value: 'add_food',
                    child: _buildMenuItemChild(
                      Icons.fastfood_rounded,
                      'Add Menu',
                    ),
                  ),
                  // Enhanced Menu Item: Add Drinks Menu
                  PopupMenuItem<String>(
                    value: 'Order',
                    child: _buildMenuItemChild(
                      Icons.local_bar_rounded,
                      'View Orders',
                    ),
                  ),
                  // Enhanced Menu Item: Add Menu Category
                  PopupMenuItem<String>(
                    value: 'add_category',
                    child: _buildMenuItemChild(
                      Icons.category_rounded,
                      'Add Menu Category',
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'add_menu_choice',
                    child: _buildMenuItemChild(
                      Icons.select_all_rounded,
                      'Add Menu Choice',
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'add_promotion',
                    child: _buildMenuItemChild(
                      Icons.local_offer_rounded,
                      'Add Promotion',
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Page Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      "Admin Dashboard",
                      style: TextStyle(
                        color: kWhite,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Manage menus and categories",
                      style: TextStyle(color: kMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // Logout Button
              _loggingOut
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: kPrimary,
                        ),
                      ),
                    )
                  : IconButton(
                      tooltip: "Log out",
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: kPrimary,
                        size: 26,
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
