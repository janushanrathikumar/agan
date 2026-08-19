// lib/manage_menu_items.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:restorant/admin/add_food_menu.dart';
import 'edit_menu_item.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:restorant/platform_image/platform_image.dart';

const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF2A2928);
const kWhite = Color(0xFFFFFFFF);
const kMuted = Color(0xFFB7B7B6);
const kFieldBg = Color(0xFF383735);
const kDiscount = Color(0xFFE0483E);

// --- Web Safe Image Widget ---
class _WebSafeImage extends StatelessWidget {
  final String imageUrl;
  final Widget fallback;

  const _WebSafeImage({required this.imageUrl, required this.fallback});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) return fallback;
    if (kIsWeb) {
      final String viewId =
          'manage-img-${imageUrl.hashCode}_${DateTime.now().microsecondsSinceEpoch}';
      return buildUniversalImage(
        imageUrl: imageUrl, // Pass your actual image URL variable here
        width: 100, // Adjust width as needed
        height: 100, // Adjust height as needed
        fallback: const Icon(Icons.image_not_supported),
      );

      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: IgnorePointer(child: HtmlElementView(viewType: viewId)),
      );
    }
    return Image.network(
      imageUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class ManageMenuItemsPage extends StatefulWidget {
  const ManageMenuItemsPage({super.key});

  @override
  State<ManageMenuItemsPage> createState() => _ManageMenuItemsPageState();
}

class _ManageMenuItemsPageState extends State<ManageMenuItemsPage> {
  String _selectedType = 'All'; // 'All', 'food', 'drink', 'combo'
  String _selectedCategory = 'All';

  Future<void> _deleteItem(
    BuildContext context,
    String docId,
    String? imageFileName,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kFieldBg,
        title: const Text('Delete Item?', style: TextStyle(color: kWhite)),
        content: const Text(
          'Are you sure you want to permanently delete this menu item?',
          style: TextStyle(color: kMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: kWhite)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('menu_items')
            .doc(docId)
            .delete();

        if (imageFileName != null && imageFileName.isNotEmpty) {
          try {
            await FirebaseStorage.instance
                .ref('menu_images/$imageFileName')
                .delete();
          } catch (e) {
            debugPrint("Failed to delete image: $e");
          }
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item deleted successfully'),
              backgroundColor: kPrimary,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  double _getDisplayPrice(Map<String, dynamic> m) {
    bool hasMultipleSizes = m['hasMultipleSizes'] == true;
    List<dynamic> sizes = m['sizes'] ?? [];

    if (hasMultipleSizes && sizes.isNotEmpty) {
      double minPrice = double.infinity;
      for (var s in sizes) {
        double p = ((s['dineInPrice'] ?? s['price'] ?? 0) as num).toDouble();
        if (p < minPrice) minPrice = p;
      }
      return minPrice == double.infinity
          ? ((m['price'] as num?)?.toDouble() ?? 0)
          : minPrice;
    }
    return ((m['price'] as num?)?.toDouble() ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kWhite,
        title: const Text(
          'Menu Overview',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: kWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddMenuPage()),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Add Menu',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('menu_items').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kPrimary),
            );
          }

          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No menu items found.',
                style: TextStyle(color: kMuted),
              ),
            );
          }

          var allDocs = snap.data!.docs.toList();

          // 🟢 SORTING BY ITEM NO
          allDocs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>? ?? {};
            final dataB = b.data() as Map<String, dynamic>? ?? {};

            final noAStr = dataA['itemNo']?.toString().trim() ?? '';
            final noBStr = dataB['itemNo']?.toString().trim() ?? '';

            final noA = int.tryParse(noAStr);
            final noB = int.tryParse(noBStr);

            if (noA != null && noB != null) return noA.compareTo(noB);
            if (noA != null) return -1;
            if (noB != null) return 1;

            return noAStr.compareTo(noBStr);
          });

          // 🟢 FILTER BY TYPE
          var typeFilteredDocs = allDocs;
          if (_selectedType != 'All') {
            typeFilteredDocs = allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final type = data['itemType'] ?? 'food';
              return type == _selectedType;
            }).toList();
          }

          // 🟢 EXTRACT CATEGORIES FOR HORIZONTAL TABS
          Set<String> catSet = {};
          for (var doc in typeFilteredDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final cat = data['category']?.toString().trim() ?? '';
            if (cat.isNotEmpty) catSet.add(cat);
          }
          List<String> dynamicCategories = ['All', ...catSet.toList()..sort()];

          // Reset category if not available in current type filter
          String activeCategory = _selectedCategory;
          if (!dynamicCategories.contains(activeCategory)) {
            activeCategory = 'All';
          }

          // 🟢 FILTER BY CATEGORY
          var finalDocs = typeFilteredDocs;
          if (activeCategory != 'All') {
            finalDocs = typeFilteredDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final cat = data['category']?.toString().trim() ?? '';
              return cat == activeCategory;
            }).toList();
          }

          return Column(
            children: [
              // ── Top Bar: Type Filters (Food, Drink, Combo) ──
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    _buildTypePill('All', Icons.restaurant_menu),
                    _buildTypePill('food', Icons.lunch_dining),
                    _buildTypePill('drink', Icons.local_cafe),
                    _buildTypePill('combo', Icons.fastfood),
                  ],
                ),
              ),

              // ── Category Horizontal Scroll (Pizza Hut Style) ──
              if (dynamicCategories.length > 1)
                Container(
                  height: 50,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: dynamicCategories.length,
                    itemBuilder: (context, index) {
                      final cat = dynamicCategories[index];
                      final isSelected = activeCategory == cat;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? kWhite : kFieldBg,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: isSelected
                                  ? kWhite
                                  : kMuted.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: isSelected ? kBg : kWhite,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // ── Items Grid ──
              Expanded(
                child: finalDocs.isEmpty
                    ? const Center(
                        child: Text(
                          'No items found.',
                          style: TextStyle(color: kMuted),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 250, // Card width
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio:
                                  0.68, // Taller card to fit everything
                            ),
                        itemCount: finalDocs.length,
                        itemBuilder: (context, index) {
                          final doc = finalDocs[index];
                          final data = doc.data() as Map<String, dynamic>;

                          final name = data['name'] ?? 'Unnamed';
                          final itemNo = data['itemNo']?.toString() ?? '';
                          final imageUrl = data['imageUrl'] ?? '';
                          final imageFileName = data['imageFileName'];
                          final category = data['category'] ?? '';

                          final price = _getDisplayPrice(data);

                          return Container(
                            decoration: BoxDecoration(
                              color: kWhite.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: kMuted.withOpacity(0.1),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Image Area ──
                                Expanded(
                                  flex: 5,
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(16),
                                            ),
                                        child: _WebSafeImage(
                                          imageUrl: imageUrl,
                                          fallback: Container(
                                            color: kFieldBg,
                                            child: const Center(
                                              child: Icon(
                                                Icons.fastfood,
                                                color: kMuted,
                                                size: 40,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Item ID Tag
                                      if (itemNo.isNotEmpty)
                                        Positioned(
                                          top: 8,
                                          left: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: kPrimary,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '#$itemNo',
                                              style: const TextStyle(
                                                color: kWhite,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // ── Details Area ──
                                Expanded(
                                  flex: 4,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: kWhite,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          category.isEmpty
                                              ? 'Uncategorized'
                                              : category,
                                          style: const TextStyle(
                                            color: kMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const Spacer(),
                                        // ── Bottom Row: Price & Actions ──
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'CHF ${price.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: kWhite,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 15,
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                GestureDetector(
                                                  onTap: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            EditMenuItemPage(
                                                              docId: doc.id,
                                                              itemData: data,
                                                            ),
                                                      ),
                                                    );
                                                  },
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blueAccent
                                                          .withOpacity(0.15),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.edit,
                                                      color: Colors.blueAccent,
                                                      size: 16,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                GestureDetector(
                                                  onTap: () => _deleteItem(
                                                    context,
                                                    doc.id,
                                                    imageFileName,
                                                  ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: kDiscount
                                                          .withOpacity(0.15),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.delete,
                                                      color: kDiscount,
                                                      size: 16,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTypePill(String typeValue, IconData icon) {
    final isSelected = _selectedType == typeValue;
    String label = typeValue == 'All' ? 'All Items' : typeValue.toUpperCase();

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = typeValue;
            _selectedCategory = 'All'; // Reset category when changing base type
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? kPrimary : kFieldBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? kPrimary : kMuted.withOpacity(0.2),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? kWhite : kMuted, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? kWhite : kMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
