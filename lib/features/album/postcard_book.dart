import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/japan_time.dart';
import '../../data/my_catalog.dart';
import '../../data/my_store.dart';
import '../../data/weather/weather_source.dart';

/// One picture postcard of the travel album (旅のアルバム): where the user
/// got off, when, in what weather, with the station scene and train they
/// had then. A postcard per station per day; staying 5 minutes makes it gold.
@immutable
class Postcard {
  const Postcard({
    required this.id,
    required this.station,
    required this.day,
    required this.minute,
    this.from,
    this.line,
    this.weather,
    this.first = false,
    this.gold = false,
    this.memo = '',
    this.scene,
    this.train,
  });

  factory Postcard.fromJson(Map<String, dynamic> j) => Postcard(
    id: (j['id'] as num).toInt(),
    station: j['s'] as String,
    day: j['d'] as String,
    minute: (j['m'] as num).toInt(),
    from: j['f'] as String?,
    line: j['l'] as String?,
    weather: WeatherKind.values.where((k) => k.name == j['w']).firstOrNull,
    first: j['1'] == true,
    gold: j['g'] == true,
    memo: j['memo'] as String? ?? '',
    scene: j['sc'] as String?,
    train: j['tr'] as String?,
  );

  /// When it was made (milliseconds), also its order in the album.
  final int id;
  final String station;

  /// yyyy-mm-dd and minutes after midnight, Japan time.
  final String day;
  final int minute;

  /// Where the trip started and the last line ridden (null for a stay).
  final String? from;
  final String? line;

  /// The weather then, when のりば knew it.
  final WeatherKind? weather;

  /// The first visit to the station (the day it was stamped).
  final bool first;

  /// The user stayed 5 minutes there (gold stamp).
  final bool gold;

  /// The user's own line on the back; empty = the written message.
  final String memo;

  /// MY scene and train items at the time (ids), for the picture.
  final String? scene;
  final String? train;

  int get hour => minute ~/ 60;

  /// mm-dd, to find "a year ago today".
  String get monthDay => day.substring(5);

  Postcard copyWith({bool? gold, WeatherKind? weather, String? memo}) => Postcard(
    id: id,
    station: station,
    day: day,
    minute: minute,
    from: from,
    line: line,
    weather: weather ?? this.weather,
    first: first,
    gold: gold ?? this.gold,
    memo: memo ?? this.memo,
    scene: scene,
    train: train,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    's': station,
    'd': day,
    'm': minute,
    'f': ?from,
    'l': ?line,
    'w': ?weather?.name,
    if (first) '1': true,
    if (gold) 'g': true,
    if (memo.isNotEmpty) 'memo': memo,
    'sc': ?scene,
    'tr': ?train,
  };
}

/// The travel album on the phone: postcards, newest first.
class PostcardBook extends ChangeNotifier {
  PostcardBook({this.prefix = 'album'});

  static final instance = PostcardBook();

  final String prefix;
  final List<Postcard> _cards = [];
  bool _loaded = false;

  /// Postcards kept (the oldest go first).
  static const keep = 500;

  static const memoMax = 40;

  bool get loaded => _loaded;
  List<Postcard> get cards => List.unmodifiable(_cards);

  /// Loads the album. The first time, the trips already in MY become
  /// postcards (without the weather, which was not kept).
  Future<void> load(MyStore my) async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$prefix.cards');
    _cards.clear();
    if (raw == null) {
      for (final t in my.trips) {
        if (t.stations.isEmpty) continue;
        final station = t.stations.last;
        if (_cards.any((c) => c.station == station && c.day == t.day)) continue;
        _cards.insert(
          0,
          Postcard(
            id: _cards.length + 1,
            station: station,
            day: t.day,
            minute: t.minute,
            from: t.stations.first == station ? null : t.stations.first,
            line: t.lines.isEmpty ? null : t.lines.last,
            first: my.stamps[station] == t.day,
            gold: my.stayed(station),
          ),
        );
      }
    } else {
      try {
        for (final c in jsonDecode(raw) as List) {
          _cards.add(Postcard.fromJson(c as Map<String, dynamic>));
        }
      } catch (_) {
        // A broken album starts again; the stamps are kept in MY.
      }
    }
    _cards.sort(_newestFirst);
    _loaded = true;
    if (raw == null) await _save();
    notifyListeners();
  }

  /// A postcard from [station]: after a trip ([from], [line]) or a 5 minute
  /// stay ([gold]). The same station on the same day updates its card.
  Future<Postcard> add({
    required MyStore my,
    required String station,
    String? from,
    String? line,
    WeatherKind? weather,
    bool gold = false,
    DateTime? now,
  }) async {
    if (!_loaded) await load(my);
    final jst = now ?? japanNow();
    final day = jst.toIso8601String().substring(0, 10);
    final w = weather == WeatherKind.unknown ? null : weather;
    final i = _cards.indexWhere((c) => c.station == station && c.day == day);
    if (i >= 0) {
      final c = _cards[i] = _cards[i].copyWith(gold: gold || _cards[i].gold, weather: _cards[i].weather ?? w);
      await _save();
      return c;
    }
    final own = my.sceneForStation(station);
    final card = Postcard(
      id: _nextId(),
      station: station,
      day: day,
      minute: jst.hour * 60 + jst.minute,
      from: from == station ? null : from,
      line: line,
      weather: w,
      first: my.stamps[station] == day,
      gold: gold,
      scene: own != null && my.owns(own.id) ? own.id : (my.loaded ? my.equipped(MySlot.scene) : null),
      train: my.loaded ? my.equipped(MySlot.train) : null,
    );
    _cards
      ..insert(0, card)
      ..sort(_newestFirst);
    if (_cards.length > keep) _cards.removeRange(keep, _cards.length);
    await _save();
    return card;
  }

  /// Unique even for two postcards in the same millisecond.
  int _nextId() {
    var id = DateTime.now().millisecondsSinceEpoch;
    for (final c in _cards) {
      if (c.id >= id) id = c.id + 1;
    }
    return id;
  }

  static int _newestFirst(Postcard a, Postcard b) {
    final d = b.day.compareTo(a.day);
    return d != 0 ? d : b.minute.compareTo(a.minute);
  }

  Future<void> setMemo(int id, String memo) async {
    final i = _cards.indexWhere((c) => c.id == id);
    if (i < 0) return;
    final m = memo.trim();
    _cards[i] = _cards[i].copyWith(memo: m.length > memoMax ? m.substring(0, memoMax) : m);
    await _save();
  }

  /// Postcards from this day in earlier years (newest first).
  List<Postcard> onThisDay(DateTime jst) {
    final md = jst.toIso8601String().substring(5, 10);
    final year = jst.year.toString();
    return [
      for (final c in _cards)
        if (c.monthDay == md && !c.day.startsWith(year)) c,
    ];
  }

  Future<void> _save() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$prefix.cards', jsonEncode([for (final c in _cards) c.toJson()]));
  }
}
