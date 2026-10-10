// lib/shared/bill_groups.dart
//
// Paying several orders as one bill: everyone at a table, or two or three
// tables settled by one guest.
//
// Every order on a combined bill carries the same `bill_id`. There is no
// separate bill document holding a total - the bill is always rebuilt from the
// orders themselves (see BillData.forOrder), so an order edited afterwards can
// never disagree with a stored amount.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:restorant/service/service_board.dart' show kOrderCompleted;

/// Someone else paid or changed one of the orders first.
class BillConflictException implements Exception {
  const BillConflictException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BillGroups {
  BillGroups._();

  static CollectionReference<Map<String, dynamic>> get _orders =>
      FirebaseFirestore.instance.collection('orders');

  /// Whether an order can still go on a bill: not paid, not cancelled and not
  /// already part of another bill. The Service board uses the same rule for
  /// what is still open.
  static bool isOpen(Map<String, dynamic> order) {
    final status = (order['status'] ?? '').toString();
    if (status == kOrderCompleted || status == 'Canceled') return false;
    if ((order['payment_method'] ?? '').toString().isNotEmpty) return false;
    if ((order['bill_id'] ?? '').toString().isNotEmpty) return false;
    return true;
  }

  /// Pays [orderDocIds] as one bill with [method] (Cash or Card), and returns
  /// the new bill's id.
  ///
  /// One transaction: every order is read again and checked to still be open
  /// before any of them is written. Two tills combining overlapping orders at
  /// the same moment therefore cannot both take the money - the second one is
  /// refused with a [BillConflictException] and nothing it selected changes.
  static Future<String> payTogether({
    required List<String> orderDocIds,
    required String method,
  }) async {
    if (orderDocIds.isEmpty) {
      throw const BillConflictException('No orders selected.');
    }

    final billId = _orders.doc().id;
    final user = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance.runTransaction((tx) async {
      // Firestore requires every read before the first write.
      final snaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final id in orderDocIds) {
        snaps.add(await tx.get(_orders.doc(id)));
      }

      for (final snap in snaps) {
        final data = snap.data();
        if (data == null) {
          throw const BillConflictException(
            'One of the orders was deleted meanwhile.',
          );
        }
        if (!isOpen(data)) {
          throw BillConflictException(
            'Order #${data['order_id'] ?? snap.id} has already been paid.',
          );
        }
      }

      for (final snap in snaps) {
        tx.set(snap.reference, {
          'status': kOrderCompleted,
          // Kept so a combination made by mistake can be undone.
          'status_before_bill': (snap.data()!['status'] ?? 'New').toString(),
          'payment_method': method,
          'completed_at': FieldValue.serverTimestamp(),
          'completed_by': user?.uid ?? '',
          'completed_by_name': user?.displayName ?? '',
          'bill_id': billId,
        }, SetOptions(merge: true));
      }
    });

    return billId;
  }

  /// Splits a combined bill back into separate, unpaid orders, each with the
  /// status it had before. Returns how many orders were released.
  ///
  /// Combining is paying, so this also removes the recorded payment: the
  /// orders can then be paid again, together or on their own.
  static Future<int> undo(String billId) async {
    final members = await _orders.where('bill_id', isEqualTo: billId).get();
    if (members.docs.isEmpty) return 0;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in members.docs) {
      batch.update(doc.reference, {
        'status': (doc.data()['status_before_bill'] ?? 'New').toString(),
        'payment_method': FieldValue.delete(),
        'completed_at': FieldValue.delete(),
        'completed_by': FieldValue.delete(),
        'completed_by_name': FieldValue.delete(),
        'bill_id': FieldValue.delete(),
        'status_before_bill': FieldValue.delete(),
      });
    }
    await batch.commit();
    return members.docs.length;
  }
}
