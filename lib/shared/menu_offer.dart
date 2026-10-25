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
  final original = menuOriginalPrice(item, sizePrice: sizePrice);
  if (hasMenuOffer(item)) {
    final value = (item['discountValue'] as num).toDouble();
    final result = item['discountType'] == 'amount'
        ? original - value
        : original * (1 - value / 100);
    return (result.clamp(0, original) * 100).round() / 100;
  }
  if (item['isPromoActive'] == true && item['offerPrice'] is num) {
    return ((item['offerPrice'] as num).toDouble())
        .clamp(0, original)
        .toDouble();
  }
  return original;
}

String? menuOfferLabel(Map<String, dynamic> item) {
  if (hasMenuOffer(item)) {
    final value = (item['discountValue'] as num).toDouble();
    if (item['discountType'] == 'amount') {
      return 'CHF ${value.toStringAsFixed(2)} OFF';
    }
    return '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}% OFF';
  }
  final original = menuOriginalPrice(item);
  final offer = menuOfferPrice(item);
  if (offer < original && original > 0) {
    return '${((original - offer) / original * 100).round()}% OFF';
  }
  return null;
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
