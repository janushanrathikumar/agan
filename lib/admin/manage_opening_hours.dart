// lib/admin/manage_opening_hours.dart
//
// Where the week's opening times are set.
//
// One row per day: closed, or a service with an optional second one for a
// kitchen that shuts in the afternoon. What is saved here is exactly what the
// guest's home page shows.

import 'package:flutter/material.dart';

import 'package:restorant/shared/opening_hours.dart';

const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF2A2928);
const kCardBg = Color(0xFF383735);
const kItemBg = Color(0xFF2F2E2D);
const kWhite = Color(0xFFFFFFFF);
const kMuted = Color(0xFFB7B7B6);

/// Monday first, the order the week is read in.
const kWeekdayNames = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];

class ManageOpeningHoursPage extends StatefulWidget {
  const ManageOpeningHoursPage({super.key});

  @override
  State<ManageOpeningHoursPage> createState() => _ManageOpeningHoursPageState();
}

class _ManageOpeningHoursPageState extends State<ManageOpeningHoursPage> {
  List<DayHours>? _days;
  final _note = TextEditingController();
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final hours = await OpeningHoursService.load();
    if (!mounted) return;
    setState(() {
      _days = [...hours.days];
      _note.text = hours.note;
    });
  }

  Future<void> _pickTime(int index, String field) async {
    final current = switch (field) {
      'open1' => _days![index].open1,
      'close1' => _days![index].close1,
      'open2' => _days![index].open2,
      _ => _days![index].close2,
    };
    final parts = current.split(':');
    final initial = parts.length == 2
        ? TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 11,
            minute: int.tryParse(parts[1]) ?? 0,
          )
        : const TimeOfDay(hour: 11, minute: 0);

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
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

    final value =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      _days![index] = switch (field) {
        'open1' => _days![index].copyWith(open1: value),
        'close1' => _days![index].copyWith(close1: value),
        'open2' => _days![index].copyWith(open2: value),
        _ => _days![index].copyWith(close2: value),
      };
    });
  }

  /// Copies Monday's times onto every other day - the usual starting point.
  void _applyMondayToAll() {
    final monday = _days![0];
    setState(() {
      for (var i = 1; i < 7; i++) {
        _days![i] = monday.copyWith();
      }
      _message = 'Monday copied to every day. Remember to save.';
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await OpeningHoursService.save(
        OpeningHours(days: _days!, note: _note.text.trim()),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = 'Saved. The home page shows these times now.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = 'Could not save: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _days;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kWhite,
        elevation: 0,
        title: const Text('Opening hours'),
        actions: [
          if (days != null)
            TextButton.icon(
              onPressed: _saving ? null : _applyMondayToAll,
              icon: const Icon(Icons.copy_all, color: kPrimary, size: 18),
              label: const Text(
                'Monday to all',
                style: TextStyle(color: kPrimary),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: days == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: kPrimary,
              foregroundColor: kWhite,
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kWhite,
                      ),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save'),
            ),
      body: days == null
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
              children: [
                const Text(
                  'These times appear on the guest home page. A day can be '
                  'closed, or have a second service for the evening.',
                  style: TextStyle(color: kMuted),
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < 7; i++) _dayCard(i, days[i]),
                const SizedBox(height: 10),
                TextField(
                  controller: _note,
                  style: const TextStyle(color: kWhite),
                  decoration: InputDecoration(
                    labelText: 'Note (optional, e.g. holidays)',
                    labelStyle: const TextStyle(color: kMuted),
                    filled: true,
                    fillColor: kItemBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _message!,
                    style: TextStyle(
                      color: _message!.startsWith('Could not')
                          ? Colors.redAccent
                          : Colors.greenAccent,
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _dayCard(int index, DayHours day) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  kWeekdayNames[index],
                  style: const TextStyle(
                    color: kWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Text(
                'Closed',
                style: TextStyle(color: kMuted, fontSize: 12),
              ),
              Switch(
                value: day.closed,
                activeThumbColor: Colors.redAccent,
                onChanged: _saving
                    ? null
                    : (v) => setState(
                        () => _days![index] = day.copyWith(closed: v),
                      ),
              ),
            ],
          ),
          if (!day.closed) ...[
            Row(
              children: [
                _timeField('Open', day.open1, () => _pickTime(index, 'open1')),
                const SizedBox(width: 8),
                _timeField(
                  'Close',
                  day.close1,
                  () => _pickTime(index, 'close1'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (day.hasSecond || day.open2.isNotEmpty || day.close2.isNotEmpty)
              Row(
                children: [
                  _timeField(
                    'Open 2',
                    day.open2,
                    () => _pickTime(index, 'open2'),
                  ),
                  const SizedBox(width: 8),
                  _timeField(
                    'Close 2',
                    day.close2,
                    () => _pickTime(index, 'close2'),
                  ),
                  IconButton(
                    tooltip: 'Remove second service',
                    icon: const Icon(
                      Icons.close,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    onPressed: _saving
                        ? null
                        : () => setState(
                            () => _days![index] = day.copyWith(
                              open2: '',
                              close2: '',
                            ),
                          ),
                  ),
                ],
              )
            else
              TextButton.icon(
                onPressed: _saving
                    ? null
                    : () => setState(
                        () => _days![index] = day.copyWith(
                          open2: '17:00',
                          close2: '23:00',
                        ),
                      ),
                icon: const Icon(Icons.add, color: kPrimary, size: 18),
                label: const Text(
                  'Add second service',
                  style: TextStyle(color: kPrimary, fontSize: 13),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _timeField(String label, String value, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: _saving ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                value.isEmpty ? '--:--' : value,
                style: TextStyle(
                  color: value.isEmpty ? kMuted : kWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
