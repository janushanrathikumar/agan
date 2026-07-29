// lib/user/menu.dart
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'checkout.dart';
import '../language.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF112A18);
const kMuted = Color(0xFFA1B3A1);
const kWhite = Color(0xFFF7F7F2);
const kDarkCard = Color(0xFF194D25);
const kDiscount = Color(0xFFE0483E);

enum _MenuKind { drinks, foods, combos }

String _itemTypeFor(_MenuKind kind) {
  switch (kind) {
    case _MenuKind.drinks:
      return 'drink';
    case _MenuKind.combos:
      return 'combo';
    case _MenuKind.foods:
      return 'food';
  }
}

double _effectivePrice(Map<String, dynamic> m, {String? tableNo}) {
  final price = (m['price'] as num?)?.toDouble() ?? 0;
  final hasDiscount = m['hasDiscount'] == true;
  final discountValue = (m['discountValue'] as num?)?.toDouble() ?? 0;
  if (!hasDiscount || discountValue <= 0) return price;

  final discountType = (m['discountType'] as String?) ?? 'percent';
  double discounted = discountType == 'percent'
      ? price - (price * discountValue / 100)
      : price - discountValue;

  if (discounted < 0) discounted = 0;
  return discounted;
}

String _discountBadgeText(Map<String, dynamic> m) {
  final discountType = (m['discountType'] as String?) ?? 'percent';
  final discountValue = (m['discountValue'] as num?)?.toDouble() ?? 0;
  if (discountType == 'percent') {
    return '-${discountValue.toStringAsFixed(discountValue % 1 == 0 ? 0 : 1)}%';
  }
  return '-CHF ${discountValue.toStringAsFixed(2)}';
}

bool _isDiscounted(Map<String, dynamic> m) {
  final discountValue = (m['discountValue'] as num?)?.toDouble() ?? 0;
  return m['hasDiscount'] == true && discountValue > 0;
}

class _WebSafeImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final Widget fallback;

  const _WebSafeImage({
    required this.imageUrl,
    this.width,
    this.height,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) return fallback;
    if (kIsWeb) {
      final String viewId =
          'menu-img-${imageUrl.hashCode}_${DateTime.now().microsecondsSinceEpoch}';
      ui_web.platformViewRegistry.registerViewFactory(
        viewId,
        (int _) => html.ImageElement()
          ..src = imageUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'cover'
          ..style.borderRadius = '12px',
      );
      return SizedBox(
        width: width,
        height: height,
        child: IgnorePointer(child: HtmlElementView(viewType: viewId)),
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

class MenuPage extends StatefulWidget {
  final String? tableNo;
  const MenuPage({super.key, this.tableNo});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  _MenuKind _kind = _MenuKind.drinks;
  String? _selectedCategory;
  String? _currentTableNo;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  late final Stream<QuerySnapshot> _categoryStream;

  @override
  void initState() {
    super.initState();
    _currentTableNo = widget.tableNo;
    _categoryStream = FirebaseFirestore.instance
        .collection('menu_category')
        .snapshots();
    if (_currentTableNo == null) _checkOrAskMethod();
  }

  Future<void> _checkOrAskMethod() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('food_delivery')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        final method = doc.data()?['delivery_method'];
        setState(() {
          _currentTableNo = method == 'Take_Away'
              ? 'Take-Away'
              : doc.data()?['table_no'];
        });
      }
    }
    if (_currentTableNo == null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showMethodPicker());
    }
  }

  void _showMethodPicker() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: kBg.withOpacity(0.85),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              border: Border(top: BorderSide(color: kWhite.withOpacity(0.2))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'How would you like to order?',
                  style: TextStyle(
                    color: kWhite,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.storefront, color: kWhite),
                        label: const Text(
                          'Dine-In',
                          style: TextStyle(
                            color: kWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        onPressed: () async {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            await FirebaseFirestore.instance
                                .collection('food_delivery')
                                .doc(user.uid)
                                .set({
                                  'delivery_method': 'Dine_In',
                                  'table_no': 'Dine-In',
                                  'timestamp': FieldValue.serverTimestamp(),
                                });
                          }
                          if (mounted)
                            setState(() => _currentTableNo = 'Dine-In');
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kPrimary, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.takeout_dining, color: kPrimary),
                        label: const Text(
                          'Take-Away',
                          style: TextStyle(
                            color: kWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        onPressed: () async {
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
                          if (mounted)
                            setState(() => _currentTableNo = 'Take-Away');
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const leftW = 85.0;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final uid = authSnap.data?.uid;

        return StreamBuilder<QuerySnapshot>(
          stream: _categoryStream,
          builder: (context, categorySnap) {
            if (categorySnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: kBg,
                body: Center(child: CircularProgressIndicator(color: kPrimary)),
              );
            }

            final allCategoryDocs = categorySnap.data?.docs ?? [];

            return Scaffold(
              backgroundColor: kBg,
              extendBodyBehindAppBar: true,
              appBar: AppBar(
                backgroundColor: kBg.withOpacity(0.8),
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                foregroundColor: kWhite,
                title: Text(
                  AppLanguage.getText('menu'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: kWhite,
                    fontSize: 22,
                  ),
                ),
                elevation: 0,
                actions: [
                  if (_currentTableNo != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: kPrimary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: kPrimary.withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            _currentTableNo == 'Take-Away'
                                ? '🥡 Take-Away'
                                : '🍽️ $_currentTableNo',
                            style: const TextStyle(
                              color: kPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(60),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _TopSwitch(
                      kind: _kind,
                      onChanged: (k) => setState(() {
                        _kind = k;
                        _selectedCategory = null;
                        _searchQuery = '';
                        _searchCtrl.clear();
                      }),
                    ),
                  ),
                ),
              ),
              body: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF194D25), Color(0xFF0C1E11)],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Row(
                      children: [
                        SizedBox(
                          width: leftW,
                          child: _CategoryRail(
                            kind: _kind,
                            allCategoryDocs: allCategoryDocs,
                            selected: _selectedCategory,
                            onResolvedFirst: (first) {
                              if (_selectedCategory != first)
                                setState(() => _selectedCategory = first);
                            },
                            onSelect: (c) => setState(() {
                              _selectedCategory = c;
                              _searchQuery = '';
                              _searchCtrl.clear();
                            }),
                          ),
                        ),
                        Container(width: 1, color: kWhite.withOpacity(0.1)),
                        Expanded(
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  8,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 10,
                                      sigmaY: 10,
                                    ),
                                    child: TextField(
                                      controller: _searchCtrl,
                                      style: const TextStyle(
                                        color: kWhite,
                                        fontSize: 14,
                                      ),
                                      onChanged: (val) => setState(
                                        () => _searchQuery = val
                                            .trim()
                                            .toLowerCase(),
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Search all items...',
                                        hintStyle: const TextStyle(
                                          color: kMuted,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.search,
                                          color: kMuted,
                                          size: 22,
                                        ),
                                        suffixIcon: _searchQuery.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(
                                                  Icons.clear,
                                                  color: kMuted,
                                                  size: 20,
                                                ),
                                                onPressed: () => setState(() {
                                                  _searchQuery = '';
                                                  _searchCtrl.clear();
                                                }),
                                              )
                                            : null,
                                        filled: true,
                                        fillColor: kWhite.withOpacity(0.08),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 0,
                                              horizontal: 16,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: kWhite.withOpacity(0.15),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: kWhite.withOpacity(0.15),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: kPrimary.withOpacity(0.5),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: _MenuGrid(
                                  kind: _kind,
                                  category: _selectedCategory,
                                  searchQuery: _searchQuery,
                                  tableNo: _currentTableNo,
                                  onTapItem: (m, actualKind) => _showItemSheet(
                                    context,
                                    actualKind,
                                    m,
                                    uid,
                                    _currentTableNo,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              floatingActionButton: uid == null
                  ? null
                  : _CartFAB(uid: uid, tableNo: _currentTableNo),
            );
          },
        );
      },
    );
  }
}

class _CartFAB extends StatelessWidget {
  final String uid;
  final String? tableNo;
  const _CartFAB({required this.uid, this.tableNo});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat')
          .doc(uid)
          .collection('items')
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        double total = 0;
        for (final d in docs) {
          final m = (d.data() as Map<String, dynamic>? ?? {});
          total +=
              ((m['price'] as num?)?.toDouble() ?? 0) *
              ((m['qty'] as num?)?.toInt() ?? 1);
        }
        if (total == 0) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          backgroundColor: kPrimary,
          foregroundColor: kWhite,
          elevation: 8,
          icon: const Icon(Icons.shopping_cart_outlined),
          label: Text(
            'CHF ${total.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CheckoutPage(uid: uid, tableNo: tableNo),
            ),
          ),
        );
      },
    );
  }
}

class _TopSwitch extends StatelessWidget {
  final _MenuKind kind;
  final ValueChanged<_MenuKind> onChanged;
  const _TopSwitch({required this.kind, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final sel = [
      kind == _MenuKind.drinks,
      kind == _MenuKind.foods,
      kind == _MenuKind.combos,
    ];
    return Center(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kWhite.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: ToggleButtons(
              isSelected: sel,
              onPressed: (i) => onChanged(
                i == 0
                    ? _MenuKind.drinks
                    : i == 1
                    ? _MenuKind.foods
                    : _MenuKind.combos,
              ),
              borderRadius: BorderRadius.circular(12),
              constraints: const BoxConstraints(minWidth: 100, minHeight: 44),
              color: kMuted,
              selectedColor: kWhite,
              fillColor: kPrimary.withOpacity(0.85),
              borderColor: Colors.transparent,
              selectedBorderColor: Colors.transparent,
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Drinks',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Foods',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Combos',
                    style: TextStyle(fontWeight: FontWeight.w700),
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

class _CategoryRail extends StatelessWidget {
  final _MenuKind kind;
  final List<QueryDocumentSnapshot> allCategoryDocs;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final ValueChanged<String?> onResolvedFirst;

  const _CategoryRail({
    required this.kind,
    required this.allCategoryDocs,
    required this.selected,
    required this.onSelect,
    required this.onResolvedFirst,
  });

  Query _getMenuQuery() {
    return FirebaseFirestore.instance
        .collection('menu_items')
        .where('itemType', isEqualTo: _itemTypeFor(kind))
        .where('status', isEqualTo: 'on');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: StreamBuilder<QuerySnapshot>(
        key: ValueKey(kind),
        stream: _getMenuQuery().snapshots(),
        builder: (context, itemsSnap) {
          final availableCategoryNames = <String>{};
          for (final d in (itemsSnap.data?.docs ?? [])) {
            final cat =
                (((d.data() as Map<String, dynamic>?) ?? {})['category']
                    as String?) ??
                '';
            if (cat.isNotEmpty) availableCategoryNames.add(cat);
          }
          final filteredCategoryDocs = allCategoryDocs
              .where((doc) => availableCategoryNames.contains(doc.id))
              .toList(growable: false);

          if (filteredCategoryDocs.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => onResolvedFirst(null),
            );
            return const Center(
              child: Text(
                'No categories',
                textAlign: TextAlign.center,
                style: TextStyle(color: kMuted, fontSize: 12),
              ),
            );
          }

          final categoryNames = filteredCategoryDocs
              .map((d) => d.id)
              .toList(growable: false);
          if (selected == null || !categoryNames.contains(selected)) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => onResolvedFirst(categoryNames.first),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: filteredCategoryDocs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final d = filteredCategoryDocs[i];
              final name = d.id;
              final iconUrl =
                  (((d.data() as Map<String, dynamic>?) ?? {})['iconUrl']
                      as String?) ??
                  '';
              final isSel = selected == name;

              return GestureDetector(
                onTap: () => onSelect(name),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSel
                        ? kWhite.withOpacity(0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSel
                          ? kWhite.withOpacity(0.3)
                          : Colors.transparent,
                    ),
                    boxShadow: isSel
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _WebSafeImage(
                          imageUrl: iconUrl,
                          width: 48,
                          height: 48,
                          fallback: Icon(
                            Icons.fastfood,
                            color: isSel ? kWhite : kMuted,
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSel ? kWhite : kMuted,
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _MenuGrid extends StatelessWidget {
  final _MenuKind kind;
  final String? category;
  final String searchQuery;
  final String? tableNo;
  final void Function(Map<String, dynamic>, _MenuKind) onTapItem;

  const _MenuGrid({
    required this.kind,
    required this.category,
    required this.searchQuery,
    required this.tableNo,
    required this.onTapItem,
  });

  double _getDisplayPrice(Map<String, dynamic> m) {
    bool hasMultipleSizes = m['hasMultipleSizes'] == true;
    List<dynamic> sizes = m['sizes'] ?? [];
    if (hasMultipleSizes && sizes.isNotEmpty) {
      double minPrice = double.infinity;
      for (var s in sizes) {
        if (tableNo == 'Take-Away') {
          if ((s['name'] as String?)?.toLowerCase().trim() == 'kleine portion')
            continue;
          if (s['takeAwayPrice'] != null &&
              s['takeAwayPrice'].toString().isNotEmpty) {
            double p = (s['takeAwayPrice'] as num).toDouble();
            if (p < minPrice) minPrice = p;
          }
        } else {
          if (s['dineInPrice'] != null || s['price'] != null) {
            double p = ((s['dineInPrice'] ?? s['price'] ?? 0) as num)
                .toDouble();
            if (p < minPrice) minPrice = p;
          }
        }
      }
      return minPrice == double.infinity
          ? ((m['price'] as num?)?.toDouble() ?? 0)
          : minPrice;
    }
    return ((m['price'] as num?)?.toDouble() ?? 0);
  }

  Widget _buildItemCard(
    BuildContext context,
    Map<String, dynamic> m,
    double price,
    bool discounted,
    double finalPrice,
    _MenuKind actualKind,
  ) {
    final itemNo = (m['itemNo']?.toString().trim() ?? '');
    final rawName = (m['name'] as String?) ?? '';
    final name = itemNo.isNotEmpty ? '$itemNo - $rawName' : rawName;

    final note = (m['note'] as String?) ?? '';
    final imageUrl = (m['imageUrl'] as String?) ?? '';

    return GestureDetector(
      onTap: () => onTapItem(m, actualKind),
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              color: kWhite.withOpacity(0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: discounted
                    ? kDiscount.withOpacity(0.5)
                    : kWhite.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Image Box
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(18),
                      ),
                      child: SizedBox(
                        width: 110,
                        height: 110,
                        child: _WebSafeImage(
                          imageUrl: imageUrl,
                          fallback: Container(
                            color: kWhite.withOpacity(0.05),
                            child: const Icon(
                              Icons.fastfood,
                              color: kMuted,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (discounted)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: kDiscount,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            _discountBadgeText(m),
                            style: const TextStyle(
                              color: kWhite,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                // Details Box
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 14, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: kWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            height: 1.2,
                          ),
                        ),
                        if (note.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            note,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: kMuted, fontSize: 11),
                          ),
                        ],
                        const Spacer(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (discounted)
                                  Text(
                                    'CHF ${price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: kMuted,
                                      fontSize: 10,
                                      decoration: TextDecoration.lineThrough,
                                      decorationColor: kMuted,
                                    ),
                                  ),
                                Text(
                                  'CHF ${finalPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: discounted ? kDiscount : kPrimary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
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
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Query q = FirebaseFirestore.instance
        .collection('menu_items')
        .where('status', isEqualTo: 'on');
    if (searchQuery.isEmpty) {
      q = q.where('itemType', isEqualTo: _itemTypeFor(kind));
      if (category != null) q = q.where('category', isEqualTo: category);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(
            child: CircularProgressIndicator(color: kPrimary),
          );

        var docs = snap.data?.docs ?? [];

        docs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>? ?? {};
          final dataB = b.data() as Map<String, dynamic>? ?? {};

          final noA = double.tryParse(dataA['itemNo']?.toString().trim() ?? '');
          final noB = double.tryParse(dataB['itemNo']?.toString().trim() ?? '');

          if (noA != null && noB != null) return noA.compareTo(noB);
          if (noA != null) return -1;
          if (noB != null) return 1;

          final nameA = (dataA['name'] as String?)?.toLowerCase() ?? '';
          final nameB = (dataB['name'] as String?)?.toLowerCase() ?? '';
          return nameA.compareTo(nameB);
        });

        if (searchQuery.isNotEmpty) {
          docs = docs
              .where(
                (d) =>
                    (((d.data() as Map<String, dynamic>?) ?? {})['name']
                            as String?)
                        ?.toLowerCase()
                        .contains(searchQuery) ??
                    false,
              )
              .toList();
        }

        if (docs.isEmpty)
          return Center(
            child: Text(
              searchQuery.isNotEmpty
                  ? 'No matching items found.'
                  : 'No items available.',
              style: const TextStyle(color: kMuted, fontSize: 16),
            ),
          );

        final w = MediaQuery.of(context).size.width;

        if (w < 650) {
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final m = (docs[i].data() as Map<String, dynamic>?) ?? {};
              final price = _getDisplayPrice(m);
              final tempMap = {...m, 'price': price};
              final discounted = _isDiscounted(tempMap);
              final finalPrice = _effectivePrice(tempMap);
              final typeStr = (m['itemType'] as String?) ?? _itemTypeFor(kind);
              _MenuKind actualKind = kind;
              if (typeStr == 'drink')
                actualKind = _MenuKind.drinks;
              else if (typeStr == 'food')
                actualKind = _MenuKind.foods;
              else if (typeStr == 'combo')
                actualKind = _MenuKind.combos;

              return _buildItemCard(
                context,
                m,
                price,
                discounted,
                finalPrice,
                actualKind,
              );
            },
          );
        }

        int crossCount = w >= 1200 ? 4 : 3;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 3.2,
          ),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final m = (docs[i].data() as Map<String, dynamic>?) ?? {};
            final price = _getDisplayPrice(m);
            final tempMap = {...m, 'price': price};
            final discounted = _isDiscounted(tempMap);
            final finalPrice = _effectivePrice(tempMap);
            final typeStr = (m['itemType'] as String?) ?? _itemTypeFor(kind);
            _MenuKind actualKind = kind;
            if (typeStr == 'drink')
              actualKind = _MenuKind.drinks;
            else if (typeStr == 'food')
              actualKind = _MenuKind.foods;
            else if (typeStr == 'combo')
              actualKind = _MenuKind.combos;

            return _buildItemCard(
              context,
              m,
              price,
              discounted,
              finalPrice,
              actualKind,
            );
          },
        );
      },
    );
  }
}

Future<String?> _ensureUid() async {
  final auth = FirebaseAuth.instance;
  final u = auth.currentUser;
  if (u != null) return u.uid;
  final cred = await auth.signInAnonymously();
  return cred.user?.uid;
}

void _showItemSheet(
  BuildContext context,
  _MenuKind kind,
  Map<String, dynamic> item,
  String? uidHint,
  String? tableNo,
) {
  final rawName = (item['name'] as String?) ?? '';
  final itemNo = (item['itemNo']?.toString().trim() ?? '');
  final name = itemNo.isNotEmpty ? '$itemNo - $rawName' : rawName;

  final imageUrl = (item['imageUrl'] as String?) ?? '';
  final dbNote = (item['note'] as String?) ?? '';
  final category = (item['category'] as String?) ?? '';
  final allSizes = List<Map<String, dynamic>>.from(item['sizes'] ?? []);
  List<Map<String, dynamic>> displaySizes = [];
  final bool hasMultipleSizes = item['hasMultipleSizes'] == true;

  if (hasMultipleSizes) {
    if (tableNo == 'Take-Away') {
      displaySizes = allSizes.where((s) {
        if ((s['name'] as String?)?.toLowerCase().trim() == 'kleine portion')
          return false;
        return s.containsKey('takeAwayPrice') &&
            s['takeAwayPrice'] != null &&
            s['takeAwayPrice'].toString().isNotEmpty;
      }).toList();
    } else {
      displaySizes = allSizes
          .where((s) => s.containsKey('dineInPrice') || s.containsKey('price'))
          .toList();
    }
    displaySizes.sort((a, b) {
      final nameA = (a['name'] as String?)?.toLowerCase().trim() ?? '';
      final nameB = (b['name'] as String?)?.toLowerCase().trim() ?? '';
      int getWeight(String n) {
        if (n == 'portion') return 1;
        if (n == 'kleine portion') return 2;
        return 3;
      }

      int cmp = getWeight(nameA).compareTo(getWeight(nameB));
      return cmp == 0 ? nameA.compareTo(nameB) : cmp;
    });
  }

  final menuChoiceIds = List<String>.from(item['menuChoices'] ?? []);
  final additionalOptions = (item['additionalOptions'] as List<dynamic>? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  String? initialSelectedSize;
  if (hasMultipleSizes && displaySizes.isNotEmpty)
    initialSelectedSize = displaySizes.first['name'] as String?;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      int qty = 1;
      final noteCtrl = TextEditingController();
      final Map<String, String?> selectedChoice = {};
      final Set<int> selectedAddOns = {};
      String? selectedSizeName = initialSelectedSize;

      double getPriceForSize(Map<String, dynamic> sizeMap) {
        if (tableNo == 'Take-Away' && sizeMap['takeAwayPrice'] != null)
          return (sizeMap['takeAwayPrice'] as num).toDouble();
        return ((sizeMap['dineInPrice'] ?? sizeMap['price'] ?? 0) as num)
            .toDouble();
      }

      double computeTotal() {
        double original = ((item['price'] as num?) ?? 0).toDouble();
        if (hasMultipleSizes &&
            displaySizes.isNotEmpty &&
            selectedSizeName != null) {
          original = getPriceForSize(
            displaySizes.firstWhere(
              (s) => s['name'] == selectedSizeName,
              orElse: () => displaySizes.first,
            ),
          );
        }
        double effective = original;
        if (_isDiscounted(item)) {
          final dType = (item['discountType'] as String?) ?? 'percent';
          final dVal = (item['discountValue'] as num?)?.toDouble() ?? 0;
          effective = dType == 'percent'
              ? original - (original * dVal / 100)
              : original - dVal;
          if (effective < 0) effective = 0;
        }
        double addOnTotal = 0;
        for (final idx in selectedAddOns)
          addOnTotal += ((additionalOptions[idx]['price'] as num?) ?? 0)
              .toDouble();
        return (effective + addOnTotal) * qty;
      }

      double getCurrentDisplayOriginalPrice() {
        if (hasMultipleSizes &&
            displaySizes.isNotEmpty &&
            selectedSizeName != null) {
          return getPriceForSize(
            displaySizes.firstWhere(
              (s) => s['name'] == selectedSizeName,
              orElse: () => displaySizes.first,
            ),
          );
        }
        return ((item['price'] as num?) ?? 0).toDouble();
      }

      Future<bool> addToChat(StateSetter setS) async {
        if (hasMultipleSizes) {
          if (displaySizes.isEmpty) {
            if (context.mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'This item is currently not available for $tableNo.',
                  ),
                  backgroundColor: Colors.redAccent,
                ),
              );
            return false;
          }
          if (selectedSizeName == null || selectedSizeName!.isEmpty) {
            if (context.mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select a Portion / Size.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            return false;
          }
        }
        for (final groupId in menuChoiceIds) {
          if (selectedChoice[groupId] == null ||
              selectedChoice[groupId]!.isEmpty) {
            if (context.mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select all required options.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            return false;
          }
        }
        final uid = uidHint ?? await _ensureUid();
        if (uid == null) return false;

        final payload = <String, dynamic>{
          'kind': _itemTypeFor(kind),
          'name': name,
          'imageUrl': imageUrl,
          'price': computeTotal() / qty,
          'qty': qty,
          'category': category,
          'menuChoices': selectedChoice,
          'additionalOptions': selectedAddOns
              .map((i) => additionalOptions[i])
              .toList(),
          'createdAt': FieldValue.serverTimestamp(),
          'note': dbNote,
          'extraNote': noteCtrl.text.trim().isEmpty
              ? null
              : noteCtrl.text.trim(),
        };
        if (hasMultipleSizes && selectedSizeName != null)
          payload['size'] = selectedSizeName;

        await FirebaseFirestore.instance
            .collection('chat')
            .doc(uid)
            .collection('items')
            .add(payload);
        return true;
      }

      return StatefulBuilder(
        builder: (ctx, setS) {
          final orig = getCurrentDisplayOriginalPrice();
          double eff = orig;
          if (_isDiscounted(item)) {
            final dType = (item['discountType'] as String?) ?? 'percent';
            final dVal = (item['discountValue'] as num?)?.toDouble() ?? 0;
            eff = dType == 'percent' ? orig - (orig * dVal / 100) : orig - dVal;
            if (eff < 0) eff = 0;
          }

          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                decoration: BoxDecoration(
                  color: kBg.withOpacity(0.85),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  border: Border(
                    top: BorderSide(color: kWhite.withOpacity(0.2)),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 5,
                        width: 60,
                        decoration: BoxDecoration(
                          color: kWhite.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: _WebSafeImage(
                                  imageUrl: imageUrl,
                                  width: 110,
                                  height: 110,
                                  fallback: Container(
                                    color: kWhite.withOpacity(0.05),
                                    child: const Icon(
                                      Icons.image,
                                      color: kMuted,
                                      size: 40,
                                    ),
                                  ),
                                ),
                              ),
                              if (_isDiscounted(item))
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kDiscount,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _discountBadgeText(item),
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
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: kWhite,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (_isDiscounted(item))
                                  Row(
                                    children: [
                                      Text(
                                        'CHF ${orig.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: kMuted,
                                          fontSize: 14,
                                          decoration:
                                              TextDecoration.lineThrough,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'CHF ${eff.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: kDiscount,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Text(
                                    'CHF ${eff.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: kPrimary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                if (kind != _MenuKind.drinks &&
                                    dbNote.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      dbNote,
                                      style: const TextStyle(
                                        color: kMuted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      if (hasMultipleSizes) ...[
                        if (displaySizes.isNotEmpty) ...[
                          _InlineOptionRow(
                            title: 'Portion / Size',
                            values: displaySizes
                                .map((s) => s['name'] as String)
                                .toList(),
                            selected: selectedSizeName ?? '',
                            onChanged: (val) =>
                                setS(() => selectedSizeName = val),
                            showRequired: true,
                          ),
                          const SizedBox(height: 20),
                        ] else ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Text(
                              'Currently unavailable for $tableNo.',
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],

                      _SectionTitle('Note (optional)'),
                      TextField(
                        controller: noteCtrl,
                        maxLines: 2,
                        style: const TextStyle(color: kWhite),
                        decoration: InputDecoration(
                          hintText: 'Add special instructions...',
                          hintStyle: const TextStyle(color: kMuted),
                          filled: true,
                          fillColor: kWhite.withOpacity(0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: kWhite.withOpacity(0.15),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: kWhite.withOpacity(0.15),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: kPrimary.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (menuChoiceIds.isNotEmpty) ...[
                        _MenuChoicesSection(
                          choiceIds: menuChoiceIds,
                          selectedChoice: selectedChoice,
                          onChanged: (gid, val) =>
                              setS(() => selectedChoice[gid] = val),
                        ),
                        const SizedBox(height: 8),
                      ],

                      if (additionalOptions.isNotEmpty) ...[
                        _AdditionalOptionsSection(
                          options: additionalOptions,
                          selected: selectedAddOns,
                          onToggle: (idx) => setS(() {
                            selectedAddOns.contains(idx)
                                ? selectedAddOns.remove(idx)
                                : selectedAddOns.add(idx);
                          }),
                        ),
                        const SizedBox(height: 24),
                      ],
                      _SectionTitle('Quantity'),
                      Row(
                        children: [
                          _QtyBtn(
                            icon: Icons.remove,
                            onTap: () =>
                                setS(() => qty = qty > 1 ? qty - 1 : 1),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              '$qty',
                              style: const TextStyle(
                                color: kWhite,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _QtyBtn(
                            icon: Icons.add,
                            onTap: () => setS(() => qty++),
                          ),
                          const Spacer(),
                          Text(
                            'CHF ${computeTotal().toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: kWhite,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: kPrimary.withOpacity(0.8),
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () async {
                                final success = await addToChat(setS);
                                if (success && context.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Added to cart'),
                                      backgroundColor: kPrimary,
                                    ),
                                  );
                                }
                              },
                              child: const Text(
                                'Add to Cart',
                                style: TextStyle(
                                  color: kWhite,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: kPrimary,
                                foregroundColor: kWhite,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                              ),
                              onPressed: () async {
                                final success = await addToChat(setS);
                                if (success && context.mounted) {
                                  Navigator.pop(ctx);
                                  final uid = await _ensureUid();
                                  if (uid != null)
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => CheckoutPage(
                                          uid: uid,
                                          tableNo: tableNo,
                                        ),
                                      ),
                                    );
                                }
                              },
                              child: const Text(
                                'Buy Now',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
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
            ),
          );
        },
      );
    },
  );
}

class _MenuChoicesSection extends StatelessWidget {
  final List<String> choiceIds;
  final Map<String, String?> selectedChoice;
  final void Function(String groupId, String val) onChanged;
  const _MenuChoicesSection({
    required this.choiceIds,
    required this.selectedChoice,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DocumentSnapshot>>(
      future: Future.wait(
        choiceIds.map(
          (id) => FirebaseFirestore.instance
              .collection('menu_choices')
              .doc(id)
              .get(),
        ),
      ),
      builder: (context, snap) {
        if (!snap.hasData)
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: LinearProgressIndicator(color: kPrimary),
          );
        final docs = snap.data!.where((d) => d.exists).toList();
        if (docs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: docs.map((doc) {
            final data = (doc.data() as Map<String, dynamic>?) ?? {};
            return Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: _InlineOptionRow(
                title: (data['heading'] as String?) ?? '',
                values: List<String>.from(data['options'] ?? []),
                selected: selectedChoice[doc.id] ?? '',
                onChanged: (val) => onChanged(doc.id, val),
                showRequired: true,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _AdditionalOptionsSection extends StatelessWidget {
  final List<Map<String, dynamic>> options;
  final Set<int> selected;
  final void Function(int idx) onToggle;
  const _AdditionalOptionsSection({
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kWhite.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Add-ons',
                style: TextStyle(
                  color: kWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kMuted.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Optional',
                  style: TextStyle(
                    color: kMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(options.length, (i) {
            final opt = options[i];
            final optName = (opt['name'] as String?) ?? '';
            final optPrice = ((opt['price'] as num?) ?? 0).toDouble();
            final isSelected = selected.contains(i);
            return GestureDetector(
              onTap: () => onToggle(i),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? kPrimary
                              : kMuted.withOpacity(0.5),
                          width: 2,
                        ),
                        color: isSelected ? kPrimary : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: kWhite, size: 16)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        optName,
                        style: TextStyle(
                          color: isSelected ? kWhite : kMuted,
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    Text(
                      optPrice > 0
                          ? '+CHF ${optPrice.toStringAsFixed(2)}'
                          : 'Free',
                      style: TextStyle(
                        color: isSelected ? kPrimary : kMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          color: kMuted,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

class _InlineOptionRow extends StatelessWidget {
  final String title;
  final List<String> values;
  final String selected;
  final ValueChanged<String> onChanged;
  final bool showRequired;
  const _InlineOptionRow({
    required this.title,
    required this.values,
    required this.selected,
    required this.onChanged,
    this.showRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: kMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (showRequired) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: kPrimary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Required',
                    style: TextStyle(
                      color: kPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 10,
            children: values.map((v) {
              final on = v == selected;
              return GestureDetector(
                onTap: () => onChanged(v),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: on ? kPrimary : kWhite.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: on ? kPrimary : kWhite.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    v,
                    style: TextStyle(
                      color: on ? kWhite : kMuted,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }).toList(),
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
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: kWhite.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kWhite.withOpacity(0.2)),
      ),
      child: Icon(icon, color: kWhite, size: 22),
    ),
  );
}
