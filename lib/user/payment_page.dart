import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart'; // 🟢 Secondary App-க்கு தேவை

// Web Image CORS error avoidance imports
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

// --- Palette ---
const kPrimary = Color(0xFFA26334);
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

  // 🟢 2 டேட்டாபேஸ்களிலும் ஆர்டரை சேமிக்கும் லாஜிக்
  Future<void> _submitOrder(
    double total,
    Map<String, dynamic> delivery,
    List<QueryDocumentSnapshot> cartDocs,
  ) async {
    setState(() => _isSubmitting = true);

    // Default Firestore (உங்கள் தற்போதைய ஆப்)
    final firestore1 = FirebaseFirestore.instance;

    // Secondary Firestore (ez8testdb) - main.dart-ல் 'SecondaryDb' என பெயர் வைத்துள்ளோம்
    final secondaryApp = Firebase.app('SecondaryDb');
    final firestore2 = FirebaseFirestore.instanceFor(app: secondaryApp);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      // --- 1. தற்போதைய ஆப்க்கான டேட்டாவைத் தயாரித்தல் ---
      final itemsList1 = cartDocs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();

      final orderRef1 = firestore1.collection('orders').doc();
      final orderData1 = {
        'order_id': orderRef1.id,
        'uid': user.uid,
        'delivery_method': delivery['delivery_method'] ?? 'Take_Away',
        'table_no': delivery['table_no'] ?? 'N/A',
        'status': 'New',
        'total': total,
        'items': itemsList1,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // --- 2. ez8testdb BillOrder ஸ்ட்ரக்சருக்கான டேட்டாவைத் தயாரித்தல் ---

      // AJ0001 போன்ற Custom ID-ஐ உருவாக்குதல் (உதாரணத்திற்கு டைம்ஸ்டாம்ப் பயன்படுத்தப்பட்டுள்ளது)
      String customId =
          'AJ${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      final List<Map<String, dynamic>> cartItemsForDb2 = cartDocs.map((d) {
        final m = d.data() as Map<String, dynamic>;
        return {
          'comment': m['note'] ?? '',
          'dishName': m['name'] ?? '',
          'hotelId': 'AGAN_RESTAURANT', // உங்கள் கடையின் ID-ஐ மாற்றிக்கொள்ளலாம்
          'options': [], // தேவைப்பட்டால் ஆப்ஷன்களைச் சேர்க்கலாம்
          'price': (m['price'] as num?)?.toDouble() ?? 0.0,
          'quantity': (m['qty'] as num?)?.toInt() ?? 1,
          'userId': user.uid,
        };
      }).toList();

      final orderRef2 = firestore2.collection('BillOrder').doc(customId);
      final orderData2 = {
        'cartItems': cartItemsForDb2,
        'hotelId': 'jKuRDFBYEfDUzLdROtoM',
        'hotelName': 'Agan Restaurant',
        'paymentMethod': 'cash',
        'status': 'New',
        'timestamp': FieldValue.serverTimestamp(),
        'total': total,
        'userId': user.uid,
      };

      // Shipping Address இருந்தால் சேர்ப்பது
      if (delivery['delivery_method'] != 'Take_Away') {
        orderData2['shippingAddress'] = {
          'address': delivery['address'] ?? '',
          'name': user.displayName ?? 'Customer',
          'mobile': delivery['phone'] ?? '',
          'country': 'Germany',
        };
      }

      // --- 3. இரண்டு டேட்டாபேஸிலும் ஒரே நேரத்தில் டேட்டாவை சேமித்தல் ---
      await Future.wait([
        orderRef1.set(orderData1), // Default DB-ல் சேமிக்கிறது
        orderRef2.set(orderData2), // ez8testdb-ல் சேமிக்கிறது
      ]);

      // --- 4. கார்ட்டை (Cart) க்ளியர் செய்தல் ---
      final batch = firestore1.batch();
      for (final doc in cartDocs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // --- 5. வெற்றிகரமான மெசேஜ் காட்டுதல் ---
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order Confirmed! ID: $customId'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Delivery Details Card
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
                                  'Dining Details',
                                  style: TextStyle(
                                    color: kPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _infoRow(Icons.dining, 'Method', method),
                                const SizedBox(height: 8),
                                _infoRow(
                                  Icons.table_restaurant,
                                  'Table No',
                                  tableNo,
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
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
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
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          Text(
                                            '${qty}x RM ${price.toStringAsFixed(2)}',
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
                                          'RM ${(price * qty).toStringAsFixed(2)}',
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
                                          constraints: const BoxConstraints(),
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
                              "RM ${total.toStringAsFixed(2)}",
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
}
