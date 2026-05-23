// lib/home/choice_dialog.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChoiceDialog extends StatefulWidget {
  final String? docId;
  final String? existingHeading;
  final List<String>? existingOptions;

  const ChoiceDialog({
    super.key,
    this.docId,
    this.existingHeading,
    this.existingOptions,
  });

  @override
  State<ChoiceDialog> createState() => _ChoiceDialogState();
}

class _ChoiceDialogState extends State<ChoiceDialog> {
  final _headingController = TextEditingController();
  List<TextEditingController> _optionControllers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // If Editing, preload old data strings into active states
    if (widget.existingHeading != null) {
      _headingController.text = widget.existingHeading!;
    }
    if (widget.existingOptions != null && widget.existingOptions!.isNotEmpty) {
      for (var opt in widget.existingOptions!) {
        _optionControllers.add(TextEditingController(text: opt));
      }
    } else {
      // Default to 1 empty option box on initial display
      _optionControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _headingController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addNewOptionField() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOptionField(int index) {
    if (_optionControllers.length > 1) {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
      });
    }
  }

  // Save changes to cloud server collection infrastructure
  Future<void> _saveChoiceGroup() async {
    if (_headingController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    // Extract strings out from separate controllers, discarding empty entries safely
    List<String> optionsList = _optionControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    final payload = {
      'heading': _headingController.text.trim(),
      'options': optionsList,
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (widget.docId != null) {
      // Update target entry
      await FirebaseFirestore.instance
          .collection('menu_choices')
          .doc(widget.docId)
          .update(payload);
    } else {
      // Create new fresh entry
      await FirebaseFirestore.instance.collection('menu_choices').add(payload);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 STANDARD THEME EXTRACTION: Read colors globally from main.dart
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent, // Prevents unwanted Material 3 color shifting
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: 400, // Balanced form modal sizing constraint
        child: _isLoading
            ? SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(color: colorScheme.primary),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.docId != null
                          ? "Edit Menu Choice"
                          : "Add Menu Choice",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Choice Heading Text Area input field
                    TextField(
                      controller: _headingController,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: "Choice Heading (e.g. Select a Drink)",
                        labelStyle: TextStyle(color: colorScheme.outline),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: colorScheme.primary, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Dynamic list containing sub-option entries
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 250,
                      ), // Prevent overflowing boundaries
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _optionControllers.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _optionControllers[index],
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontSize: 15,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: "Option ${index + 1}",
                                      hintStyle: TextStyle(
                                        color: colorScheme.outline.withOpacity(0.6),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: colorScheme.error.withOpacity(0.8),
                                  ),
                                  tooltip: "Remove Option",
                                  onPressed: () => _removeOptionField(index),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Add Option Action Link trigger
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addNewOptionField,
                        icon: Icon(
                          Icons.add_circle_outline,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        label: Text(
                          "Add Option",
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Lower Confirmation / Cancellation Row panel
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                              color: colorScheme.outline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _saveChoiceGroup,
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                          ),
                          child: const Text(
                            "Save Choice",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}