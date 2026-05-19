// // In a new file, e.g., 'lib/widgets/admin_drawer.dart'

// import 'package:flutter/material.dart';
// import 'package:kopicue/admin/add_category.dart';
// import 'package:kopicue/admin/add_food_menu.dart';
// import 'package:kopicue/admin/drinkmenu/add_drinks_menu.dart';

// // Import your pages and constants

// // Assuming your constants (kBg, kWhite, etc.) are in the admin_app_bar.dart file
// // You might need to move them to a shared 'constants.dart' file
// // For this example, I'll copy them here.
// const kPrimary = Color(0xFFA26334);
// const kBg = Color(0xFF2A2928);
// const kWhite = Color(0xFFFFFFFF);
// const kMuted = Color(0xFFB7B7B6);

// class AdminDrawer extends StatelessWidget {
//   const AdminDrawer({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Drawer(
//       backgroundColor: kBg, // Set the background color
//       child: ListView(
//         padding: EdgeInsets.zero,
//         children: [
//           // A header for your drawer
//           DrawerHeader(
//             decoration: BoxDecoration(
//               color: kPrimary.withOpacity(0.15),
//             ),
//             child: const Text(
//               'Admin Menu',
//               style: TextStyle(
//                 color: kWhite,
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),

//           // Home
//           ListTile(
//             leading: const Icon(Icons.home, color: kMuted),
//             title: const Text('Home', style: TextStyle(color: kWhite)),
//             onTap: () {
//               Navigator.pop(context); // Close the drawer
//               Navigator.popUntil(context, (route) => route.isFirst);
//             },
//           ),

//           // Add Drinks
//           ListTile(
//             leading: const Icon(Icons.local_drink, color: kMuted),
//             title:
//                 const Text('Add Drinks Menu', style: TextStyle(color: kWhite)),
//             onTap: () {
//               Navigator.pop(context); // Close the drawer
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (_) => const AddDrinksMenuPage()),
//               );
//             },
//           ),

//           // Add Food
//           ListTile(
//             leading: const Icon(Icons.fastfood, color: kMuted),
//             title: const Text('Add Food Menu', style: TextStyle(color: kWhite)),
//             onTap: () {
//               Navigator.pop(context); // Close the drawer
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (_) => const AddFoodMenuPage()),
//               );
//             },
//           ),

//           // Add Category
//           ListTile(
//             leading: const Icon(Icons.category, color: kMuted),
//             title: const Text('Add Menu Category',
//                 style: TextStyle(color: kWhite)),
//             onTap: () {
//               Navigator.pop(context); // Close the drawer
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (_) => const AddCategoryPage()),
//               );
//             },
//           ),
//         ],
//       ),
//     );
//   }
// }
