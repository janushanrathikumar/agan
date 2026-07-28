// lib/add_menu_item.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'choice_dialog.dart';
import 'manage_menu_items.dart';

// Web Image CORS error avoidance imports
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

// --- Your Exact Color Constants ---
const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF2A2928);
const kWhite = Color(0xFFFFFFFF);
const kMuted = Color(0xFFB7B7B6);
const kFieldBg = Color(0xFF383735);
// ----------------------------------

// 🟢 Helper class for dynamic Size Option rows
class SizeOptionField {
  final TextEditingController name = TextEditingController();
  final TextEditingController price = TextEditingController();

  void dispose() {
    name.dispose();
    price.dispose();
  }
}

// 🟢 Helper class for dynamic Additional Option rows
class AdditionalOptionField {
  final TextEditingController name = TextEditingController();
  final TextEditingController price = TextEditingController();
  final TextEditingController catalog = TextEditingController();

  void dispose() {
    name.dispose();
    price.dispose();
    catalog.dispose();
  }
}

class AddMenuPage extends StatefulWidget {
  const AddMenuPage({super.key});

  @override
  State<AddMenuPage> createState() => _AddMenuPageState();
}

class _AddMenuPageState extends State<AddMenuPage> {
  final _name = TextEditingController();
  final _note = TextEditingController();
  final _price = TextEditingController(); // Standard single price

  // 🟢 Size Options state
  bool _hasMultipleSizes = false;
  final List<SizeOptionField> _sizeOptions = [];

  // 🟢 Additional Options state
  final List<AdditionalOptionField> _additionalOptions = [];

  Uint8List? _imgBytes;
  String? _imgFileName;

  String? _selectedCategory;
  String? _selectedCategoryIconUrl;

  String _itemType = 'food'; // 'food' or 'drink'

  // 🟢 Discount state
  bool _hasDiscount = false;
  String _discountType = 'percent'; // 'percent' or 'amount'
  final _discountValue = TextEditingController();

  List<Map<String, dynamic>> _allAvailableChoices = [];
  final List<Map<String, dynamic>> _selectedMenuChoices = [];
  String? _dropdownChoiceValue;

  bool _saving = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _fetchAvailableMenuChoices();
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    _price.dispose();
    _discountValue.dispose();
    for (var opt in _sizeOptions) {
      opt.dispose();
    }
    for (var opt in _additionalOptions) {
      opt.dispose();
    }
    super.dispose();
  }

  // 🟢 Add / Remove Size option fields
  void _addSizeField() =>
      setState(() => _sizeOptions.add(SizeOptionField()));

  void _removeSizeField(int index) {
    _sizeOptions[index].dispose();
    setState(() => _sizeOptions.removeAt(index));
  }

  // 🟢 Add / Remove Additional option fields
  void _addOptionField() =>
      setState(() => _additionalOptions.add(AdditionalOptionField()));

  void _removeOptionField(int index) {
    _additionalOptions[index].dispose();
    setState(() => _additionalOptions.removeAt(index));
  }

  Future<void> _fetchAvailableMenuChoices() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('menu_choices')
          .get();
      if (mounted) {
        setState(() {
          _allAvailableChoices = snap.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching choices: $e");
    }
  }

  void _openEditChoiceDialog(Map<String, dynamic> choiceData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ChoiceDialog(
        docId: choiceData['id'],
        existingHeading: choiceData['heading'] ?? '',
        existingOptions: List<String>.from(choiceData['options'] ?? []),
        existingType: (choiceData['type'] as String?) ?? 'food',
      ),
    ).then((_) => _fetchAvailableMenuChoices());
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 90,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _imgBytes = bytes;
      _imgFileName = x.name;
    });
  }

  String _guessContentType(String? filename) {
    final ext = filename?.split('.').last.toLowerCase();
    if (ext == 'jpg' || ext == 'jpeg') return 'image/jpeg';
    if (ext == 'webp') return 'image/webp';
    if (ext == 'png') return 'image/png';
    return 'image/jpeg';
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _err = null;
    });

    try {
      final name = _name.text.trim();
      final note = _note.text.trim();

      if (name.isEmpty) throw Exception('Name is required.');
      if (_selectedCategory == null) throw Exception('Select a category.');
      if (_imgBytes == null) throw Exception('Pick an image.');

      // 🟢 Validate Prices based on Size Strategy
      double? basePrice;
      List<Map<String, dynamic>> sizesData = [];

      if (_hasMultipleSizes) {
        if (_sizeOptions.isEmpty) {
          throw Exception('Please add at least one size variant.');
        }
        for (var size in _sizeOptions) {
          final sName = size.name.text.trim();
          final sPrice = double.tryParse(size.price.text.trim());
          if (sName.isEmpty || sPrice == null) {
            throw Exception('All sizes must have a valid name and price.');
          }
          sizesData.add({'name': sName, 'price': sPrice});
        }
        // Set the primary basePrice to the lowest size price for sorting/display defaults
        basePrice = sizesData.map((e) => e['price'] as double).reduce((a, b) => a < b ? a : b);
      } else {
        basePrice = double.tryParse(_price.text.trim());
        if (basePrice == null) {
          throw Exception('A valid standard price is required.');
        }
      }

      // 🟢 Validate discount value if discount is enabled
      double discountValue = 0;
      if (_hasDiscount) {
        discountValue = double.tryParse(_discountValue.text.trim()) ?? 0;
        if (discountValue <= 0) {
          throw Exception('Enter a valid discount value');
        }
        if (_discountType == 'percent' && discountValue > 100) {
          throw Exception('Discount percent cannot exceed 100');
        }
      }

      // 🟢 Serialize Additional Options
      List<Map<String, dynamic>> optionsData = _additionalOptions.map((opt) {
        return {
          'name': opt.name.text.trim(),
          'price': double.tryParse(opt.price.text.trim()) ?? 0,
          'catalog': opt.catalog.text.trim(),
        };
      }).toList();

      final safeBase = (_imgFileName ?? name).replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]+'),
        '_',
      );
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$safeBase';
      final imgRef = FirebaseStorage.instance.ref('menu_images/$fileName');

      await imgRef.putData(
        _imgBytes!,
        SettableMetadata(contentType: _guessContentType(_imgFileName)),
      );
      final imageUrl = await imgRef.getDownloadURL();
      final List<String> choiceIds = _selectedMenuChoices
          .map((c) => c['id'] as String)
          .toList();

      await FirebaseFirestore.instance.collection('menu_items').add({
        'name': name,
        'note': note.isEmpty ? null : note,
        'price': basePrice,
        'hasMultipleSizes': _hasMultipleSizes,
        'sizes': sizesData,
        'category': _selectedCategory,
        'categoryIconUrl': _selectedCategoryIconUrl,
        'imageUrl': imageUrl,
        'imageFileName': fileName,
        'menuChoices': choiceIds,
        'additionalOptions': optionsData,
        'status': 'on',
        'itemType': _itemType,
        'hasDiscount': _hasDiscount,
        'discountType': _hasDiscount ? _discountType : null,
        'discountValue': _hasDiscount ? discountValue : 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved successfully'),
          backgroundColor: kPrimary,
        ),
      );

      _name.clear();
      _note.clear();
      _price.clear();
      setState(() {
        _imgBytes = null;
        _imgFileName = null;
        _selectedCategory = null;
        _selectedCategoryIconUrl = null;
        _selectedMenuChoices.clear();
        _dropdownChoiceValue = null;
        _hasDiscount = false;
        _discountType = 'percent';
        _discountValue.clear();
        _hasMultipleSizes = false;
        
        for (var opt in _sizeOptions) {
          opt.dispose();
        }
        _sizeOptions.clear();

        for (var opt in _additionalOptions) {
          opt.dispose();
        }
        _additionalOptions.clear();
      });
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kWhite,
        title: const Text('Add Menu Item'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          // ── Type Selector ───────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: kFieldBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kPrimary.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: const Text(
                      'Food',
                      style: TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    value: 'food',
                    groupValue: _itemType,
                    activeColor: kPrimary,
                    onChanged: (val) => setState(() {
                      _itemType = val!;
                      _selectedCategory = null;
                      _selectedCategoryIconUrl = null;
                      _selectedMenuChoices.clear();
                      _dropdownChoiceValue = null;
                    }),
                  ),
                ),
                Container(width: 1, height: 40, color: kMuted.withOpacity(0.3)),
                Expanded(
                  child: RadioListTile<String>(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: const Text(
                      'Drink',
                      style: TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    value: 'drink',
                    groupValue: _itemType,
                    activeColor: kPrimary,
                    onChanged: (val) => setState(() {
                      _itemType = val!;
                      _selectedCategory = null;
                      _selectedCategoryIconUrl = null;
                      _selectedMenuChoices.clear();
                      _dropdownChoiceValue = null;
                    }),
                  ),
                ),
                Container(width: 1, height: 40, color: kMuted.withOpacity(0.3)),
                Expanded(
                  child: RadioListTile<String>(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: const Text(
                      'Combo',
                      style: TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    value: 'combo',
                    groupValue: _itemType,
                    activeColor: kPrimary,
                    onChanged: (val) => setState(() {
                      _itemType = val!;
                      _selectedCategory = null;
                      _selectedCategoryIconUrl = null;
                      _selectedMenuChoices.clear();
                      _dropdownChoiceValue = null;
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Basic Info & Pricing ────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kFieldBg.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _input(label: 'Item Name', controller: _name),
                const SizedBox(height: 16),
                
                // Multiple Sizes Toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: kPrimary,
                  title: const Text(
                    'Has Multiple Sizes?',
                    style: TextStyle(color: kWhite, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Enable if item has sizes (e.g. Small vs Regular)',
                    style: TextStyle(color: kMuted, fontSize: 12),
                  ),
                  value: _hasMultipleSizes,
                  onChanged: (val) {
                    setState(() {
                      _hasMultipleSizes = val;
                      if (val && _sizeOptions.isEmpty) {
                         _sizeOptions.add(SizeOptionField()); // Auto-add one blank size
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),

                // Pricing Inputs Based on Toggle
                if (!_hasMultipleSizes)
                  _input(
                    label: 'Standard Price',
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Size Variants',
                            style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold),
                          ),
                          TextButton.icon(
                            onPressed: _addSizeField,
                            icon: const Icon(Icons.add, size: 16, color: kPrimary),
                            label: const Text('Add Size', style: TextStyle(color: kPrimary)),
                          )
                        ],
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _sizeOptions.length,
                        itemBuilder: (context, index) {
                          final sizeOpt = _sizeOptions[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _miniInput('Size (e.g. Kleine Portion)', sizeOpt.name)
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: _miniInput('Price', sizeOpt.price, isNumber: true)
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                  onPressed: () => _removeSizeField(index),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Discount ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kFieldBg.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _hasDiscount ? kPrimary.withOpacity(0.5) : Colors.transparent,
              ),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: kPrimary,
                  title: const Text(
                    'Apply Discount',
                    style: TextStyle(color: kWhite, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Offer a discount on this item',
                    style: TextStyle(color: kMuted, fontSize: 12),
                  ),
                  value: _hasDiscount,
                  onChanged: (val) => setState(() => _hasDiscount = val),
                ),
                if (_hasDiscount) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Percent %', style: TextStyle(color: kWhite, fontSize: 13)),
                          value: 'percent',
                          groupValue: _discountType,
                          activeColor: kPrimary,
                          onChanged: (v) => setState(() => _discountType = v!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Fixed Amount', style: TextStyle(color: kWhite, fontSize: 13)),
                          value: 'amount',
                          groupValue: _discountType,
                          activeColor: kPrimary,
                          onChanged: (v) => setState(() => _discountType = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _input(
                    label: _discountType == 'percent' ? 'Discount %' : 'Discount Amount',
                    controller: _discountValue,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Menu Choices ────────────────────────────────────────────
          const Text(
            'Menu Choices',
            style: TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: kFieldBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kMuted.withOpacity(0.3)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Builder(
              builder: (context) {
                final matchingChoices = _allAvailableChoices.where((choice) {
                  final choiceType = (choice['type'] as String?) ?? 'food';
                  return choiceType == _itemType;
                }).toList();

                return DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _dropdownChoiceValue,
                    isExpanded: true,
                    dropdownColor: kFieldBg,
                    icon: const Icon(Icons.arrow_drop_down, color: kWhite),
                    hint: Text(
                      matchingChoices.isEmpty
                          ? 'No ${_typeLabel(_itemType)} menu choices yet'
                          : 'Select Menu Choice',
                      style: const TextStyle(color: kMuted),
                    ),
                    items: matchingChoices.map((choice) => DropdownMenuItem<String>(
                      value: choice['id'],
                      child: Text(
                        choice['heading'] ?? 'Unnamed',
                        style: const TextStyle(color: kWhite),
                      ),
                    )).toList(),
                    onChanged: (newId) {
                      if (newId != null && !_selectedMenuChoices.any((c) => c['id'] == newId)) {
                        setState(() {
                          _selectedMenuChoices.add(
                            _allAvailableChoices.firstWhere((c) => c['id'] == newId),
                          );
                          _dropdownChoiceValue = null;
                        });
                      }
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          if (_selectedMenuChoices.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _selectedMenuChoices.length,
              itemBuilder: (context, index) {
                final choice = _selectedMenuChoices[index];
                final String optionsPreview = (choice['options'] ?? []).join(', ');
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: kFieldBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(
                      choice['heading'] ?? '',
                      style: const TextStyle(color: kWhite, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      optionsPreview,
                      style: const TextStyle(color: kMuted),
                      maxLines: 1,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: kMuted, size: 20),
                          onPressed: () => _openEditChoiceDialog(choice),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => setState(() => _selectedMenuChoices.removeAt(index)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 24),

          // ── Additional Options ──────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Additional Options',
                style: TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: kPrimary, size: 30),
                onPressed: _addOptionField,
              ),
            ],
          ),
          const SizedBox(height: 8),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _additionalOptions.length,
            itemBuilder: (context, index) {
              final opt = _additionalOptions[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kFieldBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kPrimary.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.add_box_outlined, color: kPrimary, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Option ${index + 1}',
                            style: const TextStyle(
                              color: kPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(child: _miniInput('Option Name', opt.name)),
                        const SizedBox(width: 8),
                        Expanded(child: _miniInput('Price', opt.price, isNumber: true)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _miniInput('Catalog Code', opt.catalog),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _removeOptionField(index),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Description / Category / Image ──────────────────────────
          const Text(
            'Item Details',
            style: TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kFieldBg.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _input(label: 'Description (optional)', controller: _note, maxLines: 3),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: kFieldBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('menu_category').snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const LinearProgressIndicator();
                      final allDocs = snap.data!.docs;
                      final matchingDocs = allDocs.where((d) {
                        final data = d.data() as Map<String, dynamic>? ?? {};
                        final catType = (data['type'] as String?) ?? 'food';
                        return catType == _itemType;
                      }).toList();
                      final names = matchingDocs.map((d) => d.id).toList();
                      final String? safeValue = names.contains(_selectedCategory) ? _selectedCategory : null;
                      if (names.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'No ${_typeLabel(_itemType)} categories yet — add one first.',
                            style: const TextStyle(color: kMuted),
                          ),
                        );
                      }
                      return DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: safeValue,
                          isExpanded: true,
                          dropdownColor: kFieldBg,
                          hint: Text(
                            '${_typeLabel(_itemType)} Category',
                            style: const TextStyle(color: kMuted),
                          ),
                          items: names.map((n) => DropdownMenuItem(
                            value: n,
                            child: Text(n, style: const TextStyle(color: kWhite)),
                          )).toList(),
                          onChanged: (v) {
                            final match = matchingDocs.firstWhere((d) => d.id == v);
                            final matchData = match.data() as Map<String, dynamic>? ?? {};
                            setState(() {
                              _selectedCategory = v;
                              _selectedCategoryIconUrl = matchData['iconUrl'] as String?;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickImage,
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: kFieldBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: _imgBytes != null
                        ? Image.memory(_imgBytes!, height: 130)
                        : const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_photo_alternate, size: 36, color: kPrimary),
                              SizedBox(height: 8),
                              Text('Select Image', style: TextStyle(color: kWhite)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Error ───────────────────────────────────────────────────
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_err!, style: const TextStyle(color: Colors.redAccent)),
            ),

          // ── Save Button ─────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: kWhite,
              ),
              child: _saving
                  ? const CircularProgressIndicator(color: kWhite)
                  : const Text('Save Menu Item', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),

          // ── Manage Menu Items ───────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.settings, color: kWhite, size: 18),
              label: const Text('Manage Menu Items', style: TextStyle(color: kWhite)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: kMuted.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageMenuItemsPage()),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Input Widgets ─────────────────────────────────────────────────────

  String _typeLabel(String type) {
    if (type == 'drink') return 'Drink';
    if (type == 'combo') return 'Combo';
    return 'Food';
  }

  Widget _input({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: kWhite),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: kMuted.withOpacity(0.8)),
        filled: true,
        fillColor: kFieldBg,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: kMuted.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: kPrimary, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _miniInput(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: kWhite, fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kMuted, fontSize: 12),
        filled: true,
        fillColor: kBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: kPrimary),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}