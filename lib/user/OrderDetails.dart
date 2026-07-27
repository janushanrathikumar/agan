import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- Palette ---
const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);
const kCardBg = Color(0xFF383735);

class MyOrdersPage extends StatelessWidget {
  const MyOrdersPage({super.key});

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'new' || s == 'pending') return Colors.orangeAccent;
    if (s == 'preparing' || s == 'cooking') return Colors.blueAccent;
    if (s == 'completed' || s == 'delivered' || s == 'ready')
      return Colors.green;
    if (s == 'cancelled') return Colors.redAccent;
    return kMuted;
  }

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;

    int hour = dt.hour;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;

    return '$day/$month/$year • $hour:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(backgroundColor: kBg, title: const Text('My Orders')),
        body: const Center(
          child: Text(
            'Please login to view orders.',
            style: TextStyle(color: kWhite),
          ),
        ),
      );
    }

    // 🟢 INDEX ERROR-ஐ தவிர்க்க orderBy-ஐ நீக்கிவிட்டோம்
    final ordersQuery = FirebaseFirestore.instance
        .collection('orders')
        .where('uid', isEqualTo: user.uid);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kWhite,
        title: const Text(
          'My Orders',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: ordersQuery.snapshots(),
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

          // 🟢 Flutter-க்குள்ளேயே தேதியின்படி வரிசைப்படுத்துகிறோம் (Local Sorting)
          var docs = snap.data?.docs.toList() ?? [];

          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;

            final aTime = aData['timestamp'] as Timestamp?;
            final bTime = bData['timestamp'] as Timestamp?;

            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;

            // Descending order (புதிய ஆர்டர்கள் முதலில்)
            return bTime.compareTo(aTime);
          });

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 60, color: kMuted),
                  SizedBox(height: 16),
                  Text(
                    'No orders found',
                    style: TextStyle(color: kMuted, fontSize: 18),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final orderId = data['order_id'] ?? doc.id;
              final status = data['status'] ?? 'Pending';
              final total = (data['total'] as num?)?.toDouble() ?? 0.0;
              final method = data['delivery_method'] ?? 'Take_Away';
              final tableNo = data['table_no'] ?? 'N/A';

              // 🟢 Charges breakdown — subtotal / service_charge /
              // service_charge_rate are now saved on the order doc by
              // payment_page.dart. Older orders placed before this change
              // won't have them, so fall back to treating the whole total
              // as the subtotal with a 0% service charge.
              final num subtotal = (data['subtotal'] as num?) ?? total;
              final num serviceCharge = (data['service_charge'] as num?) ?? 0;
              final num serviceChargeRate =
                  (data['service_charge_rate'] as num?) ?? 0;

              final timestamp = data['timestamp'] as Timestamp?;
              final dateStr = timestamp != null
                  ? _formatDateTime(timestamp.toDate())
                  : 'Date Unknown';

              final itemsList = data['items'] as List<dynamic>? ?? [];

              return Container(
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kMuted.withOpacity(0.1)),
                ),
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    childrenPadding: const EdgeInsets.all(16).copyWith(top: 0),
                    iconColor: kWhite,
                    collapsedIconColor: kMuted,
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Order: #${orderId.toString().toUpperCase().substring(0, 6)}',
                          style: const TextStyle(
                            color: kWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _getStatusColor(status)),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(status),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: kMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            dateStr,
                            style: const TextStyle(color: kMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    children: [
                      const Divider(color: kMuted, thickness: 0.2),
                      const SizedBox(height: 10),

                      // Delivery Details Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _detailColumn('Method', method),
                          if (method.toLowerCase() != 'take_away' &&
                              tableNo != 'no')
                            _detailColumn('Table No', tableNo),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 🟢 Charges breakdown row — Subtotal, Service Charge
                      // (labeled with the actual rate applied, e.g. 8.1%
                      // for dine-in / 2.6% for take-away), then the Total.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _detailColumn(
                            'Subtotal',
                            'CHF ${subtotal.toStringAsFixed(2)}',
                          ),
                          _detailColumn(
                            'Service Charge (${_methodLabel(method)} • ${(serviceChargeRate * 100).toStringAsFixed(1)}%)',
                            'CHF ${serviceCharge.toStringAsFixed(2)}',
                          ),
                          _detailColumn(
                            'Total',
                            'CHF ${total.toStringAsFixed(2)}',
                            isHighlight: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Items Breakdown:',
                          style: TextStyle(
                            color: kWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Map Dynamic Sub-Items & Options
                      ...itemsList.map((item) {
                        final itemMap = item as Map<String, dynamic>;
                        final iName = itemMap['name'] ?? '';
                        final iQty = itemMap['qty'] ?? 1;
                        final iPrice =
                            (itemMap['price'] as num?)?.toDouble() ?? 0.0;
                        final iKind = itemMap['kind'] ?? '';

                        // Drinks specific data
                        final iType = itemMap['type'] ?? '';
                        final iSugar = itemMap['sugar'] ?? '';

                        // Foods specific data
                        final iExtraNote = itemMap['extraNote'] ?? '';
                        final iAddOptions =
                            itemMap['additionalOptions'] as List<dynamic>? ??
                            [];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: kBg.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${iQty}x $iName',
                                    style: const TextStyle(
                                      color: kWhite,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    'CHF ${(iPrice * iQty).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: kPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),

                              // Drinks Options View (Type & Sugar)
                              if (iKind == 'drink' &&
                                  (iType.isNotEmpty || iSugar.isNotEmpty))
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    '☕ $iType • 🍬 Sugar: $iSugar',
                                    style: const TextStyle(
                                      color: kMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),

                              // Extra Note View
                              if (iExtraNote != null &&
                                  iExtraNote.toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    '📝 Note: $iExtraNote',
                                    style: const TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),

                              // Additional Options Fields View (Extras)
                              if (iAddOptions.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '➕ Extras:',
                                        style: TextStyle(
                                          color: kMuted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      ...iAddOptions.map((opt) {
                                        final optMap =
                                            opt as Map<String, dynamic>;
                                        final optName = optMap['name'] ?? '';
                                        final optPrice =
                                            (optMap['price'] as num?)
                                                ?.toDouble() ??
                                            0.0;
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            left: 8.0,
                                            top: 2,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '• $optName',
                                                style: const TextStyle(
                                                  color: kMuted,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              if (optPrice > 0)
                                                Text(
                                                  '+CHF ${optPrice.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    color: kMuted,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
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

  // 🟢 Human-readable label for the delivery method, used to make the
  // service-charge line self-explanatory (e.g. "Service Charge (Dine-In •
  // 8.1%)") instead of just showing a bare percentage.
  String _methodLabel(String method) {
    return method == 'Take_Away' ? 'Take-Away' : 'Dine-In';
  }

  Widget _detailColumn(String label, String value, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: kMuted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isHighlight ? kPrimary : kWhite,
            fontWeight: FontWeight.bold,
            fontSize: isHighlight ? 16 : 14,
          ),
        ),
      ],
    );
  }
}
