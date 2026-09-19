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

class BillData {
  const BillData({
    required this.title,
    required this.tableLabel,
    required this.lines,
    required this.sum,
    required this.dateTime,
    required this.operatorName,
    required this.orderId,
  });

  final String title;

  /// 'Tisch: 1', or the order type when there is no table (take-away).
  final String tableLabel;

  final List<BillLine> lines;

  /// Sum of the lines. The service charge stored on the order is deliberately
  /// left off the bill.
  final double sum;

  final DateTime dateTime;
  final String operatorName;
  final String orderId;

  static BillData fromOrder(
    Map<String, dynamic> order, {
    String? operatorName,
    String title = 'Zwischenrechnung',
  }) {
    final rawItems = order['items'] as List<dynamic>? ?? [];
    final lines = <BillLine>[];
    var sum = 0.0;

    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final qty = ((item['qty'] as num?) ?? 1).toInt();
      final unit = ((item['price'] as num?) ?? 0).toDouble();
      final name = (item['name'] ?? 'Artikel').toString();
      final size = (item['size'] ?? '').toString();
      final amount = unit * qty;
      sum += amount;
      lines.add(
        BillLine(
          qty: qty,
          name: size.isEmpty ? name : '$name $size',
          amount: amount,
        ),
      );
    }

    final table = (order['table_no'] ?? '').toString().trim();
    final chair = (order['chair_no'] ?? '').toString().trim();
    final method = (order['delivery_method'] ?? '').toString().trim();

    String tableLabel;
    if (table.isNotEmpty && table != 'N/A') {
      tableLabel = chair.isEmpty ? 'Tisch: $table' : 'Tisch: $table / $chair';
    } else {
      tableLabel = method.isEmpty ? '' : 'Take Away';
    }

    final Timestamp? ts = order['timestamp'] as Timestamp?;

    return BillData(
      title: title,
      tableLabel: tableLabel,
      lines: lines,
      sum: sum,
      dateTime: ts?.toDate() ?? DateTime.now(),
      operatorName: (operatorName == null || operatorName.trim().isEmpty)
          ? 'admin'
          : operatorName.trim(),
      orderId: (order['order_id'] ?? '').toString(),
    );
  }

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
      '',
      if (tableLabel.isNotEmpty) tableLabel,
      '------------------------------',
      for (final line in lines) ...[
        '  ${line.label}',
        '  ${money(line.amount)} CHF',
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
