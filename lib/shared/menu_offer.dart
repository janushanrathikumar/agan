import 'package:flutter/foundation.dart';

double menuComboTotal(Map<String, dynamic> item) {
  final entries = item['comboItems'] as List<dynamic>? ?? const [];
  return entries.fold<double>(0, (total, entry) {
    if (entry is! Map) return total;
    return total + ((entry['price'] as num?)?.toDouble() ?? 0);
  });
}

bool hasMenuOffer(Map<String, dynamic> item) {
  return item['hasDiscount'] == true &&
      ((item['discountValue'] as num?)?.toDouble() ?? 0) > 0;
}

double menuOriginalPrice(Map<String, dynamic> item, {double? sizePrice}) {
  if (sizePrice != null) return sizePrice;
  if (item['itemType'] == 'combo' && hasMenuOffer(item)) {
    final total = menuComboTotal(item);
    if (total > 0) return total;
  }
  return (item['price'] as num?)?.toDouble() ?? 0;
}

double menuOfferPrice(Map<String, dynamic> item, {double? sizePrice}) {
  final regular = _regularOfferPrice(item, sizePrice: sizePrice);
  if (appOffersApply && hasAppOffer(item)) {
    final app = menuAppOfferPrice(item, sizePrice: sizePrice);
    return app < regular ? app : regular;
  }
  return regular;
}

double _regularOfferPrice(Map<String, dynamic> item, {double? sizePrice}) {
  final original = menuOriginalPrice(item, sizePrice: sizePrice);
  if (hasMenuOffer(item)) {
    return _discounted(
      original,
      item['discountType'],
      (item['discountValue'] as num).toDouble(),
    );
  }
  if (item['isPromoActive'] == true && item['offerPrice'] is num) {
    return ((item['offerPrice'] as num).toDouble())
        .clamp(0, original)
        .toDouble();
  }
  return original;
}

double _discounted(double original, Object? type, double value) {
  final result = type == 'amount'
      ? original - value
      : original * (1 - value / 100);
  return (result.clamp(0, original) * 100).round() / 100;
}

String _discountLabel(Object? type, double value) {
  if (type == 'amount') return 'CHF ${value.toStringAsFixed(2)} OFF';
  return '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}% OFF';
}

String? menuOfferLabel(Map<String, dynamic> item) {
  if (appOffersApply &&
      hasAppOffer(item) &&
      menuAppOfferPrice(item) < _regularOfferPrice(item)) {
    return appOfferLabel(item);
  }
  if (hasMenuOffer(item)) {
    return _discountLabel(
      item['discountType'],
      (item['discountValue'] as num).toDouble(),
    );
  }
  final original = menuOriginalPrice(item);
  final offer = _regularOfferPrice(item);
  if (offer < original && original > 0) {
    return '${((original - offer) / original * 100).round()}% OFF';
  }
  return null;
}

/// Whether this build is the guest phone app, the only place an app offer
/// can be ordered. The website still shows app offers on the home page, but
/// sends guests to the App Store or Play Store instead of ordering them.
bool get appOffersApply =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Whether the admin switched on an app-only offer for this menu.
/// Stored apart from the regular offer as `appOfferActive`, `appOfferType`
/// ('percent' or 'amount') and `appOfferValue`.
bool hasAppOffer(Map<String, dynamic> item) {
  return item['appOfferActive'] == true &&
      ((item['appOfferValue'] as num?)?.toDouble() ?? 0) > 0;
}

/// The price with the app offer, whichever build is asking.
double menuAppOfferPrice(Map<String, dynamic> item, {double? sizePrice}) {
  final original = menuOriginalPrice(item, sizePrice: sizePrice);
  if (!hasAppOffer(item)) return original;
  return _discounted(
    original,
    item['appOfferType'],
    (item['appOfferValue'] as num).toDouble(),
  );
}

String? appOfferLabel(Map<String, dynamic> item) {
  if (!hasAppOffer(item)) return null;
  return _discountLabel(
    item['appOfferType'],
    (item['appOfferValue'] as num).toDouble(),
  );
}

/// The menus inside a combo, trimmed to what an order line needs.
/// Stored on cart and order lines as `comboItems` so the cart, kitchen
/// tickets and bills can list what the guest actually gets.
List<Map<String, dynamic>> comboOrderItems(Map<String, dynamic> menuItem) {
  if (menuItem['itemType'] != 'combo') return const [];
  final entries = menuItem['comboItems'] as List<dynamic>? ?? const [];
  return [
    for (final e in entries)
      if (e is Map && (e['name'] ?? '').toString().trim().isNotEmpty)
        {
          'name': e['name'].toString().trim(),
          'kind': (e['itemType'] ?? 'food').toString(),
        },
  ];
}

/// Readable lines for the menus inside a combo order line, e.g.
/// `['Burger', '2x Cola']`. Repeated menus are counted once with a number.
List<String> comboLines(Map<dynamic, dynamic> orderLine) {
  final entries = orderLine['comboItems'] as List<dynamic>? ?? const [];
  final counts = <String, int>{};
  for (final e in entries) {
    final name = e is Map ? (e['name'] ?? '').toString().trim() : '';
    if (name.isNotEmpty) counts[name] = (counts[name] ?? 0) + 1;
  }
  return [
    for (final entry in counts.entries)
      entry.value > 1 ? '${entry.value}x ${entry.key}' : entry.key,
  ];
}
