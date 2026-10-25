import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:restorant/shared/image_upload.dart';
import 'package:restorant/shared/menu_offer.dart';

const _kPrimary = Color(0xFFB59410);
const _kBg = Color(0xFF2A2928);
const _kMuted = Color(0xFFB7B7B6);
const _kWhite = Color(0xFFFFFFFF);
const _kCardBg = Color(0xFF383735);
const _kOffer = Color(0xFFE0483E);

/// Builds a combo from food and drink menus that already exist.
/// The combo price is the total of the selected menus minus the offer %.
/// Pass [docId] and [itemData] to edit an existing combo.
class AddComboPage extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? itemData;

  const AddComboPage({super.key, this.docId, this.itemData});

  @override
  State<AddComboPage> createState() => _AddComboPageState();
}

class _AddComboPageState extends State<AddComboPage> {
  final _name = TextEditingController();
  final _note = TextEditingController();
  final _offer = TextEditingController();

  List<Map<String, dynamic>> _menus = [];
  bool _loadingMenus = true;
  final List<Map<String, dynamic>> _selected = [];

  List<Map<String, dynamic>> _categories = [];
  String? _category;
  String? _categoryIconUrl;

  Uint8List? _imgBytes;
  String? _imgFileName;
  bool _isAvailable = true;
  bool _canTakeAway = true;
  bool _saving = false;

  bool get _isEdit => widget.docId != null;

  @override
  void initState() {
    super.initState();
    final data = widget.itemData;
    if (data != null) {
      _name.text = (data['name'] as String?) ?? '';
      _note.text = (data['note'] as String?) ?? '';
      if (hasMenuOffer(data) && data['discountType'] == 'percent') {
        final v = (data['discountValue'] as num).toDouble();
        _offer.text = v.toStringAsFixed(v % 1 == 0 ? 0 : 1);
      }
      _category = data['category'] as String?;
      _categoryIconUrl = data['categoryIconUrl'] as String?;
      _isAvailable = data['status'] != 'off';
      _canTakeAway = data['canTakeAway'] != false;
      for (final e in (data['comboItems'] as List<dynamic>? ?? const [])) {
        if (e is Map) _selected.add(Map<String, dynamic>.from(e));
      }
    }
    _offer.addListener(() => setState(() {}));
    _loadMenus();
    _loadCategories();
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    _offer.dispose();
    super.dispose();
  }

  Future<void> _loadMenus() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('menu_items')
          .get();
      final menus =
          snap.docs
              .map((d) => {'id': d.id, ...d.data()})
              .where((m) => (m['itemType'] ?? 'food') != 'combo')
              .toList()
            ..sort((a, b) {
              final t = (a['itemType'] ?? 'food').toString().compareTo(
                (b['itemType'] ?? 'food').toString(),
              );
              if (t != 0) return -t; // food first, then drink
              return (a['name'] ?? '').toString().toLowerCase().compareTo(
                (b['name'] ?? '').toString().toLowerCase(),
              );
            });
      if (mounted) setState(() => _menus = menus);
    } catch (e) {
      debugPrint('Error loading menus for combo: $e');
    } finally {
      if (mounted) setState(() => _loadingMenus = false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('menu_category')
          .get();
      final cats = snap.docs
          .where((d) => (d.data()['type'] as String?) == 'combo')
          .map((d) => {'id': d.id, ...d.data()})
          .toList();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        if (_category == null && cats.length == 1) {
          _category = cats.first['id'] as String;
          _categoryIconUrl = cats.first['iconUrl'] as String?;
        }
      });
    } catch (e) {
      debugPrint('Error loading combo categories: $e');
    }
  }

  double get _total => menuComboTotal({'comboItems': _selected});

  double get _offerPercent {
    final v = double.tryParse(_offer.text.trim().replaceAll('%', '')) ?? 0;
    return v.clamp(0, 100).toDouble();
  }

  double get _finalPrice =>
      ((_total * (1 - _offerPercent / 100)) * 100).round() / 100;

  void _addMenu(String id) {
    final menu = _menus.firstWhere((m) => m['id'] == id);
    setState(() {
      _selected.add({
        'id': menu['id'],
        'name': menu['name'],
        'price': (menu['price'] as num?)?.toDouble() ?? 0,
        'imageUrl': menu['imageUrl'],
        'note': menu['note'],
        'itemType': menu['itemType'] ?? 'food',
      });
      if (menu['canTakeAway'] == false) _canTakeAway = false;
    });
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(
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

  Future<void> _save() async {
    final name = _name.text.trim();
    final rawOffer = _offer.text.trim().replaceAll('%', '');
    final offer = rawOffer.isEmpty ? 0.0 : double.tryParse(rawOffer);
    String? error;
    if (name.isEmpty) {
      error = 'Enter a combo name.';
    } else if (_selected.length < 2) {
      error = 'Select at least two menus for the combo.';
    } else if (_category == null) {
      error = 'Select a combo category.';
    } else if (offer == null || offer < 0 || offer >= 100) {
      error = 'Offer must be a number between 0 and 99.';
    }
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _saving = true);
    try {
      String imageUrl =
          (widget.itemData?['imageUrl'] as String?) ??
          (_selected.first['imageUrl'] as String?) ??
          '';
      String? imageFileName = widget.itemData?['imageFileName'] as String?;
      if (_imgBytes != null) {
        final uploaded = await ImageUploader.upload(
          _imgBytes!,
          folder: 'menu_images',
          nameHint: _imgFileName ?? name,
          use: ImageUse.menuPhoto,
        );
        imageUrl = uploaded.url;
        imageFileName = uploaded.fileName;
      }

      final hasOffer = offer! > 0;
      final data = <String, dynamic>{
        'name': name,
        'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
        'itemType': 'combo',
        'price': _total,
        'hasMultipleSizes': false,
        'sizes': [],
        'comboItems': _selected
            .map(
              (m) => {
                'id': m['id'],
                'name': m['name'],
                'price': m['price'],
                'imageUrl': m['imageUrl'],
                'note': m['note'],
                'itemType': m['itemType'],
              },
            )
            .toList(),
        'hasDiscount': hasOffer,
        'discountType': hasOffer ? 'percent' : null,
        'discountValue': hasOffer ? offer : 0,
        'isPromoActive': hasOffer,
        'offerPrice': _finalPrice,
        'category': _category,
        'categoryIconUrl': _categoryIconUrl,
        'imageUrl': imageUrl,
        'imageFileName': imageFileName,
        'status': _isAvailable ? 'on' : 'off',
        'canTakeAway': _canTakeAway,
      };

      final col = FirebaseFirestore.instance.collection('menu_items');
      if (_isEdit) {
        await col.doc(widget.docId).update(data);
      } else {
        await col.add({
          ...data,
          'menuChoices': [],
          'additionalOptions': [],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _kPrimary,
          content: Text(_isEdit ? 'Combo updated' : 'Combo created'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save combo: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        foregroundColor: _kWhite,
        title: Text(_isEdit ? 'Edit Combo' : 'Add Combo'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _sectionTitle('1. Combo details'),
              _field(_name, 'Combo name (e.g. Burger + Cola)'),
              const SizedBox(height: 12),
              _field(_note, 'Description (optional)', maxLines: 2),
              const SizedBox(height: 12),
              _categoryDropdown(),
              const SizedBox(height: 12),
              _imagePicker(),
              const SizedBox(height: 24),
              _sectionTitle('2. Select menus'),
              _menuDropdown(),
              const SizedBox(height: 12),
              _selectedList(),
              const SizedBox(height: 12),
              _totalBox(),
              const SizedBox(height: 24),
              _sectionTitle('3. Offer'),
              _field(
                _offer,
                'Offer (%) — e.g. 30',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                suffix: '%',
              ),
              const SizedBox(height: 12),
              _offerSummary(),
              const SizedBox(height: 24),
              _switch(
                'Available',
                'Turn off to hide this combo from guests',
                _isAvailable,
                (v) => setState(() => _isAvailable = v),
              ),
              _switch(
                'Available for Take Away',
                'Turned off automatically if a selected menu is dine-in only',
                _canTakeAway,
                (v) => setState(() => _canTakeAway = v),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: _kWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: _kWhite,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _isEdit ? 'Save Combo' : 'Create Combo',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        color: _kWhite,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? suffix,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: _kWhite),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _kMuted),
        suffixText: suffix,
        suffixStyle: const TextStyle(color: _kPrimary, fontSize: 16),
        filled: true,
        fillColor: _kCardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kPrimary),
        ),
      ),
    );
  }

  Widget _box({required Widget child, Color? border}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    decoration: BoxDecoration(
      color: _kCardBg,
      borderRadius: BorderRadius.circular(12),
      border: border == null ? null : Border.all(color: border),
    ),
    child: child,
  );

  Widget _categoryDropdown() {
    if (_categories.isEmpty) {
      return _box(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text(
            'No combo category yet — add a category of type "Combo" first.',
            style: TextStyle(color: _kMuted),
          ),
        ),
      );
    }
    final ids = _categories.map((c) => c['id'] as String).toList();
    return _box(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: ids.contains(_category) ? _category : null,
          isExpanded: true,
          dropdownColor: _kCardBg,
          hint: const Text('Combo category', style: TextStyle(color: _kMuted)),
          items: [
            for (final id in ids)
              DropdownMenuItem(
                value: id,
                child: Text(id, style: const TextStyle(color: _kWhite)),
              ),
          ],
          onChanged: (v) {
            final cat = _categories.firstWhere((c) => c['id'] == v);
            setState(() {
              _category = v;
              _categoryIconUrl = cat['iconUrl'] as String?;
            });
          },
        ),
      ),
    );
  }

  Widget _imagePicker() {
    final existing = widget.itemData?['imageUrl'] as String?;
    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(12),
      child: _box(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: _imgBytes != null
                      ? Image.memory(_imgBytes!, fit: BoxFit.cover)
                      : (existing != null && existing.isNotEmpty)
                      ? Image.network(
                          existing,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.image, color: _kMuted),
                        )
                      : const Icon(Icons.add_a_photo, color: _kPrimary),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Combo image (optional) — the first selected menu\'s photo is used if you skip this.',
                  style: TextStyle(color: _kMuted, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuDropdown() {
    if (_loadingMenus) {
      return const LinearProgressIndicator(color: _kPrimary);
    }
    if (_menus.isEmpty) {
      return _box(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text(
            'No food or drink menus yet — add them first.',
            style: TextStyle(color: _kMuted),
          ),
        ),
      );
    }
    return _box(
      border: _kPrimary.withOpacity(0.6),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: null,
          isExpanded: true,
          dropdownColor: _kCardBg,
          menuMaxHeight: 420,
          icon: const Icon(Icons.add_circle, color: _kPrimary),
          hint: const Text(
            'Select a food or drink menu to add',
            style: TextStyle(color: _kWhite),
          ),
          items: [
            for (final m in _menus)
              DropdownMenuItem(
                value: m['id'] as String,
                child: Row(
                  children: [
                    Icon(
                      m['itemType'] == 'drink'
                          ? Icons.local_drink
                          : Icons.restaurant,
                      color: _kPrimary,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        (m['name'] as String?) ?? '',
                        style: const TextStyle(color: _kWhite),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'CHF ${((m['price'] as num?) ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(color: _kMuted),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (id) {
            if (id != null) _addMenu(id);
          },
        ),
      ),
    );
  }

  Widget _selectedList() {
    if (_selected.isEmpty) {
      return const Text(
        'No menus selected yet.',
        style: TextStyle(color: _kMuted),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < _selected.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  _selected[i]['itemType'] == 'drink'
                      ? Icons.local_drink
                      : Icons.restaurant,
                  color: _kPrimary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    (_selected[i]['name'] as String?) ?? '',
                    style: const TextStyle(color: _kWhite),
                  ),
                ),
                Text(
                  'CHF ${((_selected[i]['price'] as num?) ?? 0).toStringAsFixed(2)}',
                  style: const TextStyle(color: _kWhite),
                ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close, color: Colors.redAccent),
                  onPressed: () => setState(() => _selected.removeAt(i)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _totalBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kPrimary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kPrimary.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          Text(
            'Total (${_selected.length} menus)',
            style: const TextStyle(color: _kWhite, fontSize: 16),
          ),
          const Spacer(),
          Text(
            'CHF ${_total.toStringAsFixed(2)}',
            style: const TextStyle(
              color: _kPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _offerSummary() {
    final percent = _offerPercent;
    if (percent <= 0 || _total <= 0) {
      return Text(
        _total <= 0
            ? 'Select menus to see the combo price.'
            : 'No offer — guests pay the full total of CHF ${_total.toStringAsFixed(2)}.',
        style: const TextStyle(color: _kMuted),
      );
    }
    final saved = _total - _finalPrice;
    final label = '${percent.toStringAsFixed(percent % 1 == 0 ? 0 : 1)}% OFF';
    TextStyle row(Color c, {bool bold = false}) => TextStyle(
      color: c,
      fontSize: bold ? 20 : 15,
      fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kOffer.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kOffer.withOpacity(0.7), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _kOffer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: _kWhite,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Total', style: row(_kMuted)),
              const Spacer(),
              Text(
                'CHF ${_total.toStringAsFixed(2)}',
                style: row(
                  _kMuted,
                ).copyWith(decoration: TextDecoration.lineThrough),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Offer $label', style: row(_kOffer)),
              const Spacer(),
              Text('− CHF ${saved.toStringAsFixed(2)}', style: row(_kOffer)),
            ],
          ),
          const Divider(color: _kMuted, height: 20),
          Row(
            children: [
              Text('Combo price', style: row(_kWhite, bold: true)),
              const Spacer(),
              Text(
                'CHF ${_finalPrice.toStringAsFixed(2)}',
                style: row(_kPrimary, bold: true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'This offer is shown on the guest menu and on the home page.',
            style: TextStyle(color: _kMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _switch(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      activeColor: _kPrimary,
      title: Text(
        title,
        style: const TextStyle(color: _kWhite, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: _kMuted, fontSize: 12),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
