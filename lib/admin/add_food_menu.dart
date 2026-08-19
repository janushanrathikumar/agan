// lib/add_menu_item.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'choice_dialog.dart';
import 'manage_menu_items.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:restorant/platform_image/platform_image.dart';

const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF2A2928);
const kWhite = Color(0xFFFFFFFF);
const kMuted = Color(0xFFB7B7B6);
const kFieldBg = Color(0xFF383735);

// 🟢 NEW: Standardized Web-Safe Image Widget to prevent CORS errors on Web
class _WebSafeImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final Widget fallback;

  const _WebSafeImage({
    required this.imageUrl,
    this.width,
    this.height,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) return fallback;
    if (kIsWeb) {
      final String viewId =
          'add-img-${imageUrl.hashCode}_${DateTime.now().microsecondsSinceEpoch}';
      return buildUniversalImage(
        imageUrl: imageUrl, // Pass your actual image URL variable here
        width: 100, // Adjust width as needed
        height: 100, // Adjust height as needed
        fallback: const Icon(Icons.image_not_supported),
      );
    }
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class SizeOptionField {
  final TextEditingController name = TextEditingController();
  final TextEditingController dineInPrice = TextEditingController();
  final TextEditingController takeAwayPrice = TextEditingController();

  void dispose() {
    name.dispose();
    dineInPrice.dispose();
    takeAwayPrice.dispose();
  }
}

class AddMenuPage extends StatefulWidget {
  const AddMenuPage({super.key});

  @override
  State<AddMenuPage> createState() => _AddMenuPageState();
}

class _AddMenuPageState extends State<AddMenuPage> {
  final _itemNo = TextEditingController();
  final _name = TextEditingController();
  final _note = TextEditingController();
  final _price = TextEditingController();

  bool _hasMultipleSizes = false;
  final List<SizeOptionField> _sizeOptions = [];

  Uint8List? _imgBytes;
  String? _imgFileName;

  String? _selectedCategory;
  String? _selectedCategoryIconUrl;

  String _itemType = 'food';

  bool _hasDiscount = false;
  String _discountType = 'percent';
  final _discountValue = TextEditingController();

  List<Map<String, dynamic>> _allAvailableChoices = [];
  final List<Map<String, dynamic>> _selectedMenuChoices = [];
  String? _dropdownChoiceValue;

  List<Map<String, dynamic>> _allAvailableOptions = [];
  final List<Map<String, dynamic>> _selectedOptions = [];

  bool _isAvailable = true;
  bool _canTakeAway = true;

  List<Map<String, dynamic>> _allComboCandidates = [];
  final List<Map<String, dynamic>> _selectedComboItems = [];

  bool _saving = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _fetchAvailableMenuChoices();
    _fetchAvailableOptions();
    _fetchComboCandidates();
  }

  @override
  void dispose() {
    _itemNo.dispose();
    _name.dispose();
    _note.dispose();
    _price.dispose();
    _discountValue.dispose();
    for (var opt in _sizeOptions) {
      opt.dispose();
    }
    super.dispose();
  }

  void _addSizeField() => setState(() => _sizeOptions.add(SizeOptionField()));

  void _removeSizeField(int index) {
    _sizeOptions[index].dispose();
    setState(() => _sizeOptions.removeAt(index));
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

  Future<void> _fetchAvailableOptions() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('additional_options')
          .get();
      if (mounted) {
        setState(() {
          _allAvailableOptions = snap.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching options: $e");
    }
  }

  Future<void> _fetchComboCandidates() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('menu_items')
          .get();
      if (mounted) {
        setState(() {
          _allComboCandidates = snap.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .where((item) => (item['itemType'] ?? 'food') != 'combo')
              .toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching combo candidates: $e");
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
      final itemNo = _itemNo.text.trim();
      final name = _name.text.trim();
      final note = _note.text.trim();

      if (name.isEmpty) throw Exception('Name is required.');
      if (_selectedCategory == null) throw Exception('Select a category.');

      if (_itemType == 'combo') {
        if (_selectedComboItems.isEmpty) {
          throw Exception('Add at least one item to the combo.');
        }
      } else {
        if (_imgBytes == null) throw Exception('Pick an image.');
      }

      double? basePrice;
      List<Map<String, dynamic>> sizesData = [];

      if (_hasMultipleSizes) {
        if (_sizeOptions.isEmpty)
          throw Exception('Please add at least one size variant.');
        for (var size in _sizeOptions) {
          final sName = size.name.text.trim();
          final dPrice = double.tryParse(size.dineInPrice.text.trim());
          final tPriceText = size.takeAwayPrice.text.trim();
          final tPrice = tPriceText.isEmpty
              ? null
              : double.tryParse(tPriceText);

          if (sName.isEmpty || dPrice == null) {
            throw Exception(
              'All sizes must have a valid name and dine-in price.',
            );
          }

          final sizeMap = <String, dynamic>{
            'name': sName,
            'price': dPrice,
            'dineInPrice': dPrice,
          };
          if (tPrice != null) sizeMap['takeAwayPrice'] = tPrice;
          sizesData.add(sizeMap);
        }
        basePrice = sizesData
            .map((e) => e['dineInPrice'] as double)
            .reduce((a, b) => a < b ? a : b);
      } else {
        basePrice = double.tryParse(_price.text.trim());
        if (basePrice == null)
          throw Exception('A valid standard price is required.');
      }

      double discountValue = 0;
      if (_hasDiscount) {
        discountValue = double.tryParse(_discountValue.text.trim()) ?? 0;
        if (discountValue <= 0) throw Exception('Enter a valid discount value');
        if (_discountType == 'percent' && discountValue > 100) {
          throw Exception('Discount percent cannot exceed 100');
        }
      }

      List<Map<String, dynamic>> optionsData = _selectedOptions.map((opt) {
        return {
          'id': opt['id'],
          'name': opt['name'],
          'price': opt['price'],
          'catalog': opt['catalog'],
          'type': opt['type'],
        };
      }).toList();

      String imageUrl = '';
      String fileName = '';

      if (_itemType == 'combo') {
        imageUrl = (_selectedComboItems.first['imageUrl'] as String?) ?? '';
      } else {
        final safeBase = (_imgFileName ?? name).replaceAll(
          RegExp(r'[^a-zA-Z0-9._-]+'),
          '_',
        );
        fileName = '${DateTime.now().millisecondsSinceEpoch}_$safeBase';
        final imgRef = FirebaseStorage.instance.ref('menu_images/$fileName');

        await imgRef.putData(
          _imgBytes!,
          SettableMetadata(contentType: _guessContentType(_imgFileName)),
        );
        imageUrl = await imgRef.getDownloadURL();
      }

      final List<Map<String, dynamic>> comboItemsData = _selectedComboItems
          .map(
            (item) => {
              'id': item['id'],
              'name': item['name'],
              'price': item['price'],
              'imageUrl': item['imageUrl'],
            },
          )
          .toList();

      final List<String> choiceIds = _selectedMenuChoices
          .map((c) => c['id'] as String)
          .toList();

      await FirebaseFirestore.instance.collection('menu_items').add({
        'itemNo': itemNo,
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
        'status': _isAvailable ? 'on' : 'off',
        'itemType': _itemType,
        'hasDiscount': _hasDiscount,
        'discountType': _hasDiscount ? _discountType : null,
        'discountValue': _hasDiscount ? discountValue : 0,
        'canTakeAway': _canTakeAway,
        'comboItems': comboItemsData,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved successfully'),
          backgroundColor: kPrimary,
        ),
      );

      _itemNo.clear();
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
        _selectedOptions.clear();
        _hasDiscount = false;
        _discountType = 'percent';
        _discountValue.clear();
        _hasMultipleSizes = false;
        _canTakeAway = true;
        _isAvailable = true;
        _selectedComboItems.clear();

        for (var opt in _sizeOptions) opt.dispose();
        _sizeOptions.clear();
      });
      _fetchComboCandidates();
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onTypeChanged(String? val) {
    if (val == null) return;
    setState(() {
      _itemType = val;
      _selectedCategory = null;
      _selectedCategoryIconUrl = null;
      _selectedMenuChoices.clear();
      _dropdownChoiceValue = null;
      _selectedOptions.clear();
      if (val == 'combo') {
        _hasMultipleSizes = false;
        _imgBytes = null;
        _imgFileName = null;
      } else {
        _selectedComboItems.clear();
      }
    });
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
                    title: const Text(
                      'Food',
                      style: TextStyle(
                        color: kWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    value: 'food',
                    groupValue: _itemType,
                    activeColor: kPrimary,
                    onChanged: _onTypeChanged,
                  ),
                ),
                Container(width: 1, height: 40, color: kMuted.withOpacity(0.3)),
                Expanded(
                  child: RadioListTile<String>(
                    dense: true,
                    title: const Text(
                      'Drink',
                      style: TextStyle(
                        color: kWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    value: 'drink',
                    groupValue: _itemType,
                    activeColor: kPrimary,
                    onChanged: _onTypeChanged,
                  ),
                ),
                Container(width: 1, height: 40, color: kMuted.withOpacity(0.3)),
                Expanded(
                  child: RadioListTile<String>(
                    dense: true,
                    title: const Text(
                      'Combo',
                      style: TextStyle(
                        color: kWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    value: 'combo',
                    groupValue: _itemType,
                    activeColor: kPrimary,
                    onChanged: _onTypeChanged,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kFieldBg.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _input(
                  label: 'Item ID / Number (e.g., 1, 2, 003)',
                  controller: _itemNo,
                ),
                const SizedBox(height: 16),
                _input(label: 'Item Name', controller: _name),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: kPrimary,
                  title: const Text(
                    'Item Available',
                    style: TextStyle(
                      color: kWhite,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    'Toggle off to hide this item from the active menu',
                    style: TextStyle(color: kMuted, fontSize: 12),
                  ),
                  value: _isAvailable,
                  onChanged: (val) => setState(() => _isAvailable = val),
                ),
                const SizedBox(height: 8),

                if (_itemType != 'combo') ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: kPrimary,
                    title: const Text(
                      'Has Multiple Sizes?',
                      style: TextStyle(
                        color: kWhite,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text(
                      'Enable if item has sizes with distinct Dine-In and Take-Away prices',
                      style: TextStyle(color: kMuted, fontSize: 12),
                    ),
                    value: _hasMultipleSizes,
                    onChanged: (val) {
                      setState(() {
                        _hasMultipleSizes = val;
                        if (val && _sizeOptions.isEmpty) {
                          final opt1 = SizeOptionField()
                            ..name.text = 'Kleine Portion';
                          _sizeOptions.add(opt1);
                          final opt2 = SizeOptionField()..name.text = 'Portion';
                          _sizeOptions.add(opt2);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: kPrimary,
                  title: const Text(
                    'Available for Take Away?',
                    style: TextStyle(
                      color: kWhite,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    'Turn off if this item cannot be packed (e.g. a drink served only in a glass)',
                    style: TextStyle(color: kMuted, fontSize: 12),
                  ),
                  value: _canTakeAway,
                  onChanged: (val) => setState(() => _canTakeAway = val),
                ),
                const SizedBox(height: 8),

                if (_itemType == 'combo')
                  _input(
                    label: 'Combo Price',
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  )
                else if (!_hasMultipleSizes)
                  _input(
                    label: 'Standard Price',
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Size Variants (Dine-In & Take-Away)',
                            style: TextStyle(
                              color: kPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addSizeField,
                            icon: const Icon(
                              Icons.add,
                              size: 16,
                              color: kPrimary,
                            ),
                            label: const Text(
                              'Add Size',
                              style: TextStyle(color: kPrimary),
                            ),
                          ),
                        ],
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _sizeOptions.length,
                        itemBuilder: (context, index) {
                          final sizeOpt = _sizeOptions[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: kBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: kMuted.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _miniInput(
                                          'Size Name (e.g. Portion)',
                                          sizeOpt.name,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: Colors.redAccent,
                                        ),
                                        onPressed: () =>
                                            _removeSizeField(index),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _miniInput(
                                          'Dine-In Price',
                                          sizeOpt.dineInPrice,
                                          isNumber: true,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _miniInput(
                                          'Take-Away Price (Opt)',
                                          sizeOpt.takeAwayPrice,
                                          isNumber: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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

          // Discount Section
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

          // Menu Choices Section
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
            child: Builder(
              builder: (context) {
                final matchingChoices = _allAvailableChoices
                    .where(
                      (choice) =>
                          (choice['type'] as String? ?? 'food') == _itemType,
                    )
                    .toList();
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
                    items: matchingChoices
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
                      (choice['options'] ?? []).join(', '),
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

          // Additional Options Section
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
                icon: const Icon(Icons.refresh, color: kPrimary, size: 24),
                onPressed: _fetchAvailableOptions,
                tooltip: 'Refresh Options',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final matchingOptions = _allAvailableOptions
                  .where(
                    (opt) => (opt['type'] as String? ?? 'food') == _itemType,
                  )
                  .toList();
              return _MultiSelectOptionsField(
                hint: matchingOptions.isEmpty
                    ? 'No ${_typeLabel(_itemType)} additional options yet'
                    : 'Choose additional options...',
                availableOptions: matchingOptions,
                selectedOptions: _selectedOptions,
                onChanged: (newSelection) => setState(() {
                  _selectedOptions.clear();
                  _selectedOptions.addAll(newSelection);
                }),
              );
            },
          ),
          const SizedBox(height: 24),

          // Combo Items Section
          if (_itemType == 'combo') ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Combo Items',
                  style: TextStyle(
                    color: kWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: kPrimary, size: 24),
                  onPressed: _fetchComboCandidates,
                  tooltip: 'Refresh Items',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ComboItemsField(
              hint: _allComboCandidates.isEmpty
                  ? 'No menu items yet — add food/drink items first'
                  : 'Search & add items to this combo...',
              availableItems: _allComboCandidates,
              selectedItems: _selectedComboItems,
              onChanged: (newSelection) => setState(() {
                _selectedComboItems
                  ..clear()
                  ..addAll(newSelection);
              }),
            ),
            const SizedBox(height: 24),
          ],

          // Item Details Section
          const Text(
            'Item Details',
            style: TextStyle(
              color: kWhite,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
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
                _input(
                  label: 'Description (optional)',
                  controller: _note,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: kFieldBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('menu_category')
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const LinearProgressIndicator();
                      final matchingDocs = snap.data!.docs
                          .where(
                            (d) =>
                                ((d.data() as Map<String, dynamic>?)?['type']
                                        as String? ??
                                    'food') ==
                                _itemType,
                          )
                          .toList();
                      final names = matchingDocs.map((d) => d.id).toList();
                      final safeValue = names.contains(_selectedCategory)
                          ? _selectedCategory
                          : null;

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
                          onChanged: (v) {
                            final match = matchingDocs.firstWhere(
                              (d) => d.id == v,
                            );
                            setState(() {
                              _selectedCategory = v;
                              _selectedCategoryIconUrl =
                                  (match.data()
                                          as Map<String, dynamic>?)?['iconUrl']
                                      as String?;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                if (_itemType == 'combo')
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: kFieldBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    clipBehavior: Clip.hardEdge,
                    child: _selectedComboItems.isNotEmpty
                        ? _WebSafeImage(
                            imageUrl:
                                (_selectedComboItems.first['imageUrl']
                                    as String?) ??
                                '',
                            fallback: const Icon(
                              Icons.broken_image,
                              color: kMuted,
                              size: 40,
                            ),
                          )
                        : const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.image_outlined,
                                size: 36,
                                color: kMuted,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Image is taken automatically from\nthe first combo item you add',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: kMuted, fontSize: 12),
                              ),
                            ],
                          ),
                  )
                else
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
                                Icon(
                                  Icons.add_photo_alternate,
                                  size: 36,
                                  color: kPrimary,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Select Image',
                                  style: TextStyle(color: kWhite),
                                ),
                              ],
                            ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _err!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),

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
                      'Save Menu Item',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

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
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
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

class _MultiSelectOptionsField extends StatefulWidget {
  final String hint;
  final List<Map<String, dynamic>> availableOptions;
  final List<Map<String, dynamic>> selectedOptions;
  final Function(List<Map<String, dynamic>>) onChanged;

  const _MultiSelectOptionsField({
    required this.hint,
    required this.availableOptions,
    required this.selectedOptions,
    required this.onChanged,
  });

  @override
  State<_MultiSelectOptionsField> createState() =>
      _MultiSelectOptionsFieldState();
}

class _MultiSelectOptionsFieldState extends State<_MultiSelectOptionsField> {
  void _showSelectionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _MultiSelectDialog(
        availableOptions: widget.availableOptions,
        initialSelectedOptions: widget.selectedOptions,
        onSelectionChanged: widget.onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _showSelectionDialog,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: kFieldBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kMuted.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: widget.selectedOptions.isEmpty
                  ? Text(widget.hint, style: const TextStyle(color: kMuted))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.selectedOptions
                          .map(
                            (opt) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: kPrimary.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                opt['name'] ?? '',
                                style: const TextStyle(
                                  color: kWhite,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down, color: kMuted),
          ],
        ),
      ),
    );
  }
}

class _MultiSelectDialog extends StatefulWidget {
  final List<Map<String, dynamic>> availableOptions;
  final List<Map<String, dynamic>> initialSelectedOptions;
  final Function(List<Map<String, dynamic>>) onSelectionChanged;

  const _MultiSelectDialog({
    required this.availableOptions,
    required this.initialSelectedOptions,
    required this.onSelectionChanged,
  });

  @override
  State<_MultiSelectDialog> createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<_MultiSelectDialog> {
  late List<Map<String, dynamic>> _tempSelected;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tempSelected = List.from(widget.initialSelectedOptions);
  }

  @override
  Widget build(BuildContext context) {
    final filteredOptions = widget.availableOptions
        .where(
          (opt) =>
              (opt['name'] as String?)?.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ??
              false,
        )
        .toList();
    filteredOptions.sort((a, b) {
      final aSelected = _tempSelected.any((o) => o['name'] == a['name']);
      final bSelected = _tempSelected.any((o) => o['name'] == b['name']);
      if (aSelected && !bSelected) return -1;
      if (!aSelected && bSelected) return 1;
      return ((a['name'] as String?) ?? '').compareTo(
        (b['name'] as String?) ?? '',
      );
    });

    return Dialog(
      backgroundColor: kBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxHeight: 500, maxWidth: 400),
        child: Column(
          children: [
            TextField(
              style: const TextStyle(color: kWhite),
              decoration: InputDecoration(
                hintText: 'Search Options...',
                hintStyle: const TextStyle(color: kMuted),
                prefixIcon: const Icon(Icons.search, color: kMuted),
                filled: true,
                fillColor: kFieldBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filteredOptions.isEmpty
                  ? const Center(
                      child: Text(
                        'No options found',
                        style: TextStyle(color: kMuted),
                      ),
                    )
                  : RawScrollbar(
                      thumbColor: kPrimary.withOpacity(0.5),
                      radius: const Radius.circular(8),
                      thickness: 4,
                      child: ListView.builder(
                        itemCount: filteredOptions.length,
                        itemBuilder: (context, index) {
                          final opt = filteredOptions[index];
                          final isSelected = _tempSelected.any(
                            (o) => o['name'] == opt['name'],
                          );
                          return CheckboxListTile(
                            activeColor: kPrimary,
                            checkColor: kWhite,
                            side: BorderSide(color: kMuted.withOpacity(0.5)),
                            title: Text(
                              opt['name'] ?? '',
                              style: const TextStyle(
                                color: kWhite,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'CHF ${((opt['price'] as num?) ?? 0).toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: kMuted,
                                fontSize: 12,
                              ),
                            ),
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true)
                                  _tempSelected.add(opt);
                                else
                                  _tempSelected.removeWhere(
                                    (o) => o['name'] == opt['name'],
                                  );
                              });
                              widget.onSelectionChanged(_tempSelected);
                            },
                          );
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kPrimary),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Done',
                  style: TextStyle(color: kWhite, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComboItemsField extends StatefulWidget {
  final String hint;
  final List<Map<String, dynamic>> availableItems;
  final List<Map<String, dynamic>> selectedItems;
  final Function(List<Map<String, dynamic>>) onChanged;

  const _ComboItemsField({
    required this.hint,
    required this.availableItems,
    required this.selectedItems,
    required this.onChanged,
  });

  @override
  State<_ComboItemsField> createState() => _ComboItemsFieldState();
}

class _ComboItemsFieldState extends State<_ComboItemsField> {
  void _showSelectionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _ComboItemsDialog(
        availableItems: widget.availableItems,
        initialSelectedItems: widget.selectedItems,
        onSelectionChanged: widget.onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _showSelectionDialog,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: kFieldBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kMuted.withOpacity(0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: widget.selectedItems.isEmpty
                  ? Text(widget.hint, style: const TextStyle(color: kMuted))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.selectedItems.map((item) {
                        final imgUrl = (item['imageUrl'] as String?) ?? '';
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: kPrimary.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (imgUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: _WebSafeImage(
                                    imageUrl: imgUrl,
                                    width: 18,
                                    height: 18,
                                    fallback: const SizedBox(
                                      width: 18,
                                      height: 18,
                                    ),
                                  ),
                                ),
                              if (imgUrl.isNotEmpty) const SizedBox(width: 6),
                              Text(
                                item['name'] ?? '',
                                style: const TextStyle(
                                  color: kWhite,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down, color: kMuted),
          ],
        ),
      ),
    );
  }
}

class _ComboItemsDialog extends StatefulWidget {
  final List<Map<String, dynamic>> availableItems;
  final List<Map<String, dynamic>> initialSelectedItems;
  final Function(List<Map<String, dynamic>>) onSelectionChanged;

  const _ComboItemsDialog({
    required this.availableItems,
    required this.initialSelectedItems,
    required this.onSelectionChanged,
  });

  @override
  State<_ComboItemsDialog> createState() => _ComboItemsDialogState();
}

class _ComboItemsDialogState extends State<_ComboItemsDialog> {
  late List<Map<String, dynamic>> _tempSelected;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tempSelected = List.from(widget.initialSelectedItems);
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = widget.availableItems
        .where(
          (item) =>
              (item['name'] as String?)?.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ??
              false,
        )
        .toList();
    filteredItems.sort((a, b) {
      final aSelected = _tempSelected.any((o) => o['id'] == a['id']);
      final bSelected = _tempSelected.any((o) => o['id'] == b['id']);
      if (aSelected && !bSelected) return -1;
      if (!aSelected && bSelected) return 1;
      return ((a['name'] as String?) ?? '').compareTo(
        (b['name'] as String?) ?? '',
      );
    });

    return Dialog(
      backgroundColor: kBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxHeight: 520, maxWidth: 420),
        child: Column(
          children: [
            const Text(
              'Add Items to Combo',
              style: TextStyle(
                color: kWhite,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              style: const TextStyle(color: kWhite),
              decoration: InputDecoration(
                hintText: 'Search menu items...',
                hintStyle: const TextStyle(color: kMuted),
                prefixIcon: const Icon(Icons.search, color: kMuted),
                filled: true,
                fillColor: kFieldBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filteredItems.isEmpty
                  ? const Center(
                      child: Text(
                        'No items found',
                        style: TextStyle(color: kMuted),
                      ),
                    )
                  : RawScrollbar(
                      thumbColor: kPrimary.withOpacity(0.5),
                      radius: const Radius.circular(8),
                      thickness: 4,
                      child: ListView.builder(
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final imgUrl = (item['imageUrl'] as String?) ?? '';
                          final isSelected = _tempSelected.any(
                            (o) => o['id'] == item['id'],
                          );
                          return CheckboxListTile(
                            activeColor: kPrimary,
                            checkColor: kWhite,
                            side: BorderSide(color: kMuted.withOpacity(0.5)),
                            secondary: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: imgUrl.isNotEmpty
                                  ? _WebSafeImage(
                                      imageUrl: imgUrl,
                                      width: 40,
                                      height: 40,
                                      fallback: Container(
                                        width: 40,
                                        height: 40,
                                        color: kFieldBg,
                                        child: const Icon(
                                          Icons.fastfood,
                                          color: kMuted,
                                          size: 18,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 40,
                                      height: 40,
                                      color: kFieldBg,
                                      child: const Icon(
                                        Icons.fastfood,
                                        color: kMuted,
                                        size: 18,
                                      ),
                                    ),
                            ),
                            title: Text(
                              item['name'] ?? '',
                              style: const TextStyle(
                                color: kWhite,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'CHF ${((item['price'] as num?) ?? 0).toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: kMuted,
                                fontSize: 12,
                              ),
                            ),
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true)
                                  _tempSelected.add(item);
                                else
                                  _tempSelected.removeWhere(
                                    (o) => o['id'] == item['id'],
                                  );
                              });
                              widget.onSelectionChanged(_tempSelected);
                            },
                          );
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kPrimary),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Done',
                  style: TextStyle(color: kWhite, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
