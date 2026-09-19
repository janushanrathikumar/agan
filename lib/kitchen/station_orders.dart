// lib/kitchen/station_orders.dart
//
// Shared implementation behind the Kitchen and Bar pages.
//
// Both pages read the same `orders` collection the admin Order List uses, but
// each one shows only the lines that belong to it: the Kitchen sees the food
// (and combo) items, the Bar sees the drinks. Every order can be printed as a
// station ticket that contains just those lines — no prices, because a station
// ticket is a preparation slip, not a receipt.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:restorant/shared/till_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'station_alarm.dart';

// --- Palette (matches the admin section) ---
const kStPrimary = Color(0xFFB59410);
const kStBg = Color(0xFF2A2928);
const kStMuted = Color(0xFFB7B7B6);
const kStWhite = Color(0xFFFFFFFF);
const kStCardBg = Color(0xFF383735);
const kStItemBg = Color(0xFF2F2E2D);

// ==========================================
// STATION DEFINITION
// ==========================================
enum OrderStation { kitchen, bar }

/// Per-station status of an order. Stored on the order document under
/// `kitchen_status` / `bar_status`, so the two stations never overwrite each
/// other and neither one touches the order's own `status` field.
class StationStatus {
  static const pending = 'Pending';
  static const preparing = 'Preparing';
  static const ready = 'Ready';
}

extension OrderStationInfo on OrderStation {
  String get title => this == OrderStation.kitchen ? 'Kitchen' : 'Bar';

  String get ticketHeading =>
      this == OrderStation.kitchen ? '*** KITCHEN ***' : '*** BAR ***';

  /// Field on the order document holding this station's progress.
  String get statusField =>
      this == OrderStation.kitchen ? 'kitchen_status' : 'bar_status';

  String get printedAtField =>
      this == OrderStation.kitchen ? 'kitchen_printed_at' : 'bar_printed_at';

  String get updatedAtField =>
      this == OrderStation.kitchen ? 'kitchen_updated_at' : 'bar_updated_at';

  String get _ipPrefKey =>
      this == OrderStation.kitchen ? 'kitchen_printer_ip' : 'bar_printer_ip';

  String get _autoPrintPrefKey => this == OrderStation.kitchen
      ? 'kitchen_auto_print'
      : 'bar_auto_print';

  IconData get icon =>
      this == OrderStation.kitchen ? Icons.soup_kitchen : Icons.local_bar;

  Color get accent =>
      this == OrderStation.kitchen ? kStPrimary : const Color(0xFF7FB2E5);

  String get emptyLabel => this == OrderStation.kitchen
      ? 'No food items to prepare right now.'
      : 'No drinks to prepare right now.';

  /// Which order lines this station is responsible for.
  ///
  /// Drinks go to the Bar; everything else (food, combos and any item saved
  /// without a `kind`) goes to the Kitchen, so no line can fall through the
  /// gap between the two stations.
  bool ownsItem(Map<String, dynamic> item) {
    final kind = (item['kind'] ?? '').toString().toLowerCase();
    final isDrink = kind == 'drink';
    return this == OrderStation.bar ? isDrink : !isDrink;
  }
}

/// The lines of [orderData] that belong to [station].
List<Map<String, dynamic>> stationItems(
  Map<String, dynamic> orderData,
  OrderStation station,
) {
  final List<dynamic> items = orderData['items'] as List<dynamic>? ?? [];
  return items
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .where(station.ownsItem)
      .toList();
}

/// Total number of units (sum of quantities) for the station's lines.
int stationItemCount(
  Map<String, dynamic> orderData,
  OrderStation station,
) {
  var count = 0;
  for (final item in stationItems(orderData, station)) {
    count += ((item['qty'] as num?) ?? 1).toInt();
  }
  return count;
}

String stationStatusOf(Map<String, dynamic> orderData, OrderStation station) {
  final raw = (orderData[station.statusField] ?? '').toString();
  return raw.isEmpty ? StationStatus.pending : raw;
}

String orderTableLabel(Map<String, dynamic> orderData) {
  final rawTable = (orderData['table_no'] ?? '').toString().trim();
  final rawChair = (orderData['chair_no'] ?? '').toString().trim();
  if (rawTable.isEmpty || rawTable == 'N/A') return '';
  return rawChair.isEmpty ? rawTable : '$rawTable (Chair $rawChair)';
}

// ==========================================
// PER-STATION PRINTER CONFIGURATION
// ==========================================
class StationPrinterConfig {
  static final Map<OrderStation, String> _ips = {
    OrderStation.kitchen: 'ipp://192.168.1.101',
    OrderStation.bar: 'ipp://192.168.1.102',
  };
  static final Map<OrderStation, bool> _autoPrint = {
    OrderStation.kitchen: false,
    OrderStation.bar: false,
  };

  static String ipFor(OrderStation station) => _ips[station] ?? '';
  static bool autoPrintFor(OrderStation station) =>
      _autoPrint[station] ?? false;

  static Future<void> load(OrderStation station) async {
    final prefs = await SharedPreferences.getInstance();
    _ips[station] = prefs.getString(station._ipPrefKey) ?? ipFor(station);
    _autoPrint[station] = prefs.getBool(station._autoPrintPrefKey) ?? false;
  }

  static Future<void> saveIp(OrderStation station, String ip) async {
    _ips[station] = ip;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(station._ipPrefKey, ip);
  }

  static Future<void> saveAutoPrint(OrderStation station, bool value) async {
    _autoPrint[station] = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(station._autoPrintPrefKey, value);
  }
}

// ==========================================
// STATION TICKET PRINTER
// ==========================================
class StationTicketPrinter {
  static const MethodChannel _printerChannel = MethodChannel(
    'restaurantkleefeld/printer',
  );

  /// Prints the [station] portion of [orderData] as an 80mm ticket.
  ///
  /// When [isAutoPrint] is true the ticket is pushed straight to the station's
  /// network printer; if that path is unavailable (web, or no native printer
  /// bridge on this build) it falls back to the normal print dialog so the
  /// ticket is never silently lost.
  static Future<void> printTicket(
    BuildContext context,
    Map<String, dynamic> orderData,
    OrderStation station, {
    bool isAutoPrint = false,
    String? documentId,
  }) async {
    final items = stationItems(orderData, station);
    if (items.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This order has no ${station.title} items to print.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final pdfBytes = await _buildTicket(orderData, station, items);
    final orderId = (orderData['order_id'] ?? documentId ?? '').toString();

    var printed = false;
    try {
      if (isAutoPrint && !kIsWeb) {
        printed = await _printToNetworkPrinter(orderData, station, items);
        if (!printed) throw Exception('Printer did not accept the ticket');
      } else {
        printed = await TillPrinter.printPdf(
          pdfBytes,
          jobName: '${station.title}_Ticket_$orderId',
        );
      }
    } on MissingPluginException {
      // No native printer bridge on this platform — use the print dialog.
      try {
        printed = await TillPrinter.printPdf(
          pdfBytes,
          jobName: '${station.title}_Ticket_$orderId',
        );
      } catch (error) {
        if (!context.mounted) return;
        _showSnack(context, 'Could not print ticket: $error', Colors.red);
        return;
      }
    } catch (error) {
      if (!context.mounted) return;
      _showSnack(
        context,
        '${station.title} print failed: $error',
        Colors.red,
      );
      return;
    }

    if (printed && documentId != null) {
      unawaited(
        FirebaseFirestore.instance
            .collection('orders')
            .doc(documentId)
            .set({
              station.printedAtField: FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .catchError((_) {}),
      );
    }

    if (!context.mounted) return;
    _showSnack(
      context,
      printed
          ? '${station.title} ticket sent for Order #$orderId'
          : '${station.title} ticket was canceled for Order #$orderId',
      printed ? Colors.green : Colors.orange,
    );
  }

  static void _showSnack(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  static Future<Uint8List> _buildTicket(
    Map<String, dynamic> orderData,
    OrderStation station,
    List<Map<String, dynamic>> items,
  ) async {
    final pdf = pw.Document();

    final orderId = (orderData['order_id'] ?? '').toString();
    final deliveryMethod = (orderData['delivery_method'] ?? '').toString();
    final table = orderTableLabel(orderData);
    final username = (orderData['username'] ?? 'Guest').toString();
    final Timestamp? ts = orderData['timestamp'] as Timestamp?;
    final placed = ts?.toDate() ?? DateTime.now();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  station.ticketHeading,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Order #$orderId',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (table.isNotEmpty)
                pw.Text(
                  'Table: $table',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              if (deliveryMethod.isNotEmpty) pw.Text('Type: $deliveryMethod'),
              pw.Text('Customer: $username'),
              pw.Text('Placed: ${_formatDateTime(placed)}'),
              pw.Text('Printed: ${_formatDateTime(DateTime.now())}'),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              ...items.map((item) => _ticketLine(item)),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.Text(
                'Total items: ${stationItemCount(orderData, station)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// One order line, with everything the station needs to prepare it and
  /// nothing it does not (no prices).
  static pw.Widget _ticketLine(Map<String, dynamic> item) {
    final name = (item['name'] ?? 'Item').toString();
    final size = (item['size'] ?? '').toString();
    final qty = ((item['qty'] as num?) ?? 1).toInt();
    final displayName = size.isEmpty ? name : '$name ($size)';

    final Map<String, dynamic> choices = Map<String, dynamic>.from(
      item['menuChoices'] as Map? ?? {},
    );
    final List<dynamic> addOns = item['additionalOptions'] as List<dynamic>? ??
        [];
    final note = (item['note'] ?? '').toString();
    final extraNote = (item['extraNote'] ?? '').toString();
    final type = (item['type'] ?? '').toString();
    final sugar = (item['sugar'] ?? '').toString();

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 34,
                child: pw.Text(
                  '${qty}x',
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  displayName,
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (type.isNotEmpty) _ticketDetail('Type: $type'),
          if (sugar.isNotEmpty) _ticketDetail('Sugar: $sugar'),
          ...choices.entries.map((e) => _ticketDetail('${e.key}: ${e.value}')),
          ...addOns.whereType<Map>().map(
            (addon) => _ticketDetail('+ ${(addon['name'] ?? '').toString()}'),
          ),
          if (note.isNotEmpty) _ticketDetail('NOTE: $note', bold: true),
          if (extraNote.isNotEmpty)
            _ticketDetail('NOTE: $extraNote', bold: true),
        ],
      ),
    );
  }

  static pw.Widget _ticketDetail(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 34, top: 2),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static Future<bool> _printToNetworkPrinter(
    Map<String, dynamic> orderData,
    OrderStation station,
    List<Map<String, dynamic>> items,
  ) async {
    final address = StationPrinterConfig.ipFor(station)
        .replaceFirst(RegExp(r'^(ipp|socket)://'), '')
        .split(':')
        .first
        .trim();
    if (address.isEmpty) {
      throw Exception('${station.title} printer IP address is empty');
    }

    final table = orderTableLabel(orderData);
    final lines = <String>[
      station.ticketHeading,
      'Order #${orderData['order_id'] ?? ''}',
      if (table.isNotEmpty) 'Table: $table',
      'Type: ${orderData['delivery_method'] ?? ''}',
      'Printed: ${_formatDateTime(DateTime.now())}',
      '------------------------------',
    ];

    for (final item in items) {
      final name = (item['name'] ?? 'Item').toString();
      final size = (item['size'] ?? '').toString();
      final qty = ((item['qty'] as num?) ?? 1).toInt();
      lines.add('${qty}x ${size.isEmpty ? name : '$name ($size)'}');

      final Map<String, dynamic> choices = Map<String, dynamic>.from(
        item['menuChoices'] as Map? ?? {},
      );
      for (final entry in choices.entries) {
        lines.add('   ${entry.key}: ${entry.value}');
      }
      for (final addon in (item['additionalOptions'] as List<dynamic>? ?? [])
          .whereType<Map>()) {
        lines.add('   + ${(addon['name'] ?? '').toString()}');
      }
      final type = (item['type'] ?? '').toString();
      final sugar = (item['sugar'] ?? '').toString();
      if (type.isNotEmpty) lines.add('   Type: $type');
      if (sugar.isNotEmpty) lines.add('   Sugar: $sugar');
      final note = (item['note'] ?? '').toString();
      final extraNote = (item['extraNote'] ?? '').toString();
      if (note.isNotEmpty) lines.add('   NOTE: $note');
      if (extraNote.isNotEmpty) lines.add('   NOTE: $extraNote');
    }

    lines
      ..add('------------------------------')
      ..add('Total items: ${stationItemCount(orderData, station)}');

    return await _printerChannel.invokeMethod<bool>('printReceipt', {
          'address': address,
          'receipt': lines.join('\n'),
        }) ??
        false;
  }

  static String _formatDateTime(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$d/$m/${date.year} $h:$min';
  }
}

// ==========================================
// STATION ORDERS PAGE (Kitchen / Bar)
// ==========================================
class StationOrdersPage extends StatefulWidget {
  const StationOrdersPage({
    super.key,
    required this.station,
    this.onSignOut,
  });

  final OrderStation station;

  /// Supplied by [StationGate]; when set, a Logout button is shown.
  final Future<void> Function()? onSignOut;

  @override
  State<StationOrdersPage> createState() => _StationOrdersPageState();
}

class _StationOrdersPageState extends State<StationOrdersPage> {
  static const _tabs = [
    StationStatus.pending,
    StationStatus.preparing,
    StationStatus.ready,
    'All',
  ];

  String _selectedTab = StationStatus.pending;
  StreamSubscription<QuerySnapshot>? _ordersSub;
  Timer? _clockTimer;
  DateTime _pageInitTime = DateTime.now();

  /// Sounds while any order is still waiting to be started.
  final StationAlarm _alarm = StationAlarm(assetPath: 'alart.mp3');
  int _waitingCount = 0;

  OrderStation get _station => widget.station;

  @override
  void initState() {
    super.initState();
    _alarm.init();
    _alarm.autoplayBlocked.addListener(_onAlarmBlockedChanged);
    StationPrinterConfig.load(_station).then((_) {
      if (!mounted) return;
      setState(() {});
      _startOrdersListener();
    });
    // Keeps the "waiting X min" badges honest without rebuilding the stream.
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onAlarmBlockedChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    _clockTimer?.cancel();
    _alarm.autoplayBlocked.removeListener(_onAlarmBlockedChanged);
    _alarm.dispose();
    super.dispose();
  }

  /// One subscription drives both the alert sound and auto-printing.
  ///
  /// The alarm is driven from here rather than from `build`, so it keeps
  /// following the order list even while the tab is in the background and the
  /// page is not being painted.
  void _startOrdersListener() {
    _ordersSub = FirebaseFirestore.instance
        .collection('orders')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
          _updateAlarm(snapshot);

          if (!StationPrinterConfig.autoPrintFor(_station)) return;

          for (final change in snapshot.docChanges) {
            if (change.type != DocumentChangeType.added) continue;

            final data = change.doc.data();
            if (data is! Map<String, dynamic>) continue;
            if ((data['status'] ?? '') == 'Canceled') continue;
            if (stationItems(data, _station).isEmpty) continue;

            final Timestamp? ts = data['timestamp'] as Timestamp?;
            // Only orders that arrived after this page opened, so reopening
            // the page never reprints the day's backlog.
            if (ts == null || !ts.toDate().isAfter(_pageInitTime)) continue;
            if (!mounted) return;

            StationTicketPrinter.printTicket(
              context,
              data,
              _station,
              isAutoPrint: true,
              documentId: change.doc.id,
            );
          }
        });
  }

  /// Counts the orders this station still has to start, and keeps the alert
  /// sounding for exactly as long as there is at least one.
  void _updateAlarm(QuerySnapshot snapshot) {
    var waiting = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data is! Map<String, dynamic>) continue;
      if ((data['status'] ?? '') == 'Canceled') continue;
      if (stationItems(data, _station).isEmpty) continue;
      if (stationStatusOf(data, _station) != StationStatus.pending) continue;
      waiting++;
    }

    _alarm.setAlerting(waiting > 0);

    if (waiting != _waitingCount && mounted) {
      setState(() => _waitingCount = waiting);
    } else {
      _waitingCount = waiting;
    }
  }

  Future<void> _setStatus(String documentId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(documentId)
          .set({
            _station.statusField: status,
            _station.updatedAtField: FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPrinterSettings() {
    final ipCtrl = TextEditingController(
      text: StationPrinterConfig.ipFor(_station),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kStCardBg,
        title: Text(
          '${_station.title} Printer',
          style: const TextStyle(color: kStWhite),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter Printer IP Address:',
              style: TextStyle(color: kStMuted),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ipCtrl,
              style: const TextStyle(color: kStWhite),
              decoration: InputDecoration(
                hintText: 'e.g., ipp://192.168.1.101',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: kStBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: kStMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _station.accent),
            onPressed: () async {
              final navigator = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              await StationPrinterConfig.saveIp(_station, ipCtrl.text.trim());
              if (!mounted) return;
              setState(() {});
              navigator.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text('${_station.title} printer IP saved!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Save IP', style: TextStyle(color: kStWhite)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kStBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(),
            _buildSoundBlockedBanner(),
            _buildTabs(),
            Expanded(child: _buildOrders()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Row(
        children: [
          if (Navigator.of(context).canPop())
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: kStWhite,
                size: 22,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _station.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_station.icon, color: kStWhite, size: 24),
          ),
          const SizedBox(width: 16),
          Text(
            '${_station.title} Orders',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: kStWhite,
            ),
          ),
          const Spacer(),
          // Alert sound on/off. Turning it off silences the current alert too.
          IconButton(
            icon: Icon(
              _alarm.isMuted
                  ? Icons.notifications_off
                  : (_waitingCount > 0
                        ? Icons.notifications_active
                        : Icons.notifications),
              color: _alarm.isMuted
                  ? kStMuted
                  : (_waitingCount > 0 ? Colors.redAccent : _station.accent),
            ),
            tooltip: _alarm.isMuted ? 'Turn alert sound on' : 'Mute alert sound',
            onPressed: () async {
              await _alarm.setMuted(!_alarm.isMuted);
              if (mounted) setState(() {});
            },
          ),
          IconButton(
            icon: Icon(Icons.print, color: _station.accent),
            onPressed: _showPrinterSettings,
            tooltip: '${_station.title} printer settings',
          ),
          const Text(
            'Auto Print',
            style: TextStyle(
              color: kStWhite,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Switch(
            value: StationPrinterConfig.autoPrintFor(_station),
            activeColor: kStWhite,
            activeTrackColor: _station.accent,
            inactiveThumbColor: kStMuted,
            inactiveTrackColor: kStItemBg,
            onChanged: (val) async {
              await StationPrinterConfig.saveAutoPrint(_station, val);
              if (!mounted) return;
              setState(() {
                if (val) _pageInitTime = DateTime.now();
              });
            },
          ),
          if (widget.onSignOut != null) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Log out',
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.redAccent,
                  size: 22,
                ),
              ),
              onPressed: _confirmSignOut,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kStCardBg,
        title: const Text(
          'Confirm Logout',
          style: TextStyle(color: kStWhite),
        ),
        content: Text(
          'Log out of the ${_station.title} screen?',
          style: const TextStyle(color: kStMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: kStMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: kStWhite,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await widget.onSignOut?.call();
  }

  /// Browsers refuse to play audio until someone has interacted with the page,
  /// so when the alert is blocked we ask for that one tap explicitly rather
  /// than letting an order sit there silently.
  Widget _buildSoundBlockedBanner() {
    if (!_alarm.autoplayBlocked.value || _alarm.isMuted) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 4, 24, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.volume_off, color: Colors.orangeAccent, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'The browser blocked the alert sound. Tap to switch it on for '
              'this screen.',
              style: TextStyle(color: kStWhite, fontSize: 13),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              await _alarm.enableFromUserGesture();
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.volume_up, size: 18),
            label: const Text('Enable sound'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _tabs.map((tab) {
            final isActive = _selectedTab == tab;
            return GestureDetector(
              onTap: () => setState(() => _selectedTab = tab),
              child: Container(
                margin: const EdgeInsets.only(right: 32),
                padding: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isActive ? _station.accent : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    color: isActive ? _station.accent : kStMuted,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                    fontSize: 16,
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
      stream: FirebaseFirestore.instance
          .collection('orders')
          .orderBy('timestamp', descending: true)
          .limit(200)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: _station.accent),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final orderStatus = (data['status'] ?? '').toString();
          // Canceled, or already served and paid for by the waiter.
          if (orderStatus == 'Canceled' || orderStatus == 'Completed') {
            return false;
          }
          // Only orders that actually contain work for this station.
          if (stationItems(data, _station).isEmpty) return false;
          if (_selectedTab == 'All') return true;
          return stationStatusOf(data, _station) == _selectedTab;
        }).toList();

        // Pending and Preparing are worked oldest-first; finished tickets read
        // better newest-first.
        if (_selectedTab == StationStatus.pending ||
            _selectedTab == StationStatus.preparing) {
          docs.sort((a, b) {
            final ta = (a.data() as Map<String, dynamic>)['timestamp']
                as Timestamp?;
            final tb = (b.data() as Map<String, dynamic>)['timestamp']
                as Timestamp?;
            if (ta == null || tb == null) return 0;
            return ta.compareTo(tb);
          });
        }

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_station.icon, color: kStItemBg, size: 64),
                const SizedBox(height: 16),
                Text(
                  _station.emptyLabel,
                  style: const TextStyle(color: kStMuted, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            const cardWidth = 380.0;
            final columns = (constraints.maxWidth / (cardWidth + 20))
                .floor()
                .clamp(1, 4);
            final width = columns == 1
                ? constraints.maxWidth - 48
                : cardWidth;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Wrap(
                spacing: 20,
                runSpacing: 20,
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
    final orderId = (data['order_id'] ?? documentId).toString();
    final status = stationStatusOf(data, _station);
    final items = stationItems(data, _station);
    final table = orderTableLabel(data);
    final deliveryMethod = (data['delivery_method'] ?? '').toString();
    final Timestamp? ts = data['timestamp'] as Timestamp?;
    final placed = ts?.toDate();

    return Container(
      decoration: BoxDecoration(
        color: kStCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _statusColor(status).withOpacity(0.5)),
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
              _statusPill(status),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (table.isNotEmpty)
                _infoChip(Icons.table_restaurant, 'Table $table'),
              if (deliveryMethod.isNotEmpty)
                _infoChip(Icons.dining, deliveryMethod),
              if (placed != null)
                _infoChip(Icons.schedule, _waitingLabel(placed)),
            ],
          ),
          const Divider(color: kStItemBg, height: 24, thickness: 1.5),
          ...items.map(_buildItemRow),
          const SizedBox(height: 8),
          const Divider(color: kStItemBg, height: 16, thickness: 1.5),
          Row(
            children: [
              Text(
                '${stationItemCount(data, _station)} item(s)',
                style: const TextStyle(color: kStMuted, fontSize: 13),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Print ${_station.title} ticket',
                icon: Icon(Icons.print, color: _station.accent),
                onPressed: () => StationTicketPrinter.printTicket(
                  context,
                  data,
                  _station,
                  documentId: documentId,
                ),
              ),
              const SizedBox(width: 4),
              _actionButton(documentId, status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String documentId, String status) {
    switch (status) {
      case StationStatus.pending:
        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _station.accent,
            foregroundColor: kStWhite,
          ),
          onPressed: () => _setStatus(documentId, StationStatus.preparing),
          icon: const Icon(Icons.play_arrow, size: 18),
          label: const Text('Start'),
        );
      case StationStatus.preparing:
        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: kStWhite,
          ),
          onPressed: () => _setStatus(documentId, StationStatus.ready),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Ready'),
        );
      default:
        return OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: kStMuted,
            side: const BorderSide(color: kStMuted),
          ),
          onPressed: () => _setStatus(documentId, StationStatus.preparing),
          icon: const Icon(Icons.undo, size: 18),
          label: const Text('Reopen'),
        );
    }
  }

  Widget _buildItemRow(Map<String, dynamic> item) {
    final name = (item['name'] ?? 'Item').toString();
    final size = (item['size'] ?? '').toString();
    final qty = ((item['qty'] as num?) ?? 1).toInt();
    final Map<String, dynamic> choices = Map<String, dynamic>.from(
      item['menuChoices'] as Map? ?? {},
    );
    final addOns = (item['additionalOptions'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .toList();
    final note = (item['note'] ?? '').toString();
    final extraNote = (item['extraNote'] ?? '').toString();
    final type = (item['type'] ?? '').toString();
    final sugar = (item['sugar'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _station.accent.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${qty}x',
              style: TextStyle(
                color: _station.accent,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  size.isEmpty ? name : '$name ($size)',
                  style: const TextStyle(
                    color: kStWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (type.isNotEmpty) _detailText('☕ Type: $type'),
                if (sugar.isNotEmpty) _detailText('🍬 Sugar: $sugar'),
                ...choices.entries.map(
                  (e) => _detailText('✔️ ${e.key}: ${e.value}'),
                ),
                ...addOns.map(
                  (addon) =>
                      _detailText('➕ ${(addon['name'] ?? '').toString()}'),
                ),
                if (note.isNotEmpty) _detailText('📝 $note', highlight: true),
                if (extraNote.isNotEmpty)
                  _detailText('📝 $extraNote', highlight: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailText(String text, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        text,
        style: TextStyle(
          color: highlight ? Colors.orangeAccent : kStMuted,
          fontSize: 13,
          fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
        ),
      ),
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
          Text(
            label,
            style: const TextStyle(color: kStWhite, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case StationStatus.preparing:
        return Colors.orangeAccent;
      case StationStatus.ready:
        return Colors.greenAccent;
      default:
        return _station.accent;
    }
  }

  String _waitingLabel(DateTime placed) {
    final minutes = DateTime.now().difference(placed).inMinutes;
    if (minutes < 1) return 'just now';
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    return '${hours}h ${minutes % 60}m';
  }
}
