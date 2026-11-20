part of 'pixel_scene.dart';

/// What the user made of their station in MY: which station scene, the
/// decorations on it and the colour of their train.
@immutable
class SceneLook {
  const SceneLook({
    this.images = const {},
    this.overlays = const [],
    this.effects = const {},
    this.trainColor,
    this.trainArt,
    this.led = const [],
    this.ledColors = const [ledOrange],
    this.sign,
  });

  /// Equipped train with its own pictures (folder), null = the usual train.
  final String? trainArt;

  /// Scene picture per time of day. Empty = the built-in animated scene.
  /// A missing time of day falls back to another picture, colour-graded.
  final Map<DayPart, String> images;

  /// Decoration layers, same size as the scene (transparent elsewhere).
  final List<String> overlays;

  /// Drawn effects: 'petals', 'fireflies', 'garland'.
  final Set<String> effects;

  /// Equipped train colour; null = the colour of the line being used.
  final Color? trainColor;

  /// Pages shown in turn on the train's destination LED (name, reading…).
  /// Empty = the LED stays dark.
  final List<String> led;

  /// LED colour; more than one = the colour changes with each page.
  final List<Color> ledColors;

  /// The station sign hanging from the platform roof (駅名標): the name,
  /// a small second line (English or reading) and the line colour band.
  final StationSign? sign;

  SceneLook withLed(List<String> pages, List<Color> colors) => SceneLook(
    images: images,
    overlays: overlays,
    effects: effects,
    trainColor: trainColor,
    trainArt: trainArt,
    led: pages,
    ledColors: colors,
    sign: sign,
  );

  SceneLook withSign(StationSign? s) => SceneLook(
    images: images,
    overlays: overlays,
    effects: effects,
    trainColor: trainColor,
    trainArt: trainArt,
    led: led,
    ledColors: ledColors,
    sign: s,
  );

  String get key => [
    for (final e in images.entries) '${e.key.name}=${e.value}',
    ...overlays,
    ...effects,
    trainColor?.toARGB32() ?? '',
    'train=${trainArt ?? ''}',
    'led=${led.join('/')}',
    'sign=${sign?.name}/${sign?.sub}/${sign?.band.toARGB32()}',
    for (final c in ledColors) c.toARGB32(),
  ].join('|');

  @override
  bool operator ==(Object other) => other is SceneLook && other.key == key;

  @override
  int get hashCode => key.hashCode;
}
