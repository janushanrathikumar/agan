// lib/service/combine_bills_page.dart
//
// Paying several orders as one bill.
//
// Guests often order chair by chair and then one of them pays for the whole
// table - or for two or three tables at once. This screen lists every open
// order grouped by table: tick a whole table or single orders, watch the
// running total, print an interim bill to show the guest, then take a single
// payment for all of them. The admin order list and the waiter/cashier Service
// board both open it.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:restorant/admin/admin_order.dart' show OrderPrinter;
import 'package:restorant/kitchen/station_orders.dart';
import 'package:restorant/shared/bill_groups.dart';
import 'package:restorant/shared/bill_receipt.dart';
import 'package:restorant/shared/payment_prompt.dart';

class CombineBillsPage extends StatefulWidget {
  const CombineBillsPage({super.key, this.initialTable});

  /// When set, every open order of this table starts out selected.
  final String? initialTable;

  @override
  State<CombineBillsPage> createState() => _CombineBillsPageState();
}

/// One open order, with the amount it adds to a bill.
class _OpenOrder {
  _OpenOrder(this.docId, this.data) : amount = BillData.fromOrder(data).sum;

  final String docId;
  final Map<String, dynamic> data;

  /// What this order contributes to a bill - the same figure the bill prints,
  /// so the running total can never differ from the paper.
  final double amount;

  String get number => (data['order_id'] ?? docId).toString();
  String get table => (data['table_no'] ?? '').toString().trim();
  String get chair => (data['chair_no'] ?? '').toString().trim();

  /// Groups take-away orders together.
  String get tableKey => (table.isEmpty || table == 'N/A') ? '' : table;

  DateTime get placedAt =>
      (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime(2000);

  String get itemSummary {
    final items = data['items'] as List<dynamic>? ?? [];
    return items
        .whereType<Map>()
        .map((i) => '${i['qty'] ?? 1}x ${i['name'] ?? ''}')
        .join(', ');
  }
}

class _CombineBillsPageState extends State<CombineBillsPage> {
  // Recent orders only: an unpaid order is always a recent one, and this keeps
  // the stream small.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      FirebaseFirestore.instance
          .collection('orders')
          .orderBy('timestamp', descending: true)
          .limit(200)
          .snapshots();

  final Set<String> _selected = <String>{};
  bool _appliedInitialTable = false;
  bool _busy = false;

  String? get _operatorName => FirebaseAuth.instance.currentUser?.displayName;

  // ------------------------------------------------------------- selection

  void _toggleOrder(String docId) => setState(() {
    _selected.contains(docId) ? _selected.remove(docId) : _selected.add(docId);
  });

  void _toggleTable(List<_OpenOrder> orders) => setState(() {
    final allOn = orders.every((o) => _selected.contains(o.docId));
    for (final o in orders) {
      allOn ? _selected.remove(o.docId) : _selected.add(o.docId);
    }
  });

  // --------------------------------------------------------------- actions

  Future<void> _printInterim(List<_OpenOrder> chosen) async {
    final bill = BillData.fromOrders(
      [for (final o in chosen) o.data],
      operatorName: _operatorName,
    );
    await OrderPrinter.printBill(context, bill);
  }

  Future<void> _pay(List<_OpenOrder> chosen) async {
    final bill = BillData.fromOrders(
      [for (final o in chosen) o.data],
      operatorName: _operatorName,
    );
    final method = await askPaymentMethod(
      context,
      title: 'Pay ${bill.orderIds.length} orders together',
      total: bill.sum,
      breakdown: bill.sections,
    );
    if (method == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await BillGroups.payTogether(
        orderDocIds: [for (final o in chosen) o.docId],
        method: method,
      );
    } on BillConflictException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('${e.message} Nothing was charged - please check the selection.',
          Colors.redAccent);
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Could not take the payment: $e', Colors.redAccent);
      return;
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _selected.clear();
    });
    await _showPaid(bill, method);
  }

  void _snack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // ---------------------------------------------------------------- dialogs

  Future<void> _showPaid(BillData bill, String method) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kStCardBg,
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.greenAccent),
            SizedBox(width: 10),
            Text('Paid', style: TextStyle(color: kStWhite)),
          ],
        ),
        content: Text(
          'CHF ${bill.sumText} by $method\n'
          '${bill.orderIds.length} orders: ${bill.orderId}',
          style: const TextStyle(color: kStMuted, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done', style: TextStyle(color: kStMuted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kStPrimary,
              foregroundColor: kStWhite,
            ),
            onPressed: () => OrderPrinter.printBill(ctx, bill),
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Print bill'),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kStBg,
      appBar: AppBar(
        backgroundColor: kStBg,
        foregroundColor: kStWhite,
        elevation: 0,
        title: const Text('Combine bills'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kStPrimary),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final open = [
            for (final doc in snapshot.data?.docs ?? const [])
              if (BillGroups.isOpen(doc.data())) _OpenOrder(doc.id, doc.data()),
          ]..sort((a, b) => a.placedAt.compareTo(b.placedAt));

          // An order paid on another till meanwhile simply drops out.
          final openIds = {for (final o in open) o.docId};
          _selected.retainWhere(openIds.contains);

          // Insertion-ordered: tables appear in the order they were seated.
          final tables = <String, List<_OpenOrder>>{};
          for (final o in open) {
            tables.putIfAbsent(o.tableKey, () => []).add(o);
          }

          final initial = widget.initialTable?.trim();
          if (!_appliedInitialTable && initial != null && initial.isNotEmpty) {
            _appliedInitialTable = true;
            for (final o in tables[initial] ?? const <_OpenOrder>[]) {
              _selected.add(o.docId);
            }
          }

          if (open.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No open orders. Every order has been paid.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kStMuted, fontSize: 16),
                ),
              ),
            );
          }

          final chosen = [for (final o in open) if (_selected.contains(o.docId)) o];

          return Column(
            // Stretched, so the total and the pay buttons span the full width
            // rather than sitting in a narrow box.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12, left: 4),
                      child: Text(
                        'Tick a whole table, or single orders, to put them on '
                        'one bill.',
                        style: TextStyle(color: kStMuted),
                      ),
                    ),
                    for (final entry in tables.entries)
                      _tableCard(entry.key, entry.value),
                  ],
                ),
              ),
              _bottomBar(chosen),
            ],
          );
        },
      ),
    );
  }

  Widget _tableCard(String tableKey, List<_OpenOrder> orders) {
    final selectedCount = orders.where((o) => _selected.contains(o.docId)).length;
    final checkbox = selectedCount == 0
        ? false
        : selectedCount == orders.length
        ? true
        : null;
    final total = orders.fold(0.0, (sum, o) => sum + o.amount);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kStCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selectedCount > 0 ? kStPrimary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: _busy ? null : () => _toggleTable(orders),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 16, 6),
              child: Row(
                children: [
                  Checkbox(
                    tristate: true,
                    value: checkbox,
                    activeColor: kStPrimary,
                    onChanged: _busy ? null : (_) => _toggleTable(orders),
                  ),
                  Icon(
                    tableKey.isEmpty
                        ? Icons.shopping_bag_outlined
                        : Icons.table_restaurant,
                    color: kStPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tableKey.isEmpty ? 'Take Away' : 'Table $tableKey',
                      style: const TextStyle(
                        color: kStWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${orders.length} order${orders.length == 1 ? '' : 's'} · '
                    'CHF ${BillData.money(total)}',
                    style: const TextStyle(color: kStMuted),
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: kStItemBg, height: 1),
          for (final o in orders) _orderRow(o),
        ],
      ),
    );
  }

  Widget _orderRow(_OpenOrder o) {
    final t = o.placedAt;
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: _busy ? null : () => _toggleOrder(o.docId),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 2, 16, 2),
        child: Row(
          children: [
            Checkbox(
              value: _selected.contains(o.docId),
              activeColor: kStPrimary,
              onChanged: _busy ? null : (_) => _toggleOrder(o.docId),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${o.number}'
                    '${o.chair.isEmpty ? '' : ' · Chair ${o.chair}'} · $time',
                    style: const TextStyle(
                      color: kStWhite,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    o.itemSummary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kStMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              'CHF ${BillData.money(o.amount)}',
              style: const TextStyle(color: kStWhite),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(List<_OpenOrder> chosen) {
    final tableCount = {for (final o in chosen) o.tableKey}.length;
    final total = chosen.fold(0.0, (sum, o) => sum + o.amount);

    return Material(
      color: kStCardBg,
      elevation: 12,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: chosen.isEmpty
              ? const Text(
                  'Nothing selected yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kStMuted),
                )
              : Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 10,
                  spacing: 16,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${chosen.length} order${chosen.length == 1 ? '' : 's'}'
                          ' · $tableCount table${tableCount == 1 ? '' : 's'}',
                          style: const TextStyle(color: kStMuted),
                        ),
                        Text(
                          'CHF ${BillData.money(total)}',
                          style: const TextStyle(
                            color: kStPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kStWhite,
                            side: const BorderSide(color: kStMuted),
                          ),
                          onPressed: _busy ? null : () => _printInterim(chosen),
                          icon: const Icon(Icons.receipt_long, size: 18),
                          label: const Text('Interim bill'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: kStWhite,
                          ),
                          onPressed: _busy ? null : () => _pay(chosen),
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: kStWhite,
                                  ),
                                )
                              : const Icon(Icons.point_of_sale, size: 18),
                          label: const Text('Pay together'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
