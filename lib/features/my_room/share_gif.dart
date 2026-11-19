import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';

import '../../core/pixel/pixel_scene.dart';
import '../../data/weather/weather_source.dart';

/// The moving share card: the still card, with its station picture replaced
/// frame by frame by the train pulling in and the passengers getting on,
/// and the stickers on top. Encoded as a looping GIF away from the UI thread.
///
/// [card] and [stickers] are the card and its sticker layer captured at
/// [pixelRatio] (both the card's size); [scene] is where the station picture
/// sits on the card (logical pixels), drawn with [aspect] and [radius].
Future<Uint8List> buildShareGif({
  required ui.Image card,
  required ui.Image? stickers,
  required double pixelRatio,
  required Rect scene,
  required double aspect,
  required double radius,
  required SceneLook look,
  required Color lineColor,
  DayPart? part,
  WeatherKind weather = WeatherKind.sunny,
  String? sky,
}) async {
  final w = card.width, h = card.height;
  final now = part ?? dayPartOf(DateTime.now().toUtc().add(const Duration(hours: 9)));
  // Which part of the 384×192 picture shows in the card, as in the app.
  final view = SceneView.fit(scene.width, pixelRatio, aspect: aspect);
  const artScale = 3;
  final src = Rect.fromLTWH(
    view.src.left * artScale,
    view.src.top * artScale,
    view.src.width * artScale,
    view.src.height * artScale,
  );
  final dst = Rect.fromLTWH(
    scene.left * pixelRatio,
    scene.top * pixelRatio,
    scene.width * pixelRatio,
    scene.height * pixelRatio,
  );
  final clip = RRect.fromRectAndRadius(dst, Radius.circular(radius * pixelRatio));

  // Pulling in (4.6 s), then the door (3.6 s), then a moment at rest.
  final steps = <({double arrive, double platform, int cs})>[
    for (var i = 0; i <= 22; i++) (arrive: i / 22, platform: 0, cs: 20),
    for (var i = 1; i <= 11; i++) (arrive: 1, platform: i / 11, cs: 33),
    (arrive: 1, platform: 0, cs: 150),
  ];
  final frames = <Uint8List>[];
  final delays = <int>[];
  final crisp = Paint()..filterQuality = FilterQuality.none;
  for (final s in steps) {
    final pic = await renderSceneImage(
      look: look,
      part: now,
      lineColor: lineColor,
      weather: weather,
      sky: sky,
      scale: artScale,
      arrive: s.arrive,
      platform: s.platform,
    );
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawImage(card, Offset.zero, Paint());
    c.save();
    c.clipRRect(clip);
    c.drawImageRect(pic, src, dst, crisp);
    c.restore();
    if (stickers != null) c.drawImage(stickers, Offset.zero, Paint());
    final frame = await rec.endRecording().toImage(w, h);
    pic.dispose();
    final rgba = await frame.toByteData(format: ui.ImageByteFormat.rawRgba);
    frame.dispose();
    frames.add(rgba!.buffer.asUint8List());
    delays.add(s.cs);
  }
  return compute(_encode, (w: w, h: h, frames: frames, delays: delays));
}

Uint8List _encode(({int w, int h, List<Uint8List> frames, List<int> delays}) a) {
  // Octree colour reduction: much quicker than the default on a phone.
  final enc = img.GifEncoder(repeat: 0, quantizerType: img.QuantizerType.octree);
  for (var i = 0; i < a.frames.length; i++) {
    final f = img.Image.fromBytes(width: a.w, height: a.h, bytes: a.frames[i].buffer, numChannels: 4);
    enc.addFrame(f, duration: a.delays[i]);
  }
  return enc.finish()!;
}
