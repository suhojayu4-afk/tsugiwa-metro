import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/localized_text.dart';
import '../core/pixel/pixel_scene.dart';

/// Where an item goes in MY駅.
enum MySlot { scene, plate, train, roof, platform, effect, melody, sticker }

class MyItem {
  const MyItem({
    required this.id,
    required this.slot,
    required this.name,
    required this.price,
    this.priceYen,
    this.images = const {},
    this.overlay,
    this.effect,
    this.color,
    this.plate,
    this.unlock,
    this.station,
    this.sound,
    this.art,
    this.stickers = const [],
  });

  /// Sticker packs: the stickers in it (assets/art/stickers/{name}.png).
  final List<String> stickers;

  /// Train items with their own shape: folder of pictures (front_*, side_*).
  final String? art;

  final String id;
  final MySlot slot;
  final LocalizedText name;

  /// Price in coins; 0 = free from the start.
  final int price;

  /// Can also be bought straight away with money (in-app purchase), in yen.
  final int? priceYen;

  /// Station scene pictures per time of day (scene items only).
  final Map<DayPart, String> images;
  final String? overlay;
  final String? effect;
  final Color? color;

  /// Destination LED colour (plate items only).
  final PlateStyle? plate;

  /// Not sold: given for an achievement, e.g. `line:tokyo.ginza` = every
  /// station of the Ginza Line stamped.
  final String? unlock;

  /// Scene items: the station this scene shows (`tokyo.shibuya`). When you
  /// leave from that station, のりば shows this scene if you own it.
  final String? station;

  /// Melody items: the departure melody played when the train pulls in.
  final String? sound;

  bool get free => price == 0 && priceYen == null && unlock == null;

  static Color? _color(String? hex) => hex == null ? null : Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);

  factory MyItem.fromJson(Map<String, dynamic> j) => MyItem(
    id: j['id'] as String,
    slot: MySlot.values.byName(j['slot'] as String),
    name: LocalizedText.fromJson(j['name'] as Map<String, dynamic>),
    price: j['price'] as int? ?? 0,
    priceYen: j['priceYen'] as int?,
    images: {
      for (final e in (j['images'] as Map<String, dynamic>? ?? const {}).entries)
        DayPart.values.byName(e.key): e.value as String,
    },
    overlay: j['overlay'] as String?,
    effect: j['effect'] as String?,
    color: _color(j['color'] as String?),
    plate: j['plate'] == null ? null : PlateStyle.fromJson(j['plate'] as Map<String, dynamic>),
    unlock: j['unlock'] as String?,
    station: j['station'] as String?,
    sound: j['sound'] as String?,
    art: j['art'] as String?,
    stickers: List<String>.from(j['stickers'] as List? ?? const []),
  );
}

/// Colour of the destination LED on the train.
class PlateStyle {
  const PlateStyle({this.colors = const [Color(0xFFFFAA3C)]});

  /// One colour, or several that change with each LED page.
  final List<Color> colors;

  static const basic = PlateStyle();

  factory PlateStyle.fromJson(Map<String, dynamic> j) {
    final list = [for (final c in (j['led'] as List? ?? const [])) ?MyItem._color(c as String)];
    return list.isEmpty ? basic : PlateStyle(colors: list);
  }
}

class CoinPack {
  const CoinPack(this.id, this.coins, this.priceYen);
  final String id;
  final int coins;
  final int priceYen;
}

class CoinRules {
  const CoinRules({this.perTrip = 10, this.firstVisit = 20, this.firstTripOfDay = 5});
  final int perTrip;
  final int firstVisit;
  final int firstTripOfDay;
}

/// Everything MY駅 sells (assets/my/catalog.json). Prices live in that one
/// file so they can be tuned without touching code.
class MyCatalog {
  const MyCatalog({required this.items, required this.packs, required this.rules});

  final List<MyItem> items;
  final List<CoinPack> packs;
  final CoinRules rules;

  MyItem item(String id) => items.firstWhere((i) => i.id == id);
  List<MyItem> inSlot(MySlot slot) => [
    for (final i in items)
      if (i.slot == slot) i,
  ];

  /// The item each slot starts with (the first free one).
  String defaultFor(MySlot slot) => inSlot(slot).firstWhere((i) => i.free).id;

  factory MyCatalog.fromJson(Map<String, dynamic> j) {
    final r = j['coinRules'] as Map<String, dynamic>? ?? const {};
    return MyCatalog(
      items: [for (final i in (j['items'] as List).cast<Map<String, dynamic>>()) MyItem.fromJson(i)],
      packs: [
        for (final p in (j['coinPacks'] as List? ?? const []).cast<Map<String, dynamic>>())
          CoinPack(p['id'] as String, p['coins'] as int, p['priceYen'] as int),
      ],
      rules: CoinRules(
        perTrip: r['perTrip'] as int? ?? 10,
        firstVisit: r['firstVisit'] as int? ?? 20,
        firstTripOfDay: r['firstTripOfDay'] as int? ?? 5,
      ),
    );
  }

  static Future<MyCatalog>? _cache;

  /// Tests: forget the loaded catalog (each test has its own asset bundle).
  @visibleForTesting
  static void resetCache() => _cache = null;
  static Future<MyCatalog> load() => _cache ??= rootBundle
      .loadString('assets/my/catalog.json')
      .then((s) => MyCatalog.fromJson(jsonDecode(s) as Map<String, dynamic>));
}
