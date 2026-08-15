import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// --- Palette (Your Original Colors) ---
const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);
const kCardBg = Color(0xFF383735);
const kItemBg = Color(0xFF2F2E2D);

// ==========================================
// 1. MAIN LIST PAGE (Modern Design - NO Sidebar & Working Search & Back Arrow)
// ==========================================
class AdminOrdersListPage extends StatefulWidget {
  const AdminOrdersListPage({super.key});

  @override
  State<AdminOrdersListPage> createState() => _AdminOrdersListPageState();
}

class _AdminOrdersListPageState extends State<AdminOrdersListPage> {
  String _selectedTab = 'All Status';
  String _searchQuery = '';
  final List<String> _tabs = ['All Status', 'New', 'Delivered', 'Canceled'];

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

  // --- Top Header (Full Width with BACK ARROW) ---
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: kWhite, size: 22),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
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
          // Search Bar
          Container(
            width: 280,
            height: 45,
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: kItemBg, width: 1.5),
            ),
            child: TextField(
              style: const TextStyle(color: kWhite),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: const InputDecoration(
                hintText: 'Search order ID...',
                hintStyle: TextStyle(color: kMuted),
                prefixIcon: Icon(Icons.search, color: kMuted),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 24),
          const CircleAvatar(
            backgroundColor: kPrimary,
            radius: 22,
            child: Icon(Icons.admin_panel_settings, color: kWhite),
          ),
        ],
      ),
    );
  }

  // --- Status Tabs ---
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

  // --- Table Header ---
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

  // --- Orders List (Table Rows) ---
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
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No orders found.',
              style: TextStyle(color: kMuted, fontSize: 16),
            ),
          );
        }

        var orders = snapshot.data!.docs;

        // Filter based on Selected Tab
        if (_selectedTab != 'All Status') {
          orders = orders.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'Unknown';
            return status.toString().toLowerCase() ==
                _selectedTab.toLowerCase();
          }).toList();
        }

        // Filter based on Search Query
        if (_searchQuery.isNotEmpty) {
          orders = orders.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final String orderId = (data['order_id'] ?? doc.id).toString();
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
    if (status == 'New') {
      color = Colors.greenAccent;
    } else if (status == 'Canceled') {
      color = Colors.redAccent;
    } else {
      color = kPrimary;
    }

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
// 2. ORDER DETAILS PAGE (Modern Card Design & Explicit Back Arrow)
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
        final num serviceCharge = orderData['service_charge'] ?? 0;
        final num serviceChargeRate = orderData['service_charge_rate'] ?? 0;

        // 🟢 Extract Username and Role from Firestore Order Data
        final String username = orderData['username'] ?? 'Guest';
        final String role = orderData['role'] ?? 'Customer';

        // 🟢 Extract Table and Chair No
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
              Container(
                margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kPrimary.withOpacity(0.5)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.print, color: kPrimary),
                  tooltip: 'Print PDF Receipt',
                  onPressed: () => _generateAndPrintPdf(context, orderData),
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
                  displayTable, // 🟢 Passed displayTable instead of raw tableNo
                  subtotal,
                  serviceCharge,
                  serviceChargeRate,
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

  // ==========================================
  // 🖨️ PROFESSIONAL PDF RECEIPT GENERATOR
  // ==========================================
  Future<void> _generateAndPrintPdf(
    BuildContext context,
    Map<String, dynamic> orderData,
  ) async {
    final pdf = pw.Document();
    final items = orderData['items'] ?? [];
    final total = orderData['total'] ?? 0;
    final num subtotal = orderData['subtotal'] ?? total;
    final num serviceCharge = orderData['service_charge'] ?? 0;
    final num serviceChargeRate = orderData['service_charge_rate'] ?? 0;

    // 🟢 Extract Username and Role for the PDF
    final String username = orderData['username'] ?? 'Guest';
    final String role = orderData['role'] ?? 'Customer';

    // 🟢 Extract and format Table and Chair No for PDF
    final String rawTableNo = (orderData['table_no'] ?? 'N/A').toString();
    final String rawChairNo = (orderData['chair_no'] ?? '').toString();
    final String displayTable = rawChairNo.isNotEmpty && rawTableNo != 'N/A'
        ? '$rawTableNo (Chair $rawChairNo)'
        : rawTableNo;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'AGAN RESTAURANT',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Order ID: ${orderData['order_id']}'),
              pw.Text('Customer: $username ($role)'),
              pw.Text('Type: ${orderData['delivery_method']}'),
              // 🟢 Formatted table string shown here
              if (rawTableNo != 'N/A' && rawTableNo.isNotEmpty)
                pw.Text('Table No: $displayTable'),
              pw.Text('Date: ${DateTime.now().toString().substring(0, 16)}'),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 5),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      'Item',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      'Qty',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Amount',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ],
              ),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 5),

              ...items.map((item) {
                final String baseName = item['name'] ?? 'Item';
                final String size = item['size'] ?? '';
                final String name = size.isNotEmpty
                    ? '$baseName ($size)'
                    : baseName;
                final num qty = item['qty'] ?? 1;
                final num price = item['price'] ?? 0;
                final num lineTotal = price * qty;

                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(flex: 3, child: pw.Text(name)),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text('x$qty', textAlign: pw.TextAlign.center),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          'CHF ${lineTotal.toStringAsFixed(2)}',
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),

              pw.SizedBox(height: 5),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal'),
                  pw.Text('CHF ${subtotal.toStringAsFixed(2)}'),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Service Charge (${_methodLabel((orderData['delivery_method'] ?? '').toString())} • ${(serviceChargeRate * 100).toStringAsFixed(1)}%)',
                  ),
                  pw.Text('CHF ${serviceCharge.toStringAsFixed(2)}'),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'CHF ${total.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text(
                  '*** Thank You! ***',
                  style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Receipt_${orderData['order_id']}',
    );
  }

  // --- Widgets ---
  Widget _buildOrderSummaryCard(
    String orderId,
    String status,
    String deliveryMethod,
    String tableNo,
    num subtotal,
    num serviceCharge,
    num serviceChargeRate,
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
          const SizedBox(height: 12),
          _buildChargeRow(
            'Service Charge (${_methodLabel(deliveryMethod)} • ${(serviceChargeRate * 100).toStringAsFixed(1)}%)',
            serviceCharge,
          ),
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

  String _methodLabel(String method) =>
      method == 'Take_Away' ? 'Take-Away' : 'Dine-In';

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
                        '$displayName  x$qty',
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
                if (category.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: kPrimary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        color: kPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (iSize.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      '📏 Portion: $iSize',
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

  Widget _buildMenuChoices(Map<String, dynamic> item) {
    final Map<String, dynamic> choices = Map<String, dynamic>.from(
      item['menuChoices'] ?? {},
    );
    if (choices.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: FutureBuilder<List<DocumentSnapshot>>(
        future: Future.wait(
          choices.keys.map(
            (id) => FirebaseFirestore.instance
                .collection('menu_choices')
                .doc(id)
                .get(),
          ),
        ),
        builder: (context, snap) {
          final headings = <String, String>{};
          if (snap.hasData) {
            for (final doc in snap.data!) {
              if (doc.exists) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                headings[doc.id] = (data['heading'] as String?) ?? '';
              }
            }
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: choices.entries.map((e) {
              final label = headings[e.key];
              final display = (label != null && label.isNotEmpty)
                  ? '$label: ${e.value}'
                  : '${e.value}';
              return Text(
                '• $display',
                style: const TextStyle(color: kMuted, fontSize: 13),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildAdditionalOptions(Map<String, dynamic> item) {
    final List<dynamic> additionalOptions = item['additionalOptions'] ?? [];
    if (additionalOptions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add-ons:',
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
            final String catalog = (addonMap['catalog'] ?? '').toString();
            final label = catalog.isNotEmpty
                ? '$addonName ($catalog)'
                : addonName;
            return Text(
              '- $label (+CHF ${addonPrice.toStringAsFixed(2)})',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (type.isNotEmpty)
          Text(
            'Type: $type',
            style: const TextStyle(color: kMuted, fontSize: 14),
          ),
        if (sugar.isNotEmpty)
          Text(
            'Sugar: $sugar',
            style: const TextStyle(color: kMuted, fontSize: 14),
          ),
      ],
    );
  }

  Widget _buildFoodDetails(Map<String, dynamic> item) {
    final String note = item['note'] ?? '';
    final String extraNote = item['extraNote'] ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (note.isNotEmpty)
          Text(
            'Note: $note',
            style: const TextStyle(color: Colors.orangeAccent, fontSize: 13),
          ),
        if (extraNote.isNotEmpty)
          Text(
            'Extra: $extraNote',
            style: const TextStyle(color: Colors.orangeAccent, fontSize: 13),
          ),
      ],
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
