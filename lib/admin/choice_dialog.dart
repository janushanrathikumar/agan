// lib/home/choice_dialog.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const kPrimary = Color(0xFFB59410);
const kWhite = Color(0xFFFFFFFF);
const kMuted = Color(0xFFB7B7B6);
const kFieldBg = Color(0xFF383735);
const kDialogBg = Color(0xFF333230);

class ChoiceDialog extends StatefulWidget {
  final String? docId;
  final String? existingHeading;
  final List<String>? existingOptions;
  // 🟢 New — Food/Drink tag for this choice group (e.g. "Spice Level" only
  // makes sense for Food, "Sugar Level" only for Drink). Null means "new
  // group, not set yet" and defaults to 'food' below.
  final String? existingType;

  const ChoiceDialog({
    super.key,
    this.docId,
    this.existingHeading,
    this.existingOptions,
    this.existingType,
  });

  @override
  State<ChoiceDialog> createState() => _ChoiceDialogState();
}

class _ChoiceDialogState extends State<ChoiceDialog> {
  late final TextEditingController _headingCtrl;
  late List<TextEditingController> _optionCtrls;
  // 🟢 Food/Drink state, seeded from existingType when editing.
  late String _selectedType;

  bool _saving = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _headingCtrl = TextEditingController(text: widget.existingHeading ?? '');

    final opts = widget.existingOptions ?? [];
    _optionCtrls = opts.isEmpty
        ? [TextEditingController()]
        : opts.map((o) => TextEditingController(text: o)).toList();

    _selectedType = widget.existingType ?? 'food';
  }

  @override
  void dispose() {
    _headingCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOptionField() {
    setState(() => _optionCtrls.add(TextEditingController()));
  }

  void _removeOptionField(int index) {
    if (_optionCtrls.length <= 1) return; // always keep at least one row
    setState(() {
      _optionCtrls[index].dispose();
      _optionCtrls.removeAt(index);
    });
  }

  Future<void> _save() async {
    final heading = _headingCtrl.text.trim();
    final options = _optionCtrls
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (heading.isEmpty) {
      setState(() => _err = 'Heading is required');
      return;
    }
    if (options.isEmpty) {
      setState(() => _err = 'Add at least one option');
      return;
    }

    setState(() {
      _saving = true;
      _err = null;
    });

    try {
      final data = <String, dynamic>{
        'heading': heading,
        'options': options,
        // 🟢 Saved so add_menu_item.dart's Menu Choices dropdown can
        // filter to only Food or only Drink choice groups.
        'type': _selectedType,
      };

      if (widget.docId == null) {
        // New group
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('menu_choices').add(data);
      } else {
        // Editing an existing group — merge so createdAt isn't lost.
        await FirebaseFirestore.instance
            .collection('menu_choices')
            .doc(widget.docId)
            .set(data, SetOptions(merge: true));
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _err = 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.docId != null;

    return Dialog(
      backgroundColor: kDialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'Edit Menu Choice' : 'Add Menu Choice',
                style: const TextStyle(
                  color: kWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),

              // 🟢 Food / Drink / Combo selector
              Container(
                decoration: BoxDecoration(
                  color: kFieldBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kPrimary.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        title: const Text(
                          'Food',
                          style: TextStyle(
                            color: kWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        value: 'food',
                        groupValue: _selectedType,
                        activeColor: kPrimary,
                        onChanged: (v) => setState(() => _selectedType = v!),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: kMuted.withOpacity(0.3),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        title: const Text(
                          'Drink',
                          style: TextStyle(
                            color: kWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        value: 'drink',
                        groupValue: _selectedType,
                        activeColor: kPrimary,
                        onChanged: (v) => setState(() => _selectedType = v!),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: kMuted.withOpacity(0.3),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        title: const Text(
                          'Combo',
                          style: TextStyle(
                            color: kWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        value: 'combo',
                        groupValue: _selectedType,
                        activeColor: kPrimary,
                        onChanged: (v) => setState(() => _selectedType = v!),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Heading field
              TextField(
                controller: _headingCtrl,
                style: const TextStyle(color: kWhite),
                decoration: InputDecoration(
                  labelText: 'Heading (e.g. Size, Spice Level, Sugar Level)',
                  labelStyle: const TextStyle(color: kMuted),
                  filled: true,
                  fillColor: kFieldBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Options',
                    style: TextStyle(
                      color: kWhite,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: kPrimary),
                    onPressed: _addOptionField,
                  ),
                ],
              ),
              ..._optionCtrls.asMap().entries.map((entry) {
                final index = entry.key;
                final ctrl = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ctrl,
                          style: const TextStyle(color: kWhite),
                          decoration: InputDecoration(
                            hintText: 'Option ${index + 1}',
                            hintStyle: const TextStyle(color: kMuted),
                            filled: true,
                            fillColor: kFieldBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: _optionCtrls.length > 1
                            ? () => _removeOptionField(index)
                            : null,
                      ),
                    ],
                  ),
                );
              }),

              if (_err != null) ...[
                const SizedBox(height: 8),
                Text(_err!, style: const TextStyle(color: Colors.redAccent)),
              ],

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: kMuted)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: kPrimary),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: kWhite,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(isEditing ? 'Save Changes' : 'Save'),
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