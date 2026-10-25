import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:restorant/shared/menu_offer.dart';
import 'add_combo.dart';

// --- Palette ---
const kPrimary = Color(0xFFB59410);
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
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddComboPage()),
        ),
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
              final double originalPrice = menuOriginalPrice(data);
              final String imageUrl = data['imageUrl'] ?? '';
              final String itemType = data['itemType'] ?? 'food';

              // Promo fields
              final bool isPromoActive =
                  data['isPromoActive'] == true || hasMenuOffer(data);
              final double offerPrice = menuOfferPrice(data);
              final offerLabel = menuOfferLabel(data);

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
                      if (offerLabel != null)
                        Text(
                          '  $offerLabel',
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Row(
                      children: [
                        Text(
                          // 🟢 RM -> CHF, matching every other price in the app
                          'CHF ${originalPrice.toStringAsFixed(2)}',
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
                            // 🟢 RM -> CHF
                            'CHF ${offerPrice.toStringAsFixed(2)}',
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
                  onTap: () => isCombo
                      ? Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AddComboPage(docId: doc.id, itemData: data),
                          ),
                        )
                      : _showDiscountBottomSheet(context, doc),
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

  // --- Open Edit Promo Price Sheet ---
  void _showDiscountBottomSheet(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final num currentPrice = menuOriginalPrice(data);

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
          initialOfferPrice: menuOfferPrice(data),
          initialIsActive: data['isPromoActive'] ?? false,
          initialDiscountType: data['discountType'] as String?,
          initialDiscountValue: (data['discountValue'] as num?)?.toDouble(),
          initialHasDiscount: data['hasDiscount'] == true,
        );
      },
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
  final String? initialDiscountType;
  final double? initialDiscountValue;
  final bool initialHasDiscount;

  const _PromoFormWidget({
    required this.docId,
    required this.originalPrice,
    required this.initialOfferPrice,
    required this.initialIsActive,
    required this.initialDiscountType,
    required this.initialDiscountValue,
    required this.initialHasDiscount,
  });

  @override
  State<_PromoFormWidget> createState() => _PromoFormWidgetState();
}

class _PromoFormWidgetState extends State<_PromoFormWidget> {
  late TextEditingController _priceController;
  late bool _isActive;
  late bool _usePercent;
  late TextEditingController _percentController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isActive = widget.initialIsActive || widget.initialHasDiscount;
    _usePercent =
        widget.initialHasDiscount && widget.initialDiscountType == 'percent';
    _percentController = TextEditingController(
      text: _usePercent ? widget.initialDiscountValue?.toString() ?? '' : '',
    );
    _priceController = TextEditingController(
      text: widget.initialOfferPrice == widget.originalPrice
          ? ''
          : widget.initialOfferPrice.toString(),
    );
  }

  Future<void> _savePromotion() async {
    setState(() => _isSaving = true);
    final percent = double.tryParse(_percentController.text.trim());
    final enteredPrice = double.tryParse(_priceController.text.trim());
    if (_isActive &&
        (_usePercent
            ? percent == null || percent <= 0 || percent > 100
            : enteredPrice == null ||
                  enteredPrice < 0 ||
                  enteredPrice >= widget.originalPrice)) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid offer: 1–100% or a lower promo price.'),
        ),
      );
      return;
    }
    final newOfferPrice = _usePercent
        ? widget.originalPrice * (1 - (percent ?? 0) / 100)
        : enteredPrice ?? widget.originalPrice.toDouble();
    try {
      await FirebaseFirestore.instance
          .collection('menu_items')
          .doc(widget.docId)
          .update({
            'offerPrice': newOfferPrice,
            'isPromoActive': _isActive,
            'hasDiscount': _isActive && _usePercent,
            'discountType': _isActive && _usePercent ? 'percent' : null,
            'discountValue': _isActive && _usePercent ? percent : 0,
          });
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
  void dispose() {
    _priceController.dispose();
    _percentController.dispose();
    super.dispose();
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
            // 🟢 RM -> CHF
            'Original Price: CHF ${widget.originalPrice.toStringAsFixed(2)}',
            style: const TextStyle(color: kMuted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Percentage offer',
              style: TextStyle(color: kWhite),
            ),
            subtitle: const Text(
              'Apply to the full menu price',
              style: TextStyle(color: kMuted),
            ),
            value: _usePercent,
            onChanged: (value) => setState(() => _usePercent = value),
          ),
          TextField(
            controller: _usePercent ? _percentController : _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: kWhite, fontSize: 18),
            decoration: InputDecoration(
              // 🟢 RM -> CHF
              labelText: _usePercent ? 'Offer (%)' : 'New Promo Price (CHF)',
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
