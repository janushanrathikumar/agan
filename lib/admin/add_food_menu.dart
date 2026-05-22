// lib/add_food_menu.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'edit_delete_foods_menu.dart';

// வெப் இமேஜ் CORS எர்ரரைத் தவிர்க்க இந்த இம்போர்ட்டுகள் தேவை
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

const kPrimary = Color(0xFFA63334);
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);

class AddFoodMenuPage extends StatefulWidget {
  const AddFoodMenuPage({super.key});

  @override
  State<AddFoodMenuPage> createState() => _AddFoodMenuPageState();
}

class _AddFoodMenuPageState extends State<AddFoodMenuPage> {
  final _name = TextEditingController();
  final _note = TextEditingController();
  final _price = TextEditingController();

  Uint8List? _imgBytes;
  String? _imgFileName;

  String? _selectedCategory; // menu_category doc id
  String? _selectedCategoryIconUrl; // iconUrl from menu_category

  bool _saving = false;
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    _price.dispose();
    super.dispose();
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
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      default:
        return 'image/png';
    }
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

      if (name.isEmpty || price == null) {
        throw Exception('Name and valid price are required.');
      }
      if (_selectedCategory == null) {
        throw Exception('Select a menu category.');
      }
      if (_imgBytes == null) {
        throw Exception('Pick a food image.');
      }

      final safeBase = (_imgFileName ?? name).replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]+'),
        '_',
      );
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$safeBase';
      final imgRef = FirebaseStorage.instance.ref('foods_images/$fileName');

      await imgRef.putData(
        _imgBytes!,
        SettableMetadata(contentType: _guessContentType(_imgFileName)),
      );
      final imageUrl = await imgRef.getDownloadURL();

      await FirebaseFirestore.instance.collection('foods').add({
        'name': name,
        'note': note.isEmpty ? null : note,
        'price': price,
        'category': _selectedCategory,
        'categoryIconUrl': _selectedCategoryIconUrl,
        'imageUrl': imageUrl,
        'imageFileName': fileName,
        'status': 'on', // required
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Food saved')));
      _name.clear();
      _note.clear();
      _price.clear();
      setState(() {
        _imgBytes = null;
        _imgFileName = null;
        _selectedCategory = null;
        _selectedCategoryIconUrl = null;
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
        title: const Text('Add Food Menu'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Image picker
          InkWell(
            onTap: _pickImage,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFF2F2E2D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kMuted),
              ),
              alignment: Alignment.center,
              child: _imgBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        _imgBytes!,
                        height: 160,
                        fit: BoxFit.contain,
                      ),
                    )
                  : const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image, size: 36, color: kMuted),
                        SizedBox(height: 8),
                        Text(
                          'Tap to choose food image',
                          style: TextStyle(color: kWhite),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '(PNG/JPG, up to ~1MB)',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),

          _input(label: 'Food name', controller: _name),
          const SizedBox(height: 12),
          _input(label: 'Note (optional)', controller: _note),
          const SizedBox(height: 12),
          _input(
            label: 'Price',
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),

          // Menu category dropdown with icon
          Card(
            color: const Color(0xFF2F2E2D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: kMuted),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('menu_category')
                    .orderBy('createdAt', descending: false)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(8),
                      child: LinearProgressIndicator(),
                    );
                  }
                  if (snap.hasError) {
                    return Text(
                      'Error: ${snap.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    );
                  }
                  final docs = snap.data?.docs ?? [];

                  final names = <String>[];
                  final iconMap = <String, String>{};
                  for (final d in docs) {
                    final data = (d.data() as Map<String, dynamic>?) ?? {};
                    final name = d.id; // doc id
                    final iconUrl = (data['iconUrl'] as String?) ?? '';
                    names.add(name);
                    iconMap[name] = iconUrl;
                  }
                  names.sort(
                    (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
                  );

                  if (_selectedCategory != null &&
                      !names.contains(_selectedCategory)) {
                    _selectedCategory = null;
                    _selectedCategoryIconUrl = null;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Menu category',
                        style: TextStyle(color: kMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        dropdownColor: const Color(0xFF2F2E2D),
                        items: names
                            .map(
                              (n) => DropdownMenuItem(
                                value: n,
                                child: Row(
                                  children: [
                                    _CategoryIcon(iconUrl: iconMap[n]),
                                    const SizedBox(width: 8),
                                    Text(
                                      n,
                                      style: const TextStyle(color: kWhite),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedCategory = v;
                            _selectedCategoryIconUrl = v == null
                                ? null
                                : iconMap[v];
                          });
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF2F2E2D),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: kMuted),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: kPrimary,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        iconEnabledColor: kWhite,
                        style: const TextStyle(color: kWhite),
                        hint: const Text(
                          'Select category',
                          style: TextStyle(color: kMuted),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_selectedCategoryIconUrl != null &&
                          _selectedCategoryIconUrl!.isNotEmpty)
                        Row(
                          children: [
                            _CategoryIcon(iconUrl: _selectedCategoryIconUrl),
                            const SizedBox(width: 8),
                            Text(
                              _selectedCategory ?? '',
                              style: const TextStyle(color: kWhite),
                            ),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 16),
          if (_err != null)
            Text(_err!, style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: kWhite,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kWhite,
                      ),
                    )
                  : const Text('Save'),
            ),
          ),
          const SizedBox(height: 12),

          // Edit and Delete -> same manage page
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit, color: kWhite),
                  label: const Text(
                    'Edit Foods',
                    style: TextStyle(color: kWhite),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kMuted),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditDeleteFoodsMenuPage(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  label: const Text(
                    'Delete Foods',
                    style: TextStyle(color: kWhite),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kMuted),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditDeleteFoodsMenuPage(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _input({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: kWhite),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kMuted),
        filled: true,
        fillColor: const Color(0xFF2F2E2D),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: kMuted),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: kPrimary, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

// திருத்தப்பட்ட பகுதி: கேட்டகிரி ஐகான் வெப் பிரவுசரில் தெரியும்படி மாற்றப்பட்டுள்ளது
class _CategoryIcon extends StatelessWidget {
  final String? iconUrl;
  const _CategoryIcon({this.iconUrl});

  @override
  Widget build(BuildContext context) {
    final url = iconUrl ?? '';
    if (url.isEmpty) {
      return const Icon(Icons.image_not_supported, color: kMuted, size: 20);
    }

    if (kIsWeb) {
      // வெப்பில் CORS பிளாக்கிங்கைத் தவிர்க்க HTML View பயன்படுத்துகிறது
      final String viewId =
          'add-food-cat-img-${url.hashCode}_${DateTime.now().microsecondsSinceEpoch}';

      ui_web.platformViewRegistry.registerViewFactory(
        viewId,
        (int viewId) => html.ImageElement()
          ..src = url
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'cover',
      );

      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 24,
          width: 24,
          child: HtmlElementView(
            viewType: viewId,
          ), // 'viewType' சரியாகச் சேர்க்கப்பட்டுள்ளது
        ),
      );
    } else {
      // ஆண்ட்ராய்டு/ஐஓஎஸ் போன்களுக்கு
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          url,
          height: 24,
          width: 24,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image, color: kMuted, size: 20),
        ),
      );
    }
  }
}
