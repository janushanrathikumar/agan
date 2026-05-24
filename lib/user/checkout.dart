// lib/user/checkout.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'payment_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

const kPrimary = Color(0xFFA26334);
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);
const kCard = Color(0xFF3A3938);
const kFooter = Color(0xFF242322);

// ── Web-safe image ────────────────────────────────────────────────────────────
class _WebSafeImage extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final Widget fallback;
  const _WebSafeImage({
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) return fallback;
    if (kIsWeb) {
      final viewId =
          'co-img-${imageUrl.hashCode}_${DateTime.now().microsecondsSinceEpoch}';
      ui_web.platformViewRegistry.registerViewFactory(
        viewId,
        (int _) => html.ImageElement()
          ..src = imageUrl
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'cover'
          ..style.borderRadius = '10px',
      );
      return SizedBox(
        width: width,
        height: height,
        child: HtmlElementView(viewType: viewId),
      );
    }
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

// ── CheckoutPage ──────────────────────────────────────────────────────────────
class CheckoutPage extends StatefulWidget {
  final String uid;
  final String? tableNo;
  const CheckoutPage({super.key, required this.uid, this.tableNo});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  // _tableNo: null = not selected, 'Take-Away' = take-away, other = dine-in
  String? _tableNo;

  @override
  void initState() {
    super.initState();
    _tableNo = widget.tableNo;
    // Also try to load from Firestore if not passed
    if (_tableNo == null) _loadTableFromFirestore();
  }

  Future<void> _loadTableFromFirestore() async {
    final doc = await FirebaseFirestore.instance
        .collection('food_delivery')
        .doc(widget.uid)
        .get();
    if (doc.exists) {
      final method = doc.data()?['delivery_method'] ?? '';
      final tableNo = doc.data()?['table_no'] ?? '';
      setState(() {
        if (method == 'Take_Away') {
          _tableNo = 'Take-Away';
        } else if (tableNo.toString().isNotEmpty) {
          _tableNo = tableNo.toString();
        }
      });
    }
  }

  void _handleCheckout(double total, List<QueryDocumentSnapshot> docs) {
    if (_tableNo == null || _tableNo!.isEmpty) {
      // ✅ Must select table/take-away before checkout
      _showTablePicker(total, docs);
    } else {
      _goToPayment();
    }
  }

  void _showTablePicker(double total, List<QueryDocumentSnapshot> docs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TablePickerSheet(
        onConfirm: (tableNo) async {
          // ✅ Save delivery method to Firestore
          final bool isTakeAway = tableNo == 'Take-Away';
          await FirebaseFirestore.instance
              .collection('food_delivery')
              .doc(widget.uid)
              .set({
                'delivery_method': isTakeAway ? 'Take_Away' : 'Dine_In',
                'table_no': isTakeAway ? '' : tableNo, // ✅ blank for take-away
                'timestamp': FieldValue.serverTimestamp(),
              });
          setState(() => _tableNo = tableNo);
          _goToPayment();
        },
      ),
    );
  }

  void _goToPayment() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PaymentPage(uid: widget.uid)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemsRef = FirebaseFirestore.instance
        .collection('chat')
        .doc(widget.uid)
        .collection('items');

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kWhite,
        elevation: 0,
        title: const Text(
          'Your Order',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          if (_tableNo != null && _tableNo!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: kPrimary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kPrimary.withOpacity(0.5)),
                  ),
                  child: Text(
                    _tableNo == 'Take-Away' ? '🛍 Take-Away' : '🪑 $_tableNo',
                    style: const TextStyle(
                      color: kPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: itemsRef.orderBy('createdAt').snapshots(),
        builder: (context, snap) {
          if (!snap.hasData)
            return const Center(
              child: CircularProgressIndicator(color: kPrimary),
            );
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const _EmptyCart();

          double total = 0;
          for (var d in docs) {
            final m = d.data() as Map<String, dynamic>;
            total +=
                ((m['price'] as num?)?.toDouble() ?? 0) *
                ((m['qty'] as num?)?.toInt() ?? 1);
          }

          return Column(
            children: [
              // ── No table banner ──────────────────────────────────
              if (_tableNo == null || _tableNo!.isEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Please select Dine-In or Take-Away before checkout',
                          style: TextStyle(color: Colors.orange, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showTablePicker(total, docs),
                        child: const Text(
                          'Select',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Order list ───────────────────────────────────────
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) =>
                      _CartItemTile(doc: docs[i], itemsRef: itemsRef),
                ),
              ),

              // ── Order summary footer ─────────────────────────────
              _OrderSummary(
                total: total,
                tableNo: _tableNo,
                onCheckout: () => _handleCheckout(total, docs),
                onChangeTable: () => _showTablePicker(total, docs),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Cart Item Tile ────────────────────────────────────────────────────────────
class _CartItemTile extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final CollectionReference itemsRef;
  const _CartItemTile({required this.doc, required this.itemsRef});

  @override
  Widget build(BuildContext context) {
    final m = doc.data() as Map<String, dynamic>;
    final name = (m['name'] as String?) ?? '';
    final price = (m['price'] as num?)?.toDouble() ?? 0;
    final qty = (m['qty'] as num?)?.toInt() ?? 1;
    final imageUrl = (m['imageUrl'] as String?) ?? '';
    final String? drinkType = m['type'] as String?;
    final String? sugar = m['sugar'] as String?;
    final String? extraNote = m['extraNote'] as String?;
    final String? note = m['note'] as String?;
    final Map<String, dynamic> choices = Map<String, dynamic>.from(
      m['menuChoices'] ?? {},
    );
    final List addOns = (m['additionalOptions'] as List?) ?? [];

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: kWhite, size: 28),
      ),
      onDismissed: (_) => itemsRef.doc(doc.id).delete(),
      child: Container(
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kWhite.withOpacity(0.06)),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _WebSafeImage(
                imageUrl: imageUrl,
                width: 70,
                height: 70,
                fallback: Container(
                  width: 70,
                  height: 70,
                  color: kBg,
                  child: const Icon(Icons.fastfood, color: kMuted, size: 30),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: kWhite,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'CHF ${price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: kPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  if (drinkType != null) _Chip('$drinkType · $sugar sugar'),
                  ...choices.entries.map((e) => _Chip('${e.key}: ${e.value}')),
                  if (addOns.isNotEmpty)
                    _Chip('+${addOns.map((a) => a['name']).join(', ')}'),
                  if (extraNote != null && extraNote.isNotEmpty)
                    _Chip('📝 $extraNote'),
                  if (note != null && note.isNotEmpty) _Chip('📝 $note'),
                ],
              ),
            ),

            // ✅ Qty controls (+ / - buttons) + subtotal
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Qty control
                Container(
                  decoration: BoxDecoration(
                    color: kBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kWhite.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SmBtn(
                        icon: Icons.remove,
                        onTap: () {
                          if (qty <= 1) {
                            itemsRef.doc(doc.id).delete();
                          } else {
                            itemsRef.doc(doc.id).update({'qty': qty - 1});
                          }
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '$qty',
                          style: const TextStyle(
                            color: kWhite,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      _SmBtn(
                        icon: Icons.add,
                        onTap: () =>
                            itemsRef.doc(doc.id).update({'qty': qty + 1}),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'CHF ${(price * qty).toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: kMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Text(text, style: const TextStyle(color: kMuted, fontSize: 10)),
  );
}

class _SmBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SmBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Icon(icon, color: kWhite, size: 16),
    ),
  );
}

// ── Empty Cart ────────────────────────────────────────────────────────────────
class _EmptyCart extends StatelessWidget {
  const _EmptyCart();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.shopping_bag_outlined,
          color: kMuted.withOpacity(0.4),
          size: 80,
        ),
        const SizedBox(height: 16),
        const Text(
          'Your cart is empty',
          style: TextStyle(
            color: kMuted,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Add items from the menu to get started',
          style: TextStyle(color: kMuted, fontSize: 13),
        ),
      ],
    ),
  );
}

// ── Order Summary Footer ──────────────────────────────────────────────────────
class _OrderSummary extends StatelessWidget {
  final double total;
  final String? tableNo;
  final VoidCallback onCheckout;
  final VoidCallback onChangeTable;

  const _OrderSummary({
    required this.total,
    required this.tableNo,
    required this.onCheckout,
    required this.onChangeTable,
  });

  @override
  Widget build(BuildContext context) {
    final noTable = tableNo == null || tableNo!.isEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: kFooter,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: kWhite.withOpacity(0.08))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: kMuted.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          // Table / Take-Away row
          Row(
            children: [
              Icon(
                tableNo == 'Take-Away'
                    ? Icons.shopping_bag_outlined
                    : Icons.table_restaurant_outlined,
                color: noTable ? Colors.orange : kPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  noTable
                      ? 'No table selected — tap to select'
                      : tableNo == 'Take-Away'
                      ? 'Take-Away order'
                      : 'Table $tableNo',
                  style: TextStyle(
                    color: noTable ? Colors.orange : kWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: onChangeTable,
                child: Text(
                  noTable ? 'Select ›' : 'Change',
                  style: TextStyle(
                    color: noTable ? Colors.orange : kPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const Divider(color: Colors.white10, height: 18),

          // Total + Checkout button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(color: kMuted, fontSize: 12),
                  ),
                  Text(
                    'CHF ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: kWhite,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: noTable ? Colors.orange : kPrimary,
                    foregroundColor: kWhite,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: onCheckout,
                  icon: Icon(
                    noTable
                        ? Icons.warning_amber_rounded
                        : Icons.arrow_forward_rounded,
                    size: 20,
                  ),
                  label: Text(
                    noTable ? 'Select Table' : 'Checkout',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Table Picker Sheet ────────────────────────────────────────────────────────
class _TablePickerSheet extends StatefulWidget {
  final void Function(String tableNo) onConfirm;
  const _TablePickerSheet({required this.onConfirm});

  @override
  State<_TablePickerSheet> createState() => _TablePickerSheetState();
}

class _TablePickerSheetState extends State<_TablePickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _typeCtrl = TextEditingController();
  String? _scannedValue;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _typeCtrl.dispose();
    super.dispose();
  }

  void _confirm(String val) {
    Navigator.pop(context);
    widget.onConfirm(val.trim().isEmpty ? 'Take-Away' : val.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: kMuted.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Text(
              'How would you like to order?',
              style: TextStyle(
                color: kWhite,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 20),
            TabBar(
              controller: _tab,
              indicatorColor: kPrimary,
              labelColor: kPrimary,
              unselectedLabelColor: kMuted,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan QR'),
                Tab(icon: Icon(Icons.edit_outlined), text: 'Type No.'),
                Tab(icon: Icon(Icons.shopping_bag_outlined), text: 'Take-Away'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: TabBarView(
                controller: _tab,
                children: [_buildQrTab(), _buildTypeTab(), _buildTakeAwayTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrTab() {
    if (kIsWeb) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.qr_code_scanner,
              color: kMuted.withOpacity(0.4),
              size: 56,
            ),
            const SizedBox(height: 12),
            const Text(
              'QR scanning not supported on web.\nPlease type your table number.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_scannedValue != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 48),
          const SizedBox(height: 10),
          Text(
            'Table: $_scannedValue',
            style: const TextStyle(
              color: kWhite,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: kWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _confirm(_scannedValue!),
            child: const Text('Confirm Table'),
          ),
          TextButton(
            onPressed: () => setState(() => _scannedValue = null),
            child: const Text('Scan again', style: TextStyle(color: kMuted)),
          ),
        ],
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: MobileScanner(
        onDetect: (capture) {
          final barcode = capture.barcodes.firstOrNull;
          if (barcode?.rawValue != null) {
            setState(() => _scannedValue = barcode!.rawValue);
          }
        },
      ),
    );
  }

  Widget _buildTypeTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextField(
          controller: _typeCtrl,
          autofocus: false,
          keyboardType: TextInputType.text,
          style: const TextStyle(color: kWhite, fontSize: 18),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: 'e.g. T5 or 12',
            hintStyle: const TextStyle(color: kMuted),
            filled: true,
            fillColor: kBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: kMuted.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kPrimary, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: kMuted.withOpacity(0.3)),
            ),
            prefixIcon: const Icon(Icons.table_restaurant, color: kPrimary),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: kWhite,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => _confirm(_typeCtrl.text),
            child: const Text(
              'Confirm Table',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTakeAwayTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: kPrimary.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: kPrimary.withOpacity(0.3)),
          ),
          child: const Icon(
            Icons.shopping_bag_outlined,
            color: kPrimary,
            size: 44,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Your order will be\nprepared for pickup',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: kWhite,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: kWhite,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            // ✅ 'Take-Away' passed — Firestore will save table_no as ''
            onPressed: () => _confirm('Take-Away'),
            child: const Text(
              'Continue as Take-Away',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
