// lib/user/checkout.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'payment_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

const kPrimary = Color(0xFFB59410);
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

    // Only the standard mobile Image.network remains!
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
  String? _tableNo;

  @override
  void initState() {
    super.initState();
    _tableNo = widget.tableNo;
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
      final chairNo = doc.data()?['chair_no'] ?? '';
      setState(() {
        if (method == 'Take_Away') {
          _tableNo = 'Take-Away';
        } else if (tableNo.toString().isNotEmpty) {
          _tableNo = chairNo.toString().isNotEmpty
              ? '$tableNo (Chair $chairNo)'
              : tableNo.toString();
        }
      });
    }
  }

  void _handleCheckout(double total, List<QueryDocumentSnapshot> docs) {
    if (_tableNo == null || _tableNo!.isEmpty) {
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
      builder: (_) => TablePickerSheet(
        uid: widget.uid,
        onConfirm: (tableNo, chairNo) async {
          final bool isTakeAway = tableNo == 'Take-Away';

          final currentUser = FirebaseAuth.instance.currentUser;
          String fallbackName = 'Guest';
          if (currentUser != null) {
            fallbackName = (currentUser.displayName?.trim().isNotEmpty ?? false)
                ? currentUser.displayName!.trim()
                : (currentUser.email?.split('@').first ?? 'Guest');
          }

          String username = fallbackName;
          String role = 'Customer';

          try {
            final userDoc = await FirebaseFirestore.instance
              .collection('user')
              .doc(widget.uid)
              .get();

            if (userDoc.exists) {
              final data = userDoc.data();
                username =
                  data?['username'] ?? data?['userName'] ?? data?['name'] ?? fallbackName;
                role = data?['role'] ?? 'Customer';
            }
          } catch (e) {
            debugPrint('Error fetching user info: $e');
          }

          await FirebaseFirestore.instance
              .collection('food_delivery')
              .doc(widget.uid)
              .set({
                'uid': widget.uid,
                'username': username,
                'role': role,
                'delivery_method': isTakeAway ? 'Take_Away' : 'Dine_In',
                'table_no': isTakeAway ? '' : tableNo,
                'chair_no': isTakeAway ? '' : chairNo,
                'timestamp': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

          final String finalTableString = chairNo.isNotEmpty
              ? '$tableNo (Chair $chairNo)'
              : tableNo;

          setState(() => _tableNo = finalTableString);
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
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
          .collection('user')
          .doc(widget.uid)
          .get(),
        builder: (context, userSnap) {
          final currentUser = FirebaseAuth.instance.currentUser;
          String fallbackName = 'Guest';
          if (currentUser != null) {
            fallbackName = (currentUser.displayName?.trim().isNotEmpty ?? false)
                ? currentUser.displayName!.trim()
                : (currentUser.email?.split('@').first ?? 'Guest');
          }

          String username = fallbackName;
          String role = 'Customer';

          if (userSnap.hasData && userSnap.data!.exists) {
            final data = userSnap.data!.data() as Map<String, dynamic>?;
            username =
              data?['username'] ?? data?['userName'] ?? data?['name'] ?? fallbackName;
            role = data?['role'] ?? 'Customer';
          }

          return StreamBuilder<QuerySnapshot>(
            stream: itemsRef.orderBy('createdAt').snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: kPrimary),
                );
              }
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
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: kCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kWhite.withOpacity(0.06)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: kPrimary.withOpacity(0.2),
                          radius: 20,
                          child: const Icon(
                            Icons.person,
                            color: kPrimary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                style: const TextStyle(
                                  color: kWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                role,
                                style: const TextStyle(
                                  color: kMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_tableNo == null || _tableNo!.isEmpty)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.5),
                        ),
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
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 13,
                              ),
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
                  _OrderSummary(
                    total: total,
                    tableNo: _tableNo,
                    onCheckout: () => _handleCheckout(total, docs),
                    onChangeTable: () => _showTablePicker(total, docs),
                  ),
                ],
              );
            },
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
    final String? size = m['size'] as String?;

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

                  // 🟢 SHOWING SIZE
                  if (size != null && size.isNotEmpty && size != 'null')
                    _Chip('📏 Size: $size'),

                  if (drinkType != null) _Chip('☕ $drinkType · $sugar sugar'),

                  // 🟢 SHOWING READABLE CHOICES
                  ...choices.entries.map(
                    (e) => _Chip('✔️ ${e.key}: ${e.value}'),
                  ),

                  // 🟢 SHOWING ADD-ONS WITH PRICES
                  if (addOns.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    const Text(
                      '➕ Extras:',
                      style: TextStyle(
                        color: kMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ...addOns.map((a) {
                      final optName = a['name'] ?? '';
                      final optPrice = (a['price'] as num?)?.toDouble() ?? 0.0;
                      return _Chip(
                        '  • $optName (+CHF ${optPrice.toStringAsFixed(2)})',
                      );
                    }),
                  ],

                  if (extraNote != null && extraNote.isNotEmpty)
                    _Chip('📝 $extraNote'),
                  if (note != null && note.isNotEmpty) _Chip('📝 $note'),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
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

// ── Table & Chair Picker Sheet ─────────────────────────────────────────────
class TablePickerSheet extends StatefulWidget {
  final String uid;
  final void Function(String tableNo, String chairNo) onConfirm;
  const TablePickerSheet({required this.uid, required this.onConfirm});

  @override
  State<TablePickerSheet> createState() => _TablePickerSheetState();
}

class _TablePickerSheetState extends State<TablePickerSheet>
    with TickerProviderStateMixin {
  TabController? _tabController;
  final _tableCtrl = TextEditingController();
  final _chairCtrl = TextEditingController();

  String? _scannedTable;
  bool _isLoading = true;
  bool _isStaffOrAdmin = false;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    try {
      var userDoc = await FirebaseFirestore.instance
          .collection('user')
          .doc(widget.uid)
          .get();

      if (userDoc.exists) {
        final role = (userDoc.data()?['role'] as String?)
                ?.toLowerCase()
                .trim() ??
            '';
        if (role == 'cashier' ||
          role == 'admin' ||
          role == 'staff' ||
          role == 'waiter') {
          _isStaffOrAdmin = true;
        }
      }
    } catch (e) {
      debugPrint('Error fetching role in picker: $e');
    } finally {
      if (mounted) {
        setState(() {
          _tabController = TabController(
            length: _isStaffOrAdmin ? 3 : 2,
            vsync: this,
          );
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _tableCtrl.dispose();
    _chairCtrl.dispose();
    super.dispose();
  }

  void _confirm(String tableVal, String chairVal) {
    Navigator.pop(context);
    final trimmedTable = tableVal.trim();
    final trimmedChair = chairVal.trim();

    if (trimmedTable.isEmpty || trimmedTable == 'Take-Away') {
      widget.onConfirm('Take-Away', '');
      return;
    }

    widget.onConfirm(trimmedTable, trimmedChair);
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

            if (_isLoading)
              const SizedBox(
                height: 220,
                child: Center(
                  child: CircularProgressIndicator(color: kPrimary),
                ),
              )
            else ...[
              TabBar(
                controller: _tabController,
                indicatorColor: kPrimary,
                labelColor: kPrimary,
                unselectedLabelColor: kMuted,
                dividerColor: Colors.transparent,
                tabs: [
                  const Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan QR'),
                  if (_isStaffOrAdmin)
                    const Tab(
                      icon: Icon(Icons.edit_outlined),
                      text: 'Type No.',
                    ),
                  const Tab(
                    icon: Icon(Icons.shopping_bag_outlined),
                    text: 'Take-Away',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 260,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildQrTab(),
                    if (_isStaffOrAdmin) _buildTypeTab(),
                    _buildTakeAwayTab(),
                  ],
                ),
              ),
            ],
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
              'QR scanning not supported on web.\nPlease use a mobile device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_scannedTable != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 40),
          const SizedBox(height: 8),
          Text(
            'Scanned Table: $_scannedTable',
            style: const TextStyle(
              color: kWhite,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _chairCtrl,
            style: const TextStyle(color: kWhite, fontSize: 16),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'Enter Chair No. (e.g. 1, 2, A)',
              hintStyle: const TextStyle(color: kMuted, fontSize: 14),
              filled: true,
              fillColor: kBg,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kMuted.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimary, width: 2),
              ),
              prefixIcon: const Icon(Icons.chair_outlined, color: kPrimary),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: kWhite,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _confirm(_scannedTable!, _chairCtrl.text),
              child: const Text('Confirm Table & Chair'),
            ),
          ),
          TextButton(
            onPressed: () => setState(() {
              _scannedTable = null;
              _chairCtrl.clear();
            }),
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
            setState(() => _scannedTable = barcode!.rawValue);
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
          controller: _tableCtrl,
          keyboardType: TextInputType.text,
          style: const TextStyle(color: kWhite, fontSize: 16),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: 'Table No. (e.g. T5 or 12)',
            hintStyle: const TextStyle(color: kMuted, fontSize: 14),
            filled: true,
            fillColor: kBg,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: kMuted.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kPrimary, width: 2),
            ),
            prefixIcon: const Icon(Icons.table_restaurant, color: kPrimary),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _chairCtrl,
          keyboardType: TextInputType.text,
          style: const TextStyle(color: kWhite, fontSize: 16),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: 'Chair No. (e.g. 1, 2, A)',
            hintStyle: const TextStyle(color: kMuted, fontSize: 14),
            filled: true,
            fillColor: kBg,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: kMuted.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kPrimary, width: 2),
            ),
            prefixIcon: const Icon(Icons.chair_outlined, color: kPrimary),
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
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _confirm(_tableCtrl.text, _chairCtrl.text),
            child: const Text(
              'Confirm Table & Chair',
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kPrimary.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: kPrimary.withOpacity(0.3)),
          ),
          child: const Icon(
            Icons.shopping_bag_outlined,
            color: kPrimary,
            size: 40,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Your order will be\nprepared for pickup',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: kWhite,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: kWhite,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _confirm('Take-Away', ''),
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
