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

/// While the Android app is in closed testing, guests join this Google group
/// and opt in as testers before the Play Store lets them install it.
const String kTesterGroupUrl = String.fromEnvironment(
  'TESTER_GROUP_URL',
  defaultValue: 'https://groups.google.com/g/restaurant-kleefeld',
);

const String kTesterOptInUrl = String.fromEnvironment(
  'TESTER_OPT_IN_URL',
  defaultValue:
      'https://play.google.com/apps/testing/ch.restaurantkleefeld.app',
);

/// Whether Android guests go through the tester steps first. Turn this off
/// with `--dart-define=PLAY_CLOSED_TESTING=false` once the app is public.
const bool kPlayClosedTesting = bool.fromEnvironment(
  'PLAY_CLOSED_TESTING',
  defaultValue: true,
);

/// App Store listing. Left without a country so Apple opens it in the
/// guest's own store (Switzerland, Germany, …).
const String kAppStoreUrl = String.fromEnvironment(
  'APP_STORE_URL',
  defaultValue: 'https://apps.apple.com/app/restaurantkleefeld/id6804714931',
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

Future<void> _openUrl(BuildContext context, String url) async {
  final launched = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(url)));
  }
}

class _AppOnlyOfferDialog extends StatelessWidget {
  final Map<String, dynamic> item;

  const _AppOnlyOfferDialog({required this.item});

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
                  onTap: () => _openUrl(context, kAppStoreUrl),
                ),
              if (showApple && showGoogle) const SizedBox(height: 10),
              if (showGoogle)
                _StoreButton(
                  icon: Icons.shop_rounded,
                  label: singleStore
                      ? AppLanguage.getText('download_app')
                      : 'Google Play',
                  onTap: () => kPlayClosedTesting
                      ? showDialog<void>(
                          context: context,
                          builder: (_) => const _PlayInstallGuide(),
                        )
                      : _openUrl(context, kPlayStoreUrl),
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

/// The three steps a guest takes to install the Android app while it is in
/// closed testing. Each step lights up once its link was opened, so the guest
/// always sees which one comes next.
class _PlayInstallGuide extends StatefulWidget {
  const _PlayInstallGuide();

  @override
  State<_PlayInstallGuide> createState() => _PlayInstallGuideState();
}

class _PlayInstallGuideState extends State<_PlayInstallGuide> {
  int _done = 0;

  static const _steps = [
    (
      url: kTesterGroupUrl,
      icon: Icons.group_add_rounded,
      title: 'install_step1_title',
      text: 'install_step1_text',
      button: 'install_step1_button',
    ),
    (
      url: kTesterOptInUrl,
      icon: Icons.verified_user_rounded,
      title: 'install_step2_title',
      text: 'install_step2_text',
      button: 'install_step2_button',
    ),
    (
      url: kPlayStoreUrl,
      icon: Icons.download_rounded,
      title: 'install_step3_title',
      text: 'install_step3_text',
      button: 'install_step3_button',
    ),
  ];

  Future<void> _openStep(int index) async {
    await _openUrl(context, _steps[index].url);
    if (mounted && _done <= index) setState(() => _done = index + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _kCardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.android_rounded, color: _kPrimary, size: 40),
              const SizedBox(height: 10),
              Text(
                AppLanguage.getText('install_guide_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _kWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppLanguage.getText('install_guide_text'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: _kMuted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              for (var i = 0; i < _steps.length; i++)
                _GuideStep(
                  number: i + 1,
                  icon: _steps[i].icon,
                  title: AppLanguage.getText(_steps[i].title),
                  text: AppLanguage.getText(_steps[i].text),
                  button: AppLanguage.getText(_steps[i].button),
                  done: i < _done,
                  current: i == _done,
                  onTap: () => _openStep(i),
                ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: _kPrimary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLanguage.getText('install_guide_tip'),
                        style: const TextStyle(color: _kWhite, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppLanguage.getText('close'),
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

class _GuideStep extends StatelessWidget {
  final int number;
  final IconData icon;
  final String title;
  final String text;
  final String button;
  final bool done;
  final bool current;
  final VoidCallback onTap;

  const _GuideStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.text,
    required this.button,
    required this.done,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = done ? Colors.greenAccent : _kPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(current ? 0.25 : 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: current || done
              ? accent.withOpacity(0.7)
              : Colors.white.withOpacity(0.08),
          width: current ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: accent,
                child: done
                    ? const Icon(Icons.check, color: Colors.black, size: 16)
                    : Text(
                        '$number',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _kWhite,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(color: _kMuted, fontSize: 12.5)),
          const SizedBox(height: 10),
          current
              ? FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onTap,
                  icon: Icon(icon, size: 18),
                  label: Text(
                    button,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                )
              : OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: done ? Colors.greenAccent : _kWhite,
                    side: BorderSide(color: accent.withOpacity(0.6)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onTap,
                  icon: Icon(done ? Icons.refresh_rounded : icon, size: 18),
                  label: Text(button),
                ),
        ],
      ),
    );
  }
}
