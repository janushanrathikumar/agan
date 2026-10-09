// lib/user/table_booking_page.dart
//
// Where a guest reserves a table: pick a table, a day and a time, leave their
// contact details. Only tables the admin created are offered, and slots that
// are already taken are shown greyed out before anything is typed.
//
// A hall (Saal 1, Saal 2) is rented by the hour: the guest also picks how long,
// sees the price, and confirms it in a popup before anything is booked.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:restorant/language.dart';
import 'package:restorant/shared/reservation_service.dart';
import 'package:restorant/shared/table_registry.dart';

const _kBg = Color(0xFF112A18);
const _kCard = Color(0xFF1A3822);
const _kField = Color(0xFF1E3A24);
const _kPrimary = Color(0xFFB59410);
const _kMuted = Color(0xFFA1B3A1);
const _kWhite = Color(0xFFF7F7F2);

class TableBookingPage extends StatefulWidget {
  const TableBookingPage({super.key});

  @override
  State<TableBookingPage> createState() => _TableBookingPageState();
}

class _TableBookingPageState extends State<TableBookingPage> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  List<TableDoc> _tables = [];
  bool _loadingTables = true;
  TableDoc? _table;
  DateTime _date = DateTime.now();
  String? _slot;

  /// Hours a hall is rented for; unused for ordinary tables.
  int? _hours;
  int _guests = 2;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTables();
    final user = FirebaseAuth.instance.currentUser;
    _nameCtrl.text = user?.displayName ?? '';
    _emailCtrl.text = user?.email ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _isHall => _table != null && HallPricing.isHall(_table!.name);

  /// A hall seats as many as its chairs; ordinary tables keep the old cap.
  int get _maxGuests {
    final chairs = _table?.chairs.length ?? 0;
    return _isHall && chairs > 0 ? chairs : 30;
  }

  String _hoursLabel(int hours) => '$hours ${AppLanguage.getText('hrs')}';

  // Kept across rebuilds: a new stream on every tap would resubscribe and
  // flash the spinner each time a time or a duration is picked.
  Stream<Set<String>>? _occupied;
  String? _occupiedKey;

  Stream<Set<String>> _occupiedFor(TableDoc table) {
    final key = '${table.id}_${ReservationService.dateKey(_date)}';
    if (_occupied == null || _occupiedKey != key) {
      _occupiedKey = key;
      _occupied = ReservationService.streamOccupied(
        table.id,
        _date,
      ).asBroadcastStream();
    }
    return _occupied!;
  }

  Future<void> _loadTables() async {
    // Only tables that exist in the admin floor plan can be booked.
    final tables = await TableRegistry.loadTables();
    if (!mounted) return;
    setState(() {
      _tables = tables;
      _table = tables.isEmpty ? null : tables.first;
      _loadingTables = false;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 120)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _kPrimary,
            surface: _kCard,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = picked;
      _slot = null; // availability differs per day
      _hours = null;
    });
  }

  Future<void> _submit() async {
    final table = _table;
    final slot = _slot;

    if (table == null) {
      setState(() => _error = AppLanguage.getText('Please choose a table.'));
      return;
    }
    if (slot == null) {
      setState(() => _error = AppLanguage.getText('Please choose a time.'));
      return;
    }
    final hours = _isHall ? _hours : 0;
    if (hours == null) {
      setState(() => _error = AppLanguage.getText('Please choose a duration.'));
      return;
    }
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      setState(
        () => _error = AppLanguage.getText('Name and phone are required.'),
      );
      return;
    }

    // A hall costs money, so nothing is booked until the guest has seen the
    // price and confirmed it.
    if (_isHall) {
      setState(() => _error = null);
      final confirmed = await _confirmHall(table, slot, hours);
      if (!confirmed || !mounted) return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final reservation = await ReservationService.book(
        tableId: table.id,
        tableName: table.name,
        date: ReservationService.dateKey(_date),
        time: slot,
        guests: _guests,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        note: _noteCtrl.text.trim(),
        uid: FirebaseAuth.instance.currentUser?.uid ?? '',
        durationHours: hours,
      );

      if (!mounted) return;
      await _showConfirmation(reservation);
      if (mounted) Navigator.pop(context);
    } on SlotTakenException {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _slot = null;
        _hours = null;
        _error = AppLanguage.getText(
          'Sorry, that table was just booked. Please pick another time.',
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '${AppLanguage.getText('Booking failed.')} $e';
      });
    }
  }

  /// The price popup. Returns true only when the guest pressed Confirm.
  Future<bool> _confirmHall(TableDoc table, String slot, int hours) async {
    final preview = Reservation(
      id: '',
      tableId: table.id,
      tableName: table.name,
      date: ReservationService.dateKey(_date),
      time: slot,
      guests: _guests,
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      note: _noteCtrl.text.trim(),
      uid: '',
      createdAt: null,
      durationHours: hours,
      price: HallPricing.priceFor(hours),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppLanguage.getText('Please check your booking'),
                  style: const TextStyle(color: _kMuted, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  table.name,
                  style: const TextStyle(
                    color: _kWhite,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _summaryRow(Icons.calendar_today, 'Date', preview.dateLabel),
                _summaryRow(Icons.schedule, 'Time', preview.timeRangeLabel),
                _summaryRow(Icons.timelapse, 'Duration', _hoursLabel(hours)),
                _summaryRow(Icons.people, 'Guests', '$_guests'),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kPrimary),
                  ),
                  child: Row(
                    children: [
                      Text(
                        AppLanguage.getText('Price'),
                        style: const TextStyle(color: _kWhite, fontSize: 16),
                      ),
                      const Spacer(),
                      Text(
                        'CHF ${preview.price}.00',
                        style: const TextStyle(
                          color: _kPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _priceList(hours),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kWhite,
                          side: const BorderSide(color: _kMuted),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(AppLanguage.getText('Back')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPrimary,
                          foregroundColor: _kWhite,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          AppLanguage.getText('Confirm'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return result == true;
  }

  Widget _summaryRow(IconData icon, String labelKey, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: _kPrimary, size: 18),
          const SizedBox(width: 10),
          Text(
            AppLanguage.getText(labelKey),
            style: const TextStyle(color: _kMuted, fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: _kWhite,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// The full price list, with the tier that applies highlighted.
  Widget _priceList(int? hours) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLanguage.getText('Hall rental prices'),
          style: const TextStyle(color: _kMuted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        for (final tier in HallPricing.tiers)
          Builder(
            builder: (_) {
              final active =
                  hours != null && hours >= tier.from && hours <= tier.to;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      active ? Icons.check_circle : Icons.circle_outlined,
                      size: 14,
                      color: active ? _kPrimary : _kMuted.withOpacity(0.5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${tier.hours} ${AppLanguage.getText('hrs')}',
                      style: TextStyle(
                        color: active ? _kWhite : _kMuted,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'CHF ${tier.price}',
                      style: TextStyle(
                        color: active ? _kPrimary : _kMuted,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _showConfirmation(Reservation r) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent),
            const SizedBox(width: 10),
            Text(
              AppLanguage.getText(r.isHall ? 'Hall booked' : 'Table booked'),
              style: const TextStyle(color: _kWhite, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          '${r.tableName}\n${r.dateLabel} · ${r.timeRangeLabel}\n'
          '${r.guests} ${AppLanguage.getText('guests')}'
          '${r.isHall ? '\n${AppLanguage.getText('Price')}: CHF ${r.price}.00' : ''}',
          style: const TextStyle(color: _kMuted, fontSize: 15),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: _kWhite,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLanguage.getText('Done')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        foregroundColor: _kWhite,
        elevation: 0,
        title: Text(AppLanguage.getText('Book a table')),
      ),
      body: _loadingTables
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : _tables.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  AppLanguage.getText(
                    'No tables are available for booking yet.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _kMuted, fontSize: 16),
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Table'),
                  _buildTablePicker(),
                  const SizedBox(height: 20),

                  _label('Date'),
                  _buildDateField(),
                  const SizedBox(height: 20),

                  _label('Time'),
                  _buildAvailability(),
                  const SizedBox(height: 20),

                  _label('Guests'),
                  _buildGuestPicker(),
                  const SizedBox(height: 20),

                  _label('Your details'),
                  _field(_nameCtrl, 'Name', Icons.person),
                  const SizedBox(height: 12),
                  _field(_phoneCtrl, 'Phone', Icons.phone),
                  const SizedBox(height: 12),
                  _field(_emailCtrl, 'E-Mail', Icons.mail_outline),
                  const SizedBox(height: 12),
                  _field(_noteCtrl, 'Note (optional)', Icons.edit_note),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        foregroundColor: _kWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: _kWhite,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              AppLanguage.getText('Confirm booking'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _label(String key) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        AppLanguage.getText(key),
        style: const TextStyle(
          color: _kWhite,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildTablePicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _tables.map((table) {
        final selected = _table?.id == table.id;
        return GestureDetector(
          onTap: () => setState(() {
            _table = table;
            _slot = null; // availability is per table
            _hours = null;
            if (_guests > _maxGuests) _guests = _maxGuests;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? _kPrimary.withOpacity(0.2) : _kField,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? _kPrimary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  table.name,
                  style: TextStyle(
                    color: selected ? _kPrimary : _kWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (table.chairs.isNotEmpty)
                  Text(
                    '${table.chairs.length} ${AppLanguage.getText('seats')}',
                    style: const TextStyle(color: _kMuted, fontSize: 12),
                  ),
                if (HallPricing.isHall(table.name))
                  Text(
                    '${AppLanguage.getText('from')} CHF '
                    '${HallPricing.priceFor(HallPricing.minHours)}',
                    style: const TextStyle(
                      color: _kPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _kField,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: _kPrimary, size: 18),
            const SizedBox(width: 12),
            Text(
              '${_date.day.toString().padLeft(2, '0')}.'
              '${_date.month.toString().padLeft(2, '0')}.${_date.year}',
              style: const TextStyle(color: _kWhite, fontSize: 16),
            ),
            const Spacer(),
            const Icon(Icons.expand_more, color: _kMuted),
          ],
        ),
      ),
    );
  }

  /// Times already taken for this table are disabled, so a guest cannot even
  /// pick one. For a hall the same data also rules out any length of stay that
  /// would run into somebody else's booking, including one after midnight.
  Widget _buildAvailability() {
    final table = _table;
    if (table == null) return const SizedBox.shrink();
    final dateStr = ReservationService.dateKey(_date);

    return StreamBuilder<Set<String>>(
      stream: _occupiedFor(table),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: CircularProgressIndicator(color: _kPrimary),
            ),
          );
        }

        final occupied = snapshot.data ?? const <String>{};
        bool free(String slot, int hours) => ReservationService.coveredSlots(
          dateStr,
          slot,
          hours,
        ).every((s) => !occupied.contains(s.key));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSlotChips(occupied, dateStr),
            if (_isHall) ...[
              const SizedBox(height: 20),
              _label('Duration'),
              _buildDurationChips(free),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSlotChips(Set<String> occupied, String dateStr) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ReservationSlots.all().map((slot) {
        final isTaken = occupied.contains(SlotRef(dateStr, slot).key);
        final isPast = ReservationSlots.isPast(_date, slot);
        final disabled = isTaken || isPast;
        final selected = _slot == slot;

        return GestureDetector(
          onTap: disabled
              ? null
              : () => setState(() {
                  _slot = slot;
                  _hours = null;
                }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? _kPrimary
                  : disabled
                  ? Colors.black26
                  : _kField,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? _kPrimary : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isTaken)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.lock, size: 13, color: _kMuted),
                  ),
                Text(
                  slot,
                  style: TextStyle(
                    color: selected
                        ? _kWhite
                        : disabled
                        ? _kMuted.withOpacity(0.5)
                        : _kWhite,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    decoration: isTaken
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDurationChips(bool Function(String slot, int hours) free) {
    final slot = _slot;
    if (slot == null) {
      return Text(
        AppLanguage.getText('Pick a start time first.'),
        style: const TextStyle(color: _kMuted, fontSize: 13),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var h = HallPricing.minHours; h <= HallPricing.maxHours; h++)
              Builder(
                builder: (_) {
                  final available = free(slot, h);
                  final selected = _hours == h;
                  return GestureDetector(
                    onTap: available
                        ? () => setState(() => _hours = h)
                        : null,
                    child: Container(
                      width: 64,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? _kPrimary
                            : available
                            ? _kField
                            : Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _hoursLabel(h),
                        style: TextStyle(
                          color: available
                              ? _kWhite
                              : _kMuted.withOpacity(0.5),
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          decoration: available
                              ? TextDecoration.none
                              : TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        if (_hours != null) ...[
          const SizedBox(height: 12),
          Text(
            '${AppLanguage.getText('Price')}: '
            'CHF ${HallPricing.priceFor(_hours!)}.00',
            style: const TextStyle(
              color: _kPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGuestPicker() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: _kPrimary),
          onPressed: _guests > 1 ? () => setState(() => _guests--) : null,
        ),
        Text(
          '$_guests',
          style: const TextStyle(
            color: _kWhite,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, color: _kPrimary),
          onPressed: _guests < _maxGuests
              ? () => setState(() => _guests++)
              : null,
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: _kWhite),
      decoration: InputDecoration(
        labelText: AppLanguage.getText(label),
        labelStyle: const TextStyle(color: _kMuted),
        prefixIcon: Icon(icon, color: _kMuted, size: 20),
        filled: true,
        fillColor: _kField,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kPrimary, width: 1.5),
        ),
      ),
    );
  }
}
