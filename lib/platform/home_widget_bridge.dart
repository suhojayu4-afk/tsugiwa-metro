import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/pixel/pixel_scene.dart';

/// The MY station on the phone's home screen. Dart draws the station (one
/// picture per time of day, sign included); the native widget picks the
/// picture for the current hour and shows the last weather.
abstract class HomeWidgetBridge {
  Future<void> setPictures(Map<DayPart, Uint8List> pngs);
  Future<void> setWeather(String text);

  /// Today's information for both widgets (texts already localized):
  /// weather, rain, wet, route, line, lineColor, lastLabel, lastTime,
  /// firstLabel, firstTime, alarm.
  Future<void> setInfo(Map<String, Object?> info);

  /// Pictures for つぎの電車: 'full_5' (one per interval), 'full_end'.
  Future<void> setNextArt(Map<String, Uint8List> pngs);

  /// Ask the launcher to add the widget. False when it cannot (then the
  /// user adds it from the widget list).
  /// [kind]: 'my' (MY駅), 'board' (地下鉄案内) or 'next' (つぎの電車).
  Future<bool> requestPin({String kind = 'my'});
}

class NoHomeWidget implements HomeWidgetBridge {
  const NoHomeWidget();
  @override
  Future<void> setPictures(Map<DayPart, Uint8List> pngs) async {}
  @override
  Future<void> setWeather(String text) async {}
  @override
  Future<void> setInfo(Map<String, Object?> info) async {}
  @override
  Future<void> setNextArt(Map<String, Uint8List> pngs) async {}
  @override
  Future<bool> requestPin({String kind = 'my'}) async => false;
}

/// Android: "tsugiwa/widget" channel, handled in MainActivity / MyStationWidget.
class MethodChannelHomeWidget implements HomeWidgetBridge {
  MethodChannelHomeWidget([this._channel = const MethodChannel('tsugiwa/widget')]);
  final MethodChannel _channel;

  bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> setPictures(Map<DayPart, Uint8List> pngs) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('pictures', {for (final e in pngs.entries) e.key.name: e.value});
    } on PlatformException catch (e) {
      debugPrint('home widget: $e');
    } on MissingPluginException {
      // Not built with the widget (tests, other platforms).
    }
  }

  @override
  Future<void> setWeather(String text) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('weather', {'text': text});
    } on PlatformException catch (e) {
      debugPrint('home widget: $e');
    } on MissingPluginException {
      // Not built with the widget.
    }
  }

  @override
  Future<void> setInfo(Map<String, Object?> info) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('info', info);
    } on PlatformException catch (e) {
      debugPrint('home widget: $e');
    } on MissingPluginException {
      // Not built with the widget.
    }
  }

  @override
  Future<void> setNextArt(Map<String, Uint8List> pngs) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('nextArt', pngs);
    } on PlatformException catch (e) {
      debugPrint('home widget: $e');
    } on MissingPluginException {
      // Not built with the widget.
    }
  }

  @override
  Future<bool> requestPin({String kind = 'my'}) async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('pin', {'kind': kind}) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

/// Redraws the widget pictures when MY駅 changes, at most once per
/// [delay] (the user may tap several items in a row).
class HomeWidgetSync {
  HomeWidgetSync({
    required this.bridge,
    required this.listenable,
    required this.render,
    this.delay = const Duration(seconds: 2),
  });

  final HomeWidgetBridge bridge;
  final Listenable listenable;

  /// Draws the station for one time of day.
  final Future<Uint8List> Function(DayPart part) render;
  final Duration delay;

  Timer? _timer;
  String? _lastKey;
  VoidCallback? _changed;

  /// [key] describes what the pictures show; nothing is redrawn while it
  /// stays the same.
  void start(String Function() key) {
    void changed() {
      final k = key();
      if (k.isEmpty || k == _lastKey) return;
      _timer?.cancel();
      _timer = Timer(delay, () async {
        _lastKey = k;
        try {
          final pngs = {for (final part in DayPart.values) part: await render(part)};
          await bridge.setPictures(pngs);
        } catch (e) {
          _lastKey = null;
          debugPrint('home widget render: $e');
        }
      });
    }

    _changed = changed;
    listenable.addListener(changed);
    changed();
  }

  void dispose() {
    _timer?.cancel();
    if (_changed != null) listenable.removeListener(_changed!);
  }
}
