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
    this.headMark,
    this.skyArt,
    this.led = const [],
    this.ledColors = const [ledOrange],
    this.sign,
    this.underground = false,
  });

  /// The departure line is underground at this station: the built-in scene
  /// becomes the subway platform (no sky, no weather, lights always on). A
  /// station scene the user chose ([images]) stays as it is.
  final bool underground;

  /// Equipped train with its own pictures (folder), null = the usual train.
  final String? trainArt;

  /// A head mark (ヘッドマーク) on the train's face: a small round plate.
  final String? headMark;

  /// Something floating in the sky (a hot-air balloon): its picture; a
  /// smaller one further away is `<name>_far.png` next to it.
  final String? skyArt;

  /// Scene picture per time of day. Empty = the built-in animated scene.
  /// A missing time of day falls back to another picture, colour-graded.
  final Map<DayPart, String> images;

  /// Decoration layers, same size as the scene (transparent elsewhere).
  final List<String> overlays;

  /// Drawn effects: 'petals', 'fireflies', 'snow', 'leaves', 'bubbles', 'garland'
  /// and the later ones in scene_ambience.dart ('confetti', 'planes', …).
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
    headMark: headMark,
    skyArt: skyArt,
    led: pages,
    ledColors: colors,
    sign: sign,
    underground: underground,
  );

  SceneLook withSign(StationSign? s) => SceneLook(
    images: images,
    overlays: overlays,
    effects: effects,
    trainColor: trainColor,
    trainArt: trainArt,
    headMark: headMark,
    skyArt: skyArt,
    led: led,
    ledColors: ledColors,
    sign: s,
    underground: underground,
  );

  /// [overScene]: the subway platform also replaces the equipped scene
  /// (a scene bought for this very station still wins: pass false).
  SceneLook withUnderground(bool value, {bool overScene = false}) => value == underground && !(value && overScene)
      ? this
      : SceneLook(
          images: value && overScene ? const {} : images,
          overlays: overlays,
          effects: effects,
          trainColor: trainColor,
          trainArt: trainArt,
          headMark: headMark,
          skyArt: skyArt,
          led: led,
          ledColors: ledColors,
          sign: sign,
          underground: value,
        );

  /// The subway platform is shown (see [underground]).
  bool get showsUnderground => underground && images.isEmpty;

  String get key => [
    for (final e in images.entries) '${e.key.name}=${e.value}',
    ...overlays,
    ...effects,
    trainColor?.toARGB32() ?? '',
    'train=${trainArt ?? ''}',
    'mark=${headMark ?? ''}',
    'sky=${skyArt ?? ''}',
    'led=${led.join('/')}',
    'sign=${sign?.name}/${sign?.sub}/${sign?.band.toARGB32()}',
    for (final c in ledColors) c.toARGB32(),
    if (underground) 'underground',
  ].join('|');

  @override
  bool operator ==(Object other) => other is SceneLook && other.key == key;

  @override
  int get hashCode => key.hashCode;
}
