import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const kPrimary = Color(0xFFA26334);
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);

class PaymentPage extends StatefulWidget {
  final String uid;
  const PaymentPage({super.key, required this.uid});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  void _showPaymentSheet(BuildContext context, double total,
      Map<String, dynamic> delivery, List<Map<String, dynamic>> items) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1D1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PaymentBottomSheet(
        uid: widget.uid,
        total: total,
        delivery: delivery,
        items: items,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deliveryRef =
        FirebaseFirestore.instance.collection('food_delivery').doc(widget.uid);
    final itemsRef = FirebaseFirestore.instance
        .collection('chat')
        .doc(widget.uid)
        .collection('items');

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kWhite,
        title: const Text('Payment',
            style: TextStyle(
                color: kWhite, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        elevation: 0,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: deliveryRef.get(),
        builder: (context, deliverySnap) {
          if (deliverySnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final delivery =
              (deliverySnap.data?.data() ?? {}) as Map<String, dynamic>;
          final method = delivery['delivery_method'] ?? 'N/A';
          final tableNo = delivery['table_no'] ?? 'N/A';
          final ts = (delivery['timestamp'] as Timestamp?)?.toDate();

          return StreamBuilder<QuerySnapshot>(
            stream: itemsRef.snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return const Center(
                    child: Text('No items found',
                        style: TextStyle(color: kWhite, fontSize: 16)));
              }

              double total = 0;
              final items = <Map<String, dynamic>>[];
              for (final d in docs) {
                final m = (d.data() as Map<String, dynamic>? ?? {});
                final p = (m['price'] as num?)?.toDouble() ?? 0;
                final q = (m['qty'] as num?)?.toInt() ?? 1;
                total += p * q;
                items.add(m);
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Delivery Info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2F2E2D),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 15)
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Delivery Details',
                              style: TextStyle(
                                  color: kPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                          const SizedBox(height: 8),
                          _infoRow('Method', method),
                          _infoRow('Table No', tableNo),
                          if (ts != null)
                            _infoRow(
                                'Timestamp', ts.toString().split('.').first),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text('Order Summary',
                        style: TextStyle(
                            color: kPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 18)),
                    const SizedBox(height: 12),

                    // Full detailed item list
                    ListView.separated(
                      itemCount: docs.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final m =
                            (docs[i].data() as Map<String, dynamic>? ?? {});
                        final name = (m['name'] as String?) ?? '';
                        final price = (m['price'] as num?)?.toDouble() ?? 0;
                        final qty = (m['qty'] as num?)?.toInt() ?? 1;
                        final kind = (m['kind'] as String?) ?? '';
                        final type = (m['type'] as String?) ?? '';
                        final sugar = (m['sugar'] as String?) ?? '';
                        final note = (m['note'] as String?) ?? '';
                        final extraNote = (m['extraNote'] as String?) ?? '';
                        final imageUrl = (m['imageUrl'] as String?) ?? '';

                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2F2E2D),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: imageUrl.isNotEmpty
                                    ? Image.network(imageUrl,
                                        width: 70,
                                        height: 70,
                                        fit: BoxFit.cover)
                                    : Container(
                                        width: 70,
                                        height: 70,
                                        color: const Color(0xFF3A3938)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DefaultTextStyle(
                                  style: const TextStyle(color: kWhite),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16)),
                                      const SizedBox(height: 4),
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
                                      Text(
                                          'RM ${(price * qty).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: kWhite,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      onPressed: () =>
                          _showPaymentSheet(context, total, delivery, items),
                      child: const Text('Proceed to Pay',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$label: ',
              style: const TextStyle(
                  color: kMuted, fontWeight: FontWeight.w600, fontSize: 14)),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: kWhite, fontSize: 14),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ------------------- Payment Bottom Sheet --------------------

class PaymentBottomSheet extends StatefulWidget {
  final String uid;
  final double total;
  final Map<String, dynamic> delivery;
  final List<Map<String, dynamic>> items;

  const PaymentBottomSheet({
    super.key,
    required this.uid,
    required this.total,
    required this.delivery,
    required this.items,
  });

  @override
  State<PaymentBottomSheet> createState() => _PaymentBottomSheetState();
}

class _PaymentBottomSheetState extends State<PaymentBottomSheet> {
  String _selectedMethod = 'card';
  final _cardName = TextEditingController();
  final _cardNumber = TextEditingController();
  final _paypalEmail = TextEditingController();

  Future<void> _completePayment(BuildContext context) async {
    final firestore = FirebaseFirestore.instance;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Create new order doc
    final orderRef = firestore.collection('orders').doc();
    await orderRef.set({
      'order_id': orderRef.id,
      'uid': user.uid,
      'delivery_method': widget.delivery['delivery_method'] ?? 'Unknown',
      'table_no': widget.delivery['table_no'] ?? 'N/A',
      'timestamp': FieldValue.serverTimestamp(),
      'payment_method': _selectedMethod == 'card' ? 'Card' : 'PayPal',
      'status': 'Pending',
      'total': widget.total,
      'items': widget.items,
    });

    // Delete chat items
    final chatItems =
        firestore.collection('chat').doc(user.uid).collection('items');
    final snapshot = await chatItems.get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }

    // Close sheet & show message
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Payment Successful! Order saved (ID: ${orderRef.id}).'),
          backgroundColor: kPrimary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 40,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: kMuted.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4)),
            ),
            const Text('Select Payment Method',
                style: TextStyle(
                    color: kPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            const SizedBox(height: 16),
            _paymentOption('card', Icons.credit_card, 'Credit / Debit Card'),
            const SizedBox(height: 8),
            _paymentOption('paypal', Icons.account_balance_wallet, 'PayPal'),
            const SizedBox(height: 16),
            if (_selectedMethod == 'card') _input('Cardholder Name', _cardName),
            if (_selectedMethod == 'card') _input('Card Number', _cardNumber),
            if (_selectedMethod == 'paypal')
              _input('PayPal Email', _paypalEmail),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total: RM ${widget.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: kWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: kWhite,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _completePayment(context),
                  child: const Text('Pay Now',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentOption(String id, IconData icon, String label) {
    final selected = _selectedMethod == id;
    return InkWell(
      onTap: () => setState(() => _selectedMethod = id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              selected ? kPrimary.withOpacity(0.15) : const Color(0xFF2F2E2D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? kPrimary : kMuted),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? kPrimary : kMuted),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    color: selected ? kPrimary : kWhite,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_circle, color: kPrimary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _input(String hint, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: kWhite),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFF2F2E2D),
          hintText: hint,
          hintStyle: const TextStyle(color: kMuted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kMuted),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kPrimary),
          ),
        ),
      ),
    );
  }
}
