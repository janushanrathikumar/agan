import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'checkout.dart';

// --- unified palette ---
const kPrimary = Color(0xFFA26334); // coffee brown
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);

enum _MenuKind { drinks, foods }

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});
  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  _MenuKind _kind = _MenuKind.drinks;
  String? _selectedCategory;

  // Stream for all menu categories, fetched once.
  late final Stream<QuerySnapshot> _categoryStream;

  @override
  void initState() {
    super.initState();
    // 1. Fetch ALL menu_category documents once.
    _categoryStream =
        FirebaseFirestore.instance.collection('menu_category').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    const leftW = 80.0;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final uid = authSnap.data?.uid;

        // 2. Wrap the entire MenuPage content in a StreamBuilder for categories
        return StreamBuilder<QuerySnapshot>(
          stream: _categoryStream,
          builder: (context, categorySnap) {
            // Display loading indicator while categories are fetched
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
                title: const Text('Menu',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, color: kWhite)),
                elevation: 0,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(54),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _TopSwitch(
                      kind: _kind,
                      onChanged: (k) => setState(() {
                        _kind = k;
                        // Reset selected category when switching menu kind
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
                      allCategoryDocs: allCategoryDocs, // Pass all categories
                      selected: _selectedCategory,
                      onResolvedFirst: (first) {
                        // Only update state if the selection has actually changed
                        if (_selectedCategory != first) {
                          setState(() => _selectedCategory = first);
                        }
                      },
                      onSelect: (c) => setState(() => _selectedCategory = c),
                    ),
                  ),
                  const VerticalDivider(width: 1, color: Color(0xFF3A3938)),
                  Expanded(
                    child: _MenuGrid(
                      kind: _kind,
                      category: _selectedCategory,
                      onTapItem: (m) => _showItemSheet(context, _kind, m, uid),
                    ),
                  ),
                ],
              ),
              // ... (FloatingActionButton remains the same)
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
                        return FloatingActionButton.extended(
                          backgroundColor: kPrimary,
                          foregroundColor: kWhite,
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: Text('RM ${total.toStringAsFixed(2)}'),
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => CheckoutPage(uid: uid)));
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
        borderColor: kMuted,
        selectedBorderColor: kPrimary,
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child:
                Text('Drinks', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('Food', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// --- Category Rail (FIXED) ---
class _CategoryRail extends StatelessWidget {
  final _MenuKind kind;
  final List<QueryDocumentSnapshot>
      allCategoryDocs; // All categories fetched once by parent
  final String? selected;
  final ValueChanged<String?> onSelect;
  final ValueChanged<String?> onResolvedFirst;
  const _CategoryRail({
    required this.kind,
    required this.allCategoryDocs, // Updated constructor
    required this.selected,
    required this.onSelect,
    required this.onResolvedFirst,
  });

  // NEW: Helper to get the stream query based on the current menu kind
  Query _getMenuQuery() {
    final col = kind == _MenuKind.drinks ? 'drinks' : 'foods';
    return FirebaseFirestore.instance
        .collection(col)
        .where('status', isEqualTo: 'on');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF242322),
      // Only StreamBuilder needed is for the *items* to figure out availability.
      // The Category Rail itself is rebuilt constantly with the parent state updates,
      // but the StreamBuilder will cache its state while the selection is processed.
      child: StreamBuilder<QuerySnapshot>(
        key: ValueKey(
            kind), // KEY ADDED: Forces StreamBuilder to reset on kind change
        stream: _getMenuQuery().snapshots(),
        builder: (context, itemsSnap) {
          // 1. Determine which categories are available (contain 'on' items)
          final availableCategoryNames = <String>{};
          for (final d in (itemsSnap.data?.docs ?? [])) {
            final m = (d.data() as Map<String, dynamic>?) ?? {};
            final cat = (m['category'] as String?) ?? '';
            if (cat.isNotEmpty) availableCategoryNames.add(cat);
          }

          // 2. Filter the ALL categories list using the AVAILABLE category names
          final filteredCategoryDocs = allCategoryDocs
              .where((doc) => availableCategoryNames.contains(doc.id))
              .toList(growable: false);

          if (filteredCategoryDocs.isEmpty) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => onResolvedFirst(null));
            return const Center(
                child: Text('No categories',
                    style: TextStyle(color: kWhite, fontSize: 10)));
          }

          final categoryNames =
              filteredCategoryDocs.map((d) => d.id).toList(growable: false);

          // 3. Auto-select the first category if none is selected or the selected one vanished
          if (selected == null || !categoryNames.contains(selected)) {
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => onResolvedFirst(categoryNames.first));
          }

          // 4. Display Loading indicator ONLY while the items stream is connecting for the first time
          if (itemsSnap.connectionState == ConnectionState.waiting &&
              !itemsSnap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: kPrimary));
          }

          // 5. Use the filtered list to build the ListView
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: filteredCategoryDocs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final d = filteredCategoryDocs[i];
              final data = (d.data() as Map<String, dynamic>?) ?? {};
              final name = d.id;
              final iconUrl = (data['iconUrl'] as String?) ?? '';
              // Use the 'selected' property from the parent widget state
              final isSel = selected == name;

              return InkWell(
                // When selecting, simply call the parent setState
                onTap: () => onSelect(name),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  decoration: BoxDecoration(
                    color:
                        isSel ? kPrimary.withOpacity(0.25) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
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
                            color: kWhite,
                            fontSize: 12,
                            fontWeight:
                                isSel ? FontWeight.w700 : FontWeight.w500),
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
      child: url.isNotEmpty
          ? Image.network(url,
              height: 44,
              width: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image, color: kMuted, size: 36))
          : const Icon(Icons.image, color: kMuted, size: 36),
    );
  }
}

// Right grid
class _MenuGrid extends StatelessWidget {
  final _MenuKind kind;
  final String? category;
  final void Function(Map<String, dynamic> item) onTapItem;
  const _MenuGrid(
      {required this.kind, required this.category, required this.onTapItem});

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
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snap.hasError)
          return Center(
              child: Text('Error: ${snap.error}',
                  style: const TextStyle(color: Colors.redAccent)));
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty)
          return const Center(
              child: Text('No items', style: TextStyle(color: kWhite)));

        final w = MediaQuery.of(context).size.width;
        final cross = w >= 1400
            ? 4
            : w >= 1100
                ? 3
                : w >= 800
                    ? 2
                    : 1;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cross,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.66),
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
                  color: const Color(0xFF2F2E2D),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kMuted),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Flexible(
                      flex: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageUrl.isNotEmpty
                            ? Image.network(imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.broken_image,
                                    color: kWhite,
                                    size: 40))
                            : Container(
                                color: const Color(0xFF3A3938),
                                child: const Icon(Icons.image, color: kWhite)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      flex: 1,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: kWhite,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('RM ${price.toStringAsFixed(2)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: kWhite, fontWeight: FontWeight.w600)),
                        ],
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
void _showItemSheet(BuildContext context, _MenuKind kind,
    Map<String, dynamic> item, String? uidHint) {
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) {
      int qty = 1;

      // Drinks options
      String drinkType = 'Hot'; // Hot / Iced
      String sugar = 'Normal'; // Normal / Half

      // Foods extra note
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
          payload.addAll({
            'type': drinkType, // Hot / Iced
            'sugar': sugar, // Normal / Half
          });
        } else {
          payload.addAll({
            'note': dbNote,
            'extraNote':
                noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
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
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                        color: kMuted, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageUrl.isNotEmpty
                          ? Image.network(imageUrl,
                              width: 110,
                              height: 110,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.broken_image,
                                  color: kWhite,
                                  size: 40))
                          : Container(
                              width: 110,
                              height: 110,
                              color: const Color(0xFF3A3938),
                              child: const Icon(Icons.image, color: kWhite)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  color: kWhite,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18)),
                          const SizedBox(height: 6),
                          Text('RM ${price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: kWhite, fontWeight: FontWeight.w600)),
                          if (kind == _MenuKind.foods && dbNote.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(dbNote,
                                style: const TextStyle(
                                    color: kMuted, fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (kind == _MenuKind.drinks) ...[
                  _SectionTitle('Type'),
                  _ChipRow(
                    values: const ['Hot', 'Iced'],
                    selected: drinkType,
                    onChanged: (v) => setS(() => drinkType = v),
                  ),
                  const SizedBox(height: 10),
                  _SectionTitle('Sugar'),
                  _ChipRow(
                    values: const ['Normal', 'Half'],
                    selected: sugar,
                    onChanged: (v) => setS(() => sugar = v),
                  ),
                  const SizedBox(height: 10),
                ] else ...[
                  _SectionTitle('Note (optional)'),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: kWhite),
                    decoration: InputDecoration(
                      hintText: 'Any preference…',
                      hintStyle: const TextStyle(color: kMuted),
                      filled: true,
                      fillColor: const Color(0xFF2F2E2D),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kMuted),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kMuted),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kPrimary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                _SectionTitle('Quantity'),
                Row(
                  children: [
                    _QtyBtn(
                        icon: Icons.remove,
                        onTap: () => setS(() => qty = qty > 1 ? qty - 1 : 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('$qty',
                          style: const TextStyle(
                              color: kWhite,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                    ),
                    _QtyBtn(icon: Icons.add, onTap: () => setS(() => qty++)),
                    const Spacer(),
                    Text('Total: RM ${total().toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: kWhite, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kMuted),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          await addToChat();
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Added to chat')));
                          }
                        },
                        child: const Text('Add to chat',
                            style: TextStyle(color: kWhite)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: kWhite,
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () async {
                          await addToChat();
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            final uid = await _ensureUid();
                            if (uid != null && context.mounted) {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => CheckoutPage(uid: uid)));
                            }
                          }
                        },
                        child: const Text('Buy now',
                            style: TextStyle(fontWeight: FontWeight.w700)),
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
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(color: kMuted, fontSize: 12)),
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final List<String> values;
  final String selected;
  final ValueChanged<String> onChanged;
  const _ChipRow(
      {required this.values, required this.selected, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: values.map((v) {
        final on = v == selected;
        return ChoiceChip(
          label: Text(v),
          selected: on,
          labelStyle: const TextStyle(color: kWhite),
          selectedColor: kPrimary,
          backgroundColor: const Color(0xFF2F2E2D),
          side: const BorderSide(color: kMuted),
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
        color: const Color(0xFF2F2E2D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kMuted),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.add, color: kWhite),
        ),
      ),
    );
  }
}
