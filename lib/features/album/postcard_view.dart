import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/localized_text.dart';
import '../../core/pixel/pixel_scene.dart';
import '../../core/pixel/pixel_ui.dart';
import '../../data/models/city.dart';
import '../../data/my_store.dart';
import '../../data/weather/weather_source.dart';
import 'postcard_book.dart';

/// Postcards are 3:2 like real ones.
const postcardAspect = 1.5;

const _paper = Color(0xFFFBF6EA);
const _paperEdge = Color(0xFFE6DCC4);
const _ink = Color(0xFF4A3F35);
const _postmark = Color(0xFFB8463A);
const _gold = Color(0xFFC79A2E);

LocalizedText _t(String ja, String ko, String en) => LocalizedText({'ja': ja, 'ko': ko, 'en': en});

String _name(CityData city, String id, String lang) => city.stations[id]?.name.of(lang) ?? id;

Color postcardLineColor(CityData city, Postcard c) {
  final line = c.line ?? city.stations[c.station]?.lines.firstOrNull;
  if (line == null) return PixelColors.ink;
  try {
    return city.line(line).color;
  } catch (_) {
    return PixelColors.ink;
  }
}

/// The written message on the back: how they got there, the weather or the
/// hour, and a sign-off. The same postcard always says the same thing.
String postcardMessage(CityData city, Postcard c, String lang) {
  final st = _name(city, c.station, lang);
  final from = c.from == null ? null : _name(city, c.from!, lang);
  final r = math.Random(c.id);
  final open = c.first
      ? _t('はじめての$st。', '처음 와 본 $st.', 'My first time at $st.')
      : c.gold
      ? _t('$stで、ゆっくりひと休み。', '$st에서 느긋하게 한숨 돌렸어요.', 'A slow little rest at $st.')
      : from != null
      ? _t('$fromから$stへ。', '$from에서 $st까지.', 'From $from to $st.')
      : _t('$stにて。', '$st에서.', 'At $st.');
  final h = c.hour;
  final List<LocalizedText> mood;
  if (c.weather == WeatherKind.rain) {
    mood = [
      _t('雨の音がやさしい日でした。', '빗소리가 다정한 날이었어요.', 'The rain sounded gentle today.'),
      _t('傘の花がホームに咲いていました。', '승강장에 우산 꽃이 피어 있었어요.', 'Umbrellas bloomed on the platform.'),
    ];
  } else if (c.weather == WeatherKind.snow) {
    mood = [
      _t('雪がちらつく、しずかな日。', '눈이 흩날리는 고요한 날.', 'A quiet day with falling snow.'),
      _t('白い息で電車を待ちました。', '하얀 입김을 불며 전철을 기다렸어요.', 'I waited for the train, breath white.'),
    ];
  } else if (h >= 19 || h < 5) {
    mood = [
      _t('夜のホームの灯りがきれいでした。', '밤 승강장 불빛이 예뻤어요.', 'The platform lights were lovely tonight.'),
      _t('今日もおつかれさま、わたし。', '오늘도 수고했어, 나.', 'Well done today, me.'),
    ];
  } else if (h >= 16) {
    mood = [
      _t('夕焼けのなか、電車を待ちました。', '노을 속에서 전철을 기다렸어요.', 'I waited for the train in the sunset.'),
      _t('空がオレンジ色にそまっていました。', '하늘이 주황빛으로 물들어 있었어요.', 'The sky turned orange.'),
    ];
  } else if (h < 10) {
    mood = [
      _t('朝の空気がすがすがしい。', '아침 공기가 상쾌해요.', 'The morning air felt fresh.'),
      _t('いってきます、の朝でした。', '"다녀오겠습니다"의 아침이었어요.', 'A good morning to set off.'),
    ];
  } else if (c.weather == WeatherKind.cloudy) {
    mood = [_t('くもり空も、わるくない。', '흐린 하늘도 나쁘지 않아요.', 'Cloudy skies are nice too.')];
  } else {
    mood = [
      _t('いい天気の一日でした。', '날씨 좋은 하루였어요.', 'It was a lovely day.'),
      _t('電車の窓から、光がきらきら。', '전철 창으로 햇살이 반짝반짝.', 'Sunlight sparkled through the train window.'),
    ];
  }
  final bye = [
    _t('また来るね。', '또 올게요.', 'I\'ll come again.'),
    _t('つぎはどこへ行こう。', '다음엔 어디로 갈까.', 'Where to next?'),
    _t('いい思い出になりました。', '좋은 추억이 됐어요.', 'A good memory.'),
  ];
  return '${open.of(lang)}\n${mood[r.nextInt(mood.length)].of(lang)}\n${bye[r.nextInt(bye.length)].of(lang)}';
}

/// 2026.11.23 14:05
String postcardDate(Postcard c) {
  final p = c.day.split('-');
  final m = c.minute % 60;
  return '${p[0]}.${int.parse(p[1])}.${int.parse(p[2])}  ${c.hour}:${m.toString().padLeft(2, '0')}';
}

/// The picture on the front: that station's platform at that hour, in that
/// weather, with the scene and train the user had then. Kept in memory for
/// the album's recent cards.
class PostcardPictures {
  static final _cache = <int, Future<ui.Image>>{};
  static final _order = <int>[];
  static const _max = 40;

  static Future<ui.Image> of(CityData city, Postcard c, MyStore my) {
    final hit = _cache[c.id];
    if (hit != null) return hit;
    final f = _cache[c.id] = _render(city, c, my);
    _order.add(c.id);
    if (_order.length > _max) _cache.remove(_order.removeAt(0));
    return f;
  }

  static SceneLook lookOf(Postcard c, MyStore my) {
    final base = my.look;
    final cat = my.catalog;
    if (cat == null) return base;
    final scene = cat.items.where((i) => i.id == c.scene).firstOrNull;
    final train = cat.items.where((i) => i.id == c.train).firstOrNull;
    return SceneLook(
      images: scene?.images ?? base.images,
      overlays: base.overlays,
      effects: base.effects,
      trainColor: train == null ? base.trainColor : train.color,
      trainArt: train == null ? base.trainArt : train.art,
      headMark: base.headMark,
      skyArt: base.skyArt,
    );
  }

  static String? skyOf(Postcard c) {
    final month = int.tryParse(c.day.substring(5, 7)) ?? 6;
    return switch (c.weather) {
      WeatherKind.rain => 'rain',
      WeatherKind.snow => 'snow',
      _ => month == 12 || month <= 2 ? 'winter' : null,
    };
  }

  static Future<ui.Image> _render(CityData city, Postcard c, MyStore my) {
    final s = city.stations[c.station];
    final band = postcardLineColor(city, c);
    final look = lookOf(
      c,
      my,
    ).withSign(s == null ? null : StationSign(name: s.name.ja, sub: s.name.of('en').toUpperCase(), band: band));
    return renderSceneImage(
      look: look,
      part: dayPartOf(DateTime(2026, 1, 1, c.hour)),
      lineColor: band,
      weather: c.weather ?? WeatherKind.sunny,
      sky: skyOf(c),
      scale: 1,
      // The train standing at the platform.
      arrive: 1,
      tick: c.id % 997,
    );
  }
}

/// The front of a postcard: the picture in a white border, the station's
/// name like a printed caption, and the postmark over the corner.
class PostcardFront extends StatelessWidget {
  const PostcardFront({super.key, required this.city, required this.card, required this.my, this.small = false});
  final CityData city;
  final Postcard card;
  final MyStore my;

  /// Album grid: a lighter postmark and smaller text.
  final bool small;

  @override
  Widget build(BuildContext context) {
    final lang = langOf(context);
    final name = _name(city, card.station, 'ja');
    final sub = lang == 'ja' ? _name(city, card.station, 'en') : _name(city, card.station, lang);
    final pad = small ? 5.0 : 10.0;
    return AspectRatio(
      aspectRatio: postcardAspect,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(small ? 6 : 10),
          border: Border.all(color: _paperEdge),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(small ? 3 : 5),
                child: FutureBuilder<ui.Image>(
                  future: PostcardPictures.of(city, card, my),
                  builder: (context, snap) => snap.data == null
                      ? const ColoredBox(color: Color(0xFFE9EEF3))
                      : CustomPaint(painter: _CropPainter(snap.data!)),
                ),
              ),
              // The caption, like the print on a picture postcard.
              Positioned(
                left: small ? 6 : 10,
                bottom: small ? 5 : 9,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: small ? 5 : 8, vertical: small ? 2 : 4),
                  decoration: BoxDecoration(color: const Color(0xCCFFFFFF), borderRadius: BorderRadius.circular(4)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PixelText(name, size: small ? 12 : 18, color: _ink),
                      if (!small) PixelText(sub, size: 10, color: PixelColors.muted),
                    ],
                  ),
                ),
              ),
              if (card.gold || card.first)
                Positioned(
                  left: small ? 5 : 8,
                  top: small ? 5 : 8,
                  child: _Tag(
                    text: card.gold ? '★' : _t('はじめて', '첫 방문', 'First visit').of(lang),
                    color: card.gold ? _gold : const Color(0xFF3F8F5A),
                    small: small,
                  ),
                ),
              Positioned(
                right: small ? -2 : 4,
                bottom: small ? -4 : 2,
                child: Transform.rotate(
                  angle: -0.18,
                  child: Postmark(
                    station: name,
                    date: card.day.replaceAll('-', '.'),
                    size: small ? 46 : 78,
                    opacity: small ? 0.75 : 0.85,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color, required this.small});
  final String text;
  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: small ? 4 : 7, vertical: small ? 1 : 3),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
    child: PixelText(text, size: small ? 10 : 12, color: Colors.white),
  );
}

/// The back: the written message (or the user's own line) on ruled paper,
/// a stamp in the line's colour and the postmark over it.
class PostcardBack extends StatelessWidget {
  const PostcardBack({super.key, required this.city, required this.card});
  final CityData city;
  final Postcard card;

  @override
  Widget build(BuildContext context) {
    final lang = langOf(context);
    final color = postcardLineColor(city, card);
    final text = card.memo.isEmpty ? postcardMessage(city, card, lang) : card.memo;
    return AspectRatio(
      aspectRatio: postcardAspect,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _paperEdge),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final k = box.maxWidth / 340;
            return Padding(
              padding: EdgeInsets.all(14 * k),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: CustomPaint(
                      painter: _RulesPainter(gap: 26 * k),
                      child: Padding(
                        padding: EdgeInsets.only(top: 4 * k, right: 8 * k),
                        child: Text(
                          text,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: pixelStyle(size: 13.5 * k, color: _ink, height: 26 * k / (13.5 * k)),
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, color: _paperEdge),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: EdgeInsets.only(left: 10 * k),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SizedBox(
                            height: 78 * k,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                _Stamp(color: color, station: _name(city, card.station, 'ja'), k: k),
                                Positioned(
                                  left: -34 * k,
                                  top: 14 * k,
                                  child: Transform.rotate(
                                    angle: -0.2,
                                    child: Postmark(
                                      station: _name(city, card.station, 'ja'),
                                      date: card.day.replaceAll('-', '.'),
                                      size: 62 * k,
                                      opacity: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          PixelText(postcardDate(card), size: 11 * k, color: PixelColors.muted),
                          SizedBox(height: 6 * k),
                          Container(height: 1, color: _paperEdge),
                          SizedBox(height: 8 * k),
                          PixelText(
                            _t('つぎはメトロ MY駅', '쓰기와 메트로 MY역', 'Tsugiwa Metro, MY Station').of(lang),
                            size: 11 * k,
                            color: _ink,
                          ),
                          SizedBox(height: 6 * k),
                          Container(height: 1, color: _paperEdge),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A postage stamp in the line's colour: perforated edge, a little train and
/// the station name.
class _Stamp extends StatelessWidget {
  const _Stamp({required this.color, required this.station, required this.k});
  final Color color;
  final String station;
  final double k;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _PerforationPainter(),
    child: Container(
      width: 58 * k,
      height: 72 * k,
      padding: EdgeInsets.all(5 * k),
      child: Container(
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.train_rounded, size: 24 * k, color: Colors.white),
            SizedBox(height: 2 * k),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 2 * k),
              child: FittedBox(child: PixelText(station, size: 11, color: Colors.white, maxLines: 1)),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PerforationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(r, Paint()..color = Colors.white);
    // Little bites out of the edge.
    final bite = Paint()..color = _paper;
    final d = size.width / 9;
    for (var x = d / 2; x < size.width; x += d) {
      canvas.drawCircle(Offset(x, 0), d * 0.28, bite);
      canvas.drawCircle(Offset(x, size.height), d * 0.28, bite);
    }
    for (var y = d / 2; y < size.height; y += d) {
      canvas.drawCircle(Offset(0, y), d * 0.28, bite);
      canvas.drawCircle(Offset(size.width, y), d * 0.28, bite);
    }
  }

  @override
  bool shouldRepaint(_PerforationPainter old) => false;
}

/// A round postmark (消印): station name on top, the date across the
/// middle between two bars, slightly faded ink.
class Postmark extends StatelessWidget {
  const Postmark({super.key, required this.station, required this.date, this.size = 70, this.opacity = 0.85});
  final String station;
  final String date;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _PostmarkPainter(station, date, opacity)),
  );
}

class _PostmarkPainter extends CustomPainter {
  _PostmarkPainter(this.station, this.date, this.opacity);
  final String station;
  final String date;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 1.5;
    final ink = _postmark.withValues(alpha: opacity);
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, size.width / 36);
    canvas.drawCircle(c, r, line);
    final barY = r * 0.32;
    canvas.drawLine(Offset(c.dx - r * 0.94, c.dy - barY), Offset(c.dx + r * 0.94, c.dy - barY), line);
    canvas.drawLine(Offset(c.dx - r * 0.94, c.dy + barY), Offset(c.dx + r * 0.94, c.dy + barY), line);
    void text(String s, double y, double fs, double maxW) {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontFamily: 'DotGothic16',
            fontFamilyFallback: const ['Galmuri11'],
            fontSize: fs,
            color: ink,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: r * 1.8);
      final scale = tp.width > maxW ? maxW / tp.width : 1.0;
      canvas.save();
      canvas.translate(c.dx, y);
      canvas.scale(scale, 1);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    text(station, c.dy - r * 0.62, size.width * 0.17, r * 1.3);
    text(date, c.dy, size.width * 0.15, r * 1.7);
    text('つぎはメトロ', c.dy + r * 0.56, size.width * 0.11, r * 1.1);
  }

  @override
  bool shouldRepaint(_PostmarkPainter old) => old.station != station || old.date != date || old.opacity != opacity;
}

class _RulesPainter extends CustomPainter {
  _RulesPainter({required this.gap});
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _paperEdge
      ..strokeWidth = 1;
    for (var y = gap + 2; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width - 8, y), p);
    }
  }

  @override
  bool shouldRepaint(_RulesPainter old) => old.gap != gap;
}

/// The scene picture cropped to the postcard's shape around the platform,
/// art pixels kept crisp.
class _CropPainter extends CustomPainter {
  _CropPainter(this.image);
  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final ih = image.height.toDouble(), iw = image.width.toDouble();
    final k = image.width / SceneArt.width;
    var w = ih * size.width / size.height;
    var h = ih;
    if (w > iw) {
      w = iw;
      h = iw * size.height / size.width;
    }
    final left = (SceneArt.focusX * k - w / 2).clamp(0.0, iw - w);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(left, (ih - h) / 2, w, h),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.image != image;
}
