// lib/user/OrderDetails.dart
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../language.dart';

// --- Modern Palette ---
const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF112A18);
const kMuted = Color(0xFFA1B3A1);
const kWhite = Color(0xFFF7F7F2);

class MyOrdersPage extends StatelessWidget {
  const MyOrdersPage({super.key});

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'new' || s == 'pending') return Colors.orangeAccent;
    if (s == 'preparing' || s == 'cooking') return Colors.blueAccent;
    if (s == 'completed' || s == 'delivered' || s == 'ready')
      return Colors.greenAccent;
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
            Center(
              child: Text(
                AppLanguage.getText('Please login to view orders.'),
                style: const TextStyle(
                  color: kWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final ordersQuery = FirebaseFirestore.instance
        .collection('orders')
        .where('uid', isEqualTo: user.uid);

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Premium Background Gradient ──
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
            child: Column(
              children: [
                // ── Custom Modern Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Row(
                    children: [
                      Text(
                        AppLanguage.getText('My Orders'),
                        style: const TextStyle(
                          color: kWhite,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Orders Stream Builder ──
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
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
                            '${AppLanguage.getText("Error:")} ${snap.error}',
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        );
                      }

                      var docs = snap.data?.docs.toList() ?? [];

                      docs.sort((a, b) {
                        final aData = a.data() as Map<String, dynamic>;
                        final bData = b.data() as Map<String, dynamic>;
                        final aTime = aData['timestamp'] as Timestamp?;
                        final bTime = bData['timestamp'] as Timestamp?;

                        if (aTime == null && bTime == null) return 0;
                        if (aTime == null) return 1;
                        if (bTime == null) return -1;

                        return bTime.compareTo(aTime);
                      });

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: kWhite.withOpacity(0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.receipt_long_rounded,
                                  size: 50,
                                  color: kMuted,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                AppLanguage.getText('No orders found'),
                                style: const TextStyle(
                                  color: kMuted,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;

                          final orderId = data['order_id'] ?? doc.id;
                          final status = data['status'] ?? 'Pending';
                          final total =
                              (data['total'] as num?)?.toDouble() ?? 0.0;
                          final method = data['delivery_method'] ?? 'Take_Away';

                          final String rawTableNo = (data['table_no'] ?? 'N/A')
                              .toString();
                          final String rawChairNo = (data['chair_no'] ?? '')
                              .toString();

                          final String displayTable = rawChairNo.isNotEmpty
                              ? '$rawTableNo (${AppLanguage.getText("Chair")} $rawChairNo)'
                              : rawTableNo;

                          final num subtotal =
                              (data['subtotal'] as num?) ?? total;
                          final num serviceCharge =
                              (data['service_charge'] as num?) ?? 0;
                          final num serviceChargeRate =
                              (data['service_charge_rate'] as num?) ?? 0;

                          final timestamp = data['timestamp'] as Timestamp?;
                          final dateStr = timestamp != null
                              ? _formatDateTime(timestamp.toDate())
                              : 'Date Unknown';

                          final itemsList =
                              data['items'] as List<dynamic>? ?? [];

                          return ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: kWhite.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: kWhite.withOpacity(0.15),
                                    width: 1.5,
                                  ),
                                ),
                                child: Theme(
                                  data: Theme.of(
                                    context,
                                  ).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    tilePadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                    childrenPadding: const EdgeInsets.fromLTRB(
                                      20,
                                      0,
                                      20,
                                      20,
                                    ),
                                    iconColor: kWhite,
                                    collapsedIconColor: kMuted,
                                    title: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '#${orderId.toString().toUpperCase().substring(0, 6)}',
                                          style: const TextStyle(
                                            color: kWhite,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(
                                              status,
                                            ).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: _getStatusColor(
                                                status,
                                              ).withOpacity(0.6),
                                            ),
                                          ),
                                          child: Text(
                                            AppLanguage.getText(
                                              status,
                                            ).toUpperCase(),
                                            style: TextStyle(
                                              color: _getStatusColor(status),
                                              fontSize: 11,
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
                                            Icons.access_time_rounded,
                                            size: 14,
                                            color: kMuted,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            dateStr,
                                            style: TextStyle(
                                              color: kMuted.withOpacity(0.9),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    children: [
                                      Divider(
                                        color: kWhite.withOpacity(0.1),
                                        thickness: 1,
                                      ),
                                      const SizedBox(height: 12),

                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          _detailColumn(
                                            AppLanguage.getText('Method'),
                                            method == 'Take_Away'
                                                ? AppLanguage.getText(
                                                    'Take-Away',
                                                  )
                                                : AppLanguage.getText(
                                                    'Dine-In',
                                                  ),
                                          ),
                                          if (method.toLowerCase() !=
                                                  'take_away' &&
                                              rawTableNo != 'no')
                                            _detailColumn(
                                              AppLanguage.getText('Table No'),
                                              displayTable,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),

                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: kWhite.withOpacity(0.04),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: kWhite.withOpacity(0.08),
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  AppLanguage.getText(
                                                    'Subtotal',
                                                  ),
                                                  style: const TextStyle(
                                                    color: kMuted,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                Text(
                                                  'CHF ${subtotal.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    color: kWhite,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (serviceCharge > 0) ...[
                                              const SizedBox(height: 6),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    '${AppLanguage.getText("Service Charge")} (${(serviceChargeRate * 100).toStringAsFixed(1)}%)',
                                                    style: const TextStyle(
                                                      color: kMuted,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  Text(
                                                    'CHF ${serviceCharge.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      color: kWhite,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                            const Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 8.0,
                                              ),
                                              child: Divider(
                                                color: Colors.white10,
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  AppLanguage.getText('Total'),
                                                  style: const TextStyle(
                                                    color: kWhite,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  'CHF ${total.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    color: kPrimary,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 20),

                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          AppLanguage.getText(
                                            'Items Breakdown',
                                          ),
                                          style: const TextStyle(
                                            color: kWhite,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      ...itemsList.map((item) {
                                        final itemMap =
                                            item as Map<String, dynamic>;
                                        final iName = itemMap['name'] ?? '';
                                        final iQty = itemMap['qty'] ?? 1;
                                        final iPrice =
                                            (itemMap['price'] as num?)
                                                ?.toDouble() ??
                                            0.0;
                                        final iKind = itemMap['kind'] ?? '';
                                        final iSize =
                                            itemMap['size']?.toString() ?? '';
                                        final iMenuChoices =
                                            itemMap['menuChoices']
                                                as Map<String, dynamic>? ??
                                            {};
                                        final iType = itemMap['type'] ?? '';
                                        final iSugar = itemMap['sugar'] ?? '';
                                        final iExtraNote =
                                            itemMap['extraNote'] ?? '';
                                        final iAddOptions =
                                            itemMap['additionalOptions']
                                                as List<dynamic>? ??
                                            [];

                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: kWhite.withOpacity(0.04),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: kWhite.withOpacity(0.06),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      '${iQty}x $iName',
                                                      style: const TextStyle(
                                                        color: kWhite,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    'CHF ${(iPrice * iQty).toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      color: kPrimary,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),

                                              if (iSize.isNotEmpty &&
                                                  iSize != 'null')
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 4.0,
                                                      ),
                                                  child: Text(
                                                    '📏 ${AppLanguage.getText("Size")}: $iSize',
                                                    style: const TextStyle(
                                                      color: kMuted,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),

                                              if (iMenuChoices.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 4.0,
                                                      ),
                                                  child: Text(
                                                    '✔️ ${iMenuChoices.entries.map((e) => '${e.key}: ${e.value}').join(', ')}',
                                                    style: const TextStyle(
                                                      color: kMuted,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),

                                              if (iKind == 'drink' &&
                                                  (iType.isNotEmpty ||
                                                      iSugar.isNotEmpty))
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 4.0,
                                                      ),
                                                  child: Text(
                                                    '☕ $iType • 🍬 ${AppLanguage.getText("sugar").toLowerCase()}: $iSugar',
                                                    style: const TextStyle(
                                                      color: kMuted,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),

                                              if (iExtraNote != null &&
                                                  iExtraNote
                                                      .toString()
                                                      .isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 4.0,
                                                      ),
                                                  child: Text(
                                                    '📝 ${AppLanguage.getText("Note:")} $iExtraNote',
                                                    style: const TextStyle(
                                                      color: Colors.amberAccent,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),

                                              if (iAddOptions.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 6.0,
                                                      ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        '➕ ${AppLanguage.getText("Extras:")}',
                                                        style: const TextStyle(
                                                          color: kMuted,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      ...iAddOptions.map((opt) {
                                                        final optMap =
                                                            opt
                                                                as Map<
                                                                  String,
                                                                  dynamic
                                                                >;
                                                        final optName =
                                                            optMap['name'] ??
                                                            '';
                                                        final optPrice =
                                                            (optMap['price']
                                                                    as num?)
                                                                ?.toDouble() ??
                                                            0.0;
                                                        return Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                left: 8.0,
                                                                top: 2,
                                                              ),
                                                          child: Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceBetween,
                                                            children: [
                                                              Text(
                                                                '• $optName',
                                                                style:
                                                                    const TextStyle(
                                                                      color:
                                                                          kMuted,
                                                                      fontSize:
                                                                          12,
                                                                    ),
                                                              ),
                                                              if (optPrice > 0)
                                                                Text(
                                                                  '+CHF ${optPrice.toStringAsFixed(2)}',
                                                                  style: const TextStyle(
                                                                    color:
                                                                        kMuted,
                                                                    fontSize:
                                                                        11,
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
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: kMuted.withOpacity(0.8), fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: kWhite,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
