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
const kPrimary = Color(0xFFA26334);
const kBg = Color(0xFF2A2928);
const kWhite = Color(0xFFFFFFFF);
const kMuted = Color(0xFFB7B7B6);
const kFieldBg = Color(0xFF383735);
// ----------------------------------

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
  final _price = TextEditingController();

  // 🟢 List to store dynamic additional option fields
  List<AdditionalOptionField> _additionalOptions = [];

  Uint8List? _imgBytes;
  String? _imgFileName;

  String? _selectedCategory;
  String? _selectedCategoryIconUrl;

  String _itemType = 'food'; // 'food' or 'drink'

  List<Map<String, dynamic>> _allAvailableChoices = [];
  List<Map<String, dynamic>> _selectedMenuChoices = [];
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
    for (var opt in _additionalOptions) {
      opt.dispose();
    }
    super.dispose();
  }

  // 🟢 Add / Remove option fields
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
      final price = double.tryParse(_price.text.trim());

      if (name.isEmpty || price == null)
        throw Exception('Name and valid price are required.');
      if (_selectedCategory == null) throw Exception('Select a category.');
      if (_imgBytes == null) throw Exception('Pick an image.');

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
        'price': price,
        'category': _selectedCategory,
        'categoryIconUrl': _selectedCategoryIconUrl,
        'imageUrl': imageUrl,
        'imageFileName': fileName,
        'menuChoices': choiceIds,
        'additionalOptions': optionsData, // 🟢 Saved with isOptional
        'status': 'on',
        'itemType': _itemType,
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
                    // Header label
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

                    // Row 1: Option Name + Price
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

                    // Delete button
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
                      final names = snap.data!.docs.map((d) => d.id).toList();
                      return DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
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
                          onChanged: (v) =>
                              setState(() => _selectedCategory = v),
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

          // ── Error ───────────────────────────────────────────────────
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _err!,
                style: const TextStyle(color: Colors.redAccent),
              ),
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
                  : const Text(
                      'Save Menu Item',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Manage Menu Items ───────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.settings, color: kWhite, size: 18),
              label: const Text(
                'Manage Menu Items',
                style: TextStyle(color: kWhite),
              ),
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
