// lib/shared/platform_support.dart
//
// What the build in front of us can actually do.

import 'package:flutter/foundation.dart';

/// Whether this build is the guest app only.
///
/// The app published to the App Store is for guests: browsing the menu,
/// ordering at a table and booking one. The admin panel, the Kitchen and Bar
/// boards and the Service board are staff tools that stay on the website, so a
/// store build leaves them out entirely - their routes are not even
/// registered, and signing in as staff lands on the guest app.
///
/// Web keeps everything. A phone build can be given the full app with
/// `--dart-define=CUSTOMER_ONLY=false`.
const bool kCustomerOnlyBuild = bool.fromEnvironment(
  'CUSTOMER_ONLY',
  defaultValue: !kIsWeb,
);

/// Whether a camera QR scanner can be shown.
///
/// mobile_scanner ships no Windows implementation, so the desktop till build
/// offers typing the chair number instead of scanning it. Asking here rather
/// than at each call site keeps that decision in one place.
bool get supportsCameraScanner =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;
