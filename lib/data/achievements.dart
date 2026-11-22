import 'package:shared_preferences/shared_preferences.dart';

import '../core/localized_text.dart';
import '../core/pixel/scene_events.dart' show slTrainSightings, yellowTrainSightings;
import '../features/trip/trip_estimator.dart' show distanceMeters;
import 'models/city.dart';
import 'my_store.dart';

/// Medal colour: how hard a badge is.
enum BadgeTier { bronze, silver, gold }

/// One achievement: a medal with a picture, a name and how to get it.
class TripBadge {
  const TripBadge(this.id, this.tier, this.icon, this.name, this.how);
  final String id;
  final BadgeTier tier;

  /// Picture in the middle of the medal (an asset).
  final String icon;
  final LocalizedText name;
  final LocalizedText how;
}

const _s = 'assets/art/stickers/';
const _w = 'assets/art/widget/';

/// Every badge, in the order shown.
const badges = [
  TripBadge(
    'first',
    BadgeTier.bronze,
    '${_s}ticket.png',
    LocalizedText({'ja': 'はじめての乗車', 'ko': '첫 승차', 'en': 'First Ride'}),
    LocalizedText({'ja': 'つぎはMetroで初めて乗る', 'ko': '처음으로 추적하며 타기', 'en': 'Finish your first tracked ride'}),
  ),
  TripBadge(
    'rides10',
    BadgeTier.bronze,
    '${_s}train.png',
    LocalizedText({'ja': '10回乗車', 'ko': '10번 승차', 'en': '10 Rides'}),
    LocalizedText({'ja': '10回乗る', 'ko': '10번 타기', 'en': 'Ride 10 times'}),
  ),
  TripBadge(
    'rides50',
    BadgeTier.silver,
    '${_s}train.png',
    LocalizedText({'ja': '50回乗車', 'ko': '50번 승차', 'en': '50 Rides'}),
    LocalizedText({'ja': '50回乗る', 'ko': '50번 타기', 'en': 'Ride 50 times'}),
  ),
  TripBadge(
    'rides100',
    BadgeTier.gold,
    '${_s}train.png',
    LocalizedText({'ja': '100回乗車', 'ko': '100번 승차', 'en': '100 Rides'}),
    LocalizedText({'ja': '100回乗る', 'ko': '100번 타기', 'en': 'Ride 100 times'}),
  ),
  TripBadge(
    'early',
    BadgeTier.silver,
    '${_w}icon_sun.webp',
    LocalizedText({'ja': '始発の達人', 'ko': '첫차의 달인', 'en': 'Early Bird'}),
    LocalizedText({'ja': '朝5:30までに乗る', 'ko': '아침 5:30 전에 타기', 'en': 'Ride before 5:30 am'}),
  ),
  TripBadge(
    'lastTrain',
    BadgeTier.silver,
    '${_w}icon_moon.webp',
    LocalizedText({'ja': '終電サバイバー', 'ko': '막차 생존자', 'en': 'Last-Train Survivor'}),
    LocalizedText({'ja': '深夜0時を過ぎて乗る', 'ko': '자정이 지나서 타기', 'en': 'Ride after midnight'}),
  ),
  TripBadge(
    'transfer',
    BadgeTier.bronze,
    '${_s}sparkle.png',
    LocalizedText({'ja': '乗り換え名人', 'ko': '환승의 달인', 'en': 'Transfer Pro'}),
    LocalizedText({'ja': '1回で3路線以上乗る', 'ko': '한 번에 3개 노선 이상 타기', 'en': 'Use 3+ lines in one ride'}),
  ),
  TripBadge(
    'long',
    BadgeTier.silver,
    '${_s}fuji.png',
    LocalizedText({'ja': '遠くへ旅人', 'ko': '먼 길 여행자', 'en': 'Long Hauler'}),
    LocalizedText({'ja': '1回で30km以上乗る', 'ko': '한 번에 30km 이상 타기', 'en': 'Ride 30 km+ in one go'}),
  ),
  TripBadge(
    'weekend',
    BadgeTier.bronze,
    '${_s}onigiri.png',
    LocalizedText({'ja': '週末トラベラー', 'ko': '주말 여행자', 'en': 'Weekend Traveller'}),
    LocalizedText({'ja': '土日に5回乗る', 'ko': '주말에 5번 타기', 'en': 'Ride 5 times on weekends'}),
  ),
  TripBadge(
    'streak7',
    BadgeTier.gold,
    '${_s}star.png',
    LocalizedText({'ja': '7日連続乗車', 'ko': '7일 연속 승차', 'en': '7-Day Streak'}),
    LocalizedText({'ja': '7日続けて毎日乗る', 'ko': '7일 동안 매일 타기', 'en': 'Ride every day for 7 days'}),
  ),
  TripBadge(
    'stamps10',
    BadgeTier.bronze,
    '${_s}hanko.png',
    LocalizedText({'ja': 'スタンプ10駅', 'ko': '도장 10역', 'en': '10 Stamps'}),
    LocalizedText({'ja': '10駅のスタンプを集める', 'ko': '10개 역 도장 모으기', 'en': 'Collect 10 station stamps'}),
  ),
  TripBadge(
    'stamps50',
    BadgeTier.silver,
    '${_s}hanko.png',
    LocalizedText({'ja': 'スタンプ50駅', 'ko': '도장 50역', 'en': '50 Stamps'}),
    LocalizedText({'ja': '50駅のスタンプを集める', 'ko': '50개 역 도장 모으기', 'en': 'Collect 50 station stamps'}),
  ),
  TripBadge(
    'stamps100',
    BadgeTier.gold,
    '${_s}hanko.png',
    LocalizedText({'ja': 'スタンプ100駅', 'ko': '도장 100역', 'en': '100 Stamps'}),
    LocalizedText({'ja': '100駅のスタンプを集める', 'ko': '100개 역 도장 모으기', 'en': 'Collect 100 station stamps'}),
  ),
  TripBadge(
    'line1',
    BadgeTier.silver,
    '${_s}rainbow.png',
    LocalizedText({'ja': '路線制覇', 'ko': '노선 제패', 'en': 'Line Complete'}),
    LocalizedText({'ja': '1路線の全駅を回る', 'ko': '한 노선의 모든 역 돌기', 'en': 'Stamp every station of a line'}),
  ),
  TripBadge(
    'yamanote',
    BadgeTier.gold,
    '${_s}heart.png',
    LocalizedText({'ja': '山手線一周', 'ko': '야마노테선 일주', 'en': 'Yamanote Loop'}),
    LocalizedText({'ja': '山手線の全30駅を回る', 'ko': '야마노테선 30개 역 모두 돌기', 'en': 'Stamp all 30 Yamanote stations'}),
  ),
  TripBadge(
    'line5',
    BadgeTier.gold,
    '${_s}cat.png',
    LocalizedText({'ja': '5路線制覇', 'ko': '5개 노선 제패', 'en': '5 Lines Complete'}),
    LocalizedText({'ja': '5路線を制覇する', 'ko': '5개 노선 제패하기', 'en': 'Complete 5 lines'}),
  ),
  TripBadge(
    'yellow',
    BadgeTier.gold,
    'assets/art/yellow_train/front_base_day.webp',
    LocalizedText({'ja': '幸運の黄色い電車', 'ko': '행운의 노란 전철', 'en': 'Lucky Yellow Train'}),
    LocalizedText({
      'ja': 'のりばでめったに来ない黄色い電車に会う',
      'ko': '승강장에서 아주 가끔 오는 노란 전철 만나기',
      'en': 'Spot the rare yellow train at the platform',
    }),
  ),
  TripBadge(
    'sl',
    BadgeTier.gold,
    'assets/art/tottori/sl/front_base_day.webp',
    LocalizedText({'ja': '若桜のSL', 'ko': '와카사의 SL', 'en': 'Wakasa Steam'}),
    LocalizedText({
      'ja': '鳥取ののりばに めったに来ない蒸気機関車に会う',
      'ko': '돗토리 승강장에 아주 가끔 오는 증기기관차 만나기',
      'en': 'Spot the rare steam locomotive on a Tottori platform',
    }),
  ),
];

/// Rare things seen on the platform (scene_events.dart), kept on the phone.
class RareSightings {
  static const _key = 'badges.yellowTrain';
  static const _slKey = 'badges.slTrain';
  static bool yellow = false;
  static bool sl = false;
  static bool _attached = false;

  /// Loads what was seen and starts listening for the yellow train.
  static Future<void> attach() async {
    if (_attached) return;
    _attached = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      yellow = prefs.getBool(_key) ?? false;
      sl = prefs.getBool(_slKey) ?? false;
    } catch (_) {
      // A badge is a nicety.
    }
    slTrainSightings.addListener(() async {
      if (sl || slTrainSightings.value == 0) return;
      sl = true;
      try {
        await (await SharedPreferences.getInstance()).setBool(_slKey, true);
      } catch (_) {}
    });
    yellowTrainSightings.addListener(() async {
      if (yellow || yellowTrainSightings.value == 0) return;
      yellow = true;
      try {
        await (await SharedPreferences.getInstance()).setBool(_key, true);
      } catch (_) {}
    });
  }
}

/// Which badges are earned, from the rides logged, the stamps and the lines.
Set<String> earnedBadges(CityData city, MyStore store) {
  final trips = store.trips;
  final stamps = city.stations.keys.where(store.stamped).length;
  final done = [
    for (final l in city.lines)
      if (store.lineComplete(l.id)) l.id,
  ];
  final got = <String>{};
  if (trips.isNotEmpty) got.add('first');
  if (trips.length >= 10) got.add('rides10');
  if (trips.length >= 50) got.add('rides50');
  if (trips.length >= 100) got.add('rides100');
  var weekend = 0;
  for (final t in trips) {
    // Logged when it ended: before 5:30 counts as an early (first) train,
    // 0:00-3:59 as after midnight (the last trains).
    if (t.minute >= 240 && t.minute <= 330) got.add('early');
    if (t.minute < 240) got.add('lastTrain');
    if (t.lines.toSet().length >= 3) got.add('transfer');
    final day = DateTime.tryParse(t.day);
    if (day != null && (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday)) weekend++;
    var metres = 0.0;
    final ids = [
      for (final id in t.stations)
        if (city.stations.containsKey(id)) id,
    ];
    for (var i = 1; i < ids.length; i++) {
      final a = city.station(ids[i - 1]), b = city.station(ids[i]);
      metres += distanceMeters(a.lat, a.lng, b.lat, b.lng);
    }
    if (metres >= 30000) got.add('long');
  }
  if (weekend >= 5) got.add('weekend');
  if (_longestStreak(trips) >= 7) got.add('streak7');
  if (stamps >= 10) got.add('stamps10');
  if (stamps >= 50) got.add('stamps50');
  if (stamps >= 100) got.add('stamps100');
  if (done.isNotEmpty) got.add('line1');
  if (done.contains('tokyo.yamanote')) got.add('yamanote');
  if (done.length >= 5) got.add('line5');
  if (RareSightings.yellow) got.add('yellow');
  if (RareSightings.sl) got.add('sl');
  return got;
}

/// Most days in a row with at least one ride.
int _longestStreak(List<TripLog> trips) {
  final days = {for (final t in trips) ?DateTime.tryParse(t.day)}.toList()..sort();
  var best = 0, run = 0;
  DateTime? prev;
  for (final d in days) {
    run = prev != null && d.difference(prev).inDays == 1 ? run + 1 : 1;
    if (run > best) best = run;
    prev = d;
  }
  return best;
}
