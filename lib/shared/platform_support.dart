// lib/shared/platform_support.dart
//
// What the build in front of us can actually do.

import 'package:flutter/foundation.dart';

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
