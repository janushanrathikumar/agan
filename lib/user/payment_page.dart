// lib/user/payment_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

// Web Image CORS error avoidance imports
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

// --- Palette ---
const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);

// 🟢 Web-Safe Image Widget
class _WebSafeImage extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final Widget fallback;

  const _WebSafeImage({
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) return fallback;

    if (kIsWeb) {
      final String viewId =
          'checkout-img-${imageUrl.hashCode}_${DateTime.now().microsecondsSinceEpoch}';

      ui_web.platformViewRegistry.registerViewFactory(
        viewId,
        (int viewId) => html.ImageElement()
          ..src = imageUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'cover'
          ..style.borderRadius = '8px',
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

class PaymentPage extends StatefulWidget {
  final String uid;
  const PaymentPage({super.key, required this.uid});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool _isSubmitting = false;

  Future<void> _submitOrder(
    double total,
    Map<String, dynamic> deliveryData,
    List<QueryDocumentSnapshot> cartDocs,
  ) async {
    setState(() => _isSubmitting = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isSubmitting = false);
      return;
    }

    final firestore1 = FirebaseFirestore.instance;
    late FirebaseFirestore firestore2;
    try {
      final secondaryApp = Firebase.app('SecondaryDb');
      firestore2 = FirebaseFirestore.instanceFor(app: secondaryApp);
    } catch (e) {
      firestore2 = firestore1;
    }

    try {
      // 🟢 GET USERNAME FROM AUTH FIRST LIKE APP_BAR
      String fallbackName = (user.displayName?.trim().isNotEmpty ?? false)
          ? user.displayName!.trim()
          : (user.email?.split('@').first ?? 'Guest');

      String username = fallbackName;
      String role = 'Customer';

      try {
        final userDoc = await firestore1
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>?;
          username = userData?['username'] ?? userData?['name'] ?? fallbackName;
          role = userData?['role'] ?? role;
        }
      } catch (e) {
        debugPrint('Failed to fetch user role/username: $e');
      }

      // 1. Generate Custom ID
      final counterRef = firestore1.collection('AppConfig').doc('OrderCounter');
      int nextIdNumber = 10000;
      await firestore1.runTransaction((transaction) async {
        final counterSnap = await transaction.get(counterRef);
        if (counterSnap.exists && counterSnap.data()!.containsKey('lastId')) {
          nextIdNumber = (counterSnap.data()!['lastId'] as int) + 1;
        }
        transaction.set(counterRef, {
          'lastId': nextIdNumber,
        }, SetOptions(merge: true));
      });

      String customOrderId = 'A$nextIdNumber';

      // 2. Prepare items list
      final itemsList = cartDocs.map((d) {
        final m = d.data() as Map<String, dynamic>;
        final kind = (m['kind'] as String?) ?? 'food';

        final itemMap = <String, dynamic>{
          'name': m['name'] ?? 'Item',
          'price': (m['price'] as num?)?.toDouble() ?? 0.0,
          'qty': (m['qty'] as num?)?.toInt() ?? 1,
          'kind': kind,
          'imageUrl': m['imageUrl'] ?? '',
          'category': m['category'] ?? '',
          'note': m['note'] ?? '',
          'extraNote': m['extraNote'],
          'additionalOptions': m['additionalOptions'] ?? [],
          'menuChoices': m['menuChoices'] ?? {},
          'timestamp': (m['createdAt'] is Timestamp)
              ? m['createdAt']
              : Timestamp.now(),
        };

        if (kind == 'drink') {
          itemMap['type'] = m['type'] ?? '';
          itemMap['sugar'] = m['sugar'] ?? '';
        }

        return itemMap;
      }).toList();

      // 3. Prepare Secondary DB structure (BillOrder)
      final String orderDeliveryMethod =
          (deliveryData['delivery_method'] as String?) ?? 'Take_Away';
      final double serviceChargeRate = orderDeliveryMethod == 'Take_Away'
          ? 0.026
          : 0.081;

      double subTotal = total;
      double deliveryFee = 0.0;
      double serviceCharge = subTotal * serviceChargeRate;
      double finalTotal = subTotal + deliveryFee + serviceCharge;

      final List<Map<String, dynamic>> cartItemsForDb2 = itemsList.map((m) {
        return {
          'dishName': m['name'],
          'price': m['price'],
          'quantity': m['qty'],
          'comment': m['note'],
          'hotelId': 'jKuRDFBYEfDUzLdROtoM',
          'userId': user.uid,
          'options': m['additionalOptions'],
        };
      }).toList();

      final orderData2 = {
        'orderId': customOrderId,
        'cartItems': cartItemsForDb2,
        'hotelId': 'jKuRDFBYEfDUzLdROtoM',
        'hotelName': 'KoreanKitchen',
        'paymentMethod': 'cash',
        'status': 'pending',
        'subTotal': subTotal,
        'deliveryFee': deliveryFee,
        'serviceCharge': serviceCharge,
        'serviceChargeRate': serviceChargeRate,
        'total': finalTotal,
        'userId': user.uid,
        'username': username,
        'role': role,
        'table_no': (deliveryData['table_no'] ?? '').toString(),
        'chair_no': (deliveryData['chair_no'] ?? '')
            .toString(), // 🟢 Dedicated chair_no field added to Secondary DB
        'timestamp': FieldValue.serverTimestamp(),
        'Accept_time': FieldValue.serverTimestamp(),
        'delivery_time': DateTime.now().add(const Duration(minutes: 60)),
        'liftOption': 'no_floors_lift_in',
        'additionalLiftCharge': 0,
        'shippingAddress': {
          'address':
              deliveryData['address'] ?? deliveryData['table_no'] ?? 'N/A',
          'name': username,
          'role': role,
          'mobile': deliveryData['phone'] ?? '000000',
          'country': 'Switzerland',
        },
      };

      // 4. Save to databases
      await Future.wait([
        firestore1.collection('orders').doc(customOrderId).set({
          'order_id': customOrderId,
          'uid': user.uid,
          'username': username,
          'role': role,
          'subtotal': subTotal,
          'service_charge': serviceCharge,
          'service_charge_rate': serviceChargeRate,
          'total': finalTotal,
          'items': itemsList,
          'status': 'New',
          'delivery_method': deliveryData['delivery_method'] ?? 'Take_Away',
          'table_no': (deliveryData['table_no'] ?? '').toString(),
          'chair_no': (deliveryData['chair_no'] ?? '')
              .toString(), // 🟢 Dedicated chair_no field added to Primary DB
          'timestamp': FieldValue.serverTimestamp(),
        }),
        firestore2.collection('BillOrder').doc(customOrderId).set(orderData2),
      ]);

      // 5. Cleanup
      final batch = firestore1.batch();
      for (final doc in cartDocs) batch.delete(doc.reference);
      batch.delete(firestore1.collection('food_delivery').doc(user.uid));
      await batch.commit();

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF383735),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.greenAccent,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Order Placed Successfully!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Order #$customOrderId',
                  style: const TextStyle(
                    color: kPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'User: $username ($role)',
                  style: const TextStyle(color: kMuted, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total: CHF ${finalTotal.toStringAsFixed(2)}',
                  style: const TextStyle(color: kMuted, fontSize: 14),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: kWhite,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );

        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deliveryRef = FirebaseFirestore.instance
        .collection('food_delivery')
        .doc(widget.uid);
    final itemsRef = FirebaseFirestore.instance
        .collection('chat')
        .doc(widget.uid)
        .collection('items');
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kWhite,
        title: const Text(
          'Order Summary',
          style: TextStyle(
            color: kWhite,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: userRef.get(),
        builder: (context, userSnap) {
          final currentUser = FirebaseAuth.instance.currentUser;
          String fallbackName = 'Guest';
          if (currentUser != null) {
            fallbackName = (currentUser.displayName?.trim().isNotEmpty ?? false)
                ? currentUser.displayName!.trim()
                : (currentUser.email?.split('@').first ?? 'Guest');
          }

          String username = fallbackName;
          String role = 'Customer';

          if (userSnap.hasData && userSnap.data!.exists) {
            final userData = userSnap.data!.data() as Map<String, dynamic>?;
            username =
                userData?['username'] ?? userData?['name'] ?? fallbackName;
            role = userData?['role'] ?? 'Customer';
          }

          return FutureBuilder<DocumentSnapshot>(
            future: deliveryRef.get(),
            builder: (context, deliverySnap) {
              if (deliverySnap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: kPrimary),
                );
              }

              final delivery =
                  (deliverySnap.data?.data() as Map<String, dynamic>?) ?? {};
              final method = delivery['delivery_method'] ?? 'Take_Away';
              final tableNo = delivery['table_no'] ?? 'N/A';
              final chairNo = delivery['chair_no'] ?? '';

              // 🟢 Format display table for UI (e.g. "T5 (Chair 2)")
              final displayTable = chairNo.toString().isNotEmpty
                  ? '$tableNo (Chair $chairNo)'
                  : tableNo.toString();

              return StreamBuilder<QuerySnapshot>(
                stream: itemsRef.snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: kPrimary),
                    );
                  }

                  final docs = snap.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No items found in cart',
                        style: TextStyle(color: kMuted, fontSize: 16),
                      ),
                    );
                  }

                  double total = 0;
                  for (final d in docs) {
                    final m = (d.data() as Map<String, dynamic>? ?? {});
                    final p = (m['price'] as num?)?.toDouble() ?? 0;
                    final q = (m['qty'] as num?)?.toInt() ?? 1;
                    total += p * q;
                  }

                  final double serviceChargeRatePreview = method == 'Take_Away'
                      ? 0.026
                      : 0.081;
                  final double serviceChargePreview =
                      total * serviceChargeRatePreview;
                  final double grandTotalPreview = total + serviceChargePreview;

                  return Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Customer & Dining Details Card
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF383735),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Customer & Dining Details',
                                      style: TextStyle(
                                        color: kPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _infoRow(
                                      Icons.person,
                                      'Username',
                                      username,
                                    ),
                                    const SizedBox(height: 8),
                                    _infoRow(
                                      Icons.admin_panel_settings,
                                      'Role',
                                      role,
                                    ),
                                    const SizedBox(height: 8),
                                    _infoRow(Icons.dining, 'Method', method),
                                    const SizedBox(height: 8),
                                    _infoRow(
                                      Icons.table_restaurant,
                                      'Table No',
                                      displayTable,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              const Text(
                                'Your Items',
                                style: TextStyle(
                                  color: kWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Item List with Delete Button
                              ListView.separated(
                                itemCount: docs.length,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (_, i) {
                                  final doc = docs[i];
                                  final m =
                                      doc.data() as Map<String, dynamic>? ?? {};
                                  final name = m['name'] ?? '';
                                  final price =
                                      (m['price'] as num?)?.toDouble() ?? 0;
                                  final qty = (m['qty'] as num?)?.toInt() ?? 1;
                                  final imageUrl = m['imageUrl'] ?? '';
                                  final note = m['note'] ?? '';

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2F2E2D),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: _WebSafeImage(
                                            imageUrl: imageUrl,
                                            width: 60,
                                            height: 60,
                                            fallback: Container(
                                              width: 60,
                                              height: 60,
                                              color: const Color(0xFF3A3938),
                                              child: const Icon(
                                                Icons.image,
                                                color: kMuted,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                  color: kWhite,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              if (note.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  note,
                                                  style: const TextStyle(
                                                    color: kMuted,
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                              const SizedBox(height: 8),
                                              Text(
                                                '${qty}x CHF ${price.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  color: kMuted,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'CHF ${(price * qty).toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: kWhite,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.redAccent,
                                                size: 22,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              onPressed: () {
                                                itemsRef.doc(doc.id).delete();
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 20),

                              // Charges breakdown card
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF383735),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _chargeRow('Subtotal', total),
                                    const SizedBox(height: 6),
                                    _chargeRow(
                                      'Service Charge (${_methodLabel(method)} • ${(serviceChargeRatePreview * 100).toStringAsFixed(1)}%)',
                                      serviceChargePreview,
                                    ),
                                    const Divider(
                                      color: kMuted,
                                      height: 20,
                                      thickness: 0.2,
                                    ),
                                    _chargeRow(
                                      'Grand Total',
                                      grandTotalPreview,
                                      isBold: true,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Sticky Bottom Footer
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Color(0xFF242322),
                          border: Border(
                            top: BorderSide(color: kMuted, width: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  "Total Payment",
                                  style: TextStyle(color: kMuted, fontSize: 13),
                                ),
                                Text(
                                  "CHF ${grandTotalPreview.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    color: kWhite,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _isSubmitting
                                  ? null
                                  : () => _submitOrder(total, delivery, docs),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: kWhite,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      "Confirm Order",
                                      style: TextStyle(
                                        color: kWhite,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: kMuted, size: 18),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: kMuted, fontSize: 14)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: kWhite,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  String _methodLabel(String method) {
    return method == 'Take_Away' ? 'Take-Away' : 'Dine-In';
  }

  Widget _chargeRow(String label, num value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isBold ? kWhite : kMuted,
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          'CHF ${value.toStringAsFixed(2)}',
          style: TextStyle(
            color: isBold ? kPrimary : kWhite,
            fontSize: isBold ? 18 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
