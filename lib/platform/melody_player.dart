import 'dart:async';

import 'package:flutter/services.dart';

/// Departure melodies, played natively (android/.../MelodyPlayer.kt; iPhone:
/// ios/Runner/AppDelegate.swift).
/// Nothing plays on silent / vibrate unless [force] (a preview the user asked
/// for in MY).
class MelodyPlayer {
  const MelodyPlayer();

  static const _channel = MethodChannel('tsugiwa/sound');

  Future<void> play(String asset, {bool force = false}) => _call('play', {'asset': asset, 'force': force});

  Future<void> stop() {
    _then?.cancel();
    return _call('stop', null);
  }

  /// The quiet sound of the train pulling in (tools/make_arrival_sound.py),
  /// timed to the のりば arrival animation.
  static const arrivalSound = 'assets/sounds/arrive.wav';

  /// When the train has stopped in that animation: the melody starts then.
  static const melodyAfterArrival = Duration(milliseconds: 4100);

  static Timer? _then;

  /// The train pulls in: its arrival sound, then [melody] (if any) once it
  /// has stopped. A new arrival cancels the melody still waiting.
  void arrive(String? melody) {
    _then?.cancel();
    play(arrivalSound);
    if (melody != null) _then = Timer(melodyAfterArrival, () => play(melody));
  }

  Future<void> _call(String method, Object? args) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // Tests and platforms without the native part.
    } on PlatformException {
      // A melody must never break anything.
    }
  }
}
