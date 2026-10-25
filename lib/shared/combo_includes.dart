import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:restorant/language.dart';
import 'package:restorant/platform_image/platform_image.dart';

const _kPrimary = Color(0xFFB59410);
const _kWhite = Color(0xFFFFFFFF);
const _kMuted = Color(0xFFB7B7B6);
const _kBg = Color(0xFF2A2928);
const _kSave = Color(0xFFFF8C00);

/// Shows every menu inside a combo with its photo, type, description
/// and single price, so guests can see exactly what the combo gives them.
///
/// The combo stores a snapshot of each menu; the live menu document is
/// read on top of it so photos and descriptions stay current.
class ComboIncludes extends StatefulWidget {
  final List<dynamic> comboItems;
  final double? savings;

  const ComboIncludes({super.key, required this.comboItems, this.savings});

  @override
  State<ComboIncludes> createState() => _ComboIncludesState();
}

class _ComboIncludesState extends State<ComboIncludes> {
  late Future<Map<String, Map<String, dynamic>>> _live;

  List<Map<String, dynamic>> get _stored => widget.comboItems
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  @override
  void initState() {
    super.initState();
    _live = _loadLive();
  }

  Future<Map<String, Map<String, dynamic>>> _loadLive() async {
    final ids = _stored
        .map((e) => e['id'])
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final result = <String, Map<String, dynamic>>{};
    final col = FirebaseFirestore.instance.collection('menu_items');
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      try {
        final snap = await col
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final d in snap.docs) {
          result[d.id] = d.data();
        }
      } catch (e) {
        debugPrint('Could not load combo menus: $e');
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final stored = _stored;
    if (stored.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<Map<String, Map<String, dynamic>>>(
      future: _live,
      builder: (context, snap) {
        final live = snap.data ?? const {};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fastfood_rounded, color: _kPrimary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${AppLanguage.getText('This Combo Includes')} (${stored.length})',
                    style: const TextStyle(
                      color: _kWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final item in stored)
              _ComboMenuCard(
                item: {...item, ...?live[item['id']], 'price': item['price']},
              ),
            if ((widget.savings ?? 0) > 0)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _kSave.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kSave.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.savings_rounded, color: _kSave, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppLanguage.getText('You Save'),
                        style: const TextStyle(
                          color: _kWhite,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      'CHF ${widget.savings!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: _kSave,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ComboMenuCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ComboMenuCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = (item['name'] as String?) ?? '';
    final note = ((item['note'] as String?) ?? '').trim();
    final imageUrl = (item['imageUrl'] as String?) ?? '';
    final isDrink = item['itemType'] == 'drink';
    final price = ((item['price'] as num?) ?? 0).toDouble();
    final fallback = Container(
      color: _kBg,
      alignment: Alignment.center,
      child: Icon(
        isDrink ? Icons.local_drink : Icons.restaurant,
        color: _kMuted,
        size: 32,
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _kWhite.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kWhite.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: imageUrl.isEmpty
                ? null
                : () => _showPhoto(context, name, imageUrl),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 84,
                height: 84,
                child: imageUrl.isEmpty
                    ? fallback
                    : buildUniversalImage(
                        imageUrl: imageUrl,
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                        fallback: fallback,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: _kPrimary, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: _kWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isDrink
                      ? AppLanguage.getText('Drink')
                      : AppLanguage.getText('Food'),
                  style: const TextStyle(
                    color: _kPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    note,
                    style: const TextStyle(color: _kMuted, fontSize: 12.5),
                  ),
                ],
                if (price > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'CHF ${price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: _kMuted,
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPhoto(BuildContext context, String name, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _kBg,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: SizedBox(
                width: double.infinity,
                height: MediaQuery.of(ctx).size.height * 0.6,
                child: buildUniversalImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  fallback: const SizedBox.shrink(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: _kWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: _kWhite),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
