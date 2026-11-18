import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/pixel/pixel_scene.dart';
import 'my_catalog.dart';

/// What a finished trip earned.
class TripReward {
  const TripReward({
    required this.trip,
    required this.newStations,
    required this.firstOfDay,
    this.stamped = const [],
    this.completedLines = const [],
    this.unlocked = const [],
  });
  final int trip;
  final int newStations;
  final int firstOfDay;

  /// Stations stamped for the first time on this trip.
  final List<String> stamped;

  /// Lines whose every station is now stamped.
  final List<String> completedLines;

  /// Reward items given for those lines.
  final List<String> unlocked;

  int get total => trip + newStations + firstOfDay;
}

enum BuyResult { ok, notEnoughCoins, alreadyOwned }

/// The user's own station sign: name, reading, the stations either side
/// and the colour of the band. An empty name shows the scene's name.
@immutable
class PlateText {
  const PlateText({this.name = '', this.kana = '', this.prev = '', this.next = '', this.band});

  static const maxName = 6;
  static const maxKana = 8;
  static const maxSide = 6;

  final String name;
  final String kana;
  final String prev;
  final String next;

  /// ARGB band colour; null = the colour of the equipped train.
  final int? band;

  Map<String, dynamic> toJson() => {'name': name, 'kana': kana, 'prev': prev, 'next': next, 'band': band};

  factory PlateText.fromJson(Map<String, dynamic> j) => PlateText(
    name: cut(j['name'], maxName),
    kana: cut(j['kana'], maxKana),
    prev: cut(j['prev'], maxSide),
    next: cut(j['next'], maxSide),
    band: j['band'] as int?,
  );

  /// Trims [v] and keeps at most [max] characters (emoji count as one).
  static String cut(Object? v, int max) {
    final s = (v is String ? v : '').trim();
    final chars = s.characters;
    return chars.length > max ? chars.take(max).toString() : s;
  }

  @override
  bool operator ==(Object other) =>
      other is PlateText &&
      other.name == name &&
      other.kana == kana &&
      other.prev == prev &&
      other.next == next &&
      other.band == band;

  @override
  int get hashCode => Object.hash(name, kana, prev, next, band);
}

/// MY駅 state kept on the phone: coins, owned items, what is equipped in
/// each slot, the station sign, and the stamp book (stations visited, with
/// the day of the first visit).
class MyStore extends ChangeNotifier {
  MyStore({this.prefix = 'my'});

  final String prefix;
  MyCatalog? _catalog;
  int _coins = 0;
  final Set<String> _owned = {};
  final Map<MySlot, String> _equipped = {};
  final Map<String, String> _visited = {};
  String? _lastTripDay;
  PlateText _plate = const PlateText();

  /// Station ids of each line in the city, for line-complete rewards.
  Map<String, List<String>> lines = const {};

  MyCatalog? get catalog => _catalog;
  bool get loaded => _catalog != null;
  int get coins => _coins;
  PlateText get plate => _plate;
  bool owns(String id) => _owned.contains(id) || (_catalog?.item(id).free ?? false);
  String equipped(MySlot slot) => _equipped[slot] ?? _catalog!.defaultFor(slot);
  bool isEquipped(String id) => _catalog != null && equipped(_catalog!.item(id).slot) == id;

  /// Stamp book: station id → first visit day (yyyy-mm-dd, Japan time).
  Map<String, String> get stamps => Map.unmodifiable(_visited);
  bool stamped(String stationId) => _visited.containsKey(stationId);

  Future<void> load({MyCatalog? catalog}) async {
    _catalog = catalog ?? await MyCatalog.load();
    final prefs = await SharedPreferences.getInstance();
    _coins = prefs.getInt('$prefix.coins') ?? 0;
    _owned
      ..clear()
      ..addAll(prefs.getStringList('$prefix.owned') ?? const []);
    _visited.clear();
    for (final id in prefs.getStringList('$prefix.visited') ?? const <String>[]) {
      _visited[id] = '';
    }
    try {
      final days = jsonDecode(prefs.getString('$prefix.visitedAt') ?? '{}') as Map<String, dynamic>;
      for (final e in days.entries) {
        if (e.value is String) _visited[e.key] = e.value as String;
      }
    } catch (_) {
      // Dates are a nicety; the stamps themselves are kept above.
    }
    _lastTripDay = prefs.getString('$prefix.lastTripDay');
    _equipped.clear();
    try {
      final raw = jsonDecode(prefs.getString('$prefix.equipped') ?? '{}') as Map<String, dynamic>;
      for (final e in raw.entries) {
        final slot = MySlot.values.where((s) => s.name == e.key).firstOrNull;
        final id = e.value;
        if (slot != null && id is String && _catalog!.items.any((i) => i.id == id)) {
          _equipped[slot] = id;
        }
      }
    } catch (_) {
      // Broken saved data: start from the defaults.
    }
    try {
      _plate = PlateText.fromJson(
        jsonDecode(prefs.getString('$prefix.plate') ?? '{}') as Map<String, dynamic>,
      );
    } catch (_) {
      _plate = const PlateText();
    }
    notifyListeners();
  }

  /// Spend coins on [id]. Free and owned items need no purchase; reward
  /// items cannot be bought.
  Future<BuyResult> buyWithCoins(String id) async {
    final item = _catalog!.item(id);
    if (owns(id)) return BuyResult.alreadyOwned;
    if (item.unlock != null || _coins < item.price) return BuyResult.notEnoughCoins;
    _coins -= item.price;
    _owned.add(id);
    await _save();
    return BuyResult.ok;
  }

  /// After a successful in-app purchase of [id] (money, not coins).
  Future<void> grant(String id) async {
    _owned.add(id);
    await _save();
  }

  Future<void> addCoins(int amount) async {
    _coins += amount;
    await _save();
  }

  Future<void> equip(String id) async {
    if (!owns(id)) return;
    _equipped[_catalog!.item(id).slot] = id;
    await _save();
  }

  Future<void> setPlate(PlateText plate) async {
    _plate = PlateText.fromJson(plate.toJson());
    await _save();
  }

  /// How many stations of [lineId] are stamped.
  ({int done, int total}) lineProgress(String lineId) {
    final ids = (lines[lineId] ?? const []).toSet();
    return (done: ids.where(_visited.containsKey).length, total: ids.length);
  }

  bool lineComplete(String lineId) {
    final p = lineProgress(lineId);
    return p.total > 0 && p.done == p.total;
  }

  /// The item given for completing [lineId], if any.
  MyItem? rewardFor(String lineId) => _catalog?.items.where((i) => i.unlock == 'line:$lineId').firstOrNull;

  /// Coins for a finished trip: per trip, first visit to each station, and
  /// a small bonus for the first trip of the day (Japan time). New stations
  /// are stamped; finishing a line gives its reward item.
  Future<TripReward> rewardTrip(List<String> stationIds, {DateTime? now}) async {
    final rules = _catalog?.rules ?? const CoinRules();
    final day = (now ?? DateTime.now().toUtc().add(const Duration(hours: 9))).toIso8601String().substring(
      0,
      10,
    );
    final fresh = [
      for (final id in stationIds.toSet())
        if (!_visited.containsKey(id)) id,
    ];
    final doneBefore = {for (final l in lines.keys) l: lineComplete(l)};
    for (final id in fresh) {
      _visited[id] = day;
    }
    final completed = [
      for (final l in lines.keys)
        if (!doneBefore[l]! && lineComplete(l)) l,
    ];
    final unlocked = [for (final l in completed) ?rewardFor(l)?.id];
    _owned.addAll(unlocked);
    final reward = TripReward(
      trip: rules.perTrip,
      newStations: fresh.length * rules.firstVisit,
      firstOfDay: _lastTripDay == day ? 0 : rules.firstTripOfDay,
      stamped: fresh,
      completedLines: completed,
      unlocked: unlocked,
    );
    _lastTripDay = day;
    _coins += reward.total;
    await _save();
    return reward;
  }

  /// The picture settings for the platform header and the MY preview.
  SceneLook get look {
    final cat = _catalog;
    if (cat == null) return const SceneLook();
    final scene = cat.item(equipped(MySlot.scene));
    final deco = [
      cat.item(equipped(MySlot.roof)),
      cat.item(equipped(MySlot.platform)),
      cat.item(equipped(MySlot.effect)),
    ];
    return SceneLook(
      images: scene.images,
      overlays: [for (final d in deco) ?d.overlay],
      effects: {for (final d in deco) ?d.effect},
      trainColor: cat.item(equipped(MySlot.train)).color,
    );
  }

  /// Look of the equipped station sign.
  PlateStyle get plateStyle {
    final cat = _catalog;
    if (cat == null) return PlateStyle.basic;
    return cat.item(equipped(MySlot.plate)).plate ?? PlateStyle.basic;
  }

  /// The scene of [stationId] in the shop, if there is one.
  MyItem? sceneForStation(String? stationId) {
    if (stationId == null || _catalog == null) return null;
    return _catalog!.items.where((i) => i.slot == MySlot.scene && i.station == stationId).firstOrNull;
  }

  /// Look for のりば when leaving from [stationId]: that station's own scene
  /// when the user owns it, otherwise the equipped one. Decorations, train
  /// and LED colour stay as equipped.
  SceneLook lookFor(String? stationId) {
    final base = look;
    final scene = sceneForStation(stationId);
    if (scene == null || !owns(scene.id)) return base;
    return SceneLook(
      images: scene.images,
      overlays: base.overlays,
      effects: base.effects,
      trainColor: base.trainColor,
      led: base.led,
      ledColors: base.ledColors,
    );
  }

  /// The equipped station scene; its name is shown when the sign has none.
  MyItem? get sceneItem => _catalog?.item(equipped(MySlot.scene));

  Future<void> _save() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$prefix.coins', _coins);
    await prefs.setStringList('$prefix.owned', _owned.toList());
    await prefs.setStringList('$prefix.visited', _visited.keys.toList());
    await prefs.setString('$prefix.visitedAt', jsonEncode(_visited));
    if (_lastTripDay != null) await prefs.setString('$prefix.lastTripDay', _lastTripDay!);
    await prefs.setString(
      '$prefix.equipped',
      jsonEncode({for (final e in _equipped.entries) e.key.name: e.value}),
    );
    await prefs.setString('$prefix.plate', jsonEncode(_plate.toJson()));
  }
}
