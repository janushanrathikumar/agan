// lib/user/menu.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'checkout.dart';
import '../language.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

const kPrimary = Color(0xFFE49024);
const kBg = Color(0xFF112A18);
const kMuted = Color(0xFFA1B3A1);
const kWhite = Color(0xFFF7F7F2);
const kDarkCard = Color(0xFF194D25);
const kDiscount = Color(0xFFE0483E); // 🟢 badge/discount accent color

enum _MenuKind { drinks, foods }

// 🟢 Computes the final (discounted) price for a menu item, based on the
// `hasDiscount` / `discountType` / `discountValue` fields saved from the
// Add/Edit Menu Item pages. Falls back to the plain price when there's no
// active discount, or if the discount value is invalid.
double _effectivePrice(Map<String, dynamic> m) {
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

// 🟢 Short badge text like "-20%" or "-CHF 5.00" shown on discounted items.
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

class MenuPage extends StatefulWidget {
  // 🟢 tableNo passed from HomePage ('Take-Away', 'T5', etc.)
  final String? tableNo;
  const MenuPage({super.key, this.tableNo});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  _MenuKind _kind = _MenuKind.drinks;
  String? _selectedCategory;
  late final Stream<QuerySnapshot> _categoryStream;

  @override
  void initState() {
    super.initState();
    _categoryStream = FirebaseFirestore.instance
        .collection('menu_category')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    const leftW = 80.0;

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
              appBar: AppBar(
                backgroundColor: kBg,
                foregroundColor: kWhite,
                title: Text(
                  AppLanguage.getText('menu'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: kWhite,
                  ),
                ),
                elevation: 0,
                // 🟢 Show table badge in app bar
                actions: [
                  if (widget.tableNo != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: kPrimary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: kPrimary.withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            widget.tableNo == 'Take-Away'
                                ? '🛍 Take-Away'
                                : '🪑 ${widget.tableNo}',
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
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(54),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _TopSwitch(
                      kind: _kind,
                      onChanged: (k) => setState(() {
                        _kind = k;
                        _selectedCategory = null;
                      }),
                    ),
                  ),
                ),
              ),
              body: Row(
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
                      onSelect: (c) => setState(() => _selectedCategory = c),
                    ),
                  ),
                  const VerticalDivider(width: 1, color: kMuted),
                  Expanded(
                    child: _MenuGrid(
                      kind: _kind,
                      category: _selectedCategory,
                      onTapItem: (m) => _showItemSheet(
                        context,
                        _kind,
                        m,
                        uid,
                        widget.tableNo,
                      ),
                    ),
                  ),
                ],
              ),
              // 🟢 FAB passes tableNo to CheckoutPage
              floatingActionButton: uid == null
                  ? null
                  : _CartFAB(uid: uid, tableNo: widget.tableNo),
            );
          },
        );
      },
    );
  }
}

// ── Cart FAB ─────────────────────────────────────────────────────────────────
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
          icon: const Icon(Icons.shopping_cart_outlined),
          label: Text(
            'CHF ${total.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          // 🟢 Pass tableNo
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

// ── Top Switch ────────────────────────────────────────────────────────────────
class _TopSwitch extends StatelessWidget {
  final _MenuKind kind;
  final ValueChanged<_MenuKind> onChanged;
  const _TopSwitch({required this.kind, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final sel = [kind == _MenuKind.drinks, kind == _MenuKind.foods];
    return Center(
      child: ToggleButtons(
        isSelected: sel,
        onPressed: (i) =>
            onChanged(i == 0 ? _MenuKind.drinks : _MenuKind.foods),
        borderRadius: BorderRadius.circular(10),
        constraints: const BoxConstraints(minWidth: 120, minHeight: 40),
        color: kWhite,
        selectedColor: kWhite,
        fillColor: kPrimary,
        borderColor: kPrimary.withOpacity(0.5),
        selectedBorderColor: kPrimary,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              AppLanguage.getText('drinks'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              AppLanguage.getText('foods'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category Rail ─────────────────────────────────────────────────────────────
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
    final type = kind == _MenuKind.drinks ? 'drink' : 'food';
    return FirebaseFirestore.instance
        .collection('menu_items')
        .where('itemType', isEqualTo: type)
        .where('status', isEqualTo: 'on');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0C1E11),
      child: StreamBuilder<QuerySnapshot>(
        key: ValueKey(kind),
        stream: _getMenuQuery().snapshots(),
        builder: (context, itemsSnap) {
          final availableCategoryNames = <String>{};
          for (final d in (itemsSnap.data?.docs ?? [])) {
            final m = (d.data() as Map<String, dynamic>?) ?? {};
            final cat = (m['category'] as String?) ?? '';
            if (cat.isNotEmpty) availableCategoryNames.add(cat);
          }
          final filteredCategoryDocs = allCategoryDocs
              .where((doc) => availableCategoryNames.contains(doc.id))
              .toList(growable: false);

          if (filteredCategoryDocs.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => onResolvedFirst(null),
            );
            return Center(
              child: Text(
                AppLanguage.getText('no_categories'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: kMuted, fontSize: 10),
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
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: filteredCategoryDocs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final d = filteredCategoryDocs[i];
              final data = (d.data() as Map<String, dynamic>?) ?? {};
              final name = d.id;
              final iconUrl = (data['iconUrl'] as String?) ?? '';
              final isSel = selected == name;
              return InkWell(
                onTap: () => onSelect(name),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSel
                        ? kPrimary.withOpacity(0.25)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSel
                          ? kPrimary.withOpacity(0.5)
                          : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _WebSafeImage(
                          imageUrl: iconUrl,
                          width: 44,
                          height: 44,
                          fallback: const Icon(
                            Icons.fastfood,
                            color: kMuted,
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSel ? kWhite : kMuted,
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
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

// ── Menu Grid ─────────────────────────────────────────────────────────────────
class _MenuGrid extends StatelessWidget {
  final _MenuKind kind;
  final String? category;
  final void Function(Map<String, dynamic>) onTapItem;

  const _MenuGrid({
    required this.kind,
    required this.category,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    final type = kind == _MenuKind.drinks ? 'drink' : 'food';
    Query q = FirebaseFirestore.instance
        .collection('menu_items')
        .where('itemType', isEqualTo: type)
        .where('status', isEqualTo: 'on');
    if (category != null) q = q.where('category', isEqualTo: category);

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(
            child: CircularProgressIndicator(color: kPrimary),
          );
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty)
          return Center(
            child: Text(
              AppLanguage.getText('no_items'),
              style: const TextStyle(color: kWhite),
            ),
          );

        int crossCount = 2;
        final w = MediaQuery.of(context).size.width;
        if (w >= 1200)
          crossCount = 5;
        else if (w >= 900)
          crossCount = 4;
        else if (w >= 600)
          crossCount = 3;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final m = (docs[i].data() as Map<String, dynamic>?) ?? {};
            final name = (m['name'] as String?) ?? '';
            final price = (m['price'] as num?)?.toDouble() ?? 0;
            final imageUrl = (m['imageUrl'] as String?) ?? '';
            final discounted = _isDiscounted(m);
            final finalPrice = _effectivePrice(m);

            return InkWell(
              onTap: () => onTapItem(m),
              child: Container(
                decoration: BoxDecoration(
                  color: kWhite.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: discounted
                        ? kDiscount.withOpacity(0.6)
                        : kWhite.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: _WebSafeImage(
                                imageUrl: imageUrl,
                                fallback: Container(
                                  color: kDarkCard,
                                  child: const Icon(
                                    Icons.image,
                                    color: kMuted,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // 🟢 Discount badge, top-left of the image
                          if (discounted)
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: kDiscount,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.25),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _discountBadgeText(m),
                                  style: const TextStyle(
                                    color: kWhite,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: kWhite,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // 🟢 Show strikethrough original price + discounted
                            // price when a promotion is active.
                            discounted
                                ? Column(
                                    children: [
                                      Text(
                                        'CHF ${price.toStringAsFixed(2)}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: kMuted,
                                          fontSize: 11,
                                          decoration:
                                              TextDecoration.lineThrough,
                                          decorationColor: kMuted,
                                        ),
                                      ),
                                      Text(
                                        'CHF ${finalPrice.toStringAsFixed(2)}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: kDiscount,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    'CHF ${price.toStringAsFixed(2)}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: kPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                          ],
                        ),
                      ),
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
}

// ── Helpers ───────────────────────────────────────────────────────────────────
Future<String?> _ensureUid() async {
  final auth = FirebaseAuth.instance;
  final u = auth.currentUser;
  if (u != null) return u.uid;
  final cred = await auth.signInAnonymously();
  return cred.user?.uid;
}

// ── Item Bottom Sheet ─────────────────────────────────────────────────────────
void _showItemSheet(
  BuildContext context,
  _MenuKind kind,
  Map<String, dynamic> item,
  String? uidHint,
  String? tableNo, // 🟢 passed through
) {
  final name = (item['name'] as String?) ?? '';
  final imageUrl = (item['imageUrl'] as String?) ?? '';
  final originalPrice = ((item['price'] as num?) ?? 0).toDouble();
  // 🟢 basePrice used for all cart/quantity math is the discounted price.
  final basePrice = _effectivePrice(item);
  final discounted = _isDiscounted(item);
  final dbNote = (item['note'] as String?) ?? '';
  final category = (item['category'] as String?) ?? '';
  final List<String> menuChoiceIds = List<String>.from(
    item['menuChoices'] ?? [],
  );
  final List<Map<String, dynamic>> additionalOptions =
      (item['additionalOptions'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: kBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      int qty = 1;
      String drinkType = 'Hot';
      String sugar = 'Normal';
      final noteCtrl = TextEditingController();
      final Map<String, String?> selectedChoice = {};
      final Set<int> selectedAddOns = {};

      double computeTotal() {
        double addOnTotal = 0;
        for (final idx in selectedAddOns) {
          addOnTotal += ((additionalOptions[idx]['price'] as num?) ?? 0)
              .toDouble();
        }
        return (basePrice + addOnTotal) * qty;
      }

      Future<void> addToChat(StateSetter setS) async {
        final uid = uidHint ?? await _ensureUid();
        if (uid == null) return;
        final chosenAddOns = selectedAddOns
            .map((i) => additionalOptions[i])
            .toList();
        final payload = <String, dynamic>{
          'kind': kind == _MenuKind.drinks ? 'drink' : 'food',
          'name': name,
          'imageUrl': imageUrl,
          'price': computeTotal() / qty,
          'qty': qty,
          'category': category,
          'menuChoices': selectedChoice,
          'additionalOptions': chosenAddOns,
          'createdAt': FieldValue.serverTimestamp(),
        };
        if (kind == _MenuKind.drinks) {
          payload.addAll({'type': drinkType, 'sugar': sugar});
        } else {
          payload.addAll({
            'note': dbNote,
            'extraNote': noteCtrl.text.trim().isEmpty
                ? null
                : noteCtrl.text.trim(),
          });
        }
        await FirebaseFirestore.instance
            .collection('chat')
            .doc(uid)
            .collection('items')
            .add(payload);
      }

      return StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 5,
                  width: 50,
                  decoration: BoxDecoration(
                    color: kMuted.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _WebSafeImage(
                            imageUrl: imageUrl,
                            width: 100,
                            height: 100,
                            fallback: Container(
                              color: kDarkCard,
                              child: const Icon(
                                Icons.image,
                                color: kMuted,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                        // 🟢 Discount badge on the sheet image too
                        if (discounted)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: kDiscount,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _discountBadgeText(item),
                                style: const TextStyle(
                                  color: kWhite,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
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
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                          ),
                          // 🟢 Strikethrough original price + discounted price
                          if (discounted)
                            Row(
                              children: [
                                Text(
                                  'CHF ${originalPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: kMuted,
                                    fontSize: 13,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: kMuted,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'CHF ${basePrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: kDiscount,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              'CHF ${basePrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: kPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          if (kind == _MenuKind.foods && dbNote.isNotEmpty)
                            Text(
                              dbNote,
                              style: const TextStyle(
                                color: kMuted,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (kind == _MenuKind.drinks) ...[
                  _SectionTitle(AppLanguage.getText('type')),
                  _ChipRow(
                    values: const ['Hot', 'Iced'],
                    selected: drinkType,
                    onChanged: (v) => setS(() => drinkType = v),
                  ),
                  const SizedBox(height: 16),
                  _SectionTitle(AppLanguage.getText('sugar')),
                  _ChipRow(
                    values: const ['Normal', 'Half'],
                    selected: sugar,
                    onChanged: (v) => setS(() => sugar = v),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  _SectionTitle(AppLanguage.getText('note_optional')),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: kWhite),
                    decoration: InputDecoration(
                      hintText: '...',
                      hintStyle: const TextStyle(color: kMuted),
                      filled: true,
                      fillColor: kWhite.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (menuChoiceIds.isNotEmpty) ...[
                  _MenuChoicesSection(
                    choiceIds: menuChoiceIds,
                    selectedChoice: selectedChoice,
                    onChanged: (gid, val) =>
                        setS(() => selectedChoice[gid] = val),
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
                ],
                _SectionTitle(AppLanguage.getText('quantity')),
                Row(
                  children: [
                    _QtyBtn(
                      icon: Icons.remove,
                      onTap: () => setS(() => qty = qty > 1 ? qty - 1 : 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '$qty',
                        style: const TextStyle(
                          color: kWhite,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _QtyBtn(icon: Icons.add, onTap: () => setS(() => qty++)),
                    const Spacer(),
                    Text(
                      'CHF ${computeTotal().toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: kWhite,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: kPrimary.withOpacity(0.8)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          await addToChat(setS);
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppLanguage.getText('added_to_cart'),
                                ),
                                backgroundColor: kPrimary,
                              ),
                            );
                          }
                        },
                        child: Text(
                          AppLanguage.getText('add_to_cart'),
                          style: const TextStyle(color: kWhite),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: kWhite,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          await addToChat(setS);
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            final uid = await _ensureUid();
                            if (uid != null)
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  // 🟢 tableNo passed here too
                                  builder: (_) =>
                                      CheckoutPage(uid: uid, tableNo: tableNo),
                                ),
                              );
                          }
                        },
                        child: Text(
                          AppLanguage.getText('buy_now'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// ── Menu Choices Section ──────────────────────────────────────────────────────
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
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(color: kPrimary),
          );
        final docs = snap.data!.where((d) => d.exists).toList();
        if (docs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: docs.map((doc) {
            final data = (doc.data() as Map<String, dynamic>?) ?? {};
            final heading = (data['heading'] as String?) ?? '';
            final options = List<String>.from(data['options'] ?? []);
            final groupId = doc.id;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kWhite.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kMuted.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        heading,
                        style: const TextStyle(
                          color: kWhite,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
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
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...options.map((opt) {
                    final isSelected = selectedChoice[groupId] == opt;
                    return InkWell(
                      onTap: () => onChanged(groupId, opt),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? kPrimary
                                      : kMuted.withOpacity(0.5),
                                  width: 2,
                                ),
                                color: isSelected
                                    ? kPrimary
                                    : Colors.transparent,
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: kWhite,
                                      size: 12,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              opt,
                              style: TextStyle(
                                color: isSelected ? kWhite : kMuted,
                                fontSize: 14,
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
          }).toList(),
        );
      },
    );
  }
}

// ── Additional Options Section ────────────────────────────────────────────────
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kWhite.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kMuted.withOpacity(0.2)),
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
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: kMuted.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Optional',
                  style: TextStyle(
                    color: kMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(options.length, (i) {
            final opt = options[i];
            final optName = (opt['name'] as String?) ?? '';
            final optPrice = ((opt['price'] as num?) ?? 0).toDouble();
            final isSelected = selected.contains(i);
            return InkWell(
              onTap: () => onToggle(i),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: isSelected
                              ? kPrimary
                              : kMuted.withOpacity(0.5),
                          width: 2,
                        ),
                        color: isSelected ? kPrimary : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: kWhite, size: 13)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        optName,
                        style: TextStyle(
                          color: isSelected ? kWhite : kMuted,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      optPrice > 0
                          ? '+CHF ${optPrice.toStringAsFixed(2)}'
                          : 'Free',
                      style: TextStyle(
                        color: isSelected ? kPrimary : kMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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

// ── Small widgets ─────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: kMuted,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _ChipRow extends StatelessWidget {
  final List<String> values;
  final String selected;
  final ValueChanged<String> onChanged;
  const _ChipRow({
    required this.values,
    required this.selected,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    children: values.map((v) {
      final on = v == selected;
      return ChoiceChip(
        label: Text(v),
        selected: on,
        labelStyle: TextStyle(
          color: on ? kWhite : kMuted,
          fontWeight: on ? FontWeight.bold : FontWeight.normal,
        ),
        selectedColor: kPrimary,
        backgroundColor: kWhite.withOpacity(0.05),
        showCheckmark: false,
        side: BorderSide(color: on ? kPrimary : kMuted.withOpacity(0.3)),
        onSelected: (_) => onChanged(v),
      );
    }).toList(),
  );
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => Ink(
    decoration: BoxDecoration(
      color: kWhite.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: kMuted.withOpacity(0.4)),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, color: kWhite, size: 20),
      ),
    ),
  );
}