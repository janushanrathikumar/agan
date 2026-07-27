// lib/add_category.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

// வெப் இமேஜ் CORS எர்ரரைத் தவிர்க்க இந்த இம்போர்ட்டுகள் தேவை
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;
const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);

class AddCategoryPage extends StatefulWidget {
  const AddCategoryPage({super.key});
  @override
  State<AddCategoryPage> createState() => _AddCategoryPageState();
}

class _AddCategoryPageState extends State<AddCategoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  Uint8List? _iconBytes;
  String? _iconFileName;
  bool _saving = false;

  // 🟢 New: every category is now tagged as Food or Drink, so
  // add_menu_item.dart can show only the categories that match the
  // item type someone is currently adding.
  String _categoryType = 'food';

  @override
  void dispose() {
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_iconBytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pick a category image')));
      return;
    }

    final name = _nameCtrl.text.trim();
    if (name.contains('/')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category name cannot contain "/"')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final safeBase = (_iconFileName ?? name).replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]+'),
        '_',
      );
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$safeBase';
      final ref = FirebaseStorage.instance.ref('menu_category_icons/$fileName');

      await ref.putData(
        _iconBytes!,
        SettableMetadata(contentType: _guessContentType(_iconFileName)),
      );
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('menu_category')
          .doc(name)
          .set({
            'name': name,
            'iconUrl': url,
            'iconFileName': fileName,
            // 🟢 Saved so add_menu_item.dart can filter categories by
            // whether "Food" or "Drink" is currently selected there.
            'type': _categoryType,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved: $name')));
      _nameCtrl.clear();
      setState(() {
        _iconBytes = null;
        _iconFileName = null;
        _categoryType = 'food';
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

  Future<void> _confirmAndDelete(DocumentSnapshot doc) async {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final name = doc.id;
    final iconFileName = (data['iconFileName'] as String?) ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text('This will remove "$name" and its image.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
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

    setState(() => _saving = true);
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
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // வெப் பிளாட்ஃபார்மில் CORS எர்ரர் இல்லாமல் இமேஜ் காட்ட உதவும் பிரத்யேக விட்ஜெட்
  Widget _buildTableImage(String iconUrl) {
    if (iconUrl.isEmpty) {
      return const Icon(Icons.image_not_supported);
    }

    if (kIsWeb) {
      // ஒவ்வொரு இமேஜுக்கும் தனித்தனி ID உருவாக்குகிறது
      final String viewId =
          'img-${iconUrl.hashCode}_${DateTime.now().microsecondsSinceEpoch}';

      // HTML Image Element-ஐ ரிஜிஸ்டர் செய்கிறது (இது CORS-ஐ பைபாஸ் செய்யும்)
      ui_web.platformViewRegistry.registerViewFactory(
        viewId,
        (int viewId) => html.ImageElement()
          ..src = iconUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'cover'
          ..style.borderRadius = '6px',
      );

      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 40,
          width: 40,
          child: HtmlElementView(viewType: viewId),
        ),
      );
    } else {
      // மொபைல் போன்களுக்கு (Android/iOS) பழையபடி Image.network வேலை செய்யும்
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          iconUrl,
          height: 40,
          width: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
        ),
      );
    }
  }

  // 🟢 Small colored chip showing Food / Drink / Combo in the categories table.
  Widget _buildTypeChip(String type) {
    Color color;
    String label;
    if (type == 'drink') {
      color = Colors.blueAccent;
      label = 'Drink';
    } else if (type == 'combo') {
      color = Colors.purpleAccent;
      label = 'Combo';
    } else {
      color = kPrimary;
      label = 'Food';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImg = _iconBytes != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Menu Category'),
        backgroundColor: kPrimary,
        foregroundColor: kWhite,
      ),
      backgroundColor: kBg,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- Form card ----
          Card(
            color: kWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: kMuted, width: 1),
            ),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🟢 Food / Drink / Combo selector — determines which
                    // item type this category will show up under when
                    // someone is adding a menu item. Combo was added
                    // because orders can already contain combo items
                    // (see admin_orders_page.dart), but until now there
                    // was no way to create a combo category or item.
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFAE6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kMuted),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                              title: const Text(
                                'Food',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              value: 'food',
                              groupValue: _categoryType,
                              activeColor: kPrimary,
                              onChanged: (v) =>
                                  setState(() => _categoryType = v!),
                            ),
                          ),
                          Container(width: 1, height: 40, color: kMuted),
                          Expanded(
                            child: RadioListTile<String>(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                              title: const Text(
                                'Drink',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              value: 'drink',
                              groupValue: _categoryType,
                              activeColor: kPrimary,
                              onChanged: (v) =>
                                  setState(() => _categoryType = v!),
                            ),
                          ),
                          Container(width: 1, height: 40, color: kMuted),
                          Expanded(
                            child: RadioListTile<String>(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                              title: const Text(
                                'Combo',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              value: 'combo',
                              groupValue: _categoryType,
                              activeColor: kPrimary,
                              onChanged: (v) =>
                                  setState(() => _categoryType = v!),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _pickImage,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        height: 160,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFAE6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kMuted),
                        ),
                        alignment: Alignment.center,
                        child: hasImg
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  _iconBytes!,
                                  height: 140,
                                  fit: BoxFit.contain,
                                ),
                              )
                            : const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.image, size: 36, color: kPrimary),
                                  SizedBox(height: 8),
                                  Text('Tap to choose category image'),
                                  SizedBox(height: 4),
                                  Text(
                                    '(PNG with transparency preferred)',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: _dec('Category name'),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return 'Required';
                        if (t.contains('/')) return 'Cannot contain "/"';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: kWhite,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _saving ? null : _save,
                        child: Text(
                          _saving ? 'Saving…' : 'Save Category',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    if (_saving)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ---- Table card ----
          Card(
            color: kWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: kMuted, width: 1),
            ),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Categories',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('menu_category')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      if (snap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('Error: ${snap.error}'),
                        );
                      }
                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('No categories yet.'),
                        );
                      }

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 760),
                          child: DataTable(
                            headingRowHeight: 44,
                            dataRowMinHeight: 56,
                            dataRowMaxHeight: 72,
                            columns: const [
                              DataColumn(label: Text('Icon')),
                              DataColumn(label: Text('Name')),
                              DataColumn(label: Text('Type')),
                              DataColumn(label: Text('Created')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: docs.map((d) {
                              final m =
                                  (d.data() as Map<String, dynamic>?) ?? {};
                              final name = (m['name'] as String?) ?? d.id;
                              final iconUrl = (m['iconUrl'] as String?) ?? '';
                              // 🟢 Categories saved before this change won't
                              // have a `type` field yet — default those to
                              // 'food' instead of showing blank/crashing.
                              final categoryType =
                                  (m['type'] as String?) ?? 'food';
                              final ts = m['createdAt'];
                              DateTime? dt;
                              if (ts is Timestamp) dt = ts.toDate();
                              final createdStr = dt != null
                                  ? '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
                                        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
                                  : '—';

                              return DataRow(
                                cells: [
                                  // திருத்தப்பட்ட பகுதி: இங்கு புதிய _buildTableImage பயன்படுத்தப்பட்டுள்ளது
                                  DataCell(_buildTableImage(iconUrl)),
                                  DataCell(Text(name)),
                                  DataCell(_buildTypeChip(categoryType)),
                                  DataCell(Text(createdStr)),
                                  DataCell(
                                    IconButton(
                                      tooltip: 'Delete',
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _confirmAndDelete(d),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: const Color(0xFFFFFAE6),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kMuted),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kPrimary, width: 1.4),
    ),
  );
}