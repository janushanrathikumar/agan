// lib/user/home_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:restorant/user/menu.dart';
import 'package:restorant/user/checkout.dart';
import '../language.dart';

const kPrimary = Color(0xFFE49024);
const kBg = Color(0xFF112A18);
const kMuted = Color(0xFFA1B3A1);
const kWhite = Color(0xFFF7F7F2);
const kCardBg = Color(0xFF1A3822);
const kItemBg = Color(0xFF1E3A24);

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // ── Dine In ────────────────────────────────────────────────────────────────
  Future<void> _handleDineIn(BuildContext context) async {
    final tableNo = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TablePickerSheet(),
    );
    if (tableNo != null && context.mounted) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('food_delivery')
            .doc(user.uid)
            .set({
          'delivery_method': 'Dine_In',
          'table_no': tableNo,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MenuPage(tableNo: tableNo)),
        );
      }
    }
  }

  // ── Take Away ──────────────────────────────────────────────────────────────
  Future<void> _handleTakeAway(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('food_delivery')
          .doc(user.uid)
          .set({
        'delivery_method': 'Take_Away',
        'table_no': '',          // ✅ blank for take-away
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => const MenuPage(tableNo: 'Take-Away')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Image.asset('assets/logo.jpeg', height: 45),
        ),
      ),
      floatingActionButton: _CartFab(
        onTap: (uid, tableNo) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CheckoutPage(uid: uid, tableNo: tableNo),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top shortcut cards ────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _TopCard(
                        label: AppLanguage.getText('rewards'),
                        icon: Icons.loyalty,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TopCard(
                        label: AppLanguage.getText('balance'),
                        icon: Icons.account_balance_wallet,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TopCard(
                        label: AppLanguage.getText('qr_scanner'),
                        icon: Icons.qr_code_scanner,
                        onTap: () => _handleDineIn(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Promo section header ──────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Special Offers',
                          style: TextStyle(
                            color: kWhite,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Today's best deals for you",
                          style:
                              TextStyle(color: kMuted, fontSize: 12),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: kPrimary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: kPrimary.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_fire_department,
                              color: kPrimary, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Hot Deals',
                            style: TextStyle(
                              color: kPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Big promo carousel ────────────────────────────────
              _PromoCarousel(
                onDineIn: () => _handleDineIn(context),
                onTakeAway: () => _handleTakeAway(context),
              ),

              const SizedBox(height: 28),

              // ── Main action buttons ───────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _BigActionButton(
                        label: AppLanguage.getText('dine_in'),
                        icon: Icons.restaurant,
                        onTap: () => _handleDineIn(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BigActionButton(
                        label: AppLanguage.getText('take_away'),
                        icon: Icons.shopping_bag,
                        onTap: () => _handleTakeAway(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Floating Cart Button ─────────────────────────────────────────────────────
class _CartFab extends StatelessWidget {
  final void Function(String uid, String? tableNo) onTap;
  const _CartFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat')
          .doc(user.uid)
          .collection('items')
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        double total = 0;
        int count = 0;
        for (final d in docs) {
          final m = (d.data() as Map<String, dynamic>? ?? {});
          double itemPrice = (m['price'] as num?)?.toDouble() ?? 0.0;
          final List addons = m['additionalOptions'] ?? [];
          double addonsTotal = 0;
          for (var a in addons) {
            if (a is Map)
              addonsTotal += (a['price'] as num?)?.toDouble() ?? 0.0;
          }
          final qty = (m['qty'] as num?)?.toInt() ?? 1;
          total += (itemPrice + addonsTotal) * qty;
          count += qty;
        }
        if (total == 0) return const SizedBox.shrink();

        return FloatingActionButton.extended(
          backgroundColor: kPrimary,
          foregroundColor: kWhite,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.shopping_cart_outlined),
              if (count > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$count',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 9),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          label: Text(
            'CHF ${total.toStringAsFixed(2)}',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16),
          ),
          onPressed: () async {
            // fetch saved table info
            final delivDoc = await FirebaseFirestore.instance
                .collection('food_delivery')
                .doc(user.uid)
                .get();
            final tableNo = delivDoc.exists
                ? (delivDoc.data()?['delivery_method'] == 'Take_Away'
                    ? 'Take-Away'
                    : delivDoc.data()?['table_no'] as String?)
                : null;
            if (context.mounted) onTap(user.uid, tableNo);
          },
        );
      },
    );
  }
}

// ── Big Promo Carousel ───────────────────────────────────────────────────────
class _PromoCarousel extends StatefulWidget {
  final VoidCallback onDineIn;
  final VoidCallback onTakeAway;
  const _PromoCarousel(
      {required this.onDineIn, required this.onTakeAway});

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  final PageController _ctrl = PageController(viewportFraction: 0.92);
  int _current = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Check if customer has selected dine-in or take-away ──────────────────
  Future<bool> _hasSelectedMethod(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final doc = await FirebaseFirestore.instance
        .collection('food_delivery')
        .doc(user.uid)
        .get();
    return doc.exists;
  }

  // ── Show method picker before opening item sheet ──────────────────────────
  Future<void> _askMethod(BuildContext context,
      Map<String, dynamic> itemData) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MethodPickerSheet(
        onDineIn: () async {
          Navigator.pop(context);
           await MenuPage();
        },
        onTakeAway: () async {
          Navigator.pop(context);
          await MenuPage();
        },
      ),
    );
    // After method selected, try again
    if (context.mounted) await _openItemSheet(context, itemData);
  }

  Future<void> _openItemSheet(
      BuildContext context, Map<String, dynamic> itemData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login first')));
      return;
    }
    final hasMethod = await _hasSelectedMethod(context);
    if (!hasMethod) {
      if (context.mounted) await _askMethod(context, itemData);
      return;
    }
    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _PromoItemSheet(itemData: itemData),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('menu_items')
          .where('isPromoActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 240,
            child: Center(
                child: CircularProgressIndicator(color: kPrimary)),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _EmptyPromo();
        }

        final promoDocs = snapshot.data!.docs;

        return Column(
          children: [
            SizedBox(
              height: 260,
              child: PageView.builder(
                controller: _ctrl,
                itemCount: promoDocs.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (context, index) {
                  final data =
                      promoDocs[index].data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Special Offer';
                  final imageUrl = (data['imageUrl'] ?? '') as String;
                  final itemType = (data['itemType'] ?? 'food') as String;
                  final num originalPrice = data['price'] ?? 0;
                  final num offerPrice = data['offerPrice'] ?? 0;
                  final bool isCombo = itemType == 'combo';
                  double discPct = 0;
                  if (originalPrice > 0 && originalPrice > offerPrice) {
                    discPct = ((originalPrice - offerPrice) /
                            originalPrice *
                            100)
                        .roundToDouble();
                  }
                  final isActive = _current == index;

                  return GestureDetector(
                    onTap: () => _openItemSheet(context, data),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: EdgeInsets.only(
                        left: index == 0 ? 16 : 8,
                        right: index == promoDocs.length - 1 ? 16 : 8,
                        top: isActive ? 0 : 10,
                        bottom: isActive ? 0 : 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: isActive
                            ? Border.all(
                                color: kPrimary.withOpacity(0.7),
                                width: 2)
                            : null,
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: kPrimary.withOpacity(0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                )
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // BG image
                            imageUrl.isNotEmpty
                                ? Image.network(imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        Container(
                                          color: kCardBg,
                                          child: const Icon(
                                              Icons.fastfood,
                                              color: kMuted,
                                              size: 80),
                                        ))
                                : Container(
                                    color: kCardBg,
                                    child: const Icon(Icons.fastfood,
                                        color: kMuted, size: 80),
                                  ),

                            // Gradient overlay
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: const [0.0, 0.4, 1.0],
                                  colors: [
                                    Colors.black.withOpacity(0.05),
                                    Colors.black.withOpacity(0.15),
                                    Colors.black.withOpacity(0.92),
                                  ],
                                ),
                              ),
                            ),

                            // Top-left badges
                            Positioned(
                              top: 14,
                              left: 14,
                              child: Row(
                                children: [
                                  _Badge(
                                    label: isCombo ? 'COMBO' : 'PROMO',
                                    color: isCombo
                                        ? const Color(0xFFFF8C00)
                                        : const Color(0xFFE53935),
                                    icon: isCombo
                                        ? Icons.layers
                                        : Icons.local_offer,
                                  ),
                                  if (discPct > 0) ...[
                                    const SizedBox(width: 6),
                                    _Badge(
                                      label: '-${discPct.toInt()}%',
                                      color: const Color(0xFF2E7D32),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Top-right quick-add circle button
                            Positioned(
                              top: 10,
                              right: 10,
                              child: GestureDetector(
                                onTap: () =>
                                    _openItemSheet(context, data),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: kPrimary,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: kPrimary.withOpacity(0.5),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.add,
                                      color: Colors.white, size: 22),
                                ),
                              ),
                            ),

                            // Bottom info
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 0, 16, 16),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              shadows: [
                                                Shadow(
                                                    color: Colors.black,
                                                    blurRadius: 6)
                                              ],
                                            ),
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'CHF ${offerPrice.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  color: kPrimary,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w900,
                                                  shadows: [
                                                    Shadow(
                                                        color: Colors.black,
                                                        blurRadius: 8)
                                                  ],
                                                ),
                                              ),
                                              if (originalPrice >
                                                  offerPrice) ...[
                                                const SizedBox(width: 8),
                                                Text(
                                                  'CHF ${originalPrice.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    color: kMuted
                                                        .withOpacity(0.85),
                                                    fontSize: 14,
                                                    decoration:
                                                        TextDecoration
                                                            .lineThrough,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Order button
                                    GestureDetector(
                                      onTap: () =>
                                          _openItemSheet(context, data),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 18, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: kPrimary,
                                          borderRadius:
                                              BorderRadius.circular(30),
                                          boxShadow: [
                                            BoxShadow(
                                              color: kPrimary
                                                  .withOpacity(0.5),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: const Text(
                                          'Order Now',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Page dots
            if (promoDocs.length > 1) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  promoDocs.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _current == i ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _current == i
                          ? kPrimary
                          : kMuted.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── Badge widget ─────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _Badge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 11),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Method picker sheet (Dine-In / Take-Away) ────────────────────────────────
class _MethodPickerSheet extends StatelessWidget {
  final VoidCallback onDineIn;
  final VoidCallback onTakeAway;
  const _MethodPickerSheet(
      {required this.onDineIn, required this.onTakeAway});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF194D25),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: kMuted.withOpacity(0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Text(
            'How would you like to order?',
            style: TextStyle(
              color: kWhite,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Please select before adding to cart',
            style: TextStyle(color: kMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _MethodBtn(
                  icon: Icons.restaurant,
                  label: 'Dine-In',
                  sub: 'Choose a table',
                  onTap: onDineIn,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MethodBtn(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Take-Away',
                  sub: 'Pick up order',
                  onTap: onTakeAway,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MethodBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  const _MethodBtn(
      {required this.icon,
      required this.label,
      required this.sub,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: kPrimary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: kWhite, size: 32),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    color: kWhite,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            const SizedBox(height: 2),
            Text(sub,
                style: TextStyle(
                    color: kWhite.withOpacity(0.7), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── Promo Item Sheet ─────────────────────────────────────────────────────────
// Full featured: choices, add-ons, qty, add-to-cart + buy-now
class _PromoItemSheet extends StatefulWidget {
  final Map<String, dynamic> itemData;
  const _PromoItemSheet({required this.itemData});

  @override
  State<_PromoItemSheet> createState() => _PromoItemSheetState();
}

class _PromoItemSheetState extends State<_PromoItemSheet> {
  int _qty = 1;
  final TextEditingController _noteCtrl = TextEditingController();
  String? _selectedChoice;
  final List<Map<String, dynamic>> _selectedAddons = [];

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  double get _basePrice {
    final bool isPromo = widget.itemData['isPromoActive'] ?? false;
    return ((isPromo
                    ? widget.itemData['offerPrice']
                    : widget.itemData['price']) as num?)
                ?.toDouble() ??
        0.0;
  }

  double get _totalPrice {
    double addons = 0;
    for (var a in _selectedAddons) {
      addons += (a['price'] as num?)?.toDouble() ?? 0.0;
    }
    return (_basePrice + addons) * _qty;
  }

  Future<void> _addToCart({bool goToCheckout = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final cartItem = {
      'name': widget.itemData['name'] ?? '',
      'price': _basePrice,
      'qty': _qty,
      'imageUrl': widget.itemData['imageUrl'] ?? '',
      'kind': widget.itemData['itemType'] ?? 'food',
      'note': _noteCtrl.text.trim(),
      'additionalOptions': _selectedAddons,
      'menuChoices':
          _selectedChoice != null ? {'Choice': _selectedChoice} : {},
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('chat')
          .doc(user.uid)
          .collection('items')
          .add(cartItem);

      if (!mounted) return;
      Navigator.pop(context);

      if (goToCheckout) {
        // Fetch delivery info for tableNo
        final delivDoc = await FirebaseFirestore.instance
            .collection('food_delivery')
            .doc(user.uid)
            .get();
        final method = delivDoc.data()?['delivery_method'] ?? '';
        final tableNo = method == 'Take_Away'
            ? 'Take-Away'
            : delivDoc.data()?['table_no'] as String?;
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CheckoutPage(uid: user.uid, tableNo: tableNo),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to cart!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.itemData['name'] ?? 'Item';
    final imageUrl = (widget.itemData['imageUrl'] ?? '') as String;
    final noteDesc = (widget.itemData['note'] ?? '') as String;
    final num originalPrice = widget.itemData['price'] ?? 0;
    final num offerPrice = widget.itemData['offerPrice'] ?? 0;
    final List<dynamic> choices =
        widget.itemData['menuChoices'] ?? [];
    final List<dynamic> addons =
        widget.itemData['additionalOptions'] ?? [];

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: kMuted.withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Item header ─────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: imageUrl.isNotEmpty
                            ? Image.network(imageUrl,
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                    width: 90,
                                    height: 90,
                                    color: kBg,
                                    child: const Icon(Icons.fastfood,
                                        color: kMuted)))
                            : Container(
                                width: 90,
                                height: 90,
                                color: kBg,
                                child: const Icon(Icons.fastfood,
                                    color: kMuted)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    color: kWhite,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            // Promo price
                            Row(
                              children: [
                                Text(
                                  'CHF ${offerPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: kPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (originalPrice > offerPrice) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    'CHF ${originalPrice.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: kMuted.withOpacity(0.7),
                                      fontSize: 13,
                                      decoration:
                                          TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (noteDesc.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(noteDesc,
                                  style: const TextStyle(
                                      color: kMuted, fontSize: 12)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Note field ──────────────────────────────────
                  const Text('Note (optional)',
                      style: TextStyle(
                          color: kWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteCtrl,
                    style: const TextStyle(color: kWhite),
                    decoration: InputDecoration(
                      hintText: 'Any special requests...',
                      hintStyle: const TextStyle(color: kMuted),
                      filled: true,
                      fillColor: kBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Choices ─────────────────────────────────────
                  if (choices.isNotEmpty) ...[
                    _SectionLabel('Choose Option', required: true),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: kBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: kMuted.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: choices.map((c) {
                          final cs = c.toString();
                          return RadioListTile<String>(
                            title: Text(cs,
                                style: const TextStyle(color: kWhite)),
                            activeColor: kPrimary,
                            value: cs,
                            groupValue: _selectedChoice,
                            onChanged: (v) =>
                                setState(() => _selectedChoice = v),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Add-ons ─────────────────────────────────────
                  if (addons.isNotEmpty) ...[
                    _SectionLabel('Add-ons', required: false),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: kBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: kMuted.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: addons.map((addon) {
                          final aMap = addon as Map<String, dynamic>;
                          final aName = aMap['name'] ?? '';
                          final aPrice =
                              (aMap['price'] as num?)?.toDouble() ??
                                  0.0;
                          final isSel = _selectedAddons.contains(aMap);
                          return CheckboxListTile(
                            title: Text(aName,
                                style: const TextStyle(color: kWhite)),
                            subtitle: Text(
                                '+CHF ${aPrice.toStringAsFixed(2)}',
                                style: const TextStyle(color: kMuted)),
                            activeColor: kPrimary,
                            checkColor: kWhite,
                            value: isSel,
                            onChanged: (val) => setState(() {
                              if (val == true)
                                _selectedAddons.add(aMap);
                              else
                                _selectedAddons.remove(aMap);
                            }),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),

          // ── Bottom bar ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            decoration: BoxDecoration(
              color: kBg,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Qty row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Quantity',
                          style: TextStyle(
                              color: kMuted, fontSize: 14)),
                      Row(
                        children: [
                          _QtyBtn(
                              icon: Icons.remove,
                              onTap: () => setState(
                                  () => _qty = _qty > 1 ? _qty - 1 : 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18),
                            child: Text('$_qty',
                                style: const TextStyle(
                                    color: kWhite,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                          ),
                          _QtyBtn(
                              icon: Icons.add,
                              onTap: () =>
                                  setState(() => _qty++)),
                        ],
                      ),
                      Text(
                        'CHF ${_totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: kWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: kPrimary),
                            padding:
                                const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                          ),
                          onPressed: () => _addToCart(),
                          child: const Text('Add to Cart',
                              style: TextStyle(color: kWhite)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            padding:
                                const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                          ),
                          onPressed: () =>
                              _addToCart(goToCheckout: true),
                          child: const Text('Buy Now',
                              style: TextStyle(
                                  color: kWhite,
                                  fontWeight: FontWeight.bold)),
                        ),
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
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _SectionLabel(this.text, {required this.required});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text,
            style: const TextStyle(
                color: kWhite,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
        const SizedBox(width: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: required
                ? kPrimary.withOpacity(0.2)
                : kMuted.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            required ? 'Required' : 'Optional',
            style: TextStyle(
                color: required ? kPrimary : kMuted,
                fontSize: 10,
                fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          border: Border.all(color: kMuted),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: kWhite, size: 20),
      ),
    );
  }
}

// ── Empty promo ──────────────────────────────────────────────────────────────
class _EmptyPromo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 170,
        decoration: BoxDecoration(
          color: kWhite.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kPrimary.withOpacity(0.3)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, color: kPrimary, size: 44),
            SizedBox(height: 12),
            Text('Welcome to our Restaurant!',
                style: TextStyle(
                    color: kWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('Check out our menu for delicious meals.',
                style: TextStyle(color: kMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ── Table Picker Sheet (for Home Page DineIn) ────────────────────────────────
class _TablePickerSheet extends StatefulWidget {
  const _TablePickerSheet();

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
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _typeCtrl.dispose();
    super.dispose();
  }

  void _confirm(String val) => Navigator.pop(context, val.trim());

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF194D25),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: kMuted.withOpacity(0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Text('Dine-In: Enter Table',
              style: TextStyle(
                  color: kWhite,
                  fontWeight: FontWeight.w700,
                  fontSize: 18)),
          const SizedBox(height: 4),
          const Text(
              'Scan the QR code on your table or type the number',
              style: TextStyle(color: kMuted, fontSize: 12),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          TabBar(
            controller: _tab,
            indicatorColor: kPrimary,
            labelColor: kPrimary,
            unselectedLabelColor: kMuted,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(
                  icon: Icon(Icons.qr_code_scanner), text: 'Scan QR'),
              Tab(icon: Icon(Icons.edit_outlined), text: 'Type No.'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 230,
            child: TabBarView(
              controller: _tab,
              children: [_buildQrTab(), _buildTypeTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrTab() {
    if (_scannedValue != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle,
              color: Colors.greenAccent, size: 52),
          const SizedBox(height: 12),
          Text('Table: $_scannedValue',
              style: const TextStyle(
                  color: kWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: kWhite,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 14),
            ),
            onPressed: () => _confirm(_scannedValue!),
            child: const Text('Go to Menu',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => setState(() => _scannedValue = null),
            child: const Text('Scan again',
                style: TextStyle(color: kMuted)),
          ),
        ],
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: MobileScanner(
        onDetect: (capture) {
          final val = capture.barcodes.firstOrNull?.rawValue;
          if (val != null && mounted)
            setState(() => _scannedValue = val);
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
          keyboardType: TextInputType.text,
          style: const TextStyle(color: kWhite, fontSize: 18),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: 'e.g.  T5  or  12',
            hintStyle: const TextStyle(color: kMuted),
            filled: true,
            fillColor: kBg,
            prefixIcon:
                const Icon(Icons.table_restaurant, color: kPrimary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: kMuted.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: kPrimary, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: kMuted.withOpacity(0.3)),
            ),
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
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              final val = _typeCtrl.text.trim();
              if (val.isNotEmpty) _confirm(val);
            },
            child: const Text('Go to Menu',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

// ── Helper widgets ───────────────────────────────────────────────────────────
class _TopCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _TopCard(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kWhite.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, size: 28, color: kPrimary),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: kWhite),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _BigActionButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kPrimary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Icon(icon, color: kWhite, size: 28),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(
                      color: kWhite,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}