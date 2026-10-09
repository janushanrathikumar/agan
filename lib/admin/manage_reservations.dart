// lib/admin/manage_reservations.dart
//
// The admin view of table reservations: who booked which table, when, and how
// to reach them. Cancelling removes the booking and frees the slot again.
import 'package:flutter/material.dart';

import 'package:restorant/shared/reservation_service.dart';

const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF2A2928);
const kWhite = Color(0xFFFFFFFF);
const kMuted = Color(0xFFB7B7B6);
const kFieldBg = Color(0xFF383735);

class ManageReservationsPage extends StatefulWidget {
  const ManageReservationsPage({super.key});

  @override
  State<ManageReservationsPage> createState() => _ManageReservationsPageState();
}

class _ManageReservationsPageState extends State<ManageReservationsPage> {
  static const _upcoming = 'Upcoming';
  static const _past = 'Past';
  String _tab = _upcoming;

  Future<void> _cancel(Reservation r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kFieldBg,
        title: const Text(
          'Cancel reservation?',
          style: TextStyle(color: kWhite),
        ),
        content: Text(
          'Remove ${r.name}\'s booking for ${r.tableName} on '
          '${r.dateLabel}, ${r.timeRangeLabel}? '
          '${r.isHall ? 'Those hours become' : 'The slot becomes'} bookable again.',
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
              'Cancel booking',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ReservationService.cancel(r.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reservation cancelled.'),
          backgroundColor: kPrimary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not cancel: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kWhite,
        elevation: 0,
        title: const Text('Table Reservations'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [_upcoming, _past].map((tab) {
                final active = _tab == tab;
                return GestureDetector(
                  onTap: () => setState(() => _tab = tab),
                  child: Container(
                    margin: const EdgeInsets.only(right: 28),
                    padding: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: active ? kPrimary : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Text(
                      tab,
                      style: TextStyle(
                        color: active ? kPrimary : kMuted,
                        fontWeight: active ? FontWeight.bold : FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Reservation>>(
              stream: ReservationService.streamAll(),
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

                final all = snapshot.data ?? [];
                final items = all
                    .where((r) => _tab == _upcoming ? !r.isPast : r.isPast)
                    .toList();
                if (_tab == _past) {
                  items.sort((a, b) => b.startsAt.compareTo(a.startsAt));
                }

                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      _tab == _upcoming
                          ? 'No upcoming reservations.'
                          : 'No past reservations.',
                      style: const TextStyle(color: kMuted, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _card(items[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Reservation r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kFieldBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: kPrimary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  r.time,
                  style: const TextStyle(
                    color: kPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  r.dateLabel,
                  style: const TextStyle(color: kMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.tableName} · ${r.guests} guest(s)',
                  style: const TextStyle(
                    color: kWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (r.isHall) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _chip(Icons.schedule, r.timeRangeLabel),
                      _chip(Icons.timelapse, '${r.durationHours} h'),
                      _chip(Icons.payments_outlined, 'CHF ${r.price}.00'),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  r.name,
                  style: const TextStyle(color: kWhite, fontSize: 14),
                ),
                Text(
                  [
                    if (r.phone.isNotEmpty) r.phone,
                    if (r.email.isNotEmpty) r.email,
                  ].join(' · '),
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),
                if (r.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '📝 ${r.note}',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cancel reservation',
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.redAccent,
              size: 20,
            ),
            onPressed: () => _cancel(r),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kPrimary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: kPrimary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: kPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
