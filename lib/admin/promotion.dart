import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- Palette ---
const kPrimary = Color(0xFFA26334);
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);
const kCardBg = Color(0xFF383735);
const kItemBg = Color(0xFF2F2E2D);

class AdminPromotionsPage extends StatelessWidget {
  const AdminPromotionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text(
          'Manage Promos & Combos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: kBg,
        foregroundColor: kWhite,
        elevation: 0,
      ),
      // 🔥 NEW: Floating Action Button to create a new Combo Package
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimary,
        foregroundColor: kWhite,
        onPressed: () => _showAddComboSheet(context),
        icon: const Icon(Icons.add_box),
        label: const Text(
          'Add Combo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Fetch all items, descending order so newest combos appear at the top
        stream: FirebaseFirestore.instance
            .collection('menu_items')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kPrimary),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No menu items found.',
                style: TextStyle(color: kMuted),
              ),
            );
          }

          final items = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.only(
              left: 12.0,
              right: 12.0,
              top: 12.0,
              bottom: 80.0,
            ), // Bottom padding for FAB
            itemCount: items.length,
            itemBuilder: (context, index) {
              final doc = items[index];
              final data = doc.data() as Map<String, dynamic>;

              final String name = data['name'] ?? 'Unknown Item';
              final num originalPrice = data['price'] ?? 0;
              final String imageUrl = data['imageUrl'] ?? '';
              final String itemType = data['itemType'] ?? 'food';

              // Promo fields
              final bool isPromoActive = data['isPromoActive'] ?? false;
              final num offerPrice = data['offerPrice'] ?? 0;

              // Check if it's a combo
              final bool isCombo = itemType == 'combo';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCombo
                        ? Colors.orangeAccent.withOpacity(0.5)
                        : (isPromoActive
                              ? Colors.green.withOpacity(0.4)
                              : Colors.transparent),
                    width: 1.5,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _placeholderImage(isCombo),
                          )
                        : _placeholderImage(isCombo),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: kWhite,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCombo)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'COMBO',
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Row(
                      children: [
                        Text(
                          'RM ${originalPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isPromoActive ? kMuted : kWhite,
                            fontSize: isPromoActive ? 13 : 15,
                            decoration: isPromoActive
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        if (isPromoActive) ...[
                          const SizedBox(width: 8),
                          Text(
                            'RM ${offerPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isPromoActive
                          ? Colors.green.withOpacity(0.15)
                          : kItemBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isPromoActive ? 'PROMO ON' : 'ADD PROMO',
                      style: TextStyle(
                        color: isPromoActive ? Colors.greenAccent : kMuted,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  onTap: () => _showDiscountBottomSheet(context, doc),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _placeholderImage(bool isCombo) {
    return Container(
      width: 60,
      height: 60,
      color: kItemBg,
      child: Icon(
        isCombo ? Icons.fastfood : Icons.restaurant_menu,
        color: kPrimary.withOpacity(0.5),
      ),
    );
  }

  // --- Open Add Combo Sheet ---
  void _showAddComboSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _CreateComboWidget(),
    );
  }

  // --- Open Edit Promo Price Sheet ---
  void _showDiscountBottomSheet(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final num currentPrice = data['price'] ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: kBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _PromoFormWidget(
          docId: doc.id,
          originalPrice: currentPrice,
          initialOfferPrice: data['offerPrice'] ?? currentPrice,
          initialIsActive: data['isPromoActive'] ?? false,
        );
      },
    );
  }
}

// ==========================================
// Stateful Form for Adding a New Combo
// ==========================================
class _CreateComboWidget extends StatefulWidget {
  const _CreateComboWidget();

  @override
  State<_CreateComboWidget> createState() => _CreateComboWidgetState();
}

class _CreateComboWidgetState extends State<_CreateComboWidget> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isSaving = false;

  Future<void> _createCombo() async {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter name and price'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    double comboPrice = double.tryParse(_priceController.text) ?? 0.0;

    try {
      // Create a new document in menu_items
      await FirebaseFirestore.instance.collection('menu_items').add({
        'name': _nameController.text.trim(),
        'note': _descController.text.trim(),
        'price': comboPrice,
        'offerPrice': comboPrice, // Combo is already a promo price usually
        'isPromoActive': true, // Active by default
        'itemType': 'combo', // Custom tag to identify combos
        'category': 'promos',
        'imageUrl': '', // Leave empty or assign a default combo image URL
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'on',
        'menuChoices': [],
        'additionalOptions': [],
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Combo Created!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create New Combo',
            style: TextStyle(
              color: kWhite,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _nameController,
            'Combo Name (e.g. Burger + Soda)',
            Icons.fastfood,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            _descController,
            'Description (Optional)',
            Icons.description,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            _priceController,
            'Combo Price (RM)',
            Icons.attach_money,
            isNumber: true,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isSaving ? null : _createCombo,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: kWhite,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Save Combo',
                      style: TextStyle(
                        color: kWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: const TextStyle(color: kWhite),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kMuted),
        filled: true,
        fillColor: kCardBg,
        prefixIcon: Icon(icon, color: kPrimary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kItemBg),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimary),
        ),
      ),
    );
  }
}

// ==========================================
// Stateful Form for Editing Promos (From previous step)
// ==========================================
class _PromoFormWidget extends StatefulWidget {
  final String docId;
  final num originalPrice;
  final num initialOfferPrice;
  final bool initialIsActive;

  const _PromoFormWidget({
    required this.docId,
    required this.originalPrice,
    required this.initialOfferPrice,
    required this.initialIsActive,
  });

  @override
  State<_PromoFormWidget> createState() => _PromoFormWidgetState();
}

class _PromoFormWidgetState extends State<_PromoFormWidget> {
  late TextEditingController _priceController;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isActive = widget.initialIsActive;
    _priceController = TextEditingController(
      text: widget.initialOfferPrice == widget.originalPrice
          ? ''
          : widget.initialOfferPrice.toString(),
    );
  }

  Future<void> _savePromotion() async {
    setState(() => _isSaving = true);
    double newOfferPrice = double.tryParse(_priceController.text) ?? 0.0;
    try {
      await FirebaseFirestore.instance
          .collection('menu_items')
          .doc(widget.docId)
          .update({'offerPrice': newOfferPrice, 'isPromoActive': _isActive});
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Promo updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set Discount / Promo',
            style: TextStyle(
              color: kWhite,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Original Price: RM ${widget.originalPrice.toStringAsFixed(2)}',
            style: const TextStyle(color: kMuted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: kWhite, fontSize: 18),
            decoration: InputDecoration(
              labelText: 'New Promo Price (RM)',
              labelStyle: const TextStyle(color: kPrimary),
              filled: true,
              fillColor: kCardBg,
              prefixIcon: const Icon(Icons.local_offer, color: kPrimary),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kItemBg),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Promo Active',
                  style: TextStyle(color: kWhite, fontSize: 16),
                ),
                Switch(
                  value: _isActive,
                  activeColor: Colors.greenAccent,
                  inactiveThumbColor: kMuted,
                  inactiveTrackColor: kItemBg,
                  onChanged: (val) => setState(() => _isActive = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isSaving ? null : _savePromotion,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: kWhite,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Save Promotion',
                      style: TextStyle(
                        color: kWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
