import 'package:flutter/material.dart';

/// Live summary of an offer while the admin types it:
/// original price, the discount, the final price and what the customer saves.
class OfferPreview extends StatelessWidget {
  final double? Function() originalPrice;
  final String discountType;
  final TextEditingController discountValue;
  final Listenable? priceListenable;

  const OfferPreview({
    super.key,
    required this.originalPrice,
    required this.discountType,
    required this.discountValue,
    this.priceListenable,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([discountValue, ?priceListenable]),
      builder: (context, _) {
        final original = originalPrice();
        final value = double.tryParse(discountValue.text.trim()) ?? 0;
        if (original == null) {
          return _box(
            const Text(
              'The offer is applied to every size price.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }
        if (original <= 0 || value <= 0) {
          return _box(
            Text(
              original <= 0
                  ? 'Enter a price (or select menus) to preview the offer.'
                  : 'Enter the offer to preview the final price.',
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }
        final isPercent = discountType == 'percent';
        final finalPrice =
            (isPercent ? original * (1 - value / 100) : original - value)
                .clamp(0, original)
                .toDouble();
        final saved = original - finalPrice;
        final label = isPercent
            ? '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}% OFF'
            : 'CHF ${value.toStringAsFixed(2)} OFF';
        return _box(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'CHF ${original.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white54,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'CHF ${finalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFFB59410),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Customer saves CHF ${saved.toStringAsFixed(2)} • shown on the home page',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _box(Widget child) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.redAccent.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
    ),
    child: child,
  );
}
