// lib/admin_order.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:restorant/kitchen/bar.dart';
import 'package:restorant/kitchen/kitchen.dart';
import 'package:restorant/kitchen/station_orders.dart';
import 'package:restorant/shared/bill_receipt.dart';
import 'edit_order_page.dart';

// --- Palette (Your Original Colors) ---
const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);
const kCardBg = Color(0xFF383735);
const kItemBg = Color(0xFF2F2E2D);

// ==========================================
// 🖨️ GLOBAL PRINTER CONFIGURATION (With Local Storage)
// ==========================================
class PrinterConfig {
  static String posPrinterIp = 'ipp://192.168.1.100';
  static bool isAutoPrintOn = false;

  // Local Storage-ல் இருந்து Settings-ஐ எடுப்பதற்கு
  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    posPrinterIp = prefs.getString('printer_ip') ?? 'ipp://192.168.1.100';
    isAutoPrintOn = prefs.getBool('auto_print_status') ?? false;
  }

  // IP Address-ஐ நிரந்தரமாக Save செய்வதற்கு
  static Future<void> saveIp(String ip) async {
    posPrinterIp = ip;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_ip', ip);
  }

  // Auto Print ON/OFF ஸ்டேட்டஸை Save செய்வதற்கு
  static Future<void> saveAutoPrintStatus(bool status) async {
    isAutoPrintOn = status;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_print_status', status);
  }
}
// ==========================================

// ==========================================
// 1. MAIN LIST PAGE (With Real-Time Auto Print Listener)
// ==========================================
class AdminOrdersListPage extends StatefulWidget {
  const AdminOrdersListPage({super.key});

  @override
  State<AdminOrdersListPage> createState() => _AdminOrdersListPageState();
}

class _AdminOrdersListPageState extends State<AdminOrdersListPage> {
  String _selectedTab = 'All Status';
  String _searchQuery = '';
  final List<String> _tabs = [
    'All Status',
    'New',
    'Completed',
    'Delivered',
    'Canceled',
  ];

  StreamSubscription<QuerySnapshot>? _ordersSub;
  DateTime _pageInitTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    // ஆப் திறக்கும்போது Save செய்யப்பட்ட Settings-ஐ எடுக்கிறோம்
    PrinterConfig.loadSettings().then((_) {
      setState(() {});
      _startAutoPrintListener();
    });
  }

  // 🔴 புதிய ஆர்டர்களைக் கவனித்து தானாகவே பிரிண்ட் செய்யும் ஃபங்ஷன்
  void _startAutoPrintListener() {
    _ordersSub = FirebaseFirestore.instance
        .collection('orders')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
          if (!PrinterConfig.isAutoPrintOn) return;

          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data() as Map<String, dynamic>;
              final status = data['status'] ?? 'Unknown';
              final Timestamp? timestamp = data['timestamp'] as Timestamp?;

              if (status == 'New' && timestamp != null) {
                final orderDate = timestamp.toDate();
                // இந்தப் பக்கம் Open ஆன பிறகு வந்த புதிய ஆர்டர் என்றால் மட்டுமே பிரிண்ட் ஆகும்
                if (orderDate.isAfter(_pageInitTime)) {
                  OrderPrinter.generateAndPrintPdf(context, data, true);
                }
              }
            }
          }
        });
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    super.dispose();
  }

  // 🖨️ Printer Settings Dialog (Admin IP மாற்றிக்கொள்ள)
  void _showPrinterSettings() {
    final TextEditingController ipCtrl = TextEditingController(
      text: PrinterConfig.posPrinterIp,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('Printer Settings', style: TextStyle(color: kWhite)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter Printer IP Address:',
              style: TextStyle(color: kMuted),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ipCtrl,
              style: const TextStyle(color: kWhite),
              decoration: InputDecoration(
                hintText: 'e.g., ipp://192.168.1.100',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: kBg,
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
            child: const Text('Cancel', style: TextStyle(color: kMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary),
            onPressed: () async {
              // 💾 Save The IP Permanently
              await PrinterConfig.saveIp(ipCtrl.text.trim());
              setState(() {}); // UI Update

              if (!mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Printer IP Saved successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Save IP', style: TextStyle(color: kWhite)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(context),
            _buildTabs(),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(
                  left: 24,
                  right: 24,
                  bottom: 24,
                  top: 8,
                ),
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildTableHeader(),
                    const Divider(color: kItemBg, height: 1, thickness: 1.5),
                    Expanded(child: _buildOrdersList()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: kWhite, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kPrimary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.restaurant, color: kWhite, size: 24),
          ),
          const SizedBox(width: 16),
          const Text(
            'Order List',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: kWhite,
            ),
          ),
          const Spacer(),

          // 🍳 Station views: the same orders split by preparation station
          _buildStationButton(
            context,
            icon: Icons.soup_kitchen,
            label: 'Kitchen',
            color: OrderStation.kitchen.accent,
            page: const KitchenPage(),
          ),
          const SizedBox(width: 8),
          _buildStationButton(
            context,
            icon: Icons.local_bar,
            label: 'Bar',
            color: OrderStation.bar.accent,
            page: const BarPage(),
          ),
          const SizedBox(width: 16),

          // 🖨️ Printer IP Settings Icon
          IconButton(
            icon: const Icon(Icons.print, color: kPrimary),
            onPressed: _showPrinterSettings,
            tooltip: 'Printer Settings',
          ),
          const SizedBox(width: 8),

          // 🟢 Auto Print Switch
          const Text(
            'Auto Print',
            style: TextStyle(
              color: kWhite,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Switch(
            value: PrinterConfig.isAutoPrintOn,
            activeColor: kWhite,
            activeTrackColor: kPrimary,
            inactiveThumbColor: kMuted,
            inactiveTrackColor: kItemBg,
            onChanged: (val) async {
              // 💾 Save Auto Print Status Permanently
              await PrinterConfig.saveAutoPrintStatus(val);
              setState(() {
                if (val) {
                  _pageInitTime = DateTime.now();
                }
              });
            },
          ),
          const SizedBox(width: 16),

          // Search Bar
          Container(
            width: 200,
            height: 45,
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: kItemBg, width: 1.5),
            ),
            child: TextField(
              style: const TextStyle(color: kWhite),
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: const InputDecoration(
                hintText: 'Search ID...',
                hintStyle: TextStyle(color: kMuted),
                prefixIcon: Icon(Icons.search, color: kMuted),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required Widget page,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      onPressed: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
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
                      color: isActive ? kPrimary : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    color: isActive ? kPrimary : kMuted,
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

  Widget _buildTableHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Order ID',
              style: TextStyle(
                color: kMuted,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Date & Time',
              style: TextStyle(
                color: kMuted,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Amount',
              style: TextStyle(
                color: kMuted,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Status',
              style: TextStyle(
                color: kMuted,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Action',
              style: TextStyle(
                color: kMuted,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimary),
          );
        }
        if (snapshot.hasError)
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No orders found.',
              style: TextStyle(color: kMuted, fontSize: 16),
            ),
          );
        }

        var orders = snapshot.data!.docs;

        if (_selectedTab != 'All Status') {
          orders = orders.where((doc) {
            final status =
                (doc.data() as Map<String, dynamic>)['status'] ?? 'Unknown';
            return status.toString().toLowerCase() ==
                _selectedTab.toLowerCase();
          }).toList();
        }

        if (_searchQuery.isNotEmpty) {
          orders = orders.where((doc) {
            final orderId =
                ((doc.data() as Map<String, dynamic>)['order_id'] ?? doc.id)
                    .toString();
            return orderId.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();
        }

        if (orders.isEmpty) {
          return const Center(
            child: Text(
              'No matching orders found.',
              style: TextStyle(color: kMuted, fontSize: 16),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(0),
          itemCount: orders.length,
          separatorBuilder: (context, index) =>
              const Divider(color: kItemBg, height: 1, thickness: 1.5),
          itemBuilder: (context, index) {
            final doc = orders[index];
            final data = doc.data() as Map<String, dynamic>;

            final String orderId = data['order_id'] ?? doc.id;
            final String status = data['status'] ?? 'Unknown';
            final num total = data['total'] ?? 0;
            final Timestamp? timestamp = data['timestamp'] as Timestamp?;
            final String date = timestamp != null
                ? _formatDate(timestamp.toDate())
                : 'No Date';

            return InkWell(
              onTap: () => _goToDetails(doc.id),
              hoverColor: kItemBg.withOpacity(0.5),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        '#$orderId',
                        style: const TextStyle(
                          color: kWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        date,
                        style: const TextStyle(color: kMuted, fontSize: 15),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'CHF ${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: kWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _buildStatusPill(status),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kPrimary,
                            side: const BorderSide(color: kPrimary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () => _goToDetails(doc.id),
                          child: const Text(
                            'View details',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusPill(String status) {
    Color color;
    if (status == 'New')
      color = Colors.greenAccent;
    else if (status == 'Canceled')
      color = Colors.redAccent;
    else
      color = kPrimary;

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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _goToDetails(String docId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminOrderDetailsPage(documentId: docId),
      ),
    );
  }
}

// ==========================================
// 2. ORDER DETAILS PAGE
// ==========================================
class AdminOrderDetailsPage extends StatelessWidget {
  final String documentId;

  const AdminOrderDetailsPage({super.key, required this.documentId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(documentId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: kBg,
            body: Center(child: CircularProgressIndicator(color: kPrimary)),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: kBg,
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: kWhite,
                  size: 22,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text('Error'),
              backgroundColor: kBg,
            ),
            body: const Center(
              child: Text('Order not found.', style: TextStyle(color: kMuted)),
            ),
          );
        }

        final Map<String, dynamic> orderData =
            snapshot.data!.data() as Map<String, dynamic>;

        final String orderId = orderData['order_id'] ?? documentId;
        final String status = orderData['status'] ?? 'Unknown';
        final String deliveryMethod = orderData['delivery_method'] ?? 'N/A';
        final num total = orderData['total'] ?? 0;
        final List<dynamic> items = orderData['items'] ?? [];

        final num subtotal = orderData['subtotal'] ?? total;

        final String username = orderData['username'] ?? 'Guest';
        final String role = orderData['role'] ?? 'Customer';

        final String rawTableNo = (orderData['table_no'] ?? 'N/A').toString();
        final String rawChairNo = (orderData['chair_no'] ?? '').toString();
        final String displayTable = rawChairNo.isNotEmpty && rawTableNo != 'N/A'
            ? '$rawTableNo (Chair $rawChairNo)'
            : rawTableNo;

        return Scaffold(
          backgroundColor: kBg,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: kWhite,
                size: 22,
              ),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Back',
            ),
            title: Text(
              'Order #$orderId',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: kBg,
            foregroundColor: kWhite,
            elevation: 0,
            actions: [
              // ✏️ Corrections stay possible after an order is completed.
              _actionButton(
                icon: Icons.edit,
                tooltip: 'Edit order',
                color: kPrimary,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditOrderPage(
                      documentId: documentId,
                      orderData: orderData,
                    ),
                  ),
                ),
              ),
              _actionButton(
                icon: Icons.delete_outline,
                tooltip: 'Delete order',
                color: Colors.redAccent,
                onPressed: () => _confirmDelete(context, orderData),
              ),
              // 🍳 Kitchen ticket: only the food/combo lines of this order
              _stationPrintAction(
                context,
                orderData,
                OrderStation.kitchen,
                Icons.soup_kitchen,
              ),
              // 🍹 Bar ticket: only the drink lines of this order
              _stationPrintAction(
                context,
                orderData,
                OrderStation.bar,
                Icons.local_bar,
              ),
              Container(
                margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kPrimary.withOpacity(0.5)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.print, color: kPrimary),
                  tooltip: 'Manual Print PDF',
                  onPressed: () => OrderPrinter.generateAndPrintPdf(
                    context,
                    orderData,
                    false,
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderSummaryCard(
                  orderId,
                  status,
                  deliveryMethod,
                  displayTable,
                  subtotal,
                  total,
                  username,
                  role,
                ),
                const SizedBox(height: 32),
                const Text(
                  'Order Items',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: kWhite,
                  ),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index] as Map<String, dynamic>;
                    return _buildItemCard(item);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// AppBar action that prints just one station's share of the order.
  /// Greyed out when the order has nothing for that station.
  Widget _actionButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  /// Deleting an order is permanent, so it names what is about to go.
  Future<void> _confirmDelete(
    BuildContext context,
    Map<String, dynamic> orderData,
  ) async {
    final orderId = (orderData['order_id'] ?? documentId).toString();
    final num total = (orderData['total'] as num?) ?? 0;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('Delete order?', style: TextStyle(color: kWhite)),
        content: Text(
          'Order #$orderId (CHF ${total.toStringAsFixed(2)}) will be removed '
          'permanently. It also disappears from the Kitchen, Bar and Service '
          'boards and from the customer\'s order list.',
          style: const TextStyle(color: kMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: kWhite)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(documentId)
          .delete();
      if (!context.mounted) return;
      Navigator.pop(context); // back to the order list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order #$orderId deleted.'),
          backgroundColor: kPrimary,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _stationPrintAction(
    BuildContext context,
    Map<String, dynamic> orderData,
    OrderStation station,
    IconData icon,
  ) {
    final hasItems = stationItems(orderData, station).isNotEmpty;
    final color = hasItems ? station.accent : kMuted;

    return Container(
      margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        tooltip: hasItems
            ? 'Print ${station.title} ticket'
            : 'No ${station.title} items in this order',
        onPressed: hasItems
            ? () => StationTicketPrinter.printTicket(
                context,
                orderData,
                station,
                documentId: documentId,
              )
            : null,
      ),
    );
  }

  Widget _buildOrderSummaryCard(
    String orderId,
    String status,
    String deliveryMethod,
    String tableNo,
    num subtotal,
    num total,
    String username,
    String role,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Order Details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: kPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: status == 'New'
                      ? Colors.green.withOpacity(0.15)
                      : kPrimary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: status == 'New'
                        ? Colors.green
                        : kPrimary.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: status == 'New' ? Colors.greenAccent : kPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: kItemBg, thickness: 1, height: 32),
          _buildSummaryRow(Icons.person, 'Customer', username),
          const SizedBox(height: 12),
          _buildSummaryRow(Icons.admin_panel_settings, 'Role', role),
          const SizedBox(height: 12),
          _buildSummaryRow(Icons.dining, 'Delivery Method', deliveryMethod),
          const SizedBox(height: 12),
          _buildSummaryRow(Icons.table_restaurant, 'Table No', tableNo),
          const Divider(color: kItemBg, thickness: 1, height: 32),
          _buildChargeRow('Subtotal', subtotal),
          const Divider(color: kItemBg, thickness: 1, height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(fontSize: 16, color: kMuted),
              ),
              Text(
                'CHF ${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: kWhite,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: kMuted, size: 20),
        const SizedBox(width: 12),
        Text('$label: ', style: const TextStyle(color: kMuted, fontSize: 15)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: kWhite,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChargeRow(String label, num value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: kMuted, fontSize: 15),
          ),
        ),
        Text(
          'CHF ${value.toStringAsFixed(2)}',
          style: const TextStyle(
            color: kWhite,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final String kind = item['kind'] ?? 'unknown';
    final String name = item['name'] ?? 'Unknown Item';
    final num price = item['price'] ?? 0;
    final num qty = item['qty'] ?? 1;
    final String imageUrl = item['imageUrl'] ?? '';
    final String category = (item['category'] ?? '').toString();
    final String iSize = item['size'] as String? ?? '';
    final String displayName = iSize.isNotEmpty ? '$name ($iSize)' : name;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kItemBg, width: 1.5),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _placeholderImage(),
                  )
                : _placeholderImage(),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$displayName  $qty',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: kWhite,
                        ),
                      ),
                    ),
                    Text(
                      'CHF ${(price * qty).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: kWhite,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (category.isNotEmpty) _tag(category, kPrimary),
                    // Which station prepares this line
                    _tag(
                      OrderStation.bar.ownsItem(item)
                          ? OrderStation.bar.title
                          : OrderStation.kitchen.title,
                      OrderStation.bar.ownsItem(item)
                          ? OrderStation.bar.accent
                          : OrderStation.kitchen.accent,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (iSize.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      '📏 Size/Portion: $iSize',
                      style: const TextStyle(
                        color: kMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (kind == 'drink') _buildDrinkDetails(item),
                if (kind == 'food' || kind == 'combo') _buildFoodDetails(item),
                _buildMenuChoices(item),
                _buildAdditionalOptions(item),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildMenuChoices(Map<String, dynamic> item) {
    final Map<String, dynamic> choices = Map<String, dynamic>.from(
      item['menuChoices'] ?? {},
    );
    if (choices.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: choices.entries
            .map(
              (e) => Text(
                '✔️ ${e.key}: ${e.value}',
                style: const TextStyle(color: kMuted, fontSize: 13),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildAdditionalOptions(Map<String, dynamic> item) {
    final List<dynamic> additionalOptions = item['additionalOptions'] ?? [];
    if (additionalOptions.isEmpty) return const SizedBox.shrink();

    final num price = item['price'] ?? 0;
    num addOnTotal = 0;
    for (var a in additionalOptions) {
      addOnTotal += (a['price'] as num?) ?? 0;
    }
    final num basePrice = price - addOnTotal;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Base Price: CHF ${basePrice.toStringAsFixed(2)}',
            style: const TextStyle(color: kMuted, fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            '➕ Extras:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: kPrimary,
            ),
          ),
          ...additionalOptions.map((addon) {
            final addonMap = addon as Map<String, dynamic>? ?? {};
            final String addonName = (addonMap['name'] ?? '').toString();
            final num addonPrice = addonMap['price'] ?? 0;
            return Text(
              '  • $addonName (+CHF ${addonPrice.toStringAsFixed(2)})',
              style: const TextStyle(color: kMuted, fontSize: 13),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDrinkDetails(Map<String, dynamic> item) {
    final String type = item['type'] ?? '';
    final String sugar = item['sugar'] ?? '';
    if (type.isEmpty && sugar.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (type.isNotEmpty)
            Text(
              '☕ Type: $type',
              style: const TextStyle(color: kMuted, fontSize: 13),
            ),
          if (sugar.isNotEmpty)
            Text(
              '🍬 Sugar: $sugar',
              style: const TextStyle(color: kMuted, fontSize: 13),
            ),
        ],
      ),
    );
  }

  Widget _buildFoodDetails(Map<String, dynamic> item) {
    final String note = item['note'] ?? '';
    final String extraNote = item['extraNote'] ?? '';
    if (note.isEmpty && extraNote.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (note.isNotEmpty)
            Text(
              '📝 Note: $note',
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 13),
            ),
          if (extraNote.isNotEmpty)
            Text(
              '📝 Extra Note: $extraNote',
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 13),
            ),
        ],
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: 80,
      height: 80,
      color: kItemBg,
      child: Icon(Icons.fastfood, color: kPrimary.withOpacity(0.5)),
    );
  }
}

// ==========================================
// 🖨️ PDF PRINTER UTILITY CLASS
// ==========================================
// ==========================================
// 🖨️ PDF PRINTER UTILITY CLASS (Updated for Epson TM-T88V)
// ==========================================
class OrderPrinter {
  static const MethodChannel _printerChannel = MethodChannel(
    'restaurantkleefeld/printer',
  );

  /// Builds the guest bill in the same layout as the restaurant's till
  /// receipt: centred header, one item per two lines, and a plain sum with no
  /// service charge added.
  static Future<void> generateAndPrintPdf(
    BuildContext context,
    Map<String, dynamic> orderData,
    bool isAutoPrint, {
    String? operatorName,
  }) async {
    final bill = BillData.fromOrder(orderData, operatorName: operatorName);
    final pdf = pw.Document();

    pw.Widget centered(String text, {double size = 11, bool bold = false}) {
      return pw.Center(
        child: pw.Text(
          text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: size,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              centered(RestaurantInfo.name, size: 13, bold: true),
              centered(RestaurantInfo.street, bold: true),
              centered(RestaurantInfo.city, bold: true),
              centered(RestaurantInfo.phone, bold: true),
              centered(RestaurantInfo.email, bold: true),
              centered(RestaurantInfo.vatId, bold: true),
              pw.SizedBox(height: 14),

              pw.Text(bill.title, style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 12),
              if (bill.tableLabel.isNotEmpty)
                pw.Text(
                  bill.tableLabel,
                  style: const pw.TextStyle(fontSize: 11),
                ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),

              // Each article prints as its name, then its amount underneath.
              ...bill.lines.map(
                (line) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4, left: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        line.label,
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                      pw.Text(
                        '${BillData.money(line.amount)} CHF',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),

              pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
              pw.Text(
                'Summe CHF:     ${bill.sumText}',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Divider(thickness: 1.2, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 10),

              pw.Text(
                'Datum ${bill.dateText}',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.Text(
                'Bediener: ${bill.operatorName}',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.Text(
                'Kasse: ${RestaurantInfo.till}',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.SizedBox(height: 16),

              ...RestaurantInfo.thankYou.map((l) => centered(l, bold: true)),
            ],
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();

    if (isAutoPrint && !kIsWeb) {
      try {
        final printed = await _printToNetworkPrinter(orderData);
        if (!printed) {
          throw Exception('Printer did not accept the receipt');
        }
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-printed Order #${orderData['order_id']}'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-print failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      try {
        final printed = await Printing.layoutPdf(
          dynamicLayout: false,
          format: PdfPageFormat.roll80,
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: 'Receipt_${orderData['order_id']}',
        );

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              printed
                  ? 'Print job sent for Order #${orderData['order_id']}'
                  : 'Printing was canceled for Order #${orderData['order_id']}',
            ),
            backgroundColor: printed ? Colors.green : Colors.orange,
          ),
        );
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not print order: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static Future<bool> _printToNetworkPrinter(
    Map<String, dynamic> orderData,
  ) async {
    final address = PrinterConfig.posPrinterIp
        .replaceFirst(RegExp(r'^(ipp|socket)://'), '')
        .split(':')
        .first
        .trim();
    if (address.isEmpty) {
      throw Exception('Printer IP address is empty');
    }

    // Same bill as the PDF, rendered as plain text for the till printer.
    final receipt = BillData.fromOrder(orderData).toPlainText().join('\n');

    return await _printerChannel.invokeMethod<bool>('printReceipt', {
          'address': address,
          'receipt': receipt,
        }) ??
        false;
  }
}
