// lib/admin/app_offer_sheet.dart
//
// Sets the offer a menu gets only when it is ordered in the phone app.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:restorant/admin/offer_preview.dart';
import 'package:restorant/shared/menu_offer.dart';

const _kPrimary = Color(0xFFB59410);
const _kBg = Color(0xFF2A2928);
const _kField = Color(0xFF383735);
const _kWhite = Color(0xFFFFFFFF);
const _kMuted = Color(0xFFB7B7B6);

/// Opens the app offer editor for one menu document.
Future<void> showAppOfferSheet(
  BuildContext context,
  String docId,
  Map<String, dynamic> data,
) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: _kBg,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _AppOfferForm(docId: docId, data: data),
  );
}

class _AppOfferForm extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _AppOfferForm({required this.docId, required this.data});

  @override
  State<_AppOfferForm> createState() => _AppOfferFormState();
}

class _AppOfferFormState extends State<_AppOfferForm> {
  late bool _active;
  late String _type;
  late final TextEditingController _value;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _active = widget.data['appOfferActive'] == true;
    _type = widget.data['appOfferType'] == 'amount' ? 'amount' : 'percent';
    final value = (widget.data['appOfferValue'] as num?)?.toDouble() ?? 0;
    _value = TextEditingController(
      text: value > 0 ? value.toString().replaceAll(RegExp(r'\.0$'), '') : '',
    );
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  bool get _hasSizes =>
      widget.data['hasMultipleSizes'] == true &&
      (widget.data['sizes'] as List<dynamic>? ?? const []).isNotEmpty;

  Future<void> _save() async {
    final value = double.tryParse(_value.text.trim().replaceAll(',', '.'));
    if (_active &&
        (value == null ||
            value <= 0 ||
            (_type == 'percent' && value > 100) ||
            (_type == 'amount' &&
                !_hasSizes &&
                value >= menuOriginalPrice(widget.data)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid app offer: 1–100% or an amount below the price.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('menu_items')
          .doc(widget.docId)
          .update({
            'appOfferActive': _active,
            'appOfferType': _active ? _type : null,
            'appOfferValue': _active ? value : 0,
          });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _active ? 'App offer is live.' : 'App offer switched off.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.data['name'] ?? '').toString();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.phone_iphone_rounded, color: _kPrimary),
                SizedBox(width: 8),
                Text(
                  'App Offer Price',
                  style: TextStyle(
                    color: _kWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(name, style: const TextStyle(color: _kMuted, fontSize: 14)),
            const SizedBox(height: 4),
            const Text(
              'Only orders from the iPhone and Android app get this price. '
              'The website shows the offer on the home page and sends guests '
              'to download the app.',
              style: TextStyle(color: _kMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: Colors.greenAccent,
              title: const Text(
                'App offer on',
                style: TextStyle(color: _kWhite, fontWeight: FontWeight.bold),
              ),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            if (_active) ...[
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'percent', label: Text('Percent %')),
                  ButtonSegment(value: 'amount', label: Text('Amount CHF')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
                style: SegmentedButton.styleFrom(
                  foregroundColor: _kMuted,
                  selectedForegroundColor: _kWhite,
                  selectedBackgroundColor: _kPrimary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _value,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(color: _kWhite, fontSize: 18),
                decoration: InputDecoration(
                  labelText: _type == 'percent'
                      ? 'App discount (%)'
                      : 'App discount (CHF)',
                  labelStyle: const TextStyle(color: _kPrimary),
                  filled: true,
                  fillColor: _kField,
                  prefixIcon: const Icon(Icons.local_offer, color: _kPrimary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              OfferPreview(
                discountType: _type,
                discountValue: _value,
                originalPrice: () =>
                    _hasSizes ? null : menuOriginalPrice(widget.data),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _kPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: _kWhite,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save App Offer',
                        style: TextStyle(
                          color: _kWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
