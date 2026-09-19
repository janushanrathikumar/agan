// lib/shared/reservation_service.dart
//
// Table reservations.
//
// The whole point of this file is that two guests must never end up with the
// same table at the same time. Firestore transactions cannot run queries, only
// reads by document id, so the slot itself *is* the document id:
//
//     reservations/{tableId}_{yyyy-MM-dd}_{HH-mm}
//
// Booking then reads that one id inside a transaction and refuses if it is
// already there. Uniqueness is enforced by the database rather than by
// checking first and hoping nobody books in between.
//
// A hall (Saal) is rented for whole hours, so one booking occupies many half
// hour slots. Each of those slots gets its own lock document,
//
//     reservation_locks/{tableId}_{yyyy-MM-dd}_{HH-mm}
//
// written in the same transaction as the booking, and every booking - hall or
// table - checks the locks for each slot it would occupy.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// The bookable times of day. A reservation holds one table for one slot.
class ReservationSlots {
  static const int openHour = 11;
  static const int lastSlotHour = 22;
  static const int stepMinutes = 30;

  /// '11:00', '11:30', … '22:00'
  static List<String> all() {
    final slots = <String>[];
    for (var minutes = openHour * 60;
        minutes <= lastSlotHour * 60;
        minutes += stepMinutes) {
      final h = (minutes ~/ 60).toString().padLeft(2, '0');
      final m = (minutes % 60).toString().padLeft(2, '0');
      slots.add('$h:$m');
    }
    return slots;
  }

  /// Slots that have not already passed, for a date that is today.
  static bool isPast(DateTime date, String slot) {
    final now = DateTime.now();
    if (date.year != now.year ||
        date.month != now.month ||
        date.day != now.day) {
      return false;
    }
    final parts = slot.split(':');
    final slotTime = DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    return slotTime.isBefore(now);
  }
}

/// Halls are rented by the hour at a flat price per length of stay.
class HallPricing {
  HallPricing._();

  static const int minHours = 1;
  static const int maxHours = 24;

  /// Saal 1, Saal 2, … are halls; every other table is booked per visit and
  /// has no price.
  static bool isHall(String tableName) =>
      tableName.trim().toLowerCase().startsWith('saal');

  /// CHF for renting a hall for [hours] whole hours.
  static int priceFor(int hours) {
    if (hours < minHours || hours > maxHours) {
      throw ArgumentError.value(hours, 'hours', 'must be $minHours-$maxHours');
    }
    if (hours == 1) return 80;
    if (hours == 2) return 120;
    if (hours == 3) return 150;
    if (hours <= 6) return 200;
    return 400;
  }

  /// The price list as shown to guests, in order.
  static const List<({String hours, int price, int from, int to})> tiers = [
    (hours: '1', price: 80, from: 1, to: 1),
    (hours: '2', price: 120, from: 2, to: 2),
    (hours: '3', price: 150, from: 3, to: 3),
    (hours: '4–6', price: 200, from: 4, to: 6),
    (hours: '7–24', price: 400, from: 7, to: 24),
  ];
}

/// One half hour of one table, the unit that cannot be booked twice.
class SlotRef {
  const SlotRef(this.date, this.time);

  /// 'yyyy-MM-dd'
  final String date;

  /// 'HH:mm'
  final String time;

  String get key => '$date $time';

  static SlotRef of(DateTime at) => SlotRef(
    ReservationService.dateKey(at),
    '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}',
  );
}

/// Raised when the table is already taken for that day and time.
class SlotTakenException implements Exception {
  const SlotTakenException(this.tableName, this.date, this.time);

  final String tableName;
  final String date;
  final String time;

  @override
  String toString() => '$tableName is already booked on $date at $time.';
}

class Reservation {
  const Reservation({
    required this.id,
    required this.tableId,
    required this.tableName,
    required this.date,
    required this.time,
    required this.guests,
    required this.name,
    required this.phone,
    required this.email,
    required this.note,
    required this.uid,
    required this.createdAt,
    this.durationHours = 0,
    this.price,
  });

  final String id;
  final String tableId;
  final String tableName;

  /// 'yyyy-MM-dd'
  final String date;

  /// 'HH:mm'
  final String time;

  final int guests;
  final String name;
  final String phone;
  final String email;
  final String note;
  final String uid;
  final DateTime? createdAt;

  /// Whole hours a hall is rented for; 0 for an ordinary table booking.
  final int durationHours;

  /// CHF, for hall bookings only.
  final int? price;

  bool get isHall => durationHours > 0;

  /// When the guests are expected, for sorting and for hiding past bookings.
  DateTime get startsAt {
    final d = date.split('-');
    final t = time.split(':');
    if (d.length != 3 || t.length != 2) return DateTime.now();
    return DateTime(
      int.tryParse(d[0]) ?? 2000,
      int.tryParse(d[1]) ?? 1,
      int.tryParse(d[2]) ?? 1,
      int.tryParse(t[0]) ?? 0,
      int.tryParse(t[1]) ?? 0,
    );
  }

  /// When a hall has to be free again; a table booking is a single slot.
  DateTime get endsAt => isHall
      ? startsAt.add(Duration(hours: durationHours))
      : startsAt.add(const Duration(minutes: ReservationSlots.stepMinutes));

  /// A hall rented until tonight is still upcoming while the party is on.
  bool get isPast => (isHall ? endsAt : startsAt).isBefore(DateTime.now());

  /// '18:00 – 22:00', with the end date added when it runs past midnight.
  String get timeRangeLabel {
    if (!isHall) return time;
    final end = endsAt;
    final endTime =
        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    final sameDay =
        end.year == startsAt.year &&
        end.month == startsAt.month &&
        end.day == startsAt.day;
    return sameDay
        ? '$time – $endTime'
        : '$time – ${end.day.toString().padLeft(2, '0')}.'
              '${end.month.toString().padLeft(2, '0')}. $endTime';
  }

  /// 'dd.MM.yyyy'
  String get dateLabel {
    final d = date.split('-');
    return d.length == 3 ? '${d[2]}.${d[1]}.${d[0]}' : date;
  }

  static Reservation fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Reservation(
      id: doc.id,
      tableId: (data['tableId'] ?? '').toString(),
      tableName: (data['tableName'] ?? '').toString(),
      date: (data['date'] ?? '').toString(),
      time: (data['time'] ?? '').toString(),
      guests: (data['guests'] as num?)?.toInt() ?? 1,
      name: (data['name'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      note: (data['note'] ?? '').toString(),
      uid: (data['uid'] ?? '').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      durationHours: (data['durationHours'] as num?)?.toInt() ?? 0,
      price: (data['price'] as num?)?.toInt(),
    );
  }
}

class ReservationService {
  static final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('reservations');

  static final CollectionReference<Map<String, dynamic>> _locks =
      FirebaseFirestore.instance.collection('reservation_locks');

  /// Where the booking notification is sent.
  static const String adminEmail = 'janushanrathikumar@gmail.com';

  // ------------------------------------------------------------------ keys

  /// 'yyyy-MM-dd'
  static String dateKey(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  /// Groups every slot of one table on one day, so availability is a single
  /// equality query and needs no composite index.
  static String slotPrefix(String tableId, String date) => '${tableId}_$date';

  /// The document id, which is also what makes double booking impossible.
  static String slotId(String tableId, String date, String time) =>
      '${tableId}_${date}_${time.replaceAll(':', '-')}';

  /// Every half hour a booking occupies, in order. Hall bookings may run past
  /// midnight, so each slot carries its own date.
  static List<SlotRef> coveredSlots(String date, String time, int hours) {
    final d = date.split('-').map(int.parse).toList();
    final t = time.split(':').map(int.parse).toList();
    final start = DateTime(d[0], d[1], d[2], t[0], t[1]);
    final steps = hours <= 0 ? 1 : hours * 60 ~/ ReservationSlots.stepMinutes;
    return [
      for (var i = 0; i < steps; i++)
        SlotRef.of(
          start.add(Duration(minutes: i * ReservationSlots.stepMinutes)),
        ),
    ];
  }

  // --------------------------------------------------------------- reading

  /// Everything already booked for one table on one day.
  static Stream<List<Reservation>> streamDay(String tableId, String date) {
    return _collection
        .where('slotPrefix', isEqualTo: slotPrefix(tableId, date))
        .snapshots()
        .map((snap) => snap.docs.map(Reservation.fromDoc).toList());
  }

  /// Every half hour of one table that is taken on [date] or the day after,
  /// as [SlotRef.key]s. The day after matters because a hall booked in the
  /// evening can run past midnight.
  static Stream<Set<String>> streamOccupied(String tableId, DateTime date) {
    final prefixes = [
      slotPrefix(tableId, dateKey(date)),
      slotPrefix(tableId, dateKey(date.add(const Duration(days: 1)))),
    ];

    Set<String> fromBookings = {};
    Set<String> fromLocks = {};
    final controller = StreamController<Set<String>>();
    void emit() => controller.add({...fromBookings, ...fromLocks});

    final subs = <StreamSubscription<dynamic>>[];
    controller.onListen = () {
      subs
        ..add(
          _collection.where('slotPrefix', whereIn: prefixes).snapshots().listen(
            (snap) {
              fromBookings = {
                for (final doc in snap.docs)
                  SlotRef(
                    (doc.data()['date'] ?? '').toString(),
                    (doc.data()['time'] ?? '').toString(),
                  ).key,
              };
              emit();
            },
            onError: controller.addError,
          ),
        )
        ..add(
          _locks.where('slotPrefix', whereIn: prefixes).snapshots().listen(
            (snap) {
              fromLocks = {
                for (final doc in snap.docs)
                  SlotRef(
                    (doc.data()['date'] ?? '').toString(),
                    (doc.data()['time'] ?? '').toString(),
                  ).key,
              };
              emit();
            },
            onError: controller.addError,
          ),
        );
    };
    controller.onCancel = () async {
      for (final sub in subs) {
        await sub.cancel();
      }
    };
    return controller.stream;
  }

  /// Every reservation, newest booking first, for the admin list.
  static Stream<List<Reservation>> streamAll() {
    return _collection.snapshots().map((snap) {
      final items = snap.docs.map(Reservation.fromDoc).toList();
      items.sort((a, b) => a.startsAt.compareTo(b.startsAt));
      return items;
    });
  }

  // --------------------------------------------------------------- booking

  /// Reserves a table for one slot, or a hall for [durationHours] hours.
  ///
  /// Throws [SlotTakenException] when somebody else got there first - including
  /// when they did so a fraction of a second earlier, because every slot is
  /// checked and claimed inside one transaction.
  static Future<Reservation> book({
    required String tableId,
    required String tableName,
    required String date,
    required String time,
    required int guests,
    required String name,
    required String phone,
    required String email,
    required String note,
    required String uid,
    int durationHours = 0,
  }) async {
    final id = slotId(tableId, date, time);
    final ref = _collection.doc(id);
    final isHall = durationHours > 0;
    final price = isHall ? HallPricing.priceFor(durationHours) : null;
    final slots = coveredSlots(date, time, durationHours);

    final data = <String, dynamic>{
      'tableId': tableId,
      'tableName': tableName,
      'date': date,
      'time': time,
      'slotPrefix': slotPrefix(tableId, date),
      'guests': guests,
      'name': name,
      'phone': phone,
      'email': email,
      'note': note,
      'uid': uid,
      'status': 'Booked',
      'createdAt': FieldValue.serverTimestamp(),
      if (isHall) ...{
        'durationHours': durationHours,
        'price': price,
        'currency': 'CHF',
      },
    };

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      // Firestore wants every read before the first write.
      for (final slot in slots) {
        final id = slotId(tableId, slot.date, slot.time);
        final booked = await transaction.get(_collection.doc(id));
        final locked = await transaction.get(_locks.doc(id));
        if (booked.exists || locked.exists) {
          throw SlotTakenException(tableName, slot.date, slot.time);
        }
      }

      transaction.set(ref, data);
      if (isHall) {
        for (final slot in slots) {
          transaction.set(_locks.doc(slotId(tableId, slot.date, slot.time)), {
            'tableId': tableId,
            'date': slot.date,
            'time': slot.time,
            'slotPrefix': slotPrefix(tableId, slot.date),
            'reservationId': id,
          });
        }
      }
    });

    final saved = Reservation(
      id: id,
      tableId: tableId,
      tableName: tableName,
      date: date,
      time: time,
      guests: guests,
      name: name,
      phone: phone,
      email: email,
      note: note,
      uid: uid,
      createdAt: DateTime.now(),
      durationHours: durationHours,
      price: price,
    );

    await _queueAdminEmail(saved);
    return saved;
  }

  /// Removing the booking and its hall locks frees every slot straight away.
  static Future<void> cancel(String id) async {
    final locks = await _locks.where('reservationId', isEqualTo: id).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final lock in locks.docs) {
      batch.delete(lock.reference);
    }
    batch.delete(_collection.doc(id));
    await batch.commit();
  }

  // ----------------------------------------------------------------- email

  /// Queues the notification for the "Trigger Email from Firestore" Firebase
  /// extension, which picks documents up from the `mail` collection and sends
  /// them. Booking must not fail just because the mail could not be queued, so
  /// any error here is swallowed.
  static Future<void> _queueAdminEmail(Reservation r) async {
    final subject = r.isHall
        ? 'Neue Saalreservierung: ${r.tableName} am ${r.dateLabel}, '
              '${r.timeRangeLabel} (CHF ${r.price})'
        : 'Neue Tischreservierung: ${r.tableName} am ${r.dateLabel} um ${r.time}';

    final rows = <String, String>{
      r.isHall ? 'Saal' : 'Tisch': r.tableName,
      'Datum': r.dateLabel,
      'Uhrzeit': r.timeRangeLabel,
      if (r.isHall) 'Dauer': '${r.durationHours} Std.',
      if (r.isHall) 'Preis': 'CHF ${r.price}',
      'Personen': r.guests.toString(),
      'Name': r.name,
      'Telefon': r.phone,
      'E-Mail': r.email,
      if (r.note.isNotEmpty) 'Bemerkung': r.note,
    };

    final text = rows.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    final html = StringBuffer(
      '<h2>${r.isHall ? 'Neue Saalreservierung' : 'Neue Tischreservierung'}</h2>'
      '<table>',
    );
    for (final e in rows.entries) {
      html.write('<tr><td><b>${e.key}</b></td><td>${e.value}</td></tr>');
    }
    html.write('</table>');

    try {
      await FirebaseFirestore.instance.collection('mail').add({
        'to': [adminEmail],
        'message': {
          'subject': subject,
          'text': text,
          'html': html.toString(),
        },
        'reservationId': r.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // The reservation itself is already saved and visible in the admin list.
    }
  }
}
