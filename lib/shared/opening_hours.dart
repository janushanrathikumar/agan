// lib/shared/opening_hours.dart
//
// The restaurant's opening times for the week.
//
// The admin keeps them in one place and the guest's home page shows the whole
// week, with today picked out and a note saying whether the kitchen is open
// right now. A day can be closed, or have two services - lunch and evening -
// which is how the week usually runs.

import 'package:cloud_firestore/cloud_firestore.dart';

/// One day of the week.
class DayHours {
  const DayHours({
    this.closed = false,
    this.open1 = '',
    this.close1 = '',
    this.open2 = '',
    this.close2 = '',
  });

  /// Closed all day - a rest day.
  final bool closed;

  /// First service, 'HH:mm'. Empty when the day has no times set.
  final String open1;
  final String close1;

  /// An optional second service, for a kitchen that shuts in the afternoon.
  final String open2;
  final String close2;

  bool get hasFirst => open1.isNotEmpty && close1.isNotEmpty;
  bool get hasSecond => open2.isNotEmpty && close2.isNotEmpty;

  /// Nothing to show for this day at all.
  bool get isEmpty => !closed && !hasFirst && !hasSecond;

  /// '11:00 – 14:00, 17:00 – 23:00'
  String get label {
    if (closed || isEmpty) return '';
    return [
      if (hasFirst) '$open1 – $close1',
      if (hasSecond) '$open2 – $close2',
    ].join(', ');
  }

  /// Whether [minutesOfDay] falls in one of the day's services.
  ///
  /// A service whose end is earlier than its start runs past midnight, and
  /// then counts until the end of the day here; the small hours belong to the
  /// previous day's service, which [OpeningHours.isOpenAt] takes care of.
  bool covers(int minutesOfDay) {
    if (closed) return false;
    bool inRange(String from, String to) {
      final start = _minutes(from);
      final end = _minutes(to);
      if (start == null || end == null) return false;
      if (end > start) return minutesOfDay >= start && minutesOfDay < end;
      return minutesOfDay >= start; // runs into the next day
    }

    return (hasFirst && inRange(open1, close1)) ||
        (hasSecond && inRange(open2, close2));
  }

  /// Whether a service started yesterday is still running at [minutesOfDay].
  bool spillsInto(int minutesOfDay) {
    if (closed) return false;
    bool spills(String from, String to) {
      final start = _minutes(from);
      final end = _minutes(to);
      if (start == null || end == null || end > start) return false;
      return minutesOfDay < end;
    }

    return (hasFirst && spills(open1, close1)) ||
        (hasSecond && spills(open2, close2));
  }

  static int? _minutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  Map<String, dynamic> toMap() => {
    'closed': closed,
    'open1': open1,
    'close1': close1,
    'open2': open2,
    'close2': close2,
  };

  static DayHours fromMap(Map<String, dynamic> map) => DayHours(
    closed: map['closed'] == true,
    open1: (map['open1'] ?? '').toString(),
    close1: (map['close1'] ?? '').toString(),
    open2: (map['open2'] ?? '').toString(),
    close2: (map['close2'] ?? '').toString(),
  );

  DayHours copyWith({
    bool? closed,
    String? open1,
    String? close1,
    String? open2,
    String? close2,
  }) => DayHours(
    closed: closed ?? this.closed,
    open1: open1 ?? this.open1,
    close1: close1 ?? this.close1,
    open2: open2 ?? this.open2,
    close2: close2 ?? this.close2,
  );
}

class OpeningHours {
  const OpeningHours({required this.days, this.note = ''});

  /// Seven entries, Monday first - the order the week is read in.
  final List<DayHours> days;

  /// A line under the table, for holidays and the like.
  final String note;

  /// Nothing has been filled in yet, so there is nothing to show a guest.
  bool get isEmpty => days.every((d) => d.isEmpty);

  DayHours dayFor(DateTime date) => days[(date.weekday - 1) % 7];

  /// Whether the restaurant is open at [now], including a service that
  /// started the day before and runs past midnight.
  bool isOpenAt(DateTime now) {
    final minutes = now.hour * 60 + now.minute;
    if (dayFor(now).covers(minutes)) return true;
    final yesterday = now.subtract(const Duration(days: 1));
    return dayFor(yesterday).spillsInto(minutes);
  }

  static OpeningHours fromDoc(DocumentSnapshot? doc) {
    final data = doc?.data() as Map<String, dynamic>?;
    final raw = data?['days'] as List<dynamic>? ?? const [];
    return OpeningHours(
      days: [
        for (var i = 0; i < 7; i++)
          i < raw.length && raw[i] is Map
              ? DayHours.fromMap(Map<String, dynamic>.from(raw[i] as Map))
              : const DayHours(),
      ],
      note: (data?['note'] ?? '').toString(),
    );
  }

  static OpeningHours get empty =>
      OpeningHours(days: List.filled(7, const DayHours()));
}

class OpeningHoursService {
  OpeningHoursService._();

  static DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('AppConfig').doc('opening_hours');

  static Stream<OpeningHours> stream() =>
      _doc.snapshots().map(OpeningHours.fromDoc);

  static Future<OpeningHours> load() async =>
      OpeningHours.fromDoc(await _doc.get());

  static Future<void> save(OpeningHours hours) => _doc.set({
    'days': [for (final day in hours.days) day.toMap()],
    'note': hours.note,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
