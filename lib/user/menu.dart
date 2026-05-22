import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'checkout.dart';
import '../language.dart'; // Language file இணைக்கப்பட்டுள்ளது (path-ஐ சரிபார்க்கவும்)

// வெப் இமேஜ் CORS எர்ரரைத் தவிர்க்க இந்த இம்போர்ட்டுகள் தேவை
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

// --- லோகோ நிறங்கள் ---
const kPrimary = Color(0xFFE49024); // Orange
const kBg = Color(0xFF112A18); // Dark Green
const kMuted = Color(0xFFA1B3A1); // Muted Green
const kWhite = Color(0xFFF7F7F2); // Cream White
const kDarkCard = Color(0xFF194D25); // Card Background Green

enum _MenuKind { drinks, foods }

// வெப் பிளாட்ஃபார்மில் CORS எர்ரர் இல்லாமல் இமேஜ் காட்ட உதவும் பொதுவான விட்ஜெட்
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
        (int viewId) => html.ImageElement()
          ..src = imageUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'cover'
          ..style.borderRadius = '12px', // படங்களின் ஓரங்களை வளைக்க
      );

      return SizedBox(
        width: width,
        height: height,
        child: HtmlElementView(viewType: viewId),
      );
    } else {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
  }
}

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});
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
                        if (_selectedCategory != first) {
                          setState(() => _selectedCategory = first);
                        }
                      },
                      onSelect: (c) => setState(() => _selectedCategory = c),
                    ),
                  ),
                  const VerticalDivider(
                    width: 1,
                    color: kMuted,
                  ), // Divider நிறம் மாற்றம்
                  Expanded(
                    child: _MenuGrid(
                      kind: _kind,
                      category: _selectedCategory,
                      onTapItem: (m) => _showItemSheet(context, _kind, m, uid),
                    ),
                  ),
                ],
              ),
              floatingActionButton: uid == null
                  ? null
                  : StreamBuilder<QuerySnapshot>(
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
                          final p = (m['price'] as num?)?.toDouble() ?? 0;
                          final q = (m['qty'] as num?)?.toInt() ?? 1;
                          total += p * q;
                        }

                        // Cart-ல் items இருந்தால் மட்டும் FAB காட்டவும்
                        if (total == 0) return const SizedBox.shrink();

                        return FloatingActionButton.extended(
                          backgroundColor: kPrimary,
                          foregroundColor: kWhite,
                          icon: const Icon(
                            Icons.shopping_cart_outlined,
                          ), // Icon changed
                          label: Text(
                            'CHF ${total.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CheckoutPage(uid: uid),
                              ),
                            );
                          },
                        );
                      },
                    ),
            );
          },
        );
      },
    );
  }
}

// --- Toggle ---
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

// --- Category Rail ---
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
    final col = kind == _MenuKind.drinks ? 'drinks' : 'foods';
    return FirebaseFirestore.instance
        .collection(col)
        .where('status', isEqualTo: 'on');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0C1E11), // லோகோவின் மிக அடர்ந்த பச்சை
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

          if (itemsSnap.connectionState == ConnectionState.waiting &&
              !itemsSnap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: kPrimary),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CatIconLarge(url: iconUrl),
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

class _CatIconLarge extends StatelessWidget {
  final String url;
  const _CatIconLarge({required this.url});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: _WebSafeImage(
        imageUrl: url,
        width: 44,
        height: 44,
        fallback: const Icon(Icons.fastfood, color: kMuted, size: 30),
      ),
    );
  }
}

// --- Menu Grid (FIXED: 2 Items per row on mobile) ---
class _MenuGrid extends StatelessWidget {
  final _MenuKind kind;
  final String? category;
  final void Function(Map<String, dynamic> item) onTapItem;
  const _MenuGrid({
    required this.kind,
    required this.category,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    final col = kind == _MenuKind.drinks ? 'drinks' : 'foods';
    Query q = FirebaseFirestore.instance
        .collection(col)
        .where('status', isEqualTo: 'on');
    if (category != null) q = q.where('category', isEqualTo: category);

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimary),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Error: ${snap.error}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text(
              AppLanguage.getText('no_items'),
              style: const TextStyle(color: kWhite),
            ),
          );
        }

        final w = MediaQuery.of(context).size.width;

        // --- திருத்தப்பட்ட Grid Logic ---
        // மொபைலில் சரியாக 2 ஐட்டம்கள் வரும்படி அமைக்கப்பட்டுள்ளது.
        int crossCount = 2; // மொபைல்/சிறிய திரைகளுக்கு டீஃபால்ட்
        if (w >= 1200)
          crossCount = 5;
        else if (w >= 900)
          crossCount = 4;
        else if (w >= 600)
          crossCount = 3;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(
            12,
            12,
            12,
            80,
          ), // FAB மறைக்காமல் இருக்க கீழே அதிக இடம்
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: 12, // இடைவெளி குறைக்கப்பட்டுள்ளது
            crossAxisSpacing: 12,
            childAspectRatio: 0.72, // படத்தின் உயரத்தை சீரமைக்க
          ),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final m = (docs[i].data() as Map<String, dynamic>?) ?? {};
            final name = (m['name'] as String?) ?? '';
            final price = (m['price'] as num?)?.toDouble() ?? 0;
            final imageUrl = (m['imageUrl'] as String?) ?? '';

            return InkWell(
              onTap: () => onTapItem(m),
              child: Container(
                decoration: BoxDecoration(
                  color: kWhite.withOpacity(
                    0.06,
                  ), // அடர் பச்சை பின்னணியில் லேசான வெள்ளை
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kWhite.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // படத்திற்கான பகுதி
                    Expanded(
                      flex: 5,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
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
                    // எழுத்துக்களுக்கான பகுதி
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
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
                            Text(
                              'CHF ${price.toStringAsFixed(2)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color:
                                    kPrimary, // விலையை ஆரஞ்சு நிறத்தில் காட்ட
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

/// Ensure a uid (anonymous auth if needed)
Future<String?> _ensureUid() async {
  final auth = FirebaseAuth.instance;
  final u = auth.currentUser;
  if (u != null) return u.uid;
  final cred = await auth.signInAnonymously();
  return cred.user?.uid;
}

/// Bottom sheet and “Add to chat” write
void _showItemSheet(
  BuildContext context,
  _MenuKind kind,
  Map<String, dynamic> item,
  String? uidHint,
) {
  final name = (item['name'] as String?) ?? '';
  final imageUrl = (item['imageUrl'] as String?) ?? '';
  final price = ((item['price'] as num?) ?? 0).toDouble();
  final dbNote = (item['note'] as String?) ?? '';
  final category = (item['category'] as String?) ?? '';

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

      double total() => price * qty;

      Future<void> addToChat() async {
        final uid = uidHint ?? await _ensureUid();
        if (uid == null) return;

        final payload = <String, dynamic>{
          'kind': kind == _MenuKind.drinks ? 'drink' : 'food',
          'name': name,
          'imageUrl': imageUrl,
          'price': price,
          'qty': qty,
          'category': category,
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _WebSafeImage(
                        imageUrl: imageUrl,
                        width: 100,
                        height: 100,
                        fallback: Container(
                          width: 100,
                          height: 100,
                          color: kDarkCard,
                          child: const Icon(
                            Icons.image,
                            color: kMuted,
                            size: 40,
                          ),
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
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'CHF ${price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: kPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          if (kind == _MenuKind.foods && dbNote.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              dbNote,
                              style: const TextStyle(
                                color: kMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
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
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: kPrimary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
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
                      '${AppLanguage.getText('total')} CHF ${total().toStringAsFixed(2)}',
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
                          await addToChat();
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
                          await addToChat();
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            final uid = await _ensureUid();
                            if (uid != null && context.mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CheckoutPage(uid: uid),
                                ),
                              );
                            }
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

// ---------- small helpers ----------

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Align(
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
  Widget build(BuildContext context) {
    return Wrap(
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
          showCheckmark:
              false, // Checkmark-ஐ நீக்கினால் வடிவமைப்பு அழகாக இருக்கும்
          side: BorderSide(color: on ? kPrimary : kMuted.withOpacity(0.3)),
          onSelected: (_) => onChanged(v),
        );
      }).toList(),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Ink(
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
}
