// lib/user/opening_hours_card.dart
//
// The week's opening times on the guest's home page.
//
// It shows the whole week at a glance with today picked out, and a badge
// saying whether the kitchen is open at this moment. Until the admin has
// filled anything in, the card stays away entirely.

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:restorant/language.dart';
import 'package:restorant/shared/opening_hours.dart';

const _kPrimary = Color(0xFFB59410);
const _kCardBg = Color(0xFF163820);
const _kRowBg = Color(0xFF1E3A24);
const _kMuted = Color(0xFFA1B3A1);
const _kWhite = Color(0xFFF7F7F2);

/// Monday first, in the order the week is read.
const _dayKeys = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

class OpeningHoursCard extends StatefulWidget {
  const OpeningHoursCard({super.key});

  @override
  State<OpeningHoursCard> createState() => _OpeningHoursCardState();
}

class _OpeningHoursCardState extends State<OpeningHoursCard> {
  late final Stream<OpeningHours> _stream = OpeningHoursService.stream();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Nothing arrives from Firestore when opening time simply passes, so the
    // badge and the highlighted day are re-checked against the clock.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<OpeningHours>(
      stream: _stream,
      builder: (context, snapshot) {
        final hours = snapshot.data;
        // Nothing set yet: the card takes up no room at all.
        if (hours == null || hours.isEmpty) return const SizedBox.shrink();

        final now = DateTime.now();
        final open = hours.isOpenAt(now);
        final todayIndex = (now.weekday - 1) % 7;

        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded, color: _kPrimary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLanguage.getText('opening_hours'),
                        style: const TextStyle(
                          color: _kWhite,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    _badge(open),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _kCardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kPrimary.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < 7; i++)
                        _dayRow(i, hours.days[i], i == todayIndex),
                      if (hours.note.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: _kMuted,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                hours.note,
                                style: const TextStyle(
                                  color: _kMuted,
                                  fontSize: 12.5,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _badge(bool open) {
    final color = open ? const Color(0xFF4CAF50) : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            AppLanguage.getText(open ? 'open_now' : 'closed_now'),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayRow(int index, DayHours day, bool isToday) {
    final label = day.closed || day.label.isEmpty
        ? AppLanguage.getText('day_closed')
        : day.label;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isToday ? _kRowBg : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isToday
            ? Border.all(color: _kPrimary.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              AppLanguage.getText(_dayKeys[index]),
              style: TextStyle(
                color: isToday ? _kWhite : _kMuted,
                fontSize: 14,
                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: day.closed || day.label.isEmpty
                  ? Colors.redAccent.withValues(alpha: 0.85)
                  : (isToday ? _kPrimary : _kWhite),
              fontSize: 13.5,
              fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
