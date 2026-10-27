// lib/user/app_offer_dialog.dart
//
// What the website shows when a guest taps an offer that only the app gives.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:restorant/shared/menu_offer.dart';
import '../language.dart';

/// Play Store listing, from the Android application id.
const String kPlayStoreUrl = String.fromEnvironment(
  'PLAY_STORE_URL',
  defaultValue:
      'https://play.google.com/store/apps/details?id=ch.restaurantkleefeld.app',
);

/// App Store listing. Set this to the app's page (https://apps.apple.com/app/id…)
/// once it is published; until then guests land on an App Store search.
const String kAppStoreUrl = String.fromEnvironment(
  'APP_STORE_URL',
  defaultValue: 'https://apps.apple.com/ch/search?term=Restaurant%20Kleefeld',
);

const _kPrimary = Color(0xFFB59410);
const _kCardBg = Color(0xFF1A3822);
const _kWhite = Color(0xFFF7F7F2);
const _kMuted = Color(0xFFA1B3A1);
const _kDiscount = Color(0xFFE0483E);

/// Tells the guest the offer is only in the app and links to the store for
/// their phone (both stores on a computer). Resolves to true when the guest
/// chose to order the menu here at the regular price instead.
Future<bool> showAppOnlyOfferDialog(
  BuildContext context,
  Map<String, dynamic> item,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _AppOnlyOfferDialog(item: item),
  );
  return result ?? false;
}

class _AppOnlyOfferDialog extends StatelessWidget {
  final Map<String, dynamic> item;

  const _AppOnlyOfferDialog({required this.item});

  Future<void> _open(BuildContext context, String url) async {
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(url)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (item['name'] ?? '').toString();
    final original = menuOriginalPrice(item);
    final offer = menuAppOfferPrice(item);
    final label = appOfferLabel(item);
    // On the web this follows the browser, so an iPhone gets the App Store
    // and an Android phone the Play Store.
    final platform = defaultTargetPlatform;
    final showApple = platform != TargetPlatform.android;
    final showGoogle = platform != TargetPlatform.iOS;
    final singleStore = showApple != showGoogle;

    return Dialog(
      backgroundColor: _kCardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone_iphone_rounded,
                  color: _kPrimary,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLanguage.getText('app_offer_only_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _kWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLanguage.getText('app_offer_only_text'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: _kMuted, fontSize: 14),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _kWhite,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(
                          'CHF ${offer.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: _kPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (original > offer)
                          Text(
                            'CHF ${original.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: _kMuted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        if (label != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _kDiscount,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (showApple)
                _StoreButton(
                  icon: Icons.apple,
                  label: singleStore
                      ? AppLanguage.getText('download_app')
                      : 'App Store',
                  onTap: () => _open(context, kAppStoreUrl),
                ),
              if (showApple && showGoogle) const SizedBox(height: 10),
              if (showGoogle)
                _StoreButton(
                  icon: Icons.shop_rounded,
                  label: singleStore
                      ? AppLanguage.getText('download_app')
                      : 'Google Play',
                  onTap: () => _open(context, kPlayStoreUrl),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  AppLanguage.getText('order_regular_price'),
                  style: const TextStyle(color: _kMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _StoreButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: _kPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
    );
  }
}
