// lib/edit_menu_item.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'choice_dialog.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF2A2928);
const kWhite = Color(0xFFFFFFFF);
const kMuted = Color(0xFFB7B7B6);
const kFieldBg = Color(0xFF383735);

class _WebSafeImage extends StatelessWidget {
  final String imageUrl;
  final double height;

  const _WebSafeImage({required this.imageUrl, required this.height});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return const Icon(Icons.broken_image, color: kMuted, size: 40);
    }

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
  final _itemNo = TextEditingController();
  final _name = TextEditingController();
  final _note = TextEditingController();
  final _price = TextEditingController();

  bool _hasMultipleSizes = false;
  final List<SizeOptionField> _sizeOptions = [];

  List<Map<String, dynamic>> _allAvailableOptions = [];
  List<Map<String, dynamic>> _selectedOptions = [];

  Uint8List? _imgBytes;
  String? _imgFileName;
  String? _existingImageUrl;
  String? _existingImageFileName;

  String? _selectedCategory;
  String? _selectedCategoryIconUrl;
  String _itemType = 'food';

  bool _hasDiscount = false;
  String _discountType = 'percent';
  final _discountValue = TextEditingController();

  List<Map<String, dynamic>> _allAvailableChoices = [];
  List<Map<String, dynamic>> _selectedMenuChoices = [];
  String? _dropdownChoiceValue;

  // 🟢 NEW: Take Away availability (e.g. drinks that can't be packed)
  bool _canTakeAway = true;

  // 🟢 NEW: Combo item selection (search & add existing menu items)
  List<Map<String, dynamic>> _allComboCandidates = [];
  List<Map<String, dynamic>> _selectedComboItems = [];

  bool _saving = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _itemNo.text = widget.itemData['itemNo']?.toString() ?? '';
    _name.text = widget.itemData['name'] ?? '';
    _price.text = (widget.itemData['price'] ?? '').toString();
    _note.text = widget.itemData['note'] ?? '';
    _itemType = widget.itemData['itemType'] ?? 'food';
    _selectedCategory = widget.itemData['category'];
    _selectedCategoryIconUrl = widget.itemData['categoryIconUrl'];
    _existingImageUrl = widget.itemData['imageUrl'];
    _existingImageFileName = widget.itemData['imageFileName'];

    _hasMultipleSizes = widget.itemData['hasMultipleSizes'] ?? false;
    final sizesData = widget.itemData['sizes'] as List<dynamic>? ?? [];
    for (var s in sizesData) {
      final opt = SizeOptionField();
      opt.name.text = s['name'] ?? '';
      opt.dineInPrice.text = (s['dineInPrice'] ?? s['price'] ?? '').toString();
      opt.takeAwayPrice.text = (s['takeAwayPrice'] ?? '').toString();
      _sizeOptions.add(opt);
    }

    _hasDiscount = widget.itemData['hasDiscount'] ?? false;
    _discountType = widget.itemData['discountType'] ?? 'percent';
    final existingDiscountValue = widget.itemData['discountValue'];
    _discountValue.text = existingDiscountValue == null
        ? ''
        : existingDiscountValue.toString();

    final List<dynamic> existingOptions =
        widget.itemData['additionalOptions'] ?? [];
    _selectedOptions = existingOptions.map((opt) {
      return Map<String, dynamic>.from(opt);
    }).toList();

    _canTakeAway = widget.itemData['canTakeAway'] ?? true;
    final List<dynamic> existingComboItems =
        widget.itemData['comboItems'] ?? [];
    _selectedComboItems = existingComboItems
        .map((c) => Map<String, dynamic>.from(c))
        .toList();

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

  // 🟢 NEW: Fetch existing food/drink items that can be bundled into a combo
  Future<void> _fetchComboCandidates() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('menu_items')
          .get();
      if (mounted) {
        setState(() {
          _allComboCandidates = snap.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .where(
                (item) =>
                    (item['itemType'] ?? 'food') != 'combo' &&
                    item['id'] != widget.docId,
              )
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

  String _typeLabel(String type) {
    if (type == 'drink') return 'Drink';
    if (type == 'combo') return 'Combo';
    return 'Food';
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      final itemNo = _itemNo.text.trim();
      final name = _name.text.trim();
      if (name.isEmpty) throw Exception('Name is required');

      if (_itemType == 'combo' && _selectedComboItems.isEmpty) {
        throw Exception('Add at least one item to the combo.');
      }

      double? basePrice;
      List<Map<String, dynamic>> sizesData = [];

      if (_hasMultipleSizes) {
        if (_sizeOptions.isEmpty) {
          throw Exception('Please add at least one size variant.');
        }
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

          if (tPrice != null) {
            sizeMap['takeAwayPrice'] = tPrice;
          }

          sizesData.add(sizeMap);
        }
        basePrice = sizesData
            .map((e) => e['dineInPrice'] as double)
            .reduce((a, b) => a < b ? a : b);
      } else {
        basePrice = double.tryParse(_price.text.trim());
        if (basePrice == null) {
          throw Exception('A valid standard price is required.');
        }
      }

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

      List<Map<String, dynamic>> optionsData = _selectedOptions.map((opt) {
        return {
          'id': opt['id'],
          'name': opt['name'],
          'price': opt['price'],
          'catalog': opt['catalog'],
          'type': opt['type'],
        };
      }).toList();

      String imageUrl = _existingImageUrl ?? '';
      String imageFileName = _existingImageFileName ?? '';

      if (_imgBytes != null) {
        // 🟢 A custom image was picked (works for food/drink AND combo now).
        if (_existingImageFileName != null &&
            _existingImageFileName!.isNotEmpty) {
          try {
            await FirebaseStorage.instance
                .ref('menu_images/$_existingImageFileName')
                .delete();
          } catch (e) {
            debugPrint("Failed to delete old image: $e");
          }
        }

        imageFileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final imgRef = FirebaseStorage.instance.ref(
          'menu_images/$imageFileName',
        );
        await imgRef.putData(_imgBytes!);
        imageUrl = await imgRef.getDownloadURL();
      } else if (_itemType == 'combo' && imageUrl.isEmpty) {
        // 🟢 No custom image was ever set for this combo — fall back to
        // the first selected combo item's photo automatically.
        imageUrl = (_selectedComboItems.first['imageUrl'] as String?) ?? '';
        imageFileName = '';
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

      await FirebaseFirestore.instance
          .collection('menu_items')
          .doc(widget.docId)
          .update({
            'itemNo': itemNo,
            'name': name,
            'note': _note.text.trim(),
            'price': basePrice,
            'hasMultipleSizes': _hasMultipleSizes,
            'sizes': sizesData,
            'category': _selectedCategory,
            'categoryIconUrl': _selectedCategoryIconUrl,
            'imageUrl': imageUrl,
            'imageFileName': imageFileName,
            'menuChoices': _selectedMenuChoices.map((c) => c['id']).toList(),
            'additionalOptions': optionsData,
            'itemType': _itemType,
            'hasDiscount': _hasDiscount,
            'discountType': _hasDiscount ? _discountType : null,
            'discountValue': _hasDiscount ? discountValue : 0,
            'canTakeAway': _canTakeAway,
            'comboItems': comboItemsData,
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
                    groupValue: _itemType,
                    activeColor: kPrimary,
                    onChanged: _onTypeChanged,
                  ),
                ),
                Container(width: 1, height: 40, color: kMuted.withOpacity(0.3)),
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
                    groupValue: _itemType,
                    activeColor: kPrimary,
                    onChanged: _onTypeChanged,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 🟢 Combo items can now ALSO have their image edited manually.
          // If no custom image was ever picked, it falls back to the first
          // combo item's photo automatically.
          Builder(
            builder: (context) {
              final String comboFallbackUrl = _selectedComboItems.isNotEmpty
                  ? ((_selectedComboItems.first['imageUrl'] as String?) ?? '')
                  : '';
              final bool hasExisting =
                  _existingImageUrl != null && _existingImageUrl!.isNotEmpty;
              final String previewUrl = hasExisting
                  ? _existingImageUrl!
                  : comboFallbackUrl;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: _pickImage,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: kFieldBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_imgBytes != null)
                            Image.memory(
                              _imgBytes!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            )
                          else if (previewUrl.isNotEmpty)
                            _WebSafeImage(imageUrl: previewUrl, height: 150)
                          else
                            const Center(
                              child: Column(
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
                          if (_imgBytes != null || previewUrl.isNotEmpty)
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.55),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit, size: 14, color: kWhite),
                                    SizedBox(width: 4),
                                    Text(
                                      'Tap to change',
                                      style: TextStyle(
                                        color: kWhite,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_itemType == 'combo') ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hasExisting || _imgBytes != null
                                ? 'Custom combo image set — tap above to change.'
                                : 'Using the photo of the first combo item. Tap above to set a custom one.',
                            style: const TextStyle(color: kMuted, fontSize: 11),
                          ),
                        ),
                        if ((hasExisting || _imgBytes != null) &&
                            comboFallbackUrl.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _imgBytes = null;
                                _imgFileName = null;
                                _existingImageUrl = null;
                                _existingImageFileName = null;
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Use combo item photo',
                              style: TextStyle(color: kPrimary, fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              );
            },
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
                          final opt1 = SizeOptionField();
                          opt1.name.text = 'Kleine Portion';
                          _sizeOptions.add(opt1);

                          final opt2 = SizeOptionField();
                          opt2.name.text = 'Portion';
                          _sizeOptions.add(opt2);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                ],

                // 🟢 NEW: Take Away availability toggle
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

                const SizedBox(height: 16),
                _input(
                  label: 'Description (optional)',
                  controller: _note,
                  maxLines: 3,
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

          // 🟢 NEW Multi-Select Design For Additional Options
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
              final matchingOptions = _allAvailableOptions.where((opt) {
                final optType = (opt['type'] as String?) ?? 'food';
                return optType == _itemType;
              }).toList();

              return _MultiSelectOptionsField(
                hint: matchingOptions.isEmpty
                    ? 'No ${_typeLabel(_itemType)} additional options yet'
                    : 'Choose additional options...',
                availableOptions: matchingOptions,
                selectedOptions: _selectedOptions,
                onChanged: (newSelection) {
                  setState(() {
                    _selectedOptions.clear();
                    _selectedOptions.addAll(newSelection);
                  });
                },
              );
            },
          ),
          const SizedBox(height: 24),

          // 🟢 NEW: Combo Items — search & add existing menu items
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
              onChanged: (newSelection) {
                setState(() {
                  _selectedComboItems = List.from(newSelection);
                });
              },
            ),
            const SizedBox(height: 24),
          ],

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

                final allDocs = snap.data!.docs;
                final matchingDocs = allDocs.where((d) {
                  final data = d.data() as Map<String, dynamic>? ?? {};
                  final catType = (data['type'] as String?) ?? 'food';
                  return catType == _itemType;
                }).toList();

                final names = matchingDocs.map((d) => d.id).toList();

                final String? safeValue = names.contains(_selectedCategory)
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
                      final match = matchingDocs.firstWhere((d) => d.id == v);
                      final matchData =
                          match.data() as Map<String, dynamic>? ?? {};
                      setState(() {
                        _selectedCategory = v;
                        _selectedCategoryIconUrl =
                            matchData['iconUrl'] as String?;
                      });
                    },
                  ),
                );
              },
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
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: const TextStyle(color: kWhite, fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kMuted, fontSize: 12),
        filled: true,
        fillColor: kFieldBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: kPrimary),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

// 🟢 NEW: Custom Multi-Select Field Widget
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
      builder: (ctx) {
        return _MultiSelectDialog(
          availableOptions: widget.availableOptions,
          initialSelectedOptions: widget.selectedOptions,
          onSelectionChanged: widget.onChanged,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _showSelectionDialog,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        //minHeight: 52,
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
                      children: widget.selectedOptions.map((opt) {
                        return Container(
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

// 🟢 NEW: Dialog containing Search & Checkboxes
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
    final filteredOptions = widget.availableOptions.where((opt) {
      final name = (opt['name'] as String?)?.toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    filteredOptions.sort((a, b) {
      final aSelected = _tempSelected.any((o) => o['name'] == a['name']);
      final bSelected = _tempSelected.any((o) => o['name'] == b['name']);
      if (aSelected && !bSelected) return -1;
      if (!aSelected && bSelected) return 1;
      final nameA = (a['name'] as String?) ?? '';
      final nameB = (b['name'] as String?) ?? '';
      return nameA.compareTo(nameB);
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
                                if (val == true) {
                                  _tempSelected.add(opt);
                                } else {
                                  _tempSelected.removeWhere(
                                    (o) => o['name'] == opt['name'],
                                  );
                                }
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

// 🟢 NEW: Combo Items field — shows selected items as chips with thumbnails
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
      builder: (ctx) {
        return _ComboItemsDialog(
          availableItems: widget.availableItems,
          initialSelectedItems: widget.selectedItems,
          onSelectionChanged: widget.onChanged,
        );
      },
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
                                  child: Image.network(
                                    imgUrl,
                                    width: 18,
                                    height: 18,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox(width: 18, height: 18),
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

// 🟢 NEW: Search & checkbox dialog for combo item selection
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
    final filteredItems = widget.availableItems.where((item) {
      final name = (item['name'] as String?)?.toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    filteredItems.sort((a, b) {
      final aSelected = _tempSelected.any((o) => o['id'] == a['id']);
      final bSelected = _tempSelected.any((o) => o['id'] == b['id']);
      if (aSelected && !bSelected) return -1;
      if (!aSelected && bSelected) return 1;
      final nameA = (a['name'] as String?) ?? '';
      final nameB = (b['name'] as String?) ?? '';
      return nameA.compareTo(nameB);
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
                                  ? Image.network(
                                      imgUrl,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
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
                                if (val == true) {
                                  _tempSelected.add(item);
                                } else {
                                  _tempSelected.removeWhere(
                                    (o) => o['id'] == item['id'],
                                  );
                                }
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
