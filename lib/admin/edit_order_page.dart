// lib/admin/edit_order_page.dart
//
// Lets an admin correct an order after the fact - including one that has
// already been completed and paid.
//
// Every money figure is derived, never typed: change a quantity or remove a
// line and the total is recalculated on the spot and saved with it, so the
// order can never be left with items that disagree with what was charged.
// Nothing is added on top of the items - there is no service charge.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF2A2928);
const kWhite = Color(0xFFFFFFFF);
const kMuted = Color(0xFFB7B7B6);
const kCardBg = Color(0xFF383735);
const kItemBg = Color(0xFF2F2E2D);

class EditOrderPage extends StatefulWidget {
  const EditOrderPage({
    super.key,
    required this.documentId,
    required this.orderData,
  });

  final String documentId;
  final Map<String, dynamic> orderData;

  @override
  State<EditOrderPage> createState() => _EditOrderPageState();
}

class _EditOrderPageState extends State<EditOrderPage> {
  late List<Map<String, dynamic>> _items;
  late TextEditingController _tableCtrl;
  late TextEditingController _chairCtrl;
  late String _deliveryMethod;
  late String _status;
  late String _paymentMethod;

  bool _saving = false;
  String? _error;

  static const _statuses = ['New', 'Completed', 'Delivered', 'Canceled'];
  static const _methods = ['Dine_In', 'Take_Away'];

  @override
  void initState() {
    super.initState();
    final data = widget.orderData;

    _items = (data['items'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    _tableCtrl = TextEditingController(
      text: (data['table_no'] ?? '').toString(),
    );
    _chairCtrl = TextEditingController(
      text: (data['chair_no'] ?? '').toString(),
    );

    final method = (data['delivery_method'] ?? 'Dine_In').toString();
    _deliveryMethod = _methods.contains(method) ? method : 'Dine_In';

    final status = (data['status'] ?? 'New').toString();
    _status = _statuses.contains(status) ? status : 'New';

    _paymentMethod = (data['payment_method'] ?? '').toString();
  }

  @override
  void dispose() {
    _tableCtrl.dispose();
    _chairCtrl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- totals

  double get _subtotal {
    var sum = 0.0;
    for (final item in _items) {
      final qty = ((item['qty'] as num?) ?? 1).toInt();
      final price = ((item['price'] as num?) ?? 0).toDouble();
      sum += price * qty;
    }
    return sum;
  }

  /// The guest pays exactly the sum of the items.
  double get _total => _subtotal;

  // -------------------------------------------------------------- editing

  void _changeQty(int index, int delta) {
    setState(() {
      final qty = ((_items[index]['qty'] as num?) ?? 1).toInt() + delta;
      if (qty < 1) return;
      _items[index]['qty'] = qty;
    });
  }

  Future<void> _removeItem(int index) async {
    final name = (_items[index]['name'] ?? 'this item').toString();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('Remove item?', style: TextStyle(color: kWhite)),
        content: Text(
          'Remove "$name" from this order? The total will be recalculated.',
          style: const TextStyle(color: kMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: kMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) setState(() => _items.removeAt(index));
  }

  Future<void> _save() async {
    if (_items.isEmpty) {
      setState(
        () => _error = 'An order needs at least one item. Delete it instead.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.documentId)
          .set({
            'items': _items,
            'table_no': _tableCtrl.text.trim(),
            'chair_no': _chairCtrl.text.trim(),
            'delivery_method': _deliveryMethod,
            'status': _status,
            // Recalculated, never carried over from the old order.
            'subtotal': _subtotal,
            'total': _total,
            if (_paymentMethod.isNotEmpty) 'payment_method': _paymentMethod,
            'edited_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order updated.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save: $e';
      });
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final orderId = (widget.orderData['order_id'] ?? widget.documentId)
        .toString();

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kWhite,
        elevation: 0,
        title: Text('Edit Order #$orderId'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Items'),
            ..._items.asMap().entries.map((e) => _itemRow(e.key, e.value)),

            const SizedBox(height: 24),
            _sectionTitle('Order details'),
            Row(
              children: [
                Expanded(child: _textField(_tableCtrl, 'Table No.')),
                const SizedBox(width: 12),
                Expanded(child: _textField(_chairCtrl, 'Chair No.')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _dropdown(
                    label: 'Type',
                    value: _deliveryMethod,
                    items: _methods,
                    onChanged: (v) => setState(() => _deliveryMethod = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dropdown(
                    label: 'Status',
                    value: _status,
                    items: _statuses,
                    onChanged: (v) => setState(() => _status = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _dropdown(
              label: 'Payment',
              value: _paymentMethod.isEmpty ? 'Not paid' : _paymentMethod,
              items: const ['Not paid', 'Cash', 'Card'],
              onChanged: (v) => setState(
                () => _paymentMethod = v == 'Not paid' ? '' : v,
              ),
            ),

            const SizedBox(height: 24),
            _sectionTitle('Totals'),
            _totalsCard(),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: kWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: kWhite,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving…' : 'Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          color: kPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _itemRow(int index, Map<String, dynamic> item) {
    final name = (item['name'] ?? 'Item').toString();
    final size = (item['size'] ?? '').toString();
    final qty = ((item['qty'] as num?) ?? 1).toInt();
    final price = ((item['price'] as num?) ?? 0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  size.isEmpty ? name : '$name ($size)',
                  style: const TextStyle(
                    color: kWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'CHF ${price.toStringAsFixed(2)} each',
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: kPrimary),
            onPressed: qty > 1 ? () => _changeQty(index, -1) : null,
          ),
          Text(
            '$qty',
            style: const TextStyle(
              color: kWhite,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: kPrimary),
            onPressed: () => _changeQty(index, 1),
          ),
          SizedBox(
            width: 90,
            child: Text(
              'CHF ${(price * qty).toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: kWhite,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Remove item',
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.redAccent,
              size: 20,
            ),
            onPressed: () => _removeItem(index),
          ),
        ],
      ),
    );
  }

  Widget _totalsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _totalRow('Subtotal', _subtotal),
          const Divider(color: kItemBg, height: 24),
          _totalRow('Total', _total, emphasise: true),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool emphasise = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: emphasise ? kWhite : kMuted,
            fontSize: emphasise ? 16 : 14,
            fontWeight: emphasise ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          'CHF ${value.toStringAsFixed(2)}',
          style: TextStyle(
            color: emphasise ? kPrimary : kWhite,
            fontSize: emphasise ? 20 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _textField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: kWhite),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kMuted),
        filled: true,
        fillColor: kCardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kPrimary, width: 1.5),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kMuted),
        filled: true,
        fillColor: kCardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: kCardBg,
          style: const TextStyle(color: kWhite),
          items: items
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
