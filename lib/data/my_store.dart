import 'dart:convert';
import 'dart:math' as math;

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

/// One finished trip, for the monthly ride report on the share card.
@immutable
class TripLog {
  const TripLog({required this.day, required this.minute, required this.stations, this.lines = const []});

  factory TripLog.fromJson(Map<String, dynamic> j) => TripLog(
    day: j['d'] as String,
    minute: (j['m'] as num).toInt(),
    stations: List<String>.from(j['s'] as List),
    lines: List<String>.from(j['l'] as List? ?? const []),
  );

  /// yyyy-mm-dd and minutes after midnight, Japan time (when it ended).
  final String day;
  final int minute;

  /// Every station passed, in order, and the lines ridden.
  final List<String> stations;
  final List<String> lines;

  Map<String, dynamic> toJson() => {'d': day, 'm': minute, 's': stations, 'l': lines};
}

/// What a friend's invite code did.
enum InviteResult { ok, own, used, invalid }

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

/// Test builds only (`--dart-define=TSUGIWA_UNLIMITED_COINS=true`, see
/// codemagic.yaml): coins never run out. Off in normal builds.
const unlimitedCoins = bool.fromEnvironment('TSUGIWA_UNLIMITED_COINS');
const unlimitedCoinsShown = 999999;

/// MY駅 state kept on the phone: coins, owned items, what is equipped in
/// each slot, the station sign, and the stamp book (stations visited, with
/// the day of the first visit).
class MyStore extends ChangeNotifier {
  MyStore({this.prefix = 'my', this.unlimited = unlimitedCoins});

  final String prefix;

  /// Test builds: coins never run out (buying costs nothing).
  final bool unlimited;
  MyCatalog? _catalog;
  int _coins = 0;
  final Set<String> _owned = {};
  final Map<MySlot, String> _equipped = {};
  final Map<String, String> _visited = {};

  /// Stations where the user really stayed 5 minutes (gold stamps).
  final Set<String> _stayed = {};
  String? _lastTripDay;
  PlateText _plate = const PlateText();
  final List<TripLog> _trips = [];
  String _invite = '';
  bool _inviteUsed = false;

  /// Coins for entering a friend's invite code (once).
  static const inviteCoins = 300;

  /// Trips kept for the ride report.
  static const _keepTrips = 400;

  /// Station ids of each line in the city, for line-complete rewards.
  Map<String, List<String>> lines = const {};

  /// The city's own station picture per time of day (Tottori: the country
  /// station). The station scenes in the shop are Tokyo's, so outside Tokyo
  /// this picture is shown whatever scene is equipped. Empty = Tokyo.
  Map<DayPart, String> cityScene = const {};

  /// The city shown ('tokyo', 'tottori'): a station scene bought for one of
  /// its stations is shown there instead of [cityScene].
  String cityId = 'tokyo';

  /// The city's own train pictures (Tottori: the diesel railcar), used while
  /// the equipped train has none of its own. Null = the standard train.
  String? cityTrainArt;

  MyCatalog? get catalog => _catalog;
  bool get loaded => _catalog != null;
  int get coins => unlimited ? unlimitedCoinsShown : _coins;
  PlateText get plate => _plate;
  bool owns(String id) => _owned.contains(id) || (_catalog?.item(id).free ?? false);
  String equipped(MySlot slot) => _equipped[slot] ?? _catalog!.defaultFor(slot);
  bool isEquipped(String id) => _catalog != null && equipped(_catalog!.item(id).slot) == id;

  /// Stamp book: station id → first visit day (yyyy-mm-dd, Japan time).
  Map<String, String> get stamps => Map.unmodifiable(_visited);

  /// Finished trips, oldest first (the latest [_keepTrips]).
  List<TripLog> get trips => List.unmodifiable(_trips);

  /// This phone's invite code for friends (6 letters and digits that cannot
  /// be mistaken for each other).
  String get inviteCode => _invite;
  bool get inviteUsed => _inviteUsed;

  static bool validInvite(String code) => RegExp(r'^[ACDEFGHJKLMNPQRTUVWXY3479]{6}$').hasMatch(code);

  /// A friend's code: [inviteCoins] coins, once, and not your own.
  Future<InviteResult> useInvite(String code) async {
    final c = code.trim().toUpperCase();
    if (!validInvite(c)) return InviteResult.invalid;
    if (c == _invite) return InviteResult.own;
    if (_inviteUsed) return InviteResult.used;
    _inviteUsed = true;
    _coins += inviteCoins;
    await _save();
    return InviteResult.ok;
  }

  bool stamped(String stationId) => _visited.containsKey(stationId);

  /// Gold stamp: the user stayed at this station (StayWatcher).
  bool stayed(String stationId) => _stayed.contains(stationId);

  /// Coins for a gold stamp.
  static const stayCoins = 30;

  /// Stayed 5 minutes at [stationId]: a gold stamp the first time (and the
  /// usual stamp too if it is new). Returns the coins earned, 0 if it already
  /// had its gold stamp.
  Future<int> stampStay(String stationId, {DateTime? now}) async {
    if (_stayed.contains(stationId)) return 0;
    final rules = _catalog?.rules ?? const CoinRules();
    final jst = now ?? DateTime.now().toUtc().add(const Duration(hours: 9));
    var coins = stayCoins;
    if (!_visited.containsKey(stationId)) {
      _visited[stationId] = jst.toIso8601String().substring(0, 10);
      coins += rules.firstVisit;
    }
    _stayed.add(stationId);
    _coins += coins;
    await _save();
    return coins;
  }

  Future<void> load({MyCatalog? catalog}) async {
    _catalog = catalog ?? await MyCatalog.load();
    final prefs = await SharedPreferences.getInstance();
    _coins = prefs.getInt('$prefix.coins') ?? 0;
    _owned
      ..clear()
      ..addAll(prefs.getStringList('$prefix.owned') ?? const []);
    _stayed
      ..clear()
      ..addAll(prefs.getStringList('$prefix.stayed') ?? const []);
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
    _trips.clear();
    try {
      for (final t in jsonDecode(prefs.getString('$prefix.trips') ?? '[]') as List) {
        _trips.add(TripLog.fromJson(t as Map<String, dynamic>));
      }
    } catch (_) {
      // The ride report is a nicety; start it again.
    }
    _inviteUsed = prefs.getBool('$prefix.inviteUsed') ?? false;
    _invite = prefs.getString('$prefix.invite') ?? '';
    if (!validInvite(_invite)) {
      const letters = 'ACDEFGHJKLMNPQRTUVWXY3479';
      final r = math.Random.secure();
      _invite = String.fromCharCodes([for (var i = 0; i < 6; i++) letters.codeUnitAt(r.nextInt(letters.length))]);
      await prefs.setString('$prefix.invite', _invite);
    }
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
      _plate = PlateText.fromJson(jsonDecode(prefs.getString('$prefix.plate') ?? '{}') as Map<String, dynamic>);
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
    if (item.unlock != null || coins < item.price) return BuyResult.notEnoughCoins;
    if (!unlimited) _coins -= item.price;
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
  Future<TripReward> rewardTrip(List<String> stationIds, {DateTime? now, List<String> ridden = const []}) async {
    final rules = _catalog?.rules ?? const CoinRules();
    final jst = now ?? DateTime.now().toUtc().add(const Duration(hours: 9));
    final day = jst.toIso8601String().substring(0, 10);
    _trips.add(TripLog(day: day, minute: jst.hour * 60 + jst.minute, stations: stationIds, lines: ridden));
    if (_trips.length > _keepTrips) _trips.removeRange(0, _trips.length - _keepTrips);
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

  /// The equipped departure melody (asset), or null when it is off.
  String? get melody => _catalog?.item(equipped(MySlot.melody)).sound;

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
      images: cityScene.isNotEmpty && !(scene.station?.startsWith('$cityId.') ?? false) ? cityScene : scene.images,
      overlays: [for (final d in deco) ?d.overlay],
      effects: {for (final d in deco) ?d.effect},
      trainColor: cat.item(equipped(MySlot.train)).color,
      trainArt: cat.item(equipped(MySlot.train)).art ?? cityTrainArt,
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
      trainArt: base.trainArt,
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
    await prefs.setStringList('$prefix.stayed', _stayed.toList());
    await prefs.setString('$prefix.visitedAt', jsonEncode(_visited));
    if (_lastTripDay != null) await prefs.setString('$prefix.lastTripDay', _lastTripDay!);
    await prefs.setString('$prefix.equipped', jsonEncode({for (final e in _equipped.entries) e.key.name: e.value}));
    await prefs.setString('$prefix.plate', jsonEncode(_plate.toJson()));
    await prefs.setString('$prefix.trips', jsonEncode([for (final t in _trips) t.toJson()]));
    await prefs.setBool('$prefix.inviteUsed', _inviteUsed);
  }
}
