import 'dart:math';

import '../../core/localized_text.dart';
import '../../data/congestion/congestion_source.dart';
import '../../data/last_train_alarm.dart' show minutesToLast;
import '../../data/models/city.dart';
import '../../data/weather/weather_source.dart';
import '../trip/route_finder.dart';
import 'first_ride_screen.dart' show FirstRideProgress;
import 'guide_data.dart';

export 'guide_data.dart' show GuideTip, TipKind;

/// The tip that opens the first-ride guide when tapped.
const firstRideTipId = 'firstRide';

LocalizedText _t(String ja, String ko, String en) => LocalizedText({'ja': ja, 'ko': ko, 'en': en});

/// The rotation takes one line from each of these in turn, so two lines of
/// the same kind never follow each other while another kind still has some.
/// What depends on the moment comes first (after the stations' own tips).
const _rotation = ['weather', 'season', 'greet', 'crowd', 'manners', 'howto', 'app', 'trivia'];

/// A warning at the head comes back after this many other lines.
const _warnEvery = 10;

/// Greetings used when the general pool is not loaded (yet).
final _greetings = [
  PoolTip(
    TipKind.fun,
    _t('おはようございます。今日もいってらっしゃい！', '좋은 아침이에요. 오늘도 잘 다녀오세요!', 'Good morning! Have a nice day!'),
    cat: 'greet',
    hours: (4, 10),
  ),
  PoolTip(
    TipKind.fun,
    _t('こんにちは。つぎの電車もご案内します', '안녕하세요. 다음 열차도 안내해 드릴게요', 'Hello! I\'ll guide you to the next train'),
    cat: 'greet',
    hours: (10, 17),
  ),
  PoolTip(
    TipKind.fun,
    _t('おつかれさまでした。気をつけて帰ってね', '수고 많으셨어요. 조심히 들어가세요', 'Good work today. Get home safe'),
    cat: 'greet',
    hours: (17, 4),
  ),
];

Object? _memoKey;
List<GuideTip> _memo = const [];

/// The station attendant's tips for now. First what matters most: the last
/// train, rain, a long change, the best exit at the destination, crowds,
/// stamps, a course to try. Then a long rotation that does not repeat: tips of
/// the start and destination stations and the general pool (only the lines
/// that fit the hour, the season, the weather and the crowd), one category
/// after another, in an order fixed by the day and the stations. A greeting
/// for the time of day closes the round.
///
/// The platform screen asks on every build: the same situation gives back the
/// very same list, so nothing is built twice (and the card keeps its place).
List<GuideTip> guideTips({
  required CityData city,
  required GuideData data,
  required DateTime now,
  required String lang,
  RouteResult? route,
  String? fromId,
  String? toId,
  WeatherNow? weather,
  CongestionLevel? crowd,
  bool Function(String stationId)? stamped,
  bool Function(String stationId)? stayed,
}) {
  final jst = now.toUtc().add(const Duration(hours: 9));
  // Last train: from an hour before.
  final lineId = route?.legs.first.lineId ?? (fromId == null ? null : city.station(fromId).lines.first);
  // The same last train as the next-train card, the alarm and the widget:
  // with a route, the last departure that still makes every connection.
  final left = minutesToLast(city, jst, route: route, lineId: lineId);
  final toLast = left != null && left <= 60 ? left : null;
  final temp = weather?.tempC;
  final key = (
    city,
    data,
    lang,
    jst.year * 10000 + jst.month * 100 + jst.day,
    jst.hour,
    toLast,
    route == null
        ? null
        : Object.hashAll([for (final l in route.legs) Object.hash(l.lineId, l.stationIds.first, l.through)]),
    fromId,
    toId,
    weather?.kind,
    weather?.wetLater,
    temp == null ? 0 : (temp >= 30 ? 1 : (temp <= 5 ? -1 : 0)),
    crowd,
    fromId == null ? null : stamped?.call(fromId),
    fromId == null ? null : stayed?.call(fromId),
    FirstRideProgress.done.value,
  );
  if (key == _memoKey) return _memo;

  final tips = <GuideTip>[];
  String name(String id) => city.station(id).name.of(lang);

  if (toLast != null) {
    tips.add(
      GuideTip(
        TipKind.warn,
        _t(
          '終電まで あと$toLast分です。乗り遅れに気をつけて',
          '막차까지 $toLast분 남았어요. 놓치지 않게 조심하세요',
          'The last train leaves in $toLast min. Don\'t miss it!',
        ),
        id: 'last',
      ),
    );
  }

  // Weather.
  if (weather != null) {
    if (weather.kind == WeatherKind.rain || weather.kind == WeatherKind.snow) {
      tips.add(
        GuideTip(
          TipKind.warn,
          _t(
            '雨や雪で足元がすべりやすいです。ホームでは走らないでね',
            '비나 눈으로 바닥이 미끄러워요. 승강장에서는 뛰지 마세요',
            'Floors are slippery in the rain or snow. Please don\'t run on the platform',
          ),
        ),
      );
    } else if (weather.wetLater) {
      tips.add(
        GuideTip(
          TipKind.help,
          _t('このあと雨の予報。傘を持っていくと安心です', '이따가 비 예보가 있어요. 우산을 챙기면 안심이에요', 'Rain is on the way later. Take an umbrella'),
        ),
      );
    }
  }

  // A long change on the way.
  final changeAt = <String>[];
  var through = false;
  if (route != null) {
    var told = false;
    for (var i = 1; i < route.legs.length; i++) {
      final a = route.legs[i - 1], b = route.legs[i];
      if (b.through) {
        through = true;
        continue;
      }
      final at = a.stationIds.last, next = b.stationIds.first;
      changeAt.add(at);
      if (told) continue;
      final walk = at == next ? city.station(at).transferWalkMin(a.lineId, b.lineId) : (city.walkMin(at, next) ?? 5);
      if (walk >= 5) {
        told = true;
        tips.add(
          GuideTip(
            TipKind.help,
            _t(
              '${name(at)}での乗り換えは 歩いて約$walk分。時間に余裕をもってね',
              '${name(at)}에서 환승은 걸어서 약 $walk분. 여유 있게 가세요',
              'Changing at ${name(at)} takes about $walk min on foot. Give yourself time',
            ),
            id: 'change:$at',
          ),
        );
      }
    }
  }

  // The best exit at the destination (or the start, without a route).
  final exitAt = toId ?? fromId;
  if (exitAt != null) {
    final exits = data.exits[exitAt];
    if (exits != null && exits.isNotEmpty) {
      final e = exits.first;
      tips.add(
        GuideTip(
          TipKind.help,
          _t(
            '${name(exitAt)}では「${e.name.of('ja')}」が ${e.near.of('ja')}に便利です',
            '${name(exitAt)}에서는 「${e.name.of('ko')}」가 ${e.near.of('ko')}에 편해요',
            'At ${name(exitAt)}, the ${e.name.of('en')} is handy for ${e.near.of('en')}',
          ),
          id: 'exit:$exitAt',
        ),
      );
    }
  }

  // Crowds.
  if (crowd == CongestionLevel.packed || crowd == CongestionLevel.crowded) {
    tips.add(
      GuideTip(
        TipKind.help,
        _t(
          'いまは混雑しそう。1本見送るのも手です',
          '지금은 붐빌 것 같아요. 한 대 보내는 것도 방법이에요',
          'It looks crowded now. Letting one train go can help',
        ),
      ),
    );
  }

  // New to trains here: the first-ride guide (tap the bubble to open it).
  if (!FirstRideProgress.done.value) {
    tips.add(
      GuideTip(
        TipKind.help,
        _t(
          '電車がはじめての方へ。ここをタップで「日本の電車はじめて」',
          '전철이 처음이라면, 여기를 눌러 「일본 전철 첫걸음」',
          'New to Japanese trains? Tap here for the first-ride guide',
        ),
        id: firstRideTipId,
      ),
    );
  }

  // Stamps.
  if (fromId != null && stamped != null && !stamped(fromId)) {
    tips.add(
      GuideTip(
        TipKind.fun,
        _t(
          '${name(fromId)}のスタンプはまだです。乗って集めよう',
          '${name(fromId)} 스탬프는 아직이에요. 타고 모아 봐요',
          'No stamp from ${name(fromId)} yet. Ride to collect it',
        ),
        id: 'stamp:$fromId',
      ),
    );
  } else if (fromId != null && stayed != null && !stayed(fromId)) {
    tips.add(
      GuideTip(
        TipKind.fun,
        _t('駅で5分すごすと ゴールドスタンプ★がもらえます', '역에서 5분 머무르면 골드 스탬프★를 받아요', 'Stay 5 minutes at a station for a gold stamp ★'),
      ),
    );
  }

  // A course to try: one not finished yet, changing with the day.
  final open = [
    for (final c in data.courses)
      if (stamped == null || !c.finished(stamped)) c,
  ];
  if (open.isNotEmpty) {
    final c = open[(jst.day + jst.month) % open.length];
    tips.add(
      GuideTip(
        TipKind.fun,
        _t(
          'おでかけなら「${c.name.of('ja')}」はいかが？ 路線図の「コース」からどうぞ',
          '나들이라면 「${c.name.of('ko')}」 어때요? 노선도의 「코스」에서 볼 수 있어요',
          'Going out? Try "${c.name.of('en')}" from Courses on the route map',
        ),
        id: 'course:${c.id}',
      ),
    );
  }

  // The rotation, in an order of its own for each day and pair of stations.
  final moment = TipMoment.at(
    jst,
    weather: weather,
    crowd: crowd,
    hasRoute: route != null,
    changes: changeAt.isNotEmpty,
    through: through,
  );
  final seed = _hash('${jst.year}-${jst.month}-${jst.day}|$fromId|$toId');
  final queues = <List<GuideTip>>[
    _stationTips(city, data, [?toId, ?fromId, ...changeAt], seed),
    for (final (i, cat) in _rotation.indexed)
      [
        for (final p in data.pool)
          if (p.cat == cat && p.fits(moment)) p,
      ]..shuffle(Random(seed + i + 1)),
  ];
  // The greeting that closes the round.
  final greets = queues[1 + _rotation.indexOf('greet')];
  final at = greets.lastIndexWhere((g) => g.kind == TipKind.fun);
  final GuideTip bye = at >= 0
      ? greets.removeAt(at)
      : _greetings.firstWhere((g) => g.fits(moment), orElse: () => _greetings.last);

  final seen = {for (final t in tips) t.key};
  final warns = [
    for (final t in tips)
      if (t.kind == TipKind.warn) t,
  ];
  var count = 0;
  for (var round = 0, more = true; more; round++) {
    more = false;
    for (final q in queues) {
      if (round >= q.length) continue;
      more = true;
      final t = q[round];
      if (t.key == bye.key || !seen.add(t.key)) continue;
      tips.add(t);
      if (++count % _warnEvery == 0) tips.addAll(warns);
    }
  }
  tips.add(bye);

  _memoKey = key;
  return _memo = List.unmodifiable(tips);
}

/// Tips of the stations of this trip, each with the station's name in front:
/// the destination and the start in turn, then where trains are changed.
List<GuideTip> _stationTips(CityData city, GuideData data, List<String> ids, int seed) {
  final lists = <List<GuideTip>>[];
  final done = <String>{};
  for (final id in ids) {
    final lines = data.stationTips[id];
    if (lines == null || !done.add(id)) continue;
    final n = city.station(id).name;
    lists.add(
      [
        for (final l in lines)
          GuideTip(
            TipKind.help,
            _t('${n.of('ja')}：${l.of('ja')}', '${n.of('ko')}: ${l.of('ko')}', '${n.of('en')}: ${l.of('en')}'),
          ),
      ]..shuffle(Random(seed ^ lists.length)),
    );
  }
  final out = <GuideTip>[];
  for (var i = 0, more = true; more; i++) {
    more = false;
    for (final l in lists) {
      if (i >= l.length) continue;
      more = true;
      out.add(l[i]);
    }
  }
  return out;
}

/// FNV-1a: the same number for the same text on every run and device.
int _hash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7fffffff;
  }
  return h;
}
