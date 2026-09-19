// lib/service/service_board.dart
//
// The board waiters and cashiers work from.
//
// It shows every live order with the Kitchen and Bar progress side by side, so
// service staff can see at a glance what is still being prepared and what is
// ready to carry out. Once an order has been handed to the table they press
// Complete, pick how it was paid, and get the whole order - food and drinks
// together - as a single bill.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:restorant/admin/admin_order.dart' show OrderPrinter;
import 'package:restorant/kitchen/station_orders.dart';
import 'package:restorant/shared/bill_receipt.dart';

/// Order-level status written when service staff close an order out.
const String kOrderCompleted = 'Completed';

/// How the guest paid. Stored on the order as `payment_method`.
class PaymentMethod {
  static const cash = 'Cash';
  static const card = 'Card';
}

/// Where one order stands across both preparation stations.
class OrderServiceState {
  const OrderServiceState({
    required this.hasFood,
    required this.hasDrinks,
    required this.kitchenStatus,
    required this.barStatus,
    required this.completed,
    required this.paymentMethod,
  });

  final bool hasFood;
  final bool hasDrinks;

  /// Empty when the order has nothing for that station.
  final String kitchenStatus;
  final String barStatus;

  final bool completed;
  final String paymentMethod;

  /// A station that has no items for this order can never hold it up.
  bool get kitchenDone => !hasFood || kitchenStatus == StationStatus.ready;
  bool get barDone => !hasDrinks || barStatus == StationStatus.ready;

  /// Everything ordered has been prepared, so it can go to the table.
  bool get readyToServe => kitchenDone && barDone;
}

OrderServiceState serviceStateOf(Map<String, dynamic> data) {
  final hasFood = stationItems(data, OrderStation.kitchen).isNotEmpty;
  final hasDrinks = stationItems(data, OrderStation.bar).isNotEmpty;

  return OrderServiceState(
    hasFood: hasFood,
    hasDrinks: hasDrinks,
    kitchenStatus: hasFood ? stationStatusOf(data, OrderStation.kitchen) : '',
    barStatus: hasDrinks ? stationStatusOf(data, OrderStation.bar) : '',
    completed: (data['status'] ?? '').toString() == kOrderCompleted,
    paymentMethod: (data['payment_method'] ?? '').toString(),
  );
}

class ServiceBoardPage extends StatefulWidget {
  const ServiceBoardPage({super.key});

  @override
  State<ServiceBoardPage> createState() => _ServiceBoardPageState();
}

class _ServiceBoardPageState extends State<ServiceBoardPage> {
  static const _tabReady = 'Ready to serve';
  static const _tabProgress = 'In progress';
  static const _tabCompleted = 'Completed';
  static const _tabs = [_tabReady, _tabProgress, _tabCompleted];

  String _selectedTab = _tabReady;
  Timer? _clockTimer;
  late final Stream<QuerySnapshot> _ordersStream;

  @override
  void initState() {
    super.initState();
    // Created once: rebuilding the stream on every build would drop the
    // subscription and flash the list back to its spinner.
    _ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .orderBy('timestamp', descending: true)
        .limit(60)
        .snapshots();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------- completing

  Future<void> _completeOrder(
    String documentId,
    Map<String, dynamic> data,
  ) async {
    final method = await _askPaymentMethod(data);
    if (method == null || !mounted) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(documentId)
          .set({
            'status': kOrderCompleted,
            'payment_method': method,
            'completed_at': FieldValue.serverTimestamp(),
            'completed_by': user?.uid ?? '',
            'completed_by_name': user?.displayName ?? '',
          }, SetOptions(merge: true));

      if (!mounted) return;
      // Show the finished order as one bill covering both stations.
      await _showBill(documentId, {
        ...data,
        'status': kOrderCompleted,
        'payment_method': method,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not complete the order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _askPaymentMethod(Map<String, dynamic> data) {
    final orderId = (data['order_id'] ?? '').toString();
    // The amount on the bill, so what is collected always matches what the
    // guest is handed.
    final billSum = BillData.fromOrder(data).sum;
    String? selected;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: kStCardBg,
          title: Text(
            'Order #$orderId',
            style: const TextStyle(color: kStWhite),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total to collect: CHF ${BillData.money(billSum)}',
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
                    child: _paymentChoice(
                      label: PaymentMethod.cash,
                      icon: Icons.payments,
                      selected: selected == PaymentMethod.cash,
                      onTap: () =>
                          setDialogState(() => selected = PaymentMethod.cash),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _paymentChoice(
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
              label: const Text('Complete'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentChoice({
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

  // ------------------------------------------------------------------- bill

  /// The bill exactly as it prints: same header, same lines, same sum.
  Future<void> _showBill(String documentId, Map<String, dynamic> data) {
    final bill = BillData.fromOrder(
      data,
      operatorName: FirebaseAuth.instance.currentUser?.displayName,
    );
    final payment = (data['payment_method'] ?? '').toString();

    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kStCardBg,
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _centered(RestaurantInfo.name, size: 16, bold: true),
                _centered(RestaurantInfo.street),
                _centered(RestaurantInfo.city),
                _centered(RestaurantInfo.phone),
                _centered(RestaurantInfo.email),
                _centered(RestaurantInfo.vatId),
                const SizedBox(height: 16),

                Text(bill.title, style: _receiptStyle()),
                const SizedBox(height: 12),
                if (bill.tableLabel.isNotEmpty)
                  Text(bill.tableLabel, style: _receiptStyle()),
                const Divider(color: kStItemBg, height: 18),

                ...bill.lines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(line.label, style: _receiptStyle()),
                        Text(
                          '${BillData.money(line.amount)} CHF',
                          style: _receiptStyle(),
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(color: kStItemBg, height: 18),
                Text(
                  'Summe CHF:     ${bill.sumText}',
                  style: _receiptStyle(size: 16, bold: true),
                ),
                const Divider(color: kStItemBg, height: 18, thickness: 2),
                const SizedBox(height: 6),

                Text('Datum ${bill.dateText}', style: _receiptStyle()),
                Text('Bediener: ${bill.operatorName}', style: _receiptStyle()),
                Text('Kasse: ${RestaurantInfo.till}', style: _receiptStyle()),

                if (payment.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Bezahlt mit $payment',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                ...RestaurantInfo.thankYou.map(
                  (line) => _centered(line, bold: true),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => OrderPrinter.generateAndPrintPdf(
              ctx,
              data,
              false,
              operatorName: bill.operatorName,
            ),
            icon: const Icon(Icons.print, color: kStPrimary, size: 18),
            label: const Text(
              'Rechnung drucken',
              style: TextStyle(color: kStPrimary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kStPrimary,
              foregroundColor: kStWhite,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Schliessen'),
          ),
        ],
      ),
    );
  }

  TextStyle _receiptStyle({double size = 13, bool bold = false}) {
    return TextStyle(
      color: kStWhite,
      fontSize: size,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );
  }

  Widget _centered(String text, {double size = 13, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: _receiptStyle(size: size, bold: bold),
      ),
    );
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kStBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildTabs(),
            Expanded(child: _buildOrders()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kStPrimary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.room_service, color: kStWhite, size: 22),
          ),
          const SizedBox(width: 12),
          const Text(
            'Service',
            style: TextStyle(
              color: kStWhite,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _tabs.map((tab) {
            final isActive = _selectedTab == tab;
            return GestureDetector(
              onTap: () => setState(() => _selectedTab = tab),
              child: Container(
                margin: const EdgeInsets.only(right: 24),
                padding: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isActive ? kStPrimary : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    color: isActive ? kStPrimary : kStMuted,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOrders() {
    return StreamBuilder<QuerySnapshot>(
      stream: _ordersStream,
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

        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if ((data['status'] ?? '') == 'Canceled') return false;
          final state = serviceStateOf(data);
          switch (_selectedTab) {
            case _tabReady:
              return !state.completed && state.readyToServe;
            case _tabProgress:
              return !state.completed && !state.readyToServe;
            default:
              return state.completed;
          }
        }).toList();

        // Waiting orders are worked oldest-first; finished ones read better
        // newest-first.
        if (_selectedTab != _tabCompleted) {
          docs.sort((a, b) {
            final ta =
                (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            final tb =
                (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            if (ta == null || tb == null) return 0;
            return ta.compareTo(tb);
          });
        }

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.room_service, color: kStItemBg, size: 56),
                const SizedBox(height: 12),
                Text(
                  _selectedTab == _tabReady
                      ? 'Nothing is ready to serve right now.'
                      : _selectedTab == _tabProgress
                      ? 'No orders are being prepared.'
                      : 'No completed orders yet.',
                  style: const TextStyle(color: kStMuted, fontSize: 15),
                ),
              ],
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            const cardWidth = 400.0;
            final columns = (constraints.maxWidth / (cardWidth + 16))
                .floor()
                .clamp(1, 3);
            final width = columns == 1 ? constraints.maxWidth - 40 : cardWidth;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: docs
                    .map(
                      (doc) => SizedBox(
                        width: width,
                        child: _buildOrderCard(
                          doc.id,
                          doc.data() as Map<String, dynamic>,
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOrderCard(String documentId, Map<String, dynamic> data) {
    final state = serviceStateOf(data);
    final orderId = (data['order_id'] ?? documentId).toString();
    final table = orderTableLabel(data);
    final method = (data['delivery_method'] ?? '').toString();
    final billSum = BillData.fromOrder(data).sum;
    final Timestamp? ts = data['timestamp'] as Timestamp?;

    final accent = state.completed
        ? kStMuted
        : state.readyToServe
        ? Colors.greenAccent
        : Colors.orangeAccent;

    return Container(
      decoration: BoxDecoration(
        color: kStCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#$orderId',
                  style: const TextStyle(
                    color: kStWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _pill(
                state.completed
                    ? 'Completed'
                    : state.readyToServe
                    ? 'Ready to serve'
                    : 'Preparing',
                accent,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (table.isNotEmpty)
                _infoChip(Icons.table_restaurant, 'Table $table'),
              if (method.isNotEmpty) _infoChip(Icons.dining, method),
              if (ts != null)
                _infoChip(Icons.schedule, _waitingLabel(ts.toDate())),
            ],
          ),
          const Divider(color: kStItemBg, height: 22, thickness: 1.5),

          // Both station statuses, always visible to service staff.
          _stationRow(data, OrderStation.kitchen, state.kitchenStatus),
          const SizedBox(height: 10),
          _stationRow(data, OrderStation.bar, state.barStatus),

          const Divider(color: kStItemBg, height: 22, thickness: 1.5),
          Row(
            children: [
              Text(
                'CHF ${BillData.money(billSum)}',
                style: const TextStyle(
                  color: kStWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (state.completed && state.paymentMethod.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '· ${state.paymentMethod}',
                  style: const TextStyle(color: Colors.greenAccent),
                ),
              ],
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showBill(documentId, data),
                icon: const Icon(Icons.receipt_long, size: 18),
                label: const Text('Bill'),
                style: TextButton.styleFrom(foregroundColor: kStPrimary),
              ),
              const SizedBox(width: 4),
              if (!state.completed)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: state.readyToServe
                        ? Colors.green
                        : kStItemBg,
                    foregroundColor: state.readyToServe ? kStWhite : kStMuted,
                  ),
                  // Only servable once both stations are done with it.
                  onPressed: state.readyToServe
                      ? () => _completeOrder(documentId, data)
                      : null,
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Complete'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// One station's line: its status plus exactly what it is making, so service
  /// staff can see the whole order without opening anything.
  Widget _stationRow(
    Map<String, dynamic> data,
    OrderStation station,
    String status,
  ) {
    final stationLines = stationItems(data, station);
    final hasItems = stationLines.isNotEmpty;
    final items = stationLines.map((item) {
      final qty = ((item['qty'] as num?) ?? 1).toInt();
      final name = (item['name'] ?? 'Item').toString();
      final size = (item['size'] ?? '').toString();
      return '${qty}x ${size.isEmpty ? name : '$name ($size)'}';
    }).toList();
    final color = !hasItems
        ? kStMuted
        : status == StationStatus.ready
        ? Colors.greenAccent
        : status == StationStatus.preparing
        ? Colors.orangeAccent
        : station.accent;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(station.icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    station.title,
                    style: const TextStyle(
                      color: kStWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasItems ? status : 'nothing ordered',
                    style: TextStyle(color: color, fontSize: 13),
                  ),
                ],
              ),
              if (items.isNotEmpty)
                Text(
                  items.join(', '),
                  style: const TextStyle(color: kStMuted, fontSize: 12),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: kStItemBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: kStMuted),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: kStWhite, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _waitingLabel(DateTime placed) {
    final minutes = DateTime.now().difference(placed).inMinutes;
    if (minutes < 1) return 'just now';
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    return '${hours}h ${minutes % 60}m';
  }
}
