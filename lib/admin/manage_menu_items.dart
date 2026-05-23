// lib/manage_menu_items.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_menu_item.dart'; // 👈 IMPORTANT: Import the new edit page

// --- Your Exact Color Constants ---
const kPrimary = Color(0xFFA26334);
const kBg = Color(0xFF2A2928);
const kWhite = Color(0xFFFFFFFF);
const kMuted = Color(0xFFB7B7B6);
const kFieldBg = Color(0xFF383735); 
// ----------------------------------

class ManageMenuItemsPage extends StatelessWidget {
  const ManageMenuItemsPage({super.key});

  Future<void> _deleteItem(BuildContext context, String docId, String itemName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kFieldBg,
        title: const Text('Delete Item', style: TextStyle(color: kWhite)),
        content: Text('Are you sure you want to delete "$itemName"?', style: const TextStyle(color: kMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: kMuted))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('menu_items').doc(docId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$itemName deleted'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Widget _buildListForType(String itemType) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('menu_items').where('itemType', isEqualTo: itemType).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kPrimary));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No items found.', style: TextStyle(color: kMuted)));

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: kFieldBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kMuted.withOpacity(0.2))),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    data['imageUrl'] ?? '',
                    width: 50, height: 50, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, color: kMuted),
                  ),
                ),
                title: Text(data['name'] ?? '', style: const TextStyle(color: kWhite, fontWeight: FontWeight.bold)),
                subtitle: Text('CHF ${data['price']}', style: const TextStyle(color: kPrimary)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🟢 UPDATED: Navigate to Edit Screen
                    IconButton(
                      icon: const Icon(Icons.edit, color: kMuted),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditMenuItemPage(
                              docId: docId,
                              itemData: data,
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _deleteItem(context, docId, data['name'] ?? 'Item'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, 
      child: Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kBg,
          foregroundColor: kWhite,
          title: const Text('Manage Menu', style: TextStyle(fontWeight: FontWeight.bold)),
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: kPrimary,
            labelColor: kPrimary,
            unselectedLabelColor: kMuted,
            tabs: [
              Tab(text: "Foods"),
              Tab(text: "Drinks"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildListForType('food'), 
            _buildListForType('drink'), 
          ],
        ),
      ),
    );
  }
}