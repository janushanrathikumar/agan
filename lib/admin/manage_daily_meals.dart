// lib/admin/manage_daily_meals.dart
//
// Where the dish of the day is put up.
//
// A meal is given a price and the hours it is on offer; the guest's home page
// shows it only inside that window. Switching one off hides it without losing
// it, so yesterday's dish can be put back up tomorrow with new hours.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:restorant/platform_image/platform_image.dart';
import 'package:restorant/shared/daily_meal.dart';
import 'package:restorant/shared/image_upload.dart';

const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF2A2928);
const kCardBg = Color(0xFF383735);
const kItemBg = Color(0xFF2F2E2D);
const kWhite = Color(0xFFFFFFFF);
const kMuted = Color(0xFFB7B7B6);

class ManageDailyMealsPage extends StatelessWidget {
  const ManageDailyMealsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kWhite,
        elevation: 0,
        title: const Text('Daily Meal'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimary,
        foregroundColor: kWhite,
        onPressed: () => _showEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Add daily meal'),
      ),
      body: StreamBuilder<List<DailyMeal>>(
        stream: DailyMealService.streamAll(),
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

          final meals = snapshot.data ?? const <DailyMeal>[];
          if (meals.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'No daily meal yet.\nAdd one and it appears on the guest home '
                  'page during the hours you choose.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kMuted, fontSize: 16),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            itemCount: meals.length,
            itemBuilder: (context, i) => _card(context, meals[i]),
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, DailyMeal meal) {
    final now = DateTime.now();
    final live = meal.isAvailableAt(now);
    final ended = meal.hasEnded;

    return Opacity(
      opacity: ended ? 0.8 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: live ? Colors.greenAccent : Colors.transparent,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 64,
                child: meal.imageUrl.isEmpty
                    ? const ColoredBox(
                        color: kItemBg,
                        child: Icon(Icons.restaurant_menu, color: kMuted),
                      )
                    : buildUniversalImage(
                        imageUrl: meal.imageUrl,
                        width: 64,
                        height: 64,
                        fallback: const ColoredBox(
                          color: kItemBg,
                          child: Icon(Icons.restaurant_menu, color: kMuted),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          meal.name,
                          style: const TextStyle(
                            color: kWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'CHF ${meal.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: kPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (meal.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meal.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: kMuted, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 14, color: kMuted),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          meal.windowLabel,
                          style: const TextStyle(color: kMuted, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  if (ended) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Its time is over. Give it a new date to offer it again.',
                      style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _badge(
                        live
                            ? 'Showing now'
                            : ended
                            ? 'Ended'
                            : 'Scheduled',
                        live
                            ? Colors.greenAccent
                            : ended
                            ? kMuted
                            : Colors.orangeAccent,
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: meal.active,
                        activeColor: kPrimary,
                        onChanged: (v) =>
                            DailyMealService.setActive(meal.id, v),
                      ),
                      const Text(
                        'Active',
                        style: TextStyle(color: kMuted, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit, color: kPrimary, size: 20),
                        onPressed: () => _showEditor(context, meal: meal),
                      ),
                      if (ended)
                        IconButton(
                          tooltip: 'Offer again on a new date',
                          icon: const Icon(
                            Icons.event_repeat,
                            color: Colors.greenAccent,
                            size: 20,
                          ),
                          onPressed: () =>
                              _showEditor(context, meal: meal, reschedule: true),
                        ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: () => _confirmDelete(context, meal),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, DailyMeal meal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: const Text('Delete daily meal?', style: TextStyle(color: kWhite)),
        content: Text(
          '"${meal.name}" is removed for good. Orders already placed keep it.',
          style: const TextStyle(color: kMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep', style: TextStyle(color: kWhite)),
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
    if (ok != true) return;

    await DailyMealService.delete(meal.id);
    await ImageUploader.deleteQuietly('daily_meals', meal.imageFileName);
  }

  Future<void> _showEditor(
    BuildContext context, {
    DailyMeal? meal,
    bool reschedule = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DailyMealEditor(meal: meal, reschedule: reschedule),
    );
  }
}

class _DailyMealEditor extends StatefulWidget {
  const _DailyMealEditor({this.meal, this.reschedule = false});

  final DailyMeal? meal;

  /// Opened on a meal whose time is over, to put it back on the menu: the
  /// date starts on the next day it could run and it is switched on again,
  /// so saving is all it takes.
  final bool reschedule;

  @override
  State<_DailyMealEditor> createState() => _DailyMealEditorState();
}

class _DailyMealEditorState extends State<_DailyMealEditor> {
  late final _name = TextEditingController(text: widget.meal?.name ?? '');
  late final _description = TextEditingController(
    text: widget.meal?.description ?? '',
  );
  late final _price = TextEditingController(
    text: widget.meal == null ? '' : widget.meal!.price.toStringAsFixed(2),
  );

  late DateTime _day;
  late TimeOfDay _from;
  late TimeOfDay _until;
  // A meal put back on the menu is switched on, whatever it was before.
  late bool _active = widget.reschedule || (widget.meal?.active ?? true);

  Uint8List? _pickedImage;
  String? _pickedName;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final meal = widget.meal;
    if (meal != null) {
      _from = TimeOfDay.fromDateTime(meal.availableFrom);
      _until = TimeOfDay.fromDateTime(meal.availableUntil);

      if (widget.reschedule) {
        // Keep the same hours and move to the soonest day they still lie
        // ahead - today while that is possible, otherwise tomorrow.
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final startToday = DateTime(
          today.year,
          today.month,
          today.day,
          _from.hour,
          _from.minute,
        );
        _day = startToday.isAfter(now)
            ? today
            : today.add(const Duration(days: 1));
      } else {
        _day = DateTime(
          meal.availableFrom.year,
          meal.availableFrom.month,
          meal.availableFrom.day,
        );
      }
    } else {
      // A lunch dish is the usual case, so that is what a new one starts as.
      final now = DateTime.now();
      _day = DateTime(now.year, now.month, now.day);
      _from = const TimeOfDay(hour: 11, minute: 0);
      _until = const TimeOfDay(hour: 14, minute: 0);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  /// The meal this was opened on had already run out.
  bool get _wasOver => widget.meal?.hasEnded ?? false;

  DateTime get _fromDateTime =>
      DateTime(_day.year, _day.month, _day.day, _from.hour, _from.minute);

  /// An end time earlier than the start means the dish runs past midnight.
  DateTime get _untilDateTime {
    var end = DateTime(
      _day.year,
      _day.month,
      _day.day,
      _until.hour,
      _until.minute,
    );
    if (!end.isAfter(_fromDateTime)) {
      end = end.add(const Duration(days: 1));
    }
    return end;
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 90,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedImage = bytes;
      _pickedName = picked.name;
    });
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(now.year - 1),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: kPrimary,
            surface: kCardBg,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _day = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _from : _until,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: kPrimary,
            surface: kCardBg,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => isStart ? _from = picked : _until = picked);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final price = double.tryParse(_price.text.trim().replaceAll(',', '.'));

    if (name.isEmpty) {
      setState(() => _error = 'Please enter a name.');
      return;
    }
    if (price == null || price <= 0) {
      setState(() => _error = 'Please enter a valid price.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      var imageUrl = widget.meal?.imageUrl ?? '';
      var imageFileName = widget.meal?.imageFileName ?? '';
      String? replaced;

      if (_pickedImage != null) {
        final uploaded = await ImageUploader.upload(
          _pickedImage!,
          folder: 'daily_meals',
          nameHint: _pickedName ?? name,
          use: ImageUse.menuPhoto,
        );
        replaced = imageFileName;
        imageUrl = uploaded.url;
        imageFileName = uploaded.fileName;
      }

      await DailyMealService.save(
        id: widget.meal?.id,
        name: name,
        description: _description.text.trim(),
        price: price,
        imageUrl: imageUrl,
        imageFileName: imageFileName,
        availableFrom: _fromDateTime,
        availableUntil: _untilDateTime,
        active: _active,
      );

      // Only once the meal points at the new picture.
      if (replaced != null && replaced != imageFileName) {
        await ImageUploader.deleteQuietly('daily_meals', replaced);
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save: $error';
      });
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: kMuted),
    filled: true,
    fillColor: kItemBg,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: kPrimary, width: 1.5),
    ),
  );

  Widget _pickerTile(String label, String value, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: _saving ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: kItemBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: kMuted, fontSize: 11)),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: kWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String two(int v) => v.toString().padLeft(2, '0');

    return AlertDialog(
      backgroundColor: kCardBg,
      title: Text(
        widget.meal == null
            ? 'Add daily meal'
            : widget.reschedule
            ? 'Offer again'
            : 'Edit daily meal',
        style: const TextStyle(color: kWhite),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_wasOver) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.orangeAccent.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_repeat,
                        color: Colors.orangeAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.reschedule
                              ? 'This meal had ended. The date below is its '
                                    'new one - change it if you want another.'
                              : 'This meal has ended. Change the date below '
                                    'to offer it again.',
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: _name,
                style: const TextStyle(color: kWhite),
                decoration: _dec('Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                style: const TextStyle(color: kWhite),
                maxLines: 2,
                decoration: _dec('Description (optional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _price,
                style: const TextStyle(color: kWhite),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _dec('Price (CHF)'),
              ),
              const SizedBox(height: 16),

              const Text(
                'Shown to guests',
                style: TextStyle(color: kMuted, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _pickerTile(
                    'Day',
                    '${two(_day.day)}.${two(_day.month)}.${_day.year}',
                    _pickDay,
                  ),
                  const SizedBox(width: 8),
                  _pickerTile(
                    'From',
                    '${two(_from.hour)}:${two(_from.minute)}',
                    () => _pickTime(isStart: true),
                  ),
                  const SizedBox(width: 8),
                  _pickerTile(
                    'Until',
                    '${two(_until.hour)}:${two(_until.minute)}',
                    () => _pickTime(isStart: false),
                  ),
                ],
              ),
              if (_untilDateTime.day != _fromDateTime.day) ...[
                const SizedBox(height: 6),
                const Text(
                  'Runs past midnight into the next day.',
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
                ),
              ],
              const SizedBox(height: 16),

              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kWhite,
                      side: const BorderSide(color: kMuted),
                    ),
                    onPressed: _saving ? null : _pickImage,
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: const Text('Picture'),
                  ),
                  const SizedBox(width: 12),
                  if (_pickedImage != null)
                    const Text(
                      'New picture chosen',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                    )
                  else if ((widget.meal?.imageUrl ?? '').isNotEmpty)
                    const Text(
                      'Picture already set',
                      style: TextStyle(color: kMuted, fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                activeColor: kPrimary,
                title: const Text(
                  'Active',
                  style: TextStyle(color: kWhite, fontSize: 14),
                ),
                subtitle: const Text(
                  'Switch off to hide it without deleting.',
                  style: TextStyle(color: kMuted, fontSize: 11),
                ),
                onChanged: _saving ? null : (v) => setState(() => _active = v),
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: kMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: kWhite,
          ),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kWhite,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
