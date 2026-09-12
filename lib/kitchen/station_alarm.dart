// lib/kitchen/station_alarm.dart
//
// The alert that keeps sounding on the Kitchen/Bar boards while an order is
// still waiting to be started.
//
// Two details matter for it to keep sounding when the browser is minimised or
// the tab is in the background:
//
//  * The loop is handled by the media element itself (`ReleaseMode.loop`), not
//    by a Dart timer. Browsers heavily throttle timers in hidden tabs, so a
//    "replay every N seconds" timer would stutter or stop; native media
//    playback is not throttled.
//  * Nothing pauses playback on visibility changes.
//
// The browser still refuses to start audio without a user gesture, so
// [autoplayBlocked] tells the UI to offer a one-tap "enable sound" button.
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class StationAlarm {
  StationAlarm({required this.assetPath});

  /// Path relative to the assets folder (AudioPlayer prefixes 'assets/').
  final String assetPath;

  final AudioPlayer _player = AudioPlayer();

  bool _wantsSound = false;
  bool _playing = false;
  bool _muted = false;

  /// Set when the browser refused to start playback because there has been no
  /// user gesture yet. The UI turns this into a "tap to enable" prompt.
  final ValueNotifier<bool> autoplayBlocked = ValueNotifier<bool>(false);

  bool get isMuted => _muted;
  bool get isPlaying => _playing;

  Future<void> init() async {
    // Loop natively and never let the player be released between loops.
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(1.0);
  }

  /// Called whenever the number of waiting orders changes.
  Future<void> setAlerting(bool shouldAlert) async {
    _wantsSound = shouldAlert;
    if (shouldAlert) {
      await _resume();
    } else {
      await _halt();
      // A fresh alert should try again even if an earlier attempt was blocked.
      autoplayBlocked.value = false;
    }
  }

  Future<void> setMuted(bool muted) async {
    _muted = muted;
    if (muted) {
      await _halt();
    } else {
      await _resume();
    }
  }

  /// Retries playback from a real user gesture, which is what the browser
  /// wants before it will let a page make noise.
  Future<void> enableFromUserGesture() async {
    autoplayBlocked.value = false;
    await _resume();
  }

  Future<void> _resume() async {
    if (!_wantsSound || _muted || _playing) return;
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource(assetPath));
      _playing = true;

      // A browser that refuses autoplay rejects its internal play() promise
      // without that surfacing here, which would leave the screen showing an
      // alert while staying silent. Confirm the audio actually moved.
      if (!await _confirmStarted()) {
        _playing = false;
        autoplayBlocked.value = true;
        return;
      }
      autoplayBlocked.value = false;
    } catch (e) {
      // Almost always the browser's autoplay policy (NotAllowedError).
      _playing = false;
      autoplayBlocked.value = true;
      debugPrint('Station alarm could not start: $e');
    }
  }

  /// True once playback position has actually advanced. Polls briefly, because
  /// the first position reading can legitimately be zero while the file is
  /// still being decoded.
  Future<bool> _confirmStarted() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!_wantsSound || _muted) return false;
      final position = await _player.getCurrentPosition();
      if (position != null && position > Duration.zero) return true;
    }
    debugPrint('Station alarm stayed silent - browser blocked playback.');
    return false;
  }

  Future<void> _halt() async {
    if (!_playing) return;
    _playing = false;
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('Station alarm could not stop: $e');
    }
  }

  Future<void> dispose() async {
    _wantsSound = false;
    await _halt();
    autoplayBlocked.dispose();
    await _player.dispose();
  }
}
