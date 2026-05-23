// lib/home/add_menu_choice_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'choice_dialog.dart'; // We will create this next

const kPrimary = Color(0xFFA26334);
const kBg = Color(0xFF2A2928);
const kWhite = Color(0xFFFFFFFF);
const kMuted = Color(0xFFB7B7B6);

class AddMenuChoicePage extends StatefulWidget {
  const AddMenuChoicePage({super.key});

  @override
  State<AddMenuChoicePage> createState() => _AddMenuChoicePageState();
}

class _AddMenuChoicePageState extends State<AddMenuChoicePage> {
  // Open dialog to handle both Creating and Editing groups
  void _openChoiceDialog({String? docId, String? existingHeading, List<String>? existingOptions}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ChoiceDialog(
        docId: docId,
        existingHeading: existingHeading,
        existingOptions: existingOptions,
      ),
    );
  }

  // Handle deleting a choice group completely from Firestore
  Future<void> _deleteChoiceGroup(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF333230),
        title: const Text("Delete Choice Group?", style: TextStyle(color: kWhite)),
        content: const Text("This will permanently remove this heading and all its nested sub-options.", style: TextStyle(color: kMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel", style: TextStyle(color: kMuted))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('menu_choices').doc(docId).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C2B2A),
        iconTheme: const IconThemeData(color: kPrimary),
        title: const Text("Add Menu Choice", style: TextStyle(color: kWhite, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // Top Global Accent Add Action button
          Center(
            child: ElevatedButton.icon(
              onPressed: () => _openChoiceDialog(),
              icon: const Icon(Icons.add, color: kWhite, size: 18),
              label: const Text("Add Menu Choice", style: TextStyle(color: kWhite, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA26334), // Dark Teal like your reference UI
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Realtime Stream of choice groups from Firestore
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('menu_choices').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimary));
                
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text("No choices created yet.", style: TextStyle(color: kMuted)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final String docId = docs[index].id;
                    final String heading = data['heading'] ?? '';
                    final List<String> options = List<String>.from(data['options'] ?? []);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF383735),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.15)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        title: Text(
                          heading,
                          style: const TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: options.isEmpty 
                          ? null 
                          : Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: options.map((opt) => Text(opt, style: const TextStyle(color: kMuted, fontSize: 14, height: 1.4))).toList(),
                              ),
                            ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: kMuted),
                              onPressed: () => _openChoiceDialog(docId: docId, existingHeading: heading, existingOptions: options),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _deleteChoiceGroup(docId),
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
    );
  }
}