// lib/admin/manage_tables.dart
//
// Defines the floor plan: tables, the chairs on them, and the QR code each
// chair carries. Chair numbers are unique across the whole restaurant so that a
// waiter can type a chair number on its own and get the table back.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:restorant/shared/table_registry.dart';
import 'table_qr_printer.dart';

const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF2A2928);
const kWhite = Color(0xFFFFFFFF);
const kMuted = Color(0xFFB7B7B6);
const kFieldBg = Color(0xFF383735);
const kDialogBg = Color(0xFF333230);

/// A typo in the chair-count field should not create thousands of chairs.
const int kMaxChairsPerBatch = 100;

class ManageTablesPage extends StatefulWidget {
  const ManageTablesPage({super.key});

  @override
  State<ManageTablesPage> createState() => _ManageTablesPageState();
}

class _ManageTablesPageState extends State<ManageTablesPage> {
  String? _selectedTableId;

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // ------------------------------------------------------------ table CRUD

  Future<void> _openTableDialog({TableDoc? existing}) async {
    final tables = await TableRegistry.loadTables();
    if (!mounted) return;

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final orderCtrl = TextEditingController(
      text: (existing?.sortOrder ?? tables.length + 1).toString(),
    );
    final chairCountCtrl = TextEditingController();
    final nextNo = TableRegistry.nextChairNumberIn(tables);

    bool isSaving = false;
    String? err;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> save() async {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) {
              setDialogState(() => err = 'Table name is required.');
              return;
            }

            final chairCount = existing == null
                ? int.tryParse(chairCountCtrl.text.trim()) ?? 0
                : 0;
            if (existing == null && chairCount > kMaxChairsPerBatch) {
              setDialogState(
                () => err = 'Add at most $kMaxChairsPerBatch chairs at a time.',
              );
              return;
            }
            if (existing == null && chairCount < 0) {
              setDialogState(() => err = 'Chair count cannot be negative.');
              return;
            }

            setDialogState(() {
              isSaving = true;
              err = null;
            });

            try {
              final sortOrder = int.tryParse(orderCtrl.text.trim()) ?? 0;
              if (existing == null) {
                final id = await TableRegistry.createTable(
                  name: name,
                  sortOrder: sortOrder,
                  chairs: TableRegistry.generateChairs(
                    count: chairCount,
                    startNo: nextNo,
                  ),
                );
                if (mounted) setState(() => _selectedTableId = id);
              } else {
                await TableRegistry.updateTable(
                  tableId: existing.id,
                  name: name,
                  sortOrder: sortOrder,
                  chairs: existing.chairs,
                );
              }

              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              _snack(
                existing == null ? 'Table created.' : 'Table updated.',
                Colors.green,
              );
            } catch (e) {
              setDialogState(() {
                isSaving = false;
                err = 'Could not save: $e';
              });
            }
          }

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
                      existing == null ? 'Add Table' : 'Edit Table',
                      style: const TextStyle(
                        color: kWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _dialogField(
                      controller: nameCtrl,
                      label: 'Table name',
                      hint: 'e.g. Table 001',
                      icon: Icons.table_restaurant,
                    ),
                    const SizedBox(height: 12),
                    _dialogField(
                      controller: orderCtrl,
                      label: 'Display order',
                      hint: 'e.g. 1',
                      icon: Icons.sort,
                      number: true,
                    ),
                    if (existing == null) ...[
                      const SizedBox(height: 12),
                      _dialogField(
                        controller: chairCountCtrl,
                        label: 'Number of chairs',
                        hint: 'e.g. 6',
                        icon: Icons.chair_alt,
                        number: true,
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (_) {
                          final count =
                              int.tryParse(chairCountCtrl.text.trim()) ?? 0;
                          if (count <= 0) {
                            return const Text(
                              'Chairs continue the restaurant-wide numbering.',
                              style: TextStyle(color: kMuted, fontSize: 12),
                            );
                          }
                          return Text(
                            'Will create chairs $nextNo'
                            '–${nextNo + count - 1}.',
                            style: const TextStyle(
                              color: kPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ],
                    if (err != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        err!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSaving
                              ? null
                              : () => Navigator.pop(dialogContext),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: kMuted),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: kWhite,
                          ),
                          onPressed: isSaving ? null : save,
                          child: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: kWhite,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  existing == null ? 'Save' : 'Save Changes',
                                ),
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

  Future<void> _deleteTable(TableDoc table) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kFieldBg,
        title: const Text('Delete Table?', style: TextStyle(color: kWhite)),
        content: Text(
          'This permanently removes "${table.name}" and its '
          '${table.chairs.length} chair(s). Any QR codes already printed for '
          'those chairs will stop working.',
          style: const TextStyle(color: kMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: kWhite)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await TableRegistry.deleteTable(table.id);
      if (!mounted) return;
      setState(() {
        if (_selectedTableId == table.id) _selectedTableId = null;
      });
      _snack('Table deleted.', kPrimary);
    } catch (e) {
      _snack('Failed to delete: $e', Colors.redAccent);
    }
  }

  // ------------------------------------------------------------ chair CRUD

  Future<void> _addChair(TableDoc table) async {
    final tables = await TableRegistry.loadTables();
    if (!mounted) return;

    final nextNo = TableRegistry.nextChairNumberIn(tables);
    try {
      await TableRegistry.updateTable(
        tableId: table.id,
        name: table.name,
        sortOrder: table.sortOrder,
        chairs: [
          ...table.chairs,
          ChairEntry(id: ChairEntry.newId(), no: nextNo),
        ],
      );
      _snack('Chair $nextNo added.', Colors.green);
    } catch (e) {
      _snack('Could not add chair: $e', Colors.redAccent);
    }
  }

  Future<void> _editChairNumber(TableDoc table, ChairEntry chair) async {
    final tables = await TableRegistry.loadTables();
    if (!mounted) return;

    final ctrl = TextEditingController(text: chair.no.toString());
    String? err;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> save() async {
            final newNo = int.tryParse(ctrl.text.trim());
            if (newNo == null || newNo <= 0) {
              setDialogState(() => err = 'Enter a chair number above 0.');
              return;
            }

            // Restaurant-wide uniqueness: name the clashing table so the admin
            // knows where the number is already in use.
            final clashElsewhere = TableRegistry.tableUsingChairNumber(
              tables,
              newNo,
              exceptTableId: table.id,
            );
            final clashHere = table.chairs.any(
              (c) => c.no == newNo && c.id != chair.id,
            );
            if (clashElsewhere != null) {
              setDialogState(
                () => err =
                    'Chair $newNo already belongs to ${clashElsewhere.name}.',
              );
              return;
            }
            if (clashHere) {
              setDialogState(
                () => err = 'Chair $newNo already exists on this table.',
              );
              return;
            }

            setDialogState(() {
              isSaving = true;
              err = null;
            });

            try {
              await TableRegistry.updateTable(
                tableId: table.id,
                name: table.name,
                sortOrder: table.sortOrder,
                chairs: table.chairs
                    .map(
                      (c) => c.id == chair.id
                          // The id is kept, so QR codes already printed for
                          // this chair keep pointing at the right seat.
                          ? ChairEntry(id: c.id, no: newNo)
                          : c,
                    )
                    .toList(),
              );
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              _snack('Chair updated.', Colors.green);
            } catch (e) {
              setDialogState(() {
                isSaving = false;
                err = 'Could not save: $e';
              });
            }
          }

          return Dialog(
            backgroundColor: kDialogBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Edit Chair Number',
                    style: TextStyle(
                      color: kWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Chair numbers are unique across the whole restaurant.',
                    style: TextStyle(color: kMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  _dialogField(
                    controller: ctrl,
                    label: 'Chair number',
                    hint: 'e.g. 7',
                    icon: Icons.chair_alt,
                    number: true,
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      err!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isSaving
                            ? null
                            : () => Navigator.pop(dialogContext),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: kMuted),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: kWhite,
                        ),
                        onPressed: isSaving ? null : save,
                        child: isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: kWhite,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save Changes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteChair(TableDoc table, ChairEntry chair) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kFieldBg,
        title: const Text('Delete Chair?', style: TextStyle(color: kWhite)),
        content: Text(
          'Remove chair ${chair.no} from ${table.name}? Its printed QR code '
          'will stop working.',
          style: const TextStyle(color: kMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: kWhite)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await TableRegistry.updateTable(
        tableId: table.id,
        name: table.name,
        sortOrder: table.sortOrder,
        chairs: table.chairs.where((c) => c.id != chair.id).toList(),
      );
      _snack('Chair ${chair.no} deleted.', kPrimary);
    } catch (e) {
      _snack('Failed to delete: $e', Colors.redAccent);
    }
  }

  // -------------------------------------------------------------- QR codes

  Future<void> _printQrSheet(TableDoc table) async {
    final originCtrl = TextEditingController(
      text: TableRegistry.currentOrigin(),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isLocal = TableRegistry.isLocalOrigin(originCtrl.text);
          return AlertDialog(
            backgroundColor: kDialogBg,
            title: const Text(
              'Print QR Codes',
              style: TextStyle(color: kWhite),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The QR codes point at this address. It must be the address '
                  'guests can reach.',
                  style: TextStyle(color: kMuted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                _dialogField(
                  controller: originCtrl,
                  label: 'Website address',
                  hint: 'https://your-restaurant.ch',
                  icon: Icons.link,
                  onChanged: (_) => setDialogState(() {}),
                ),
                if (isLocal) ...[
                  const SizedBox(height: 12),
                  const Text(
                    '⚠ This is a local test address — printed codes would only '
                    'work on this computer. Replace it with your live website '
                    'address before printing.',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'In the print dialog set margins to None and scale to 100% '
                  'so the codes stay easy to scan.',
                  style: TextStyle(color: kMuted, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: kMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: kWhite,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Print'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true || !mounted) return;
    await TableQrPrinter.printSheet(
      context,
      table,
      origin: originCtrl.text.trim(),
    );
  }

  void _showChairQr(TableDoc table, ChairEntry chair) {
    final payload = TableRegistry.qrPayloadFor(table.id, chairId: chair.id);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kDialogBg,
        title: Text(
          '${table.name} · Chair ${chair.no}',
          style: const TextStyle(color: kWhite, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: QrImageView(data: payload, size: 200),
            ),
            const SizedBox(height: 12),
            SelectableText(
              payload,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kMuted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: payload));
              Navigator.pop(ctx);
              _snack('Link copied.', kPrimary);
            },
            child: const Text('Copy link', style: TextStyle(color: kPrimary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: kMuted)),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kWhite,
        title: const Text('Manage Tables & Chairs'),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimary,
        foregroundColor: kWhite,
        icon: const Icon(Icons.add),
        label: const Text('Add Table'),
        onPressed: () => _openTableDialog(),
      ),
      body: StreamBuilder<List<TableDoc>>(
        stream: TableRegistry.streamTables(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kPrimary),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final tables = snapshot.data ?? [];
          if (tables.isEmpty) {
            return const Center(
              child: Text(
                'No tables yet. Add your first table.',
                style: TextStyle(color: kMuted, fontSize: 16),
              ),
            );
          }

          final selected = tables.where((t) => t.id == _selectedTableId);
          final activeTable = selected.isEmpty ? tables.first : selected.first;

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              if (!isWide) {
                // Narrow screens get the list only; a table opens full screen.
                return _buildTableList(tables, activeTable, isWide: false);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 320,
                    child: _buildTableList(tables, activeTable, isWide: true),
                  ),
                  const VerticalDivider(width: 1, color: kFieldBg),
                  Expanded(child: _buildChairsPanel(activeTable)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTableList(
    List<TableDoc> tables,
    TableDoc activeTable, {
    required bool isWide,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        final table = tables[index];
        final isActive = isWide && table.id == activeTable.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: kFieldBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? kPrimary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: ListTile(
            onTap: () {
              setState(() => _selectedTableId = table.id);
              if (!isWide) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _ChairsScreen(
                      tableId: table.id,
                      parent: this,
                    ),
                  ),
                );
              }
            },
            title: Text(
              table.name,
              style: const TextStyle(
                color: kWhite,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              table.chairs.isEmpty
                  ? 'No chairs'
                  : '${table.chairs.length} chair(s) · '
                        '${_chairRangeLabel(table)}',
              style: const TextStyle(color: kMuted, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: kPrimary, size: 20),
                  tooltip: 'Edit table',
                  onPressed: () => _openTableDialog(existing: table),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  tooltip: 'Delete table',
                  onPressed: () => _deleteTable(table),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _chairRangeLabel(TableDoc table) {
    if (table.chairs.isEmpty) return '';
    final numbers = table.chairs.map((c) => c.no).toList()..sort();
    return numbers.length == 1
        ? 'Chair ${numbers.first}'
        : 'Chairs ${numbers.first}–${numbers.last}';
  }

  Widget _buildChairsPanel(TableDoc table) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      table.name,
                      style: const TextStyle(
                        color: kWhite,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${table.chairs.length} chair(s)',
                      style: const TextStyle(color: kMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimary,
                  side: const BorderSide(color: kPrimary),
                ),
                onPressed: () => _addChair(table),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add chair'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: kWhite,
                ),
                onPressed: table.chairs.isEmpty
                    ? null
                    : () => _printQrSheet(table),
                icon: const Icon(Icons.qr_code_2, size: 18),
                label: const Text('Print QR codes'),
              ),
            ],
          ),
        ),
        const Divider(color: kFieldBg, height: 1),
        Expanded(
          child: table.chairs.isEmpty
              ? const Center(
                  child: Text(
                    'No chairs on this table yet.',
                    style: TextStyle(color: kMuted),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: table.chairs.length,
                  itemBuilder: (context, index) {
                    final chair = table.chairs[index];
                    return _buildChairRow(table, chair);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildChairRow(TableDoc table, ChairEntry chair) {
    final payload = TableRegistry.qrPayloadFor(table.id, chairId: chair.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kFieldBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showChairQr(table, chair),
            child: Container(
              padding: const EdgeInsets.all(6),
              color: Colors.white,
              child: QrImageView(data: payload, size: 56),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chair ${chair.no}',
                  style: const TextStyle(
                    color: kWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  payload,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: kPrimary, size: 20),
            tooltip: 'Edit chair number',
            onPressed: () => _editChairNumber(table, chair),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.redAccent,
              size: 20,
            ),
            tooltip: 'Delete chair',
            onPressed: () => _deleteChair(table, chair),
          ),
        ],
      ),
    );
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool number = false,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: kWhite),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kMuted),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        prefixIcon: Icon(icon, color: kMuted, size: 20),
        filled: true,
        fillColor: kFieldBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kPrimary, width: 1.5),
        ),
      ),
    );
  }
}

/// Full-screen chair list for narrow screens, so a phone-sized admin is not a
/// dead end when the master/detail split collapses.
class _ChairsScreen extends StatelessWidget {
  const _ChairsScreen({required this.tableId, required this.parent});

  final String tableId;
  final _ManageTablesPageState parent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kWhite,
        title: const Text('Chairs'),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tables')
            .doc(tableId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kPrimary),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'This table no longer exists.',
                style: TextStyle(color: kMuted),
              ),
            );
          }
          return parent._buildChairsPanel(TableDoc.fromDoc(snapshot.data!));
        },
      ),
    );
  }
}
