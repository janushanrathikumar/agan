import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// --- Palette ---
const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);
const kCardBg = Color(0xFF383735);
const kItemBg = Color(0xFF2F2E2D);

// ==========================================
// 1. MAIN LIST PAGE (Dark Theme)
// ==========================================
class AdminOrdersListPage extends StatelessWidget {
  const AdminOrdersListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text(
          'All Orders',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: kBg,
        foregroundColor: kWhite,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
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
              child: Text('No orders found.', style: TextStyle(color: kMuted)),
            );
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: orders.length,
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

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kMuted.withOpacity(0.1)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  // நீங்கள் கேட்ட Circular Icon Design
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kPrimary.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: kPrimary.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      color: kPrimary,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    'Order #$orderId',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kWhite,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '$date • $status',
                      style: const TextStyle(color: kMuted, fontSize: 13),
                    ),
                  ),
                  trailing: Text(
                    // 🟢 RM -> CHF
                    'CHF ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: kPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AdminOrderDetailsPage(documentId: doc.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// ==========================================
// 2. ORDER DETAILS PAGE (PDF Bill Integration)
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
            appBar: AppBar(title: const Text('Error'), backgroundColor: kBg),
            body: const Center(
              child: Text('Order not found.', style: TextStyle(color: kMuted)),
            ),
          );
        }

        final Map<String, dynamic> orderData =
            snapshot.data!.data() as Map<String, dynamic>;

        final String orderId = orderData['order_id'] ?? documentId;
        final String status = orderData['status'] ?? 'Unknown';
        // 🟢 Read delivery_method / table_no directly off the order doc
        // (this is now saved at order time, see payment_page.dart).
        final String deliveryMethod = orderData['delivery_method'] ?? 'N/A';
        final String tableNo = (orderData['table_no'] ?? 'N/A').toString();
        final num total = orderData['total'] ?? 0;
        final List<dynamic> items = orderData['items'] ?? [];

        // 🟢 Charges breakdown — subtotal / service charge / rate are now
        // saved on the order doc by payment_page.dart. Older orders placed
        // before this change won't have these fields, so we fall back to
        // treating the whole total as the subtotal with a 0% service charge
        // rather than crashing or showing null.
        final num subtotal = orderData['subtotal'] ?? total;
        final num serviceCharge = orderData['service_charge'] ?? 0;
        final num serviceChargeRate = orderData['service_charge_rate'] ?? 0;

        return Scaffold(
          backgroundColor: kBg,
          appBar: AppBar(
            title: Text('Order #$orderId'),
            backgroundColor: kBg,
            foregroundColor: kWhite,
            elevation: 0,
            actions: [
              // 🖨️ PDF Print Button
              Container(
                margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kPrimary.withOpacity(0.3)),
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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderSummaryCard(
                  orderId,
                  status,
                  deliveryMethod,
                  tableNo,
                  subtotal,
                  serviceCharge,
                  serviceChargeRate,
                  total,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Order Items',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kWhite,
                  ),
                ),
                const SizedBox(height: 12),
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

    // 🟢 Same fallback logic as the details page: older orders without
    // these fields just show the total as the subtotal with no service
    // charge line, instead of throwing.
    final num subtotal = orderData['subtotal'] ?? total;
    final num serviceCharge = orderData['service_charge'] ?? 0;
    final num serviceChargeRate = orderData['service_charge_rate'] ?? 0;

    // Receipt Format (80mm Thermal Printer standard width)
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
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
              pw.Text('Type: ${orderData['delivery_method']}'),
              if ((orderData['table_no'] ?? 'N/A') != 'N/A' &&
                  (orderData['table_no'] ?? '').toString().isNotEmpty)
                pw.Text('Table No: ${orderData['table_no']}'),
              pw.Text('Date: ${DateTime.now().toString().substring(0, 16)}'),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 5),

              // Items Header
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

              // Items List
              ...items.map((item) {
                final String name = item['name'] ?? 'Item';
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
                          // 🟢 RM -> CHF
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

              // 🟢 Subtotal row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal'),
                  pw.Text('CHF ${subtotal.toStringAsFixed(2)}'),
                ],
              ),
              pw.SizedBox(height: 3),

              // 🟢 Service charge row — label includes the rate that was
              // actually applied (2.6% take-away / 8.1% dine-in), so the
              // printed bill is self-explanatory rather than just showing
              // a number with no context.
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

              // Total
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
                    // 🟢 RM -> CHF
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

    // Shows the print dialog (which also has a "Save as PDF" option)
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
  ) {
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order Details',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: kPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: status == 'New'
                      ? Colors.green.withOpacity(0.2)
                      : kMuted.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: status == 'New' ? Colors.green : kMuted,
                  ),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: status == 'New' ? Colors.greenAccent : kMuted,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: kItemBg, thickness: 1, height: 24),
          _buildSummaryRow(Icons.dining, 'Delivery Method', deliveryMethod),
          const SizedBox(height: 8),
          _buildSummaryRow(Icons.table_restaurant, 'Table No', tableNo),
          const Divider(color: kItemBg, thickness: 1, height: 24),

          // 🟢 Charges breakdown: subtotal, service charge (with the rate
          // that was actually applied), then the grand total.
          _buildChargeRow('Subtotal', subtotal),
          const SizedBox(height: 8),
          _buildChargeRow(
            'Service Charge (${_methodLabel(deliveryMethod)} • ${(serviceChargeRate * 100).toStringAsFixed(1)}%)',
            serviceCharge,
          ),
          const Divider(color: kItemBg, thickness: 1, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(fontSize: 16, color: kMuted),
              ),
              Text(
                // 🟢 RM -> CHF
                'CHF ${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
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
        Icon(icon, color: kMuted, size: 18),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: kMuted, fontSize: 14)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
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

  // 🟢 Human-readable label for the delivery method, used to make the
  // service-charge line self-explanatory (e.g. "Service Charge (Dine-In •
  // 8.1%)") instead of just showing a bare percentage.
  String _methodLabel(String method) {
    return method == 'Take_Away' ? 'Take-Away' : 'Dine-In';
  }

  // 🟢 Small helper row for the subtotal / service-charge breakdown.
  Widget _buildChargeRow(String label, num value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: kMuted, fontSize: 14)),
        Text(
          'CHF ${value.toStringAsFixed(2)}',
          style: const TextStyle(
            color: kWhite,
            fontWeight: FontWeight.bold,
            fontSize: 14,
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
    // 🟢 category is now saved on every item kind (drinks included), so
    // show it as a small chip under the item name.
    final String category = (item['category'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kItemBg,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _placeholderImage(),
                  )
                : _placeholderImage(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$name  x$qty',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: kWhite,
                        ),
                      ),
                    ),
                    Text(
                      'CHF ${(price * qty).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: kWhite,
                      ),
                    ),
                  ],
                ),
                if (category.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: kPrimary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        color: kPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                // Kind-specific details
                if (kind == 'drink') _buildDrinkDetails(item),
                // 🟢 'food' AND 'combo' items both use the food-style
                // note/extraNote layout, so combo orders (like the
                // "Buger combo" items in your sample data) now render their
                // details instead of showing nothing.
                if (kind == 'food' || kind == 'combo') _buildFoodDetails(item),

                // 🟢 Menu choices (e.g. size/spice level) and add-ons now
                // apply to EVERY kind — your sample shows a drink item
                // ("Cappuccino") carrying both menuChoices and
                // additionalOptions, which the old code never rendered.
                _buildMenuChoices(item),
                _buildAdditionalOptions(item),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🟢 Resolves each menuChoices entry (groupId -> selected value) against
  // the `menu_choices` collection to show a readable heading, e.g.
  // "Size: Large" instead of a raw document ID with no label.
  Widget _buildMenuChoices(Map<String, dynamic> item) {
    final Map<String, dynamic> choices = Map<String, dynamic>.from(
      item['menuChoices'] ?? {},
    );
    if (choices.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
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
                style: const TextStyle(color: kMuted, fontSize: 12),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // 🟢 Additional options / add-ons, now shown for every item kind
  // (previously only rendered inside the food-only details block, so
  // drink add-ons like "extra" on a Cappuccino never appeared).
  Widget _buildAdditionalOptions(Map<String, dynamic> item) {
    final List<dynamic> additionalOptions = item['additionalOptions'] ?? [];
    if (additionalOptions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add-ons:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
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
              style: const TextStyle(color: kMuted, fontSize: 12),
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
            style: const TextStyle(color: kMuted, fontSize: 13),
          ),
        if (sugar.isNotEmpty)
          Text(
            'Sugar: $sugar',
            style: const TextStyle(color: kMuted, fontSize: 13),
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
            style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
          ),
        if (extraNote.isNotEmpty)
          Text(
            'Extra: $extraNote',
            style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
          ),
      ],
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: 70,
      height: 70,
      color: kCardBg,
      child: Icon(Icons.fastfood, color: kPrimary.withOpacity(0.5)),
    );
  }
}
