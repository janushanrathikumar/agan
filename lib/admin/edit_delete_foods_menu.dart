// lib/edit_delete_foods_menu.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Your universal image importer! This handles both Web and Mobile automatically.
import 'package:restorant/platform_image/platform_image.dart';

const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);

class EditDeleteFoodsMenuPage extends StatefulWidget {
  const EditDeleteFoodsMenuPage({super.key});
  @override
  State<EditDeleteFoodsMenuPage> createState() =>
      _EditDeleteFoodsMenuPageState();
}

class _EditDeleteFoodsMenuPageState extends State<EditDeleteFoodsMenuPage> {
  late Future<Map<String, String>> _cats; // name -> iconUrl

  @override
  void initState() {
    super.initState();
    _cats = _loadCategories();
  }

  Future<Map<String, String>> _loadCategories() async {
    final q = await FirebaseFirestore.instance
        .collection('menu_category')
        .get();
    final m = <String, String>{};
    for (final d in q.docs) {
      final data = (d.data()) as Map<String, dynamic>;
      m[d.id] = (data['iconUrl'] as String?) ?? '';
    }
    return m;
  }

  Future<void> _deleteFood(DocumentSnapshot doc) async {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final name = data['name'] ?? doc.id;
    final imageFileName = data['imageFileName'] as String?;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete food?'),
        content: Text('This will remove "$name".'),
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

    try {
      if (imageFileName != null && imageFileName.isNotEmpty) {
        final ref = FirebaseStorage.instance.ref('foods_images/$imageFileName');
        try {
          await ref.delete();
        } catch (_) {}
      }
      await doc.reference.delete();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<void> _editFood(DocumentSnapshot doc, Map<String, String> cats) async {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final nameCtrl = TextEditingController(text: data['name'] as String? ?? '');
    final noteCtrl = TextEditingController(text: data['note'] as String? ?? '');
    final priceCtrl = TextEditingController(
      text: (data['price']?.toString() ?? ''),
    );
    String? category = data['category'] as String?;
    String status = (data['status'] as String?) ?? 'on';
    String? imageUrl = data['imageUrl'] as String?;
    String? imageFileName = data['imageFileName'] as String?;
    Uint8List? newImgBytes;
    String? newImgFileName;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (c) => StatefulBuilder(
        builder: (c, setS) {
          Future<void> pickNew() async {
            final x = await ImagePicker().pickImage(
              source: ImageSource.gallery,
              maxWidth: 1280,
              maxHeight: 1280,
              imageQuality: 90,
            );
            if (x == null) return;

            final bytes = await x.readAsBytes();
            setS(() {
              newImgBytes = bytes;
              newImgFileName = x.name;
            });
          }

          String guessCT(String? fn) {
            final ext = fn?.split('.').last.toLowerCase();
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

          Future<void> save() async {
            final nm = nameCtrl.text.trim();
            final pr = double.tryParse(priceCtrl.text.trim());
            if (nm.isEmpty || pr == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Name and valid price required')),
              );
              return;
            }
            try {
              String? uploadedUrl;
              String? uploadedFileName;

              if (newImgBytes != null) {
                final safeBase = (newImgFileName ?? nm).replaceAll(
                  RegExp(r'[^a-zA-Z0-9._-]+'),
                  '_',
                );
                final fn = '${DateTime.now().millisecondsSinceEpoch}_$safeBase';
                final ref = FirebaseStorage.instance.ref('foods_images/$fn');
                await ref.putData(
                  newImgBytes!,
                  SettableMetadata(contentType: guessCT(newImgFileName)),
                );
                uploadedUrl = await ref.getDownloadURL();
                uploadedFileName = fn;

                if ((imageFileName ?? '').isNotEmpty) {
                  try {
                    await FirebaseStorage.instance
                        .ref('foods_images/$imageFileName')
                        .delete();
                  } catch (_) {}
                }
              }

              final update = <String, dynamic>{
                'name': nm,
                'note': noteCtrl.text.trim().isEmpty
                    ? null
                    : noteCtrl.text.trim(),
                'price': pr,
                'category': category,
                'categoryIconUrl': (category != null)
                    ? (cats[category] ?? '')
                    : null,
                'status': status,
                'updatedAt': FieldValue.serverTimestamp(),
              };
              if (uploadedUrl != null) {
                update['imageUrl'] = uploadedUrl;
                update['imageFileName'] = uploadedFileName;
              }

              await doc.reference.update(update);
              if (mounted) Navigator.pop(context);
            } catch (e) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(c).viewInsets.bottom + 16,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: kMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      height: 64,
                      width: 64,
                      child: newImgBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                newImgBytes!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: buildUniversalImage(
                                imageUrl: imageUrl ?? '',
                                width: 64,
                                height: 64,
                                fallback: const Icon(
                                  Icons.image_not_supported,
                                  color: kWhite,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: pickNew,
                      icon: const Icon(Icons.image, color: kWhite),
                      label: const Text(
                        'Change image',
                        style: TextStyle(color: kWhite),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _tf('Name', nameCtrl),
                const SizedBox(height: 8),
                _tf('Note (optional)', noteCtrl),
                const SizedBox(height: 8),
                _tf(
                  'Price',
                  priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 8),
                // Category Dropdown
                InputDecorator(
                  decoration: _dec('Category'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: category,
                      dropdownColor: kBg,
                      isExpanded: true,
                      items: cats.keys.map((n) {
                        return DropdownMenuItem(
                          value: n,
                          child: Row(
                            children: [
                              _CategoryIcon(iconUrl: cats[n]),
                              const SizedBox(width: 8),
                              Text(n, style: const TextStyle(color: kWhite)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setS(() => category = v),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Status Dropdown
                InputDecorator(
                  decoration: _dec('Status'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: status,
                      dropdownColor: kBg,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'on',
                          child: Text('on', style: TextStyle(color: kWhite)),
                        ),
                        DropdownMenuItem(
                          value: 'off',
                          child: Text('off', style: TextStyle(color: kWhite)),
                        ),
                      ],
                      onChanged: (v) => setS(() => status = v ?? 'on'),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: kWhite,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: save,
                    child: const Text(
                      'Save changes',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kWhite,
        title: const Text('Edit / Delete Foods Menu'),
      ),
      body: FutureBuilder<Map<String, String>>(
        future: _cats,
        builder: (context, catSnap) {
          if (catSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (catSnap.hasError) {
            return Center(
              child: Text(
                'Category load error: ${catSnap.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }
          final cats = catSnap.data ?? {};

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('foods')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snap.error}',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                );
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text('No foods yet', style: TextStyle(color: kWhite)),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final d = docs[i];
                  final m = (d.data() as Map<String, dynamic>?) ?? {};
                  final name = (m['name'] as String?) ?? '—';
                  final price = (m['price'] as num?)?.toStringAsFixed(2) ?? '—';
                  final category = (m['category'] as String?) ?? '—';
                  final status = (m['status'] as String?) ?? 'on';
                  final imageUrl = (m['imageUrl'] as String?) ?? '';

                  return Card(
                    color: const Color(0xFF2F2E2D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: kMuted),
                    ),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: buildUniversalImage(
                          imageUrl: imageUrl,
                          width: 48,
                          height: 48,
                          fallback: const Icon(Icons.restaurant, color: kWhite),
                        ),
                      ),
                      title: Text(
                        '$name • RM $price',
                        style: const TextStyle(
                          color: kWhite,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Category: $category   Status: $status',
                        style: const TextStyle(color: kMuted),
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit, color: kWhite),
                            onPressed: () => _editFood(d, cats),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _deleteFood(d),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
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
  );

  Widget _tf(
    String label,
    TextEditingController c, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: c,
      keyboardType: keyboardType,
      style: const TextStyle(color: kWhite),
      decoration: _dec(label),
    );
  }
}

// Cleaned up _CategoryIcon using our universal image setup
class _CategoryIcon extends StatelessWidget {
  final String? iconUrl;
  const _CategoryIcon({this.iconUrl});

  @override
  Widget build(BuildContext context) {
    final url = iconUrl ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: buildUniversalImage(
        imageUrl: url,
        width: 20,
        height: 20,
        fallback: const Icon(
          Icons.image_not_supported,
          color: kMuted,
          size: 18,
        ),
      ),
    );
  }
}
