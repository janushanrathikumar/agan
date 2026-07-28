// lib/manage_additional_options.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF2A2928);
const kWhite = Color(0xFFFFFFFF);
const kMuted = Color(0xFFB7B7B6);
const kFieldBg = Color(0xFF383735);
const kDialogBg = Color(0xFF333230);

class ManageAdditionalOptionsPage extends StatefulWidget {
  const ManageAdditionalOptionsPage({super.key});

  @override
  State<ManageAdditionalOptionsPage> createState() =>
      _ManageAdditionalOptionsPageState();
}

class _ManageAdditionalOptionsPageState
    extends State<ManageAdditionalOptionsPage> {
  void _openOptionDialog({String? docId, Map<String, dynamic>? currentData}) {
    final nameCtrl = TextEditingController(text: currentData?['name'] ?? '');
    final priceCtrl = TextEditingController(
      text: currentData?['price']?.toString() ?? '',
    );
    final catalogCtrl = TextEditingController(
      text: currentData?['catalog'] ?? '',
    );

    // Seed the type from existing data, default to food
    String selectedType = currentData?['type'] ?? 'food';
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: kDialogBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      docId == null
                          ? 'Add Additional Option'
                          : 'Edit Additional Option',
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
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              title: const Text(
                                'Food',
                                style: TextStyle(
                                  color: kWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              value: 'food',
                              groupValue: selectedType,
                              activeColor: kPrimary,
                              onChanged: (v) =>
                                  setState(() => selectedType = v!),
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
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              title: const Text(
                                'Drink',
                                style: TextStyle(
                                  color: kWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              value: 'drink',
                              groupValue: selectedType,
                              activeColor: kPrimary,
                              onChanged: (v) =>
                                  setState(() => selectedType = v!),
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
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              title: const Text(
                                'Combo',
                                style: TextStyle(
                                  color: kWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              value: 'combo',
                              groupValue: selectedType,
                              activeColor: kPrimary,
                              onChanged: (v) =>
                                  setState(() => selectedType = v!),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    _input(label: 'Option Name', controller: nameCtrl),
                    const SizedBox(height: 12),
                    _input(
                      label: 'Price',
                      controller: priceCtrl,
                      isNumber: true,
                    ),
                    const SizedBox(height: 12),
                    _input(label: 'Catalog Code', controller: catalogCtrl),

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSaving
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: kMuted),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: kPrimary,
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final name = nameCtrl.text.trim();
                                  final price =
                                      double.tryParse(priceCtrl.text.trim()) ??
                                      0;
                                  final catalog = catalogCtrl.text.trim();

                                  if (name.isEmpty) return;

                                  setState(() => isSaving = true);
                                  try {
                                    final data = {
                                      'name': name,
                                      'price': price,
                                      'catalog': catalog,
                                      'type': selectedType, // 🟢 Save type
                                    };

                                    if (docId == null) {
                                      data['createdAt'] =
                                          FieldValue.serverTimestamp();
                                      await FirebaseFirestore.instance
                                          .collection('additional_options')
                                          .add(data);
                                    } else {
                                      await FirebaseFirestore.instance
                                          .collection('additional_options')
                                          .doc(docId)
                                          .set(data, SetOptions(merge: true));
                                    }
                                    if (context.mounted) Navigator.pop(context);
                                  } catch (e) {
                                    debugPrint(e.toString());
                                    setState(() => isSaving = false);
                                  }
                                },
                          child: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: kWhite,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(docId == null ? 'Save' : 'Save Changes'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _deleteOption(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kDialogBg,
        title: const Text('Delete Option?', style: TextStyle(color: kWhite)),
        content: const Text(
          'Are you sure you want to delete this option?',
          style: TextStyle(color: kMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: kMuted)),
          ),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('additional_options')
                  .doc(docId)
                  .delete();
              Navigator.pop(ctx);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kWhite,
        title: const Text('Manage Additional Options'),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kPrimary,
        child: const Icon(Icons.add, color: kWhite),
        onPressed: () => _openOptionDialog(),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('additional_options')
            .orderBy('type') // Optional: groups them nicely in the list
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kPrimary),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No options added yet.',
                style: TextStyle(color: kMuted),
              ),
            );
          }

          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;
              final typeStr = _capitalize((data['type'] as String?) ?? 'Food');

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: kFieldBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Row(
                    children: [
                      Text(
                        data['name'] ?? '',
                        style: const TextStyle(
                          color: kWhite,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: kPrimary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          typeStr,
                          style: const TextStyle(
                            color: kPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    'Price: ${data['price']} | Code: ${data['catalog']}',
                    style: const TextStyle(color: kMuted),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: kMuted),
                        onPressed: () =>
                            _openOptionDialog(docId: docId, currentData: data),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _deleteOption(docId),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _input({
    required String label,
    required TextEditingController controller,
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
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
}
