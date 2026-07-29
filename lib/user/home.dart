// lib/user/home_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:restorant/user/menu.dart';
import 'package:restorant/user/checkout.dart';
import '../language.dart';

const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF112A18);
const kMuted = Color(0xFFA1B3A1);
const kWhite = Color(0xFFF7F7F2);
const kCardBg = Color(0xFF1A3822);
const kItemBg = Color(0xFF1E3A24);
const kDarkBar = Color(0xFF0C1E11);
const kDiscount = Color(0xFFE0483E);

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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

  Future<void> _handleTakeAway(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('food_delivery')
          .doc(user.uid)
          .set({
            'delivery_method': 'Take_Away',
            'table_no': '',
            'timestamp': FieldValue.serverTimestamp(),
          });
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MenuPage(tableNo: 'Take-Away')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
              // ── Main action buttons (Dine In & Take Away) ──────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: _BigActionButton(
                        label: AppLanguage.getText('dine_in'),
                        icon: Icons.storefront_rounded,
                        isPrimary: true,
                        onTap: () => _handleDineIn(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _BigActionButton(
                        label: AppLanguage.getText('take_away'),
                        icon: Icons.takeout_dining_rounded,
                        isPrimary: false,
                        onTap: () => _handleTakeAway(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Promo & Combos section header ─────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Special Offers & Combos',
                          style: TextStyle(
                            color: kWhite,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Today's best deals and combos for you",
                          style: TextStyle(
                            color: kMuted.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Big promo & combo carousel ────────────────────────────────
              _PromoCarousel(
                onDineIn: () => _handleDineIn(context),
                onTakeAway: () => _handleTakeAway(context),
              ),

              const SizedBox(height: 120),
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

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            height: 65,
            width: double.infinity,
            child: FloatingActionButton.extended(
              elevation: 8,
              backgroundColor: kPrimary,
              foregroundColor: kWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onPressed: () async {
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
              label: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'View Cart',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'CHF ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Big Promo & Combo Carousel ───────────────────────────────────────────────
class _PromoCarousel extends StatefulWidget {
  final VoidCallback onDineIn;
  final VoidCallback onTakeAway;
  const _PromoCarousel({required this.onDineIn, required this.onTakeAway});

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  final PageController _ctrl = PageController(viewportFraction: 0.90);
  int _current = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<bool> _hasSelectedMethod(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final doc = await FirebaseFirestore.instance
        .collection('food_delivery')
        .doc(user.uid)
        .get();
    return doc.exists;
  }

  Future<void> _askMethod(
    BuildContext context,
    Map<String, dynamic> itemData,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MethodPickerSheet(
        onDineIn: () async {
          Navigator.pop(context);
          widget.onDineIn();
        },
        onTakeAway: () async {
          Navigator.pop(context);
          widget.onTakeAway();
        },
      ),
    );
  }

  Future<void> _openItemSheet(
    BuildContext context,
    Map<String, dynamic> itemData,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login first')));
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
            height: 280,
            child: Center(child: CircularProgressIndicator(color: kPrimary)),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return _EmptyPromo();

        final promoDocs = snapshot.data!.docs;

        return Column(
          children: [
            SizedBox(
              height: 290,
              child: PageView.builder(
                controller: _ctrl,
                itemCount: promoDocs.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (context, index) {
                  final data = promoDocs[index].data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Special Offer';
                  final imageUrl = (data['imageUrl'] ?? '') as String;

                  // 🟢 itemType ஐ பாதுகாப்பாகப் பெறுதல் மற்றும் 'combo' என  செய்தல்
                  final itemType = (data['itemType'] ?? '')
                      .toString()
                      .toLowerCase();
                  final bool isCombo = itemType == 'combo';

                  final num originalPrice = data['price'] ?? 0;
                  // // ஒருவேளை offerPrice இல்லாத பட்சத்தில் சாதாரண price-ஐ எடுத்துக்கொள்ளும்
                  final num offerPrice = data['offerPrice'] ?? originalPrice;

                  // double discPct = 0;
                  // if (originalPrice > 0 && originalPrice > offerPrice) {
                  //   discPct =
                  //       ((originalPrice - offerPrice) / originalPrice * 100)
                  //           .roundToDouble();
                  // }

                  final isActive = _current == index;

                  return GestureDetector(
                    onTap: () => _openItemSheet(context, data),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      margin: EdgeInsets.only(
                        left: 8,
                        right: 8,
                        top: isActive ? 0 : 16,
                        bottom: isActive ? 10 : 26,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: kPrimary.withOpacity(0.35),
                                  blurRadius: 25,
                                  offset: const Offset(0, 10),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            imageUrl.isNotEmpty
                                ? Image.network(imageUrl, fit: BoxFit.cover)
                                : Container(
                                    color: kCardBg,
                                    child: const Icon(
                                      Icons.fastfood,
                                      color: kMuted,
                                      size: 80,
                                    ),
                                  ),

                            // Sleek Gradient Overlay
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: const [0.0, 0.4, 0.8, 1.0],
                                  colors: [
                                    Colors.black.withOpacity(0.2),
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.8),
                                    Colors.black.withOpacity(0.95),
                                  ],
                                ),
                              ),
                            ),

                            // 🟢 Badges (COMBO என இருந்தால் மட்டும் காட்டும், HOT நீக்கப்பட்டது)
                            Positioned(
                              top: 16,
                              left: 16,
                              child: Row(
                                children: [
                                  if (isCombo)
                                    const _Badge(
                                      label: 'COMBO',
                                      color: Color(0xFFFF8C00),
                                      icon: Icons.fastfood_rounded,
                                    ),
                                  // if (discPct > 0) ...[
                                  //   if (isCombo) const SizedBox(width: 8),
                                  //   _Badge(R
                                  //     label: '-${discPct.toInt()}%',
                                  //     color: const Color(0xFF2E7D32),
                                  //   ),
                                  // ],
                                ],
                              ),
                            ),

                            // Add button
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: kPrimary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: kPrimary.withOpacity(0.5),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ),

                            // Info Bottom
                            Positioned(
                              bottom: 20,
                              left: 20,
                              right: 20,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black,
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'CHF ${offerPrice.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: kPrimary,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      if (originalPrice > offerPrice) ...[
                                        const SizedBox(width: 8),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 2,
                                          ),
                                          child: Text(
                                            'CHF ${originalPrice.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: kWhite.withOpacity(0.7),
                                              fontSize: 14,
                                              decoration:
                                                  TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
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

            // Modern Dot Indicator
            if (promoDocs.length > 1) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  promoDocs.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _current == i ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _current == i ? kPrimary : kMuted.withOpacity(0.3),
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

// ── Badges & Buttons ─────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _Badge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 12),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _BigActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _BigActionButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isPrimary ? kPrimary : kCardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          if (isPrimary)
            BoxShadow(
              color: kPrimary.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
        ],
        border: isPrimary
            ? null
            : Border.all(color: kPrimary.withOpacity(0.2), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              children: [
                Icon(icon, color: isPrimary ? kWhite : kPrimary, size: 36),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: kWhite,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Modals & Sheets (Method & Table Picker) ──────────────────────────────────
class _MethodPickerSheet extends StatelessWidget {
  final VoidCallback onDineIn;
  final VoidCallback onTakeAway;
  const _MethodPickerSheet({required this.onDineIn, required this.onTakeAway});

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Container(
        decoration: const BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: kMuted.withOpacity(0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Text(
              'How would you like to order?',
              style: TextStyle(
                color: kWhite,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please select before adding to cart',
              style: TextStyle(color: kMuted.withOpacity(0.8), fontSize: 14),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _BigActionButton(
                    label: 'Dine-In',
                    icon: Icons.storefront_rounded,
                    isPrimary: true,
                    onTap: onDineIn,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _BigActionButton(
                    label: 'Take-Away',
                    icon: Icons.takeout_dining_rounded,
                    isPrimary: false,
                    onTap: onTakeAway,
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
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Container(
        decoration: const BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: kMuted.withOpacity(0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Text(
              'Enter Table Number',
              style: TextStyle(
                color: kWhite,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scan the QR code or type it manually',
              style: TextStyle(color: kMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tab,
                indicator: BoxDecoration(
                  color: kPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: kWhite,
                unselectedLabelColor: kMuted,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'Scan QR'),
                  Tab(text: 'Type No.'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 230,
              child: TabBarView(
                controller: _tab,
                children: [_buildQrTab(), _buildTypeTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrTab() {
    if (_scannedValue != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Colors.greenAccent,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'Table: $_scannedValue',
            style: const TextStyle(
              color: kWhite,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => _confirm(_scannedValue!),
              child: const Text(
                'Go to Menu',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: kWhite,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _scannedValue = null),
            child: const Text('Scan again', style: TextStyle(color: kMuted)),
          ),
        ],
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: MobileScanner(
        onDetect: (capture) {
          final val = capture.barcodes.firstOrNull?.rawValue;
          if (val != null && mounted) setState(() => _scannedValue = val);
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
          style: const TextStyle(
            color: kWhite,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: 'e.g. T5 or 12',
            hintStyle: TextStyle(
              color: kMuted.withOpacity(0.5),
              fontWeight: FontWeight.normal,
            ),
            filled: true,
            fillColor: kBg,
            prefixIcon: const Icon(Icons.table_restaurant, color: kPrimary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: kPrimary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              final val = _typeCtrl.text.trim();
              if (val.isNotEmpty) _confirm(val);
            },
            child: const Text(
              'Go to Menu',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: kWhite,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyPromo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kPrimary.withOpacity(0.2)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu_rounded, color: kPrimary, size: 48),
            SizedBox(height: 16),
            Text(
              'Welcome to our Restaurant!',
              style: TextStyle(
                color: kWhite,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Check out our menu for delicious meals.',
              style: TextStyle(color: kMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Promo Item Sheet ─────────────────────────────────────────────────────────
class _PromoItemSheet extends StatefulWidget {
  final Map<String, dynamic> itemData;
  const _PromoItemSheet({required this.itemData});
  @override
  State<_PromoItemSheet> createState() => _PromoItemSheetState();
}

class _PromoItemSheetState extends State<_PromoItemSheet> {
  int _qty = 1;
  final TextEditingController _noteCtrl = TextEditingController();

  // 🟢 ஏற்றுமதி ஸாயஸ் (Sizes) அல்லது தேர்வுக்கான மாறிகள்
  Map<String, dynamic>? _selectedSize;
  String? _selectedChoice;
  final List<Map<String, dynamic>> _selectedAddons = [];

  @override
  void initState() {
    super.initState();
    // ஒருவேளை sizes இருக்கிறதா எனச் சோதித்து முதல் சைஸை இயல்பாகத் தேர்ந்தெடுக்கலாம்
    final List<dynamic> sizes = widget.itemData['sizes'] ?? [];
    if (sizes.isNotEmpty) {
      _selectedSize = sizes.first as Map<String, dynamic>;
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  double get _basePrice {
    final bool hasMultipleSizes = widget.itemData['hasMultipleSizes'] ?? false;
    if (hasMultipleSizes && _selectedSize != null) {
      return (_selectedSize!['price'] as num?)?.toDouble() ?? 0.0;
    }

    final bool isPromo = widget.itemData['isPromoActive'] ?? false;
    final num priceVal = isPromo
        ? (widget.itemData['offerPrice'] ?? widget.itemData['price'] ?? 0)
        : (widget.itemData['price'] ?? 0);
    return (priceVal as num).toDouble();
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
      'size': _selectedSize != null ? _selectedSize!['name'] ?? '' : '',
      'note': _noteCtrl.text.trim(),
      'additionalOptions': _selectedAddons,
      'menuChoices': _selectedChoice != null ? {'Choice': _selectedChoice} : {},
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
              builder: (_) => CheckoutPage(uid: user.uid, tableNo: tableNo),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.itemData['name'] ?? 'Item';
    final imageUrl = (widget.itemData['imageUrl'] ?? '') as String;

    final List<dynamic> sizes = widget.itemData['sizes'] ?? [];
    final bool hasMultipleSizes = widget.itemData['hasMultipleSizes'] ?? false;
    final List<dynamic> choices = widget.itemData['menuChoices'] ?? [];
    final List<dynamic> addons = widget.itemData['additionalOptions'] ?? [];

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: kMuted.withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 100,
                                height: 100,
                                color: kBg,
                                child: const Icon(
                                  Icons.fastfood,
                                  color: kMuted,
                                ),
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: kWhite,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'CHF ${_basePrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: kPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 🟢 Sizes Selection (புதிய டேட்டாவின் படி multiple sizes இருந்தால் காண்பிக்கும்)
                  if (hasMultipleSizes && sizes.isNotEmpty) ...[
                    const Text(
                      'Select Portion / Size',
                      style: TextStyle(
                        color: kWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: kBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: sizes.map((s) {
                          final sMap = s as Map<String, dynamic>;
                          final sName = sMap['name'] ?? '';
                          final sPrice =
                              (sMap['price'] as num?)?.toDouble() ?? 0.0;
                          return RadioListTile<Map<String, dynamic>>(
                            title: Text(
                              sName,
                              style: const TextStyle(
                                color: kWhite,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'CHF ${sPrice.toStringAsFixed(2)}',
                              style: const TextStyle(color: kMuted),
                            ),
                            activeColor: kPrimary,
                            value: sMap,
                            groupValue: _selectedSize,
                            onChanged: (val) =>
                                setState(() => _selectedSize = val),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  const Text(
                    'Note (optional)',
                    style: TextStyle(
                      color: kWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
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
                  const SizedBox(height: 24),
                  if (choices.isNotEmpty) ...[
                    _SectionLabel('Choose Option', required: true),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: kBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: choices.map((c) {
                          final cs = c.toString();
                          return RadioListTile<String>(
                            title: Text(
                              cs,
                              style: const TextStyle(
                                color: kWhite,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            activeColor: kPrimary,
                            value: cs,
                            groupValue: _selectedChoice,
                            onChanged: (v) =>
                                setState(() => _selectedChoice = v),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (addons.isNotEmpty) ...[
                    _SectionLabel('Add-ons', required: false),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: kBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: addons.map((addon) {
                          final aMap = addon as Map<String, dynamic>;
                          final aName = aMap['name'] ?? '';
                          final aPrice =
                              (aMap['price'] as num?)?.toDouble() ?? 0.0;
                          final isSel = _selectedAddons.contains(aMap);
                          return CheckboxListTile(
                            title: Text(
                              aName,
                              style: const TextStyle(
                                color: kWhite,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '+CHF ${aPrice.toStringAsFixed(2)}',
                              style: const TextStyle(color: kMuted),
                            ),
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
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            decoration: BoxDecoration(
              color: kDarkBar,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Quantity',
                        style: TextStyle(
                          color: kMuted,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          _QtyBtn(
                            icon: Icons.remove,
                            onTap: () =>
                                setState(() => _qty = _qty > 1 ? _qty - 1 : 1),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              '$_qty',
                              style: const TextStyle(
                                color: kWhite,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _QtyBtn(
                            icon: Icons.add,
                            onTap: () => setState(() => _qty++),
                          ),
                        ],
                      ),
                      Text(
                        'CHF ${_totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: kWhite,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: kPrimary, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () => _addToCart(),
                            child: const Text(
                              'Add to Cart',
                              style: TextStyle(
                                color: kWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () => _addToCart(goToCheckout: true),
                            child: const Text(
                              'Buy Now',
                              style: TextStyle(
                                color: kWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
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

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _SectionLabel(this.text, {required this.required});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            color: kWhite,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: required
                ? kPrimary.withOpacity(0.2)
                : kMuted.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            required ? 'Required' : 'Optional',
            style: TextStyle(
              color: required ? kPrimary : kMuted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: kItemBg,
          border: Border.all(color: kMuted.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: kWhite, size: 22),
      ),
    );
  }
}
