import '../../core/localized_text.dart';
import '../../data/congestion/congestion_source.dart';
import '../../data/models/city.dart';
import '../../data/weather/weather_source.dart';
import '../trip/route_finder.dart';
import 'guide_data.dart';

/// What a tip is about (the attendant points for warnings).
enum TipKind { warn, help, fun }

class GuideTip {
  const GuideTip(this.kind, this.text);
  final TipKind kind;
  final LocalizedText text;
}

LocalizedText _t(String ja, String ko, String en) => LocalizedText({'ja': ja, 'ko': ko, 'en': en});

/// The station attendant's tips for now, most useful first: the last train,
/// rain, a long change, the best exit at the destination, crowds, stamps, a
/// course to try, then a greeting for the time of day.
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
  final tips = <GuideTip>[];
  String name(String id) => city.station(id).name.of(lang);

  // Last train: from an hour before.
  final lineId = route?.legs.first.lineId ?? (fromId == null ? null : city.station(fromId).lines.first);
  final toLast = lineId == null ? null : city.timetables[lineId]?.minutesToLastTrain(jst);
  if (toLast != null && toLast <= 60) {
    tips.add(
      GuideTip(
        TipKind.warn,
        _t(
          '終電まで あと$toLast分です。乗り遅れに気をつけて',
          '막차까지 $toLast분 남았어요. 놓치지 않게 조심하세요',
          'The last train leaves in $toLast min. Don\'t miss it!',
        ),
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
  if (route != null) {
    for (var i = 1; i < route.legs.length; i++) {
      final a = route.legs[i - 1], b = route.legs[i];
      if (b.through) continue;
      final at = a.stationIds.last, next = b.stationIds.first;
      final walk = at == next ? city.station(at).transferWalkMin(a.lineId, b.lineId) : (city.walkMin(at, next) ?? 5);
      if (walk >= 5) {
        tips.add(
          GuideTip(
            TipKind.help,
            _t(
              '${name(at)}での乗り換えは 歩いて約$walk分。時間に余裕をもってね',
              '${name(at)}에서 환승은 걸어서 약 $walk분. 여유 있게 가세요',
              'Changing at ${name(at)} takes about $walk min on foot. Give yourself time',
            ),
          ),
        );
        break;
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
      ),
    );
  }

  // A greeting for the time of day.
  final h = jst.hour;
  tips.add(
    GuideTip(
      TipKind.fun,
      h < 10
          ? _t('おはようございます。今日もいってらっしゃい！', '좋은 아침이에요. 오늘도 잘 다녀오세요!', 'Good morning! Have a nice day!')
          : h < 17
          ? _t('こんにちは。つぎの電車もご案内します', '안녕하세요. 다음 열차도 안내해 드릴게요', 'Hello! I\'ll guide you to the next train')
          : _t('おつかれさまでした。気をつけて帰ってね', '수고 많으셨어요. 조심히 들어가세요', 'Good work today. Get home safe'),
    ),
  );
  return tips;
}
