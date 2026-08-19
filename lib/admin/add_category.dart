// lib/add_category.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

// வெப் இமேஜ் CORS எர்ரரைத் தவிர்க்க
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:restorant/platform_image/platform_image.dart';

// 🟢 FULL DARK THEME COLORS
const kPrimary = Color(0xFFB59410); // Gold/Yellow
const kBg = Color(0xFF121212); // Deep Dark Background
const kCardBg = Color(0xFF2A2928); // Dark Card Background
const kMuted = Color(0xFF8E8E8E); // Muted Gray
const kWhite = Color(0xFFFFFFFF); // White for Text

class AddCategoryPage extends StatefulWidget {
  const AddCategoryPage({super.key});
  @override
  State<AddCategoryPage> createState() => _AddCategoryPageState();
}

class _AddCategoryPageState extends State<AddCategoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _itemNoCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  Uint8List? _iconBytes;
  String? _iconFileName;
  bool _saving = false;
  String _categoryType = 'food';
  String? _selectedCategoryId; // To track selected category

  @override
  void dispose() {
    _itemNoCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final p = ImagePicker();
    final x = await p.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _iconBytes = bytes;
      _iconFileName = x.name;
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

  // 🟢 Add / Edit Save Function
  Future<void> _saveCategory({DocumentSnapshot? existingDoc}) async {
    if (!_formKey.currentState!.validate()) return;

    final isEdit = existingDoc != null;
    final existingData = isEdit
        ? existingDoc.data() as Map<String, dynamic>
        : {};

    if (!isEdit && _iconBytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pick a category image')));
      return;
    }

    final itemNo = _itemNoCtrl.text.trim();
    final name = _nameCtrl.text.trim();

    if (name.contains('/')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category name cannot contain "/"')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      String iconUrl = existingData['iconUrl'] ?? '';
      String iconFileName = existingData['iconFileName'] ?? '';

      // Upload new image if selected
      if (_iconBytes != null) {
        final safeBase = (_iconFileName ?? name).replaceAll(
          RegExp(r'[^a-zA-Z0-9._-]+'),
          '_',
        );
        iconFileName = '${DateTime.now().millisecondsSinceEpoch}_$safeBase';
        final ref = FirebaseStorage.instance.ref(
          'menu_category_icons/$iconFileName',
        );

        await ref.putData(
          _iconBytes!,
          SettableMetadata(contentType: _guessContentType(_iconFileName)),
        );
        iconUrl = await ref.getDownloadURL();
      }

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('menu_category')
          .doc(name)
          .set({
            'itemNo': itemNo,
            'name': name,
            'iconUrl': iconUrl,
            'iconFileName': iconFileName,
            'type': _categoryType,
            'createdAt': isEdit
                ? existingData['createdAt']
                : FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // If name changed during edit, delete the old document
      if (isEdit && existingDoc.id != name) {
        await FirebaseFirestore.instance
            .collection('menu_category')
            .doc(existingDoc.id)
            .delete();
        setState(() => _selectedCategoryId = name);
      } else if (!isEdit) {
        setState(() => _selectedCategoryId = name);
      }

      if (!mounted) return;

      // 🟢 டயலாங்கை மட்டும் க்ளோஸ் செய்ய `Navigator.pop(context)` பயன்படுத்தப்பட்டுள்ளது
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEdit ? 'Updated: $name' : 'Saved: $name')),
      );

      // ஃபார்மை க்ளியர் செய்தல்
      _itemNoCtrl.clear();
      _nameCtrl.clear();
      setState(() {
        _iconBytes = null;
        _iconFileName = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // 🟢 Delete Category Function
  Future<void> _confirmAndDelete(DocumentSnapshot doc) async {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final name = doc.id;
    final iconFileName = (data['iconFileName'] as String?) ?? '';

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('Delete category?', style: TextStyle(color: kWhite)),
        content: Text(
          'This will remove "$name" and its image.',
          style: const TextStyle(color: kMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel', style: TextStyle(color: kMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      if (iconFileName.isNotEmpty) {
        final ref = FirebaseStorage.instance.ref(
          'menu_category_icons/$iconFileName',
        );
        try {
          await ref.delete();
        } catch (_) {}
      }
      await doc.reference.delete();
      setState(() => _selectedCategoryId = null);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Deleted: $name')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  // 🟢 Universal Image Builder
  Widget _buildWebSafeImage(
    String iconUrl, {
    double height = 150,
    double width = 150,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: buildUniversalImage(
        imageUrl: iconUrl,
        width: width,
        height: height,
        fallback: Icon(
          Icons.image_not_supported,
          size: height / 2,
          color: kMuted,
        ),
      ),
    );
  }

  // 🟢 Show Add / Edit Dialog Form
  void _showCategoryForm({DocumentSnapshot? existingDoc}) {
    if (existingDoc != null) {
      final data = existingDoc.data() as Map<String, dynamic>;
      _itemNoCtrl.text = data['itemNo'] ?? '';
      _nameCtrl.text = data['name'] ?? existingDoc.id;
      _categoryType = data['type'] ?? 'food';
      _iconBytes = null;
    } else {
      _itemNoCtrl.clear();
      _nameCtrl.clear();
      _categoryType = 'food';
      _iconBytes = null;
    }

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isEdit = existingDoc != null;
          final existingImageUrl = isEdit
              ? (existingDoc.data() as Map<String, dynamic>)['iconUrl']
              : null;

          return AlertDialog(
            backgroundColor: kCardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: kPrimary, width: 1),
            ),
            title: Text(
              isEdit ? 'Edit Category' : 'Add Menu Category',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: kWhite,
              ),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Category Type
                    Container(
                      decoration: BoxDecoration(
                        color: kBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kMuted.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: ['food', 'drink', 'combo'].map((type) {
                          return Expanded(
                            child: RadioListTile<String>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                type.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: kWhite,
                                ),
                              ),
                              value: type,
                              groupValue: _categoryType,
                              activeColor: kPrimary,
                              onChanged: (v) {
                                setState(() => _categoryType = v!);
                                setDialogState(() {});
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Image Picker
                    InkWell(
                      onTap: () async {
                        await _pickImage();
                        setDialogState(() {});
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        height: 140,
                        decoration: BoxDecoration(
                          color: kBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kMuted.withOpacity(0.3)),
                        ),
                        alignment: Alignment.center,
                        child: _iconBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  _iconBytes!,
                                  height: 120,
                                  fit: BoxFit.contain,
                                ),
                              )
                            : (isEdit &&
                                  existingImageUrl != null &&
                                  existingImageUrl.isNotEmpty)
                            ? _buildWebSafeImage(
                                existingImageUrl,
                                height: 120,
                                width: double.infinity,
                              )
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
                                    'Tap to choose image',
                                    style: TextStyle(color: kMuted),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _itemNoCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: kWhite),
                      decoration: _dec('Category ID / Number (e.g., 1, 2)'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _nameCtrl,
                      style: const TextStyle(color: kWhite),
                      decoration: _dec('Category name'),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return 'Required';
                        if (t.contains('/')) return 'Cannot contain "/"';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: kMuted)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _saving
                    ? null
                    : () => _saveCategory(existingDoc: existingDoc),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        isEdit ? 'Update' : 'Save',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: kMuted),
    filled: true,
    fillColor: kBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: kMuted.withOpacity(0.3)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kPrimary, width: 1.4),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text(
          'Menu Categories',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: kPrimary,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 700;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: isDesktop ? 280 : constraints.maxWidth,
                  child: _buildSidebar(),
                ),
                if (isDesktop) const SizedBox(width: 16),
                if (isDesktop) Expanded(child: _buildRightPanel()),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSidebar() {
    return Card(
      color: kCardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: kMuted.withOpacity(0.2), width: 1),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Categories',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kWhite,
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimary,
                    side: const BorderSide(color: kPrimary),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 0,
                    ),
                  ),
                  onPressed: () => _showCategoryForm(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                ),
              ],
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('menu_category')
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: kPrimary),
                    );
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No categories yet.',
                        style: TextStyle(color: kMuted),
                      ),
                    );
                  }

                  var sortedDocs = docs.toList();
                  sortedDocs.sort((a, b) {
                    final d1 = a.data() as Map<String, dynamic>? ?? {};
                    final d2 = b.data() as Map<String, dynamic>? ?? {};
                    final n1 =
                        int.tryParse(d1['itemNo']?.toString() ?? '') ?? 0;
                    final n2 =
                        int.tryParse(d2['itemNo']?.toString() ?? '') ?? 0;
                    return n1.compareTo(n2);
                  });

                  return ListView.builder(
                    itemCount: sortedDocs.length,
                    itemBuilder: (context, index) {
                      final doc = sortedDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['name'] ?? doc.id;
                      final isSelected = _selectedCategoryId == doc.id;

                      return InkWell(
                        onTap: () =>
                            setState(() => _selectedCategoryId = doc.id),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? kPrimary.withOpacity(0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected
                                ? Border.all(color: kPrimary)
                                : null,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.drag_indicator,
                                color: kMuted,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected ? kPrimary : kWhite,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.circle,
                                  color: kPrimary,
                                  size: 10,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    return Card(
      color: kCardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: kMuted.withOpacity(0.2), width: 1),
      ),
      elevation: 4,
      child: _selectedCategoryId == null
          ? const Center(
              child: Text(
                'Select a category to view details',
                style: TextStyle(color: kMuted, fontSize: 16),
              ),
            )
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('menu_category')
                  .doc(_selectedCategoryId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(
                    child: Text(
                      'Category deleted or not found.',
                      style: TextStyle(color: kWhite),
                    ),
                  );
                }

                final doc = snapshot.data!;
                final data = doc.data() as Map<String, dynamic>;
                final name = data['name'] ?? doc.id;
                final itemNo = data['itemNo'] ?? '-';
                final type = data['type'] ?? 'food';
                final iconUrl = data['iconUrl'] ?? '';

                return Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Category Details',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: kWhite,
                            ),
                          ),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: kPrimary,
                                  side: const BorderSide(color: kPrimary),
                                ),
                                onPressed: () =>
                                    _showCategoryForm(existingDoc: doc),
                                icon: const Icon(Icons.edit, size: 18),
                                label: const Text('Edit'),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red.shade900,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => _confirmAndDelete(doc),
                                icon: const Icon(Icons.delete, size: 18),
                                label: const Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 150,
                            width: 150,
                            decoration: BoxDecoration(
                              color: kBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: kMuted.withOpacity(0.3),
                              ),
                            ),
                            child: _buildWebSafeImage(
                              iconUrl,
                              height: 150,
                              width: 150,
                            ),
                          ),
                          const SizedBox(width: 32),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _detailRow('Category Name:', name),
                                const SizedBox(height: 16),
                                _detailRow('Category ID / Order:', itemNo),
                                const SizedBox(height: 16),
                                _detailRow(
                                  'Type:',
                                  type.toString().toUpperCase(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _detailRow(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, color: kMuted)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: kWhite,
          ),
        ),
      ],
    );
  }
}
