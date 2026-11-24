import 'dart:ui' show Brightness;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the app looks and behaves (設定): light or dark, less movement, sound.
///
/// The colours are plain values read while widgets build
/// (PixelColors in core/pixel/pixel_ui.dart), so a change of look rebuilds the
/// whole app from the top (lib/app.dart): [restart] counts those rebuilds.
class AppLook {
  static const lookKey = 'settings.look';
  static const motionKey = 'settings.reduceMotion';
  static const soundKey = 'settings.sound';

  /// 'system' follows the phone; 'light' and 'dark' hold one look.
  static const looks = ['system', 'light', 'dark'];
  static final ValueNotifier<String> look = ValueNotifier<String>('system');

  /// Less movement: pictures stay on their first frame, effects stand still
  /// (also saves battery).
  static final ValueNotifier<bool> reduceMotion = ValueNotifier<bool>(false);

  /// The arrival sound and the departure melody.
  static final ValueNotifier<bool> sound = ValueNotifier<bool>(true);

  /// Goes up each time the app must be built again from the top: a new look,
  /// or all data deleted.
  static final ValueNotifier<int> restart = ValueNotifier<int>(0);

  /// While above zero (a trip is on screen) the phone turning dark or light
  /// by itself does not rebuild the app: the trip would be lost. The look
  /// follows once the trip is over.
  static int _holds = 0;
  static bool _waiting = false;
  static void hold() => _holds++;
  static void release() {
    if (_holds > 0) _holds--;
    if (_holds == 0 && _waiting) {
      _waiting = false;
      restart.value++;
    }
  }

  /// The phone's own look changed. Rebuilds now, or after the trip.
  static void phoneLookChanged() {
    if (look.value != 'system') return;
    if (_holds > 0) {
      _waiting = true;
    } else {
      restart.value++;
    }
  }

  static bool darkFor(Brightness phone) => switch (look.value) {
    'dark' => true,
    'light' => false,
    _ => phone == Brightness.dark,
  };

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(lookKey);
      look.value = looks.contains(saved) ? saved! : 'system';
      reduceMotion.value = prefs.getBool(motionKey) ?? false;
      sound.value = prefs.getBool(soundKey) ?? true;
    } catch (_) {
      // Storage not ready: the defaults.
    }
  }

  static Future<void> setLook(String value) async {
    if (!looks.contains(value) || value == look.value) return;
    look.value = value;
    restart.value++;
    await _save((p) => p.setString(lookKey, value));
  }

  static Future<void> setReduceMotion(bool value) async {
    reduceMotion.value = value;
    await _save((p) => p.setBool(motionKey, value));
  }

  static Future<void> setSound(bool value) async {
    sound.value = value;
    await _save((p) => p.setBool(soundKey, value));
  }

  static Future<void> _save(Future<bool> Function(SharedPreferences) write) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (_) {
      // Not saved: the choice still holds until the app closes.
    }
  }
}
