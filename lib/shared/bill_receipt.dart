// lib/shared/bill_receipt.dart
//
// The one definition of what a bill looks like, shared by the printed receipt
// and the on-screen bill, so the two can never drift apart.
//
// The layout mirrors the till receipt the restaurant already hands out:
//
//     Restaurantkleefeld
//     Mädergutstrasse 5
//        3018 Bern
//      031 556 82 88
//   restaurantkleefeld@gmx.ch
//     CHE-385.703.146
//
//   Zwischenrechnung
//
//   Tisch: 1
//   ------------------------------
//     1 x Coca Cola 33cl
//     4,20 CHF
//   ------------------------------
//   Summe CHF:     63,60
//
//   Datum 07.09.2026 23:58:13
//   Bediener: admin
//   Kasse: 1
//
//   Vielen Dank für Ihren Einkauf!
//
// Amounts use the Swiss/German comma decimal ("4,20 CHF") and the total is the
// plain sum of the lines - no service charge is added on the bill.
//
// Several orders can be paid as one bill - everyone at a table, or two or three
// tables together. Such a bill keeps one section per table, each with its own
// subtotal, so the guest paying can still see who had what:
//
//   Tisch: 3 / 9, 10
//     2 x Rivella            8,40 CHF
//   Zwischensumme CHF:       8,40
//   ------------------------------
//   Tisch: 4
//     ...
//   Summe CHF:              31,10
import 'package:cloud_firestore/cloud_firestore.dart';

/// Printed at the top of every bill. Change it here and both the paper receipt
/// and the on-screen bill follow.
class RestaurantInfo {
  static const name = 'Restaurantkleefeld';
  static const street = 'Mädergutstrasse 5';
  static const city = '3018 Bern';
  static const phone = '031 556 82 88';
  static const email = 'restaurantkleefeld@gmx.ch';
  static const vatId = 'CHE-385.703.146';

  /// Till number shown as "Kasse: 1".
  static const till = '1';

  static const thankYou = [
    'Vielen Dank für Ihren Einkauf!',
    'Besuchen Sie uns wieder.',
    'Auf Wiedersehen!',
  ];
}

/// One printed line: what it was, and what it cost.
class BillLine {
  const BillLine({required this.qty, required this.name, required this.amount});

  final int qty;
  final String name;

  /// Line total, i.e. unit price times [qty].
  final double amount;

  String get label => '$qty x $name';
}

/// One table's part of a bill: what was ordered there and what it comes to.
class BillSection {
  const BillSection({required this.label, required this.lines});

  /// 'Tisch: 3 / 9, 10', or 'Take Away' when there is no table.
  final String label;

  final List<BillLine> lines;

  double get subtotal => lines.fold(0.0, (total, line) => total + line.amount);
}

class BillData {
  const BillData({
    required this.title,
    required this.sections,
    required this.dateTime,
    required this.operatorName,
    required this.orderIds,
  });

  final String title;

  /// One per table. A bill for a single order has exactly one.
  final List<BillSection> sections;

  final DateTime dateTime;
  final String operatorName;

  /// The order numbers this bill covers, e.g. ['A1002', 'A1003'].
  final List<String> orderIds;

  /// Paid together with other orders, rather than on its own.
  bool get isCombined => orderIds.length > 1;

  /// Several tables on one bill: each gets its own heading and subtotal.
  bool get hasTableSections => sections.length > 1;

  /// 'Tisch: 1' for a bill covering one table; empty when it spans several,
  /// since each section then carries its own.
  String get tableLabel => sections.length == 1 ? sections.single.label : '';

  /// Every line on the bill, in print order.
  List<BillLine> get lines => [for (final s in sections) ...s.lines];

  /// Sum of the lines. The service charge stored on an order is deliberately
  /// left off the bill.
  double get sum => sections.fold(0.0, (total, s) => total + s.subtotal);

  String get orderId => orderIds.join(', ');

  static BillData fromOrder(
    Map<String, dynamic> order, {
    String? operatorName,
    String title = 'Zwischenrechnung',
  }) {
    // One order prints exactly as it always has: its lines as ordered, not
    // merged, under a single table heading.
    final lines = [
      for (final item in _items(order))
        BillLine(qty: item.qty, name: item.name, amount: item.amount),
    ];

    final Timestamp? ts = order['timestamp'] as Timestamp?;

    return BillData(
      title: title,
      sections: [BillSection(label: _tableLabel(order), lines: lines)],
      dateTime: ts?.toDate() ?? DateTime.now(),
      operatorName: _operator(operatorName),
      orderIds: [(order['order_id'] ?? '').toString()],
    );
  }

  /// One bill for several orders - everyone at a table, or several tables
  /// paying together.
  ///
  /// Orders are grouped into one section per table, in the order the tables
  /// were seated. Within a table, the same article ordered from several chairs
  /// is added up into one line, which is what a guest paying for the table
  /// expects to read.
  static BillData fromOrders(
    List<Map<String, dynamic>> orders, {
    String? operatorName,
    String title = 'Zwischenrechnung',
  }) {
    if (orders.length == 1) {
      return fromOrder(orders.single, operatorName: operatorName, title: title);
    }

    final sorted = [...orders]
      ..sort((a, b) => _timestampOf(a).compareTo(_timestampOf(b)));

    // Insertion-ordered, so sections follow seating order.
    final tables = <String, _TableAccumulator>{};
    for (final order in sorted) {
      final key = _tableKey(order);
      final table = tables.putIfAbsent(key, () => _TableAccumulator(key));
      final chair = (order['chair_no'] ?? '').toString().trim();
      if (chair.isNotEmpty) table.chairs.add(chair);
      for (final item in _items(order)) {
        table.add(item);
      }
    }

    return BillData(
      title: title,
      sections: [for (final table in tables.values) table.toSection()],
      dateTime: DateTime.now(),
      operatorName: _operator(operatorName),
      orderIds: [
        for (final order in sorted) (order['order_id'] ?? '').toString(),
      ],
    );
  }

  /// The bill an order belongs to: just that order, or - when it was paid
  /// together with others - every order on the same bill. This is what makes
  /// reprinting from any one of them print the whole bill.
  static Future<BillData> forOrder(
    Map<String, dynamic> order, {
    String? operatorName,
  }) async {
    final billId = (order['bill_id'] ?? '').toString();
    if (billId.isEmpty) return fromOrder(order, operatorName: operatorName);

    final snap = await FirebaseFirestore.instance
        .collection('orders')
        .where('bill_id', isEqualTo: billId)
        .get();
    final members = snap.docs.map((doc) => doc.data()).toList();
    if (members.isEmpty) return fromOrder(order, operatorName: operatorName);
    return fromOrders(members, operatorName: operatorName);
  }

  // -------------------------------------------------------------- helpers

  static List<({int qty, String name, double unit, double amount})> _items(
    Map<String, dynamic> order,
  ) {
    final rawItems = order['items'] as List<dynamic>? ?? [];
    return [
      for (final raw in rawItems)
        if (raw is Map)
          () {
            final item = Map<String, dynamic>.from(raw);
            final qty = ((item['qty'] as num?) ?? 1).toInt();
            final unit = ((item['price'] as num?) ?? 0).toDouble();
            final name = (item['name'] ?? 'Artikel').toString();
            final size = (item['size'] ?? '').toString();
            return (
              qty: qty,
              name: size.isEmpty ? name : '$name $size',
              unit: unit,
              amount: unit * qty,
            );
          }(),
    ];
  }

  /// Groups orders of the same table; every take-away order shares one.
  static String _tableKey(Map<String, dynamic> order) {
    final table = (order['table_no'] ?? '').toString().trim();
    return (table.isEmpty || table == 'N/A') ? '' : table;
  }

  static String _tableLabel(Map<String, dynamic> order) {
    final table = _tableKey(order);
    final chair = (order['chair_no'] ?? '').toString().trim();
    final method = (order['delivery_method'] ?? '').toString().trim();
    if (table.isNotEmpty) {
      return chair.isEmpty ? 'Tisch: $table' : 'Tisch: $table / $chair';
    }
    return method.isEmpty ? '' : 'Take Away';
  }

  static DateTime _timestampOf(Map<String, dynamic> order) =>
      (order['timestamp'] as Timestamp?)?.toDate() ?? DateTime(2000);

  static String _operator(String? name) =>
      (name == null || name.trim().isEmpty) ? 'admin' : name.trim();

  /// '63,60' - Swiss/German decimal comma, as on the till receipt.
  static String money(num value) =>
      value.toStringAsFixed(2).replaceAll('.', ',');

  /// '07.09.2026 23:58:13'
  static String stamp(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year} '
        '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  String get sumText => money(sum);
  String get dateText => stamp(dateTime);

  /// Plain-text rendering, used by the ESC/POS network printer path.
  List<String> toPlainText() {
    return [
      RestaurantInfo.name,
      RestaurantInfo.street,
      RestaurantInfo.city,
      RestaurantInfo.phone,
      RestaurantInfo.email,
      RestaurantInfo.vatId,
      '',
      title,
      if (isCombined) 'Bestellungen: $orderId',
      '',
      if (!hasTableSections) ...[
        if (tableLabel.isNotEmpty) tableLabel,
        '------------------------------',
        for (final line in lines) ...[
          '  ${line.label}',
          '  ${money(line.amount)} CHF',
        ],
      ] else
        for (final section in sections) ...[
          if (section != sections.first) '------------------------------',
          section.label,
          for (final line in section.lines) ...[
            '  ${line.label}',
            '  ${money(line.amount)} CHF',
          ],
          'Zwischensumme CHF: ${money(section.subtotal)}',
        ],
      '------------------------------',
      'Summe CHF:     $sumText',
      '==============================',
      '',
      'Datum $dateText',
      'Bediener: $operatorName',
      'Kasse: ${RestaurantInfo.till}',
      '',
      ...RestaurantInfo.thankYou,
    ];
  }
}

/// Collects one table's items while a combined bill is being built.
class _TableAccumulator {
  _TableAccumulator(this.table);

  final String table;
  final Set<String> chairs = <String>{};

  // Same article at the same price, however many chairs ordered it.
  final Map<String, ({int qty, String name, double amount})> _lines = {};

  void add(({int qty, String name, double unit, double amount}) item) {
    final key = '${item.name}|${item.unit}';
    final seen = _lines[key];
    _lines[key] = seen == null
        ? (qty: item.qty, name: item.name, amount: item.amount)
        : (
            qty: seen.qty + item.qty,
            name: item.name,
            amount: seen.amount + item.amount,
          );
  }

  BillSection toSection() {
    final label = table.isEmpty
        ? 'Take Away'
        : chairs.isEmpty
        ? 'Tisch: $table'
        : 'Tisch: $table / ${chairs.join(', ')}';
    return BillSection(
      label: label,
      lines: [
        for (final line in _lines.values)
          BillLine(qty: line.qty, name: line.name, amount: line.amount),
      ],
    );
  }
}
