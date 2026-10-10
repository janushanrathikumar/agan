// lib/shared/daily_meal.dart
//
// The dish of the day.
//
// The admin puts one up with the hours it is on offer, and it appears on the
// guest's home page only inside that window - after it, it simply stops being
// shown. It goes into the same cart as everything else, so a guest can order
// it together with items from the menu and it reaches the kitchen and the bill
// like any other line.

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:restorant/language.dart';

class DailyMeal {
  const DailyMeal({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.imageFileName,
    required this.availableFrom,
    required this.availableUntil,
    required this.active,
  });

  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;

  /// Kept so the picture can be deleted when it is replaced.
  final String imageFileName;

  final DateTime availableFrom;
  final DateTime availableUntil;

  /// Switched off by the admin without deleting it.
  final bool active;

  /// Whether a guest should see it right now.
  bool isAvailableAt(DateTime now) =>
      active && !now.isBefore(availableFrom) && now.isBefore(availableUntil);

  bool get hasEnded => DateTime.now().isAfter(availableUntil);

  /// Scheduled, but its hours have not started yet - what the home page
  /// announces once today's meal is over.
  bool isUpcomingAt(DateTime now) => active && now.isBefore(availableFrom);

  /// 'Ab morgen 11:00 – 14:00' for a meal that has not started yet; the date
  /// is spelled out when it is further off than tomorrow.
  String startLabel(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    final hours =
        '${two(availableFrom.hour)}:${two(availableFrom.minute)} – '
        '${two(availableUntil.hour)}:${two(availableUntil.minute)}';

    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(
      availableFrom.year,
      availableFrom.month,
      availableFrom.day,
    );
    final days = start.difference(today).inDays;

    if (days <= 0) return '${AppLanguage.getText('from_today')} $hours';
    if (days == 1) return '${AppLanguage.getText('from_tomorrow')} $hours';
    return '${AppLanguage.getText('from_date')} '
        '${two(start.day)}.${two(start.month)}.${start.year} $hours';
  }

  /// '03.10.2026 11:30 – 14:00', with the end date added when it runs over
  /// midnight.
  String get windowLabel {
    String two(int v) => v.toString().padLeft(2, '0');
    String date(DateTime d) => '${two(d.day)}.${two(d.month)}.${d.year}';
    String time(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

    final sameDay =
        availableFrom.year == availableUntil.year &&
        availableFrom.month == availableUntil.month &&
        availableFrom.day == availableUntil.day;

    return sameDay
        ? '${date(availableFrom)}  ${time(availableFrom)} – ${time(availableUntil)}'
        : '${date(availableFrom)} ${time(availableFrom)} – '
              '${date(availableUntil)} ${time(availableUntil)}';
  }

  static DailyMeal fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final from = (data['availableFrom'] as Timestamp?)?.toDate();
    final until = (data['availableUntil'] as Timestamp?)?.toDate();
    return DailyMeal(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      price: ((data['price'] as num?) ?? 0).toDouble(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      imageFileName: (data['imageFileName'] ?? '').toString(),
      // A meal saved without a window would otherwise show for ever; an empty
      // window shows never, which is the safer way round.
      availableFrom: from ?? DateTime.fromMillisecondsSinceEpoch(0),
      availableUntil: until ?? DateTime.fromMillisecondsSinceEpoch(0),
      active: data['active'] != false,
    );
  }

  /// What a guest adding this to the cart stores, in the very same shape the
  /// menu uses - that is what lets it be ordered alongside menu items.
  Map<String, dynamic> cartItem({required int qty, required String note}) {
    return {
      // Food, so it reaches the kitchen rather than the bar.
      'kind': 'food',
      'name': name,
      'imageUrl': imageUrl,
      'price': price,
      'qty': qty,
      'category': 'Tagesmenü',
      'menuChoices': <String, String>{},
      'additionalOptions': <dynamic>[],
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class DailyMealService {
  DailyMealService._();

  static CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('daily_meals');

  /// Everything, newest window first - the admin list.
  static Stream<List<DailyMeal>> streamAll() {
    return _collection.snapshots().map((snap) {
      final meals = snap.docs.map(DailyMeal.fromDoc).toList();
      meals.sort((a, b) => b.availableFrom.compareTo(a.availableFrom));
      return meals;
    });
  }

  /// Every switched-on meal, earliest window first.
  ///
  /// The home page decides from this which are on offer right now and which
  /// one to announce next. Splitting it there rather than in the query is what
  /// a time range forces: it needs an inequality on two fields, which
  /// Firestore cannot do in one query.
  static Stream<List<DailyMeal>> streamActive() {
    return _collection.where('active', isEqualTo: true).snapshots().map((snap) {
      final meals = snap.docs.map(DailyMeal.fromDoc).toList();
      meals.sort((a, b) => a.availableFrom.compareTo(b.availableFrom));
      return meals;
    });
  }

  static Future<void> save({
    String? id,
    required String name,
    required String description,
    required double price,
    required String imageUrl,
    required String imageFileName,
    required DateTime availableFrom,
    required DateTime availableUntil,
    required bool active,
  }) {
    final data = <String, dynamic>{
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'imageFileName': imageFileName,
      'availableFrom': Timestamp.fromDate(availableFrom),
      'availableUntil': Timestamp.fromDate(availableUntil),
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (id == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
      return _collection.add(data);
    }
    return _collection.doc(id).set(data, SetOptions(merge: true));
  }

  static Future<void> setActive(String id, bool active) =>
      _collection.doc(id).set({'active': active}, SetOptions(merge: true));

  static Future<void> delete(String id) => _collection.doc(id).delete();
}
