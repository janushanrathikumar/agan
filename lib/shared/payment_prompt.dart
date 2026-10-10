// lib/shared/payment_prompt.dart
//
// Asking how the guest paid, in one place.
//
// The Service board asks when an order is completed, the combine screen asks
// when several orders are paid as one bill, and printing a bill asks when the
// order was closed without anyone recording a payment. All three use the same
// dialog, so the wording and the amount shown can never drift apart.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:restorant/kitchen/station_orders.dart'
    show kStCardBg, kStItemBg, kStMuted, kStPrimary, kStWhite;
import 'package:restorant/shared/bill_receipt.dart';

/// How the guest paid. Stored on the order as `payment_method`.
class PaymentMethod {
  static const cash = 'Cash';
  static const card = 'Card';
}

/// Whether a payment has already been recorded for [order].
bool hasPaymentMethod(Map<String, dynamic> order) =>
    (order['payment_method'] ?? '').toString().trim().isNotEmpty;

/// Asks Cash or Card, and returns null if the staff member backed out.
///
/// [breakdown] is shown above the total, which is what lets a bill covering
/// several tables show what each of them came to.
Future<String?> askPaymentMethod(
  BuildContext context, {
  required String title,
  required double total,
  List<BillSection> breakdown = const [],
  String confirmLabel = 'Complete',
}) {
  String? selected;

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: kStCardBg,
        title: Text(title, style: const TextStyle(color: kStWhite)),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (breakdown.length > 1) ...[
                  for (final section in breakdown)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              section.label,
                              style: const TextStyle(color: kStMuted),
                            ),
                          ),
                          Text(
                            'CHF ${BillData.money(section.subtotal)}',
                            style: const TextStyle(color: kStWhite),
                          ),
                        ],
                      ),
                    ),
                  const Divider(color: kStItemBg, height: 20),
                ],
                Text(
                  'Total to collect: CHF ${BillData.money(total)}',
                  style: const TextStyle(
                    color: kStPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'How did the guest pay?',
                  style: TextStyle(color: kStMuted),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _choice(
                        label: PaymentMethod.cash,
                        icon: Icons.payments,
                        selected: selected == PaymentMethod.cash,
                        onTap: () =>
                            setDialogState(() => selected = PaymentMethod.cash),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _choice(
                        label: PaymentMethod.card,
                        icon: Icons.credit_card,
                        selected: selected == PaymentMethod.card,
                        onTap: () =>
                            setDialogState(() => selected = PaymentMethod.card),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: kStMuted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: kStWhite,
            ),
            // Stays disabled until a payment method is chosen.
            onPressed: selected == null
                ? null
                : () => Navigator.pop(ctx, selected),
            icon: const Icon(Icons.check, size: 18),
            label: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );
}

Widget _choice({
  required String label,
  required IconData icon,
  required bool selected,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: selected ? kStPrimary.withOpacity(0.18) : kStItemBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? kStPrimary : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: selected ? kStPrimary : kStMuted, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: selected ? kStPrimary : kStWhite,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Makes sure a bill about to be printed says how it was paid.
///
/// An order closed without anyone recording a payment - completed from the
/// admin edit page, say - is asked about once, here, and the answer is stored
/// on the order so the next print goes straight to the printer. An order that
/// already carries a payment method is returned untouched.
///
/// Returns the order to print, or null if the staff member backed out.
Future<Map<String, dynamic>?> ensurePaymentRecorded(
  BuildContext context, {
  required String documentId,
  required Map<String, dynamic> order,
  required bool isCompleted,
}) async {
  if (hasPaymentMethod(order) || !isCompleted) return order;

  final method = await askPaymentMethod(
    context,
    title: 'Order #${order['order_id'] ?? documentId}',
    total: BillData.fromOrder(order).sum,
    confirmLabel: 'Save & print',
  );
  if (method == null) return null;

  await FirebaseFirestore.instance.collection('orders').doc(documentId).set({
    'payment_method': method,
  }, SetOptions(merge: true));

  return {...order, 'payment_method': method};
}
