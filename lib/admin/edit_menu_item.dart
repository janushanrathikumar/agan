import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'choice_dialog.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

// --- Color Constants ---
const kPrimary = Color(0xFFA26334);
const kBg = Color(0xFF2A2928);
const kWhite = Color(0xFFFFFFFF);
const kMuted = Color(0xFFB7B7B6);
const kFieldBg = Color(0xFF383735);

// --- CORS-safe image widget for web ---
class _WebSafeImage extends StatelessWidget {
  final String imageUrl;
  final double height;

  const _WebSafeImage({required this.imageUrl, required this.height});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty)
      return const Icon(Icons.broken_image, color: kMuted, size: 40);

    if (kIsWeb) {
      final String viewId =
          'img-${imageUrl.hashCode}_${DateTime.now().microsecondsSinceEpoch}';
      ui_web.platformViewRegistry.registerViewFactory(
        viewId,
        (int viewId) => html.ImageElement()
          ..src = imageUrl
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'cover',
      );
      return SizedBox(
        height: height,
        child: HtmlElementView(viewType: viewId),
      );
    } else {
      return Image.network(
        imageUrl,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, color: kMuted),
      );
    }
  }
}

// --- Additional Option Field Helper ---
class AdditionalOptionField {
  final TextEditingController name = TextEditingController();
  final TextEditingController price = TextEditingController();
  final TextEditingController catalog = TextEditingController();

  AdditionalOptionField({String? n, String? p, String? c}) {
    name.text = n ?? '';
    price.text = p ?? '';
    catalog.text = c ?? '';
  }

  void dispose() {
    name.dispose();
    price.dispose();
    catalog.dispose();
  }
}

class EditMenuItemPage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> itemData;

  const EditMenuItemPage({
    super.key,
    required this.docId,
    required this.itemData,
  });

  @override
  State<EditMenuItemPage> createState() => _EditMenuItemPageState();
}

class _EditMenuItemPageState extends State<EditMenuItemPage> {
  final _name = TextEditingController();
  final _note = TextEditingController();
  final _price = TextEditingController();

  // Additional Options
  List<AdditionalOptionField> _additionalOptions = [];

  Uint8List? _imgBytes;
  String? _imgFileName;
  String? _existingImageUrl;
  String? _existingImageFileName;

  String? _selectedCategory;
  String? _selectedCategoryIconUrl;
  String _itemType = 'food';

  // 🟢 Discount state
  bool _hasDiscount = false;
  String _discountType = 'percent'; // 'percent' or 'amount'
  final _discountValue = TextEditingController();

  List<Map<String, dynamic>> _allAvailableChoices = [];
  List<Map<String, dynamic>> _selectedMenuChoices = [];
  String? _dropdownChoiceValue;

  bool _saving = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _name.text = widget.itemData['name'] ?? '';
    _price.text = (widget.itemData['price'] ?? '').toString();
    _note.text = widget.itemData['note'] ?? '';
    _itemType = widget.itemData['itemType'] ?? 'food';
    _selectedCategory = widget.itemData['category'];
    _selectedCategoryIconUrl = widget.itemData['categoryIconUrl'];
    _existingImageUrl = widget.itemData['imageUrl'];
    _existingImageFileName = widget.itemData['imageFileName'];

    // 🟢 Load existing discount info
    _hasDiscount = widget.itemData['hasDiscount'] ?? false;
    _discountType = widget.itemData['discountType'] ?? 'percent';
    final existingDiscountValue = widget.itemData['discountValue'];
    _discountValue.text = existingDiscountValue == null
        ? ''
        : existingDiscountValue.toString();

    // Load existing additional options
    final List<dynamic> existingOptions =
        widget.itemData['additionalOptions'] ?? [];
    _additionalOptions = existingOptions.map((opt) {
      return AdditionalOptionField(
        n: opt['name']?.toString() ?? '',
        p: opt['price']?.toString() ?? '',
        c: opt['catalog']?.toString() ?? '',
      );
    }).toList();

    _fetchAvailableMenuChoices();
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    _price.dispose();
    _discountValue.dispose();
    for (var opt in _additionalOptions) {
      opt.dispose();
    }
    super.dispose();
  }

  void _addOptionField() =>
      setState(() => _additionalOptions.add(AdditionalOptionField()));

  void _removeOptionField(int index) {
    _additionalOptions[index].dispose();
    setState(() => _additionalOptions.removeAt(index));
  }

  Future<void> _fetchAvailableMenuChoices() async {
    final snap = await FirebaseFirestore.instance
        .collection('menu_choices')
        .get();
    if (mounted) {
      setState(() {
        _allAvailableChoices = snap.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        List<dynamic> existingChoiceIds = widget.itemData['menuChoices'] ?? [];
        _selectedMenuChoices = _allAvailableChoices
            .where((choice) => existingChoiceIds.contains(choice['id']))
            .toList();
      });
    }
  }

  void _openEditChoiceDialog(Map<String, dynamic> choiceData) {
    showDialog(
      context: context,
      builder: (context) => ChoiceDialog(
        docId: choiceData['id'],
        existingHeading: choiceData['heading'] ?? '',
        existingOptions: List<String>.from(choiceData['options'] ?? []),
      ),
    ).then((_) => _fetchAvailableMenuChoices());
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 80,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _imgBytes = bytes;
      _imgFileName = x.name;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      final name = _name.text.trim();
      final price = double.tryParse(_price.text.trim());
      if (name.isEmpty || price == null)
        throw Exception('Check Name and Price');

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

      // Serialize additional options
      List<Map<String, dynamic>> optionsData = _additionalOptions.map((opt) {
        return {
          'name': opt.name.text.trim(),
          'price': double.tryParse(opt.price.text.trim()) ?? 0,
          'catalog': opt.catalog.text.trim(),
        };
      }).toList();

      String imageUrl = _existingImageUrl ?? '';
      String imageFileName = _existingImageFileName ?? '';

      if (_imgBytes != null) {
        imageFileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final imgRef = FirebaseStorage.instance.ref(
          'menu_images/$imageFileName',
        );
        await imgRef.putData(_imgBytes!);
        imageUrl = await imgRef.getDownloadURL();
      }

      await FirebaseFirestore.instance
          .collection('menu_items')
          .doc(widget.docId)
          .update({
            'name': name,
            'note': _note.text.trim(),
            'price': price,
            'category': _selectedCategory,
            'imageUrl': imageUrl,
            'imageFileName': imageFileName,
            'menuChoices': _selectedMenuChoices.map((c) => c['id']).toList(),
            'additionalOptions': optionsData,
            'itemType': _itemType,
            // 🟢 Discount fields
            'hasDiscount': _hasDiscount,
            'discountType': _hasDiscount ? _discountType : null,
            'discountValue': _hasDiscount ? discountValue : 0,
          });

      if (mounted) Navigator.pop(context);
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
        title: const Text('Edit Menu Item'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          // ── Food / Drink Toggle ─────────────────────────────────────
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
                    title: const Text(
                      'Food',
                      style: TextStyle(
                        color: kWhite,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    value: 'food',
                    groupValue: _itemType,
                    activeColor: kPrimary,
                    onChanged: (val) => setState(() => _itemType = val!),
                  ),
                ),
                Container(width: 1, height: 40, color: kMuted.withOpacity(0.3)),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text(
                      'Drink',
                      style: TextStyle(
                        color: kWhite,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    value: 'drink',
                    groupValue: _itemType,
                    activeColor: kPrimary,
                    onChanged: (val) => setState(() => _itemType = val!),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Image Picker ────────────────────────────────────────────
          InkWell(
            onTap: _pickImage,
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                color: kFieldBg,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.hardEdge,
              child: _imgBytes != null
                  ? Image.memory(
                      _imgBytes!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                  : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                  ? _WebSafeImage(imageUrl: _existingImageUrl!, height: 150)
                  : const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            size: 36,
                            color: kPrimary,
                          ),
                          SizedBox(height: 8),
                          Text('Select Image', style: TextStyle(color: kWhite)),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Basic Info ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kFieldBg.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _input(label: 'Item Name', controller: _name),
                const SizedBox(height: 12),
                _input(
                  label: 'Price',
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                _input(
                  label: 'Description (optional)',
                  controller: _note,
                  maxLines: 3,
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
                color: _hasDiscount
                    ? kPrimary.withOpacity(0.5)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: kPrimary,
                  title: const Text(
                    'Apply Discount',
                    style: TextStyle(
                      color: kWhite,
                      fontWeight: FontWeight.bold,
                    ),
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
                          title: const Text(
                            'Percent %',
                            style: TextStyle(color: kWhite, fontSize: 13),
                          ),
                          value: 'percent',
                          groupValue: _discountType,
                          activeColor: kPrimary,
                          onChanged: (v) => setState(() => _discountType = v!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Fixed Amount',
                            style: TextStyle(color: kWhite, fontSize: 13),
                          ),
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
                    label: _discountType == 'percent'
                        ? 'Discount %'
                        : 'Discount Amount',
                    controller: _discountValue,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Menu Choices ────────────────────────────────────────────
          const Text(
            'Menu Choices',
            style: TextStyle(
              color: kWhite,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: kFieldBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kMuted.withOpacity(0.3)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _dropdownChoiceValue,
                isExpanded: true,
                dropdownColor: kFieldBg,
                icon: const Icon(Icons.arrow_drop_down, color: kWhite),
                hint: const Text(
                  'Select Menu Choice',
                  style: TextStyle(color: kMuted),
                ),
                items: _allAvailableChoices
                    .map(
                      (choice) => DropdownMenuItem<String>(
                        value: choice['id'],
                        child: Text(
                          choice['heading'] ?? 'Unnamed',
                          style: const TextStyle(color: kWhite),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (newId) {
                  if (newId != null &&
                      !_selectedMenuChoices.any((c) => c['id'] == newId)) {
                    setState(() {
                      _selectedMenuChoices.add(
                        _allAvailableChoices.firstWhere(
                          (c) => c['id'] == newId,
                        ),
                      );
                      _dropdownChoiceValue = null;
                    });
                  }
                },
              ),
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
                final String optionsPreview = (choice['options'] ?? []).join(
                  ', ',
                );
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: kFieldBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(
                      choice['heading'] ?? '',
                      style: const TextStyle(
                        color: kWhite,
                        fontWeight: FontWeight.bold,
                      ),
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
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _selectedMenuChoices.removeAt(index),
                          ),
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
                style: TextStyle(
                  color: kWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
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
                    // Header
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.add_box_outlined,
                            color: kPrimary,
                            size: 16,
                          ),
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
                    // Row 1: Name + Price
                    Row(
                      children: [
                        Expanded(child: _miniInput('Option Name', opt.name)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _miniInput('Price', opt.price, isNumber: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Row 2: Catalog Code
                    _miniInput('Catalog Code', opt.catalog),
                    // Delete
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

          // ── Category ────────────────────────────────────────────────
          const Text(
            'Category',
            style: TextStyle(
              color: kWhite,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: kFieldBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kMuted.withOpacity(0.3)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('menu_category')
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const LinearProgressIndicator();
                final names = snap.data!.docs.map((d) => d.id).toList();

                // 🟢 FIX: only use _selectedCategory as the dropdown value if
                // it actually exists in the current list of category names.
                // Previously, if the saved category (e.g. "drinks1") had been
                // renamed or deleted from `menu_category`, DropdownButton
                // would crash with:
                // "There should be exactly one item with [DropdownButton]'s
                // value ... Either zero or 2 or more ... were detected"
                final String? safeValue = names.contains(_selectedCategory)
                    ? _selectedCategory
                    : null;

                return DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: safeValue,
                    isExpanded: true,
                    dropdownColor: kFieldBg,
                    hint: const Text(
                      'Menu Category',
                      style: TextStyle(color: kMuted),
                    ),
                    items: names
                        .map(
                          (n) => DropdownMenuItem(
                            value: n,
                            child: Text(
                              n,
                              style: const TextStyle(color: kWhite),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // ── Error ───────────────────────────────────────────────────
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _err!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),

          // ── Update Button ───────────────────────────────────────────
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
                  : const Text(
                      'Update Menu Item',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: kPrimary),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
