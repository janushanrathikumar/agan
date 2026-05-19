import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'payment_page.dart'; // ✅ Add this import

// --- Unified palette ---
const kPrimary = Color(0xFFA26334); // coffee brown (same across app)
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);

class CheckoutPage extends StatelessWidget {
  final String uid;
  const CheckoutPage({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final itemsRef = FirebaseFirestore.instance
        .collection('chat')
        .doc(uid)
        .collection('items');

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kWhite,
        title: const Text('Checkout',
            style: TextStyle(fontWeight: FontWeight.w700, color: kWhite)),
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: itemsRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text('Error: ${snap.error}',
                  style: const TextStyle(color: Colors.redAccent)),
            );
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text('Your chat is empty',
                  style: TextStyle(color: kWhite, fontSize: 16)),
            );
          }

          double total = 0;
          for (final d in docs) {
            final m = (d.data() as Map<String, dynamic>? ?? {});
            final p = (m['price'] as num?)?.toDouble() ?? 0;
            final q = (m['qty'] as num?)?.toInt() ?? 1;
            total += p * q;
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final id = docs[i].id;
                    final m = (docs[i].data() as Map<String, dynamic>? ?? {});
                    final name = (m['name'] as String?) ?? '';
                    final price = (m['price'] as num?)?.toDouble() ?? 0;
                    final qty = (m['qty'] as num?)?.toInt() ?? 1;
                    final imageUrl = (m['imageUrl'] as String?) ?? '';
                    final kind = (m['kind'] as String?) ?? '';
                    final type = (m['type'] as String?) ?? '';
                    final sugar = (m['sugar'] as String?) ?? '';
                    final note = (m['note'] as String?) ?? '';
                    final extraNote = (m['extraNote'] as String?) ?? '';

                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2F2E2D),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kWhite.withOpacity(0.08)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    width: 70,
                                    height: 70,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.broken_image,
                                        color: kMuted,
                                        size: 40),
                                  )
                                : Container(
                                    width: 70,
                                    height: 70,
                                    color: const Color(0xFF3A3938),
                                    child: const Icon(Icons.image,
                                        color: kMuted, size: 36),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DefaultTextStyle(
                              style: const TextStyle(color: kWhite),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16)),
                                  const SizedBox(height: 2),
                                  if (kind == 'drink')
                                    Text('Type: $type • Sugar: $sugar',
                                        style: const TextStyle(
                                            color: kMuted, fontSize: 12)),
                                  if (kind == 'food')
                                    Text(
                                      [
                                        if (note.isNotEmpty) 'Note: $note',
                                        if (extraNote.isNotEmpty)
                                          'Extra: $extraNote'
                                      ].join('  •  '),
                                      style: const TextStyle(
                                          color: kMuted, fontSize: 12),
                                    ),
                                  const SizedBox(height: 6),
                                  Text('RM ${(price * qty).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: kWhite)),
                                ],
                              ),
                            ),
                          ),
                          Column(
                            children: [
                              _QtyBtn(
                                  icon: Icons.remove,
                                  onTap: () async {
                                    final newQty = qty > 1 ? qty - 1 : 1;
                                    await itemsRef
                                        .doc(id)
                                        .update({'qty': newQty});
                                  }),
                              Text('$qty',
                                  style: const TextStyle(color: kWhite)),
                              _QtyBtn(
                                  icon: Icons.add,
                                  onTap: () async {
                                    await itemsRef
                                        .doc(id)
                                        .update({'qty': qty + 1});
                                  }),
                              IconButton(
                                onPressed: () async {
                                  await itemsRef.doc(id).delete();
                                },
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent, size: 20),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF242322),
                  border: Border(top: BorderSide(color: kMuted)),
                ),
                child: Row(
                  children: [
                    Text('Total: RM ${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: kWhite,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                    const Spacer(),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: kWhite,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      // ✅ Navigate to PaymentPage
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaymentPage(uid: uid),
                          ),
                        );
                      },
                      child: const Text('Checkout',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
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
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, color: kWhite, size: 18),
        ),
      ),
    );
  }
}
