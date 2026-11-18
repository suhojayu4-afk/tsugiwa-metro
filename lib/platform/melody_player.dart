import 'package:flutter/services.dart';

/// Departure melodies, played natively (android/.../MelodyPlayer.kt).
/// Nothing plays on silent / vibrate unless [force] (a preview the user asked
/// for in MY).
class MelodyPlayer {
  const MelodyPlayer();

  static const _channel = MethodChannel('tsugiwa/sound');

  Future<void> play(String asset, {bool force = false}) => _call('play', {'asset': asset, 'force': force});

  Future<void> stop() => _call('stop', null);

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
