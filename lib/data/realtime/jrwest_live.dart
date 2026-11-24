import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/localized_text.dart';
import 'train_status.dart';

/// JR西日本's own web data for Tottori: 運行情報 (trafficinfo) and 列車走行位置
/// (train-guide: where each train is and how late). Not open data: for the
/// owner's own use; check JR西日本's terms before a public release, or build
/// with `--dart-define=JRWEST_LIVE=false` to leave it out.
const jrWestLiveOn = bool.fromEnvironment('JRWEST_LIVE', defaultValue: true);

/// 運行情報 line names (中国エリア / 山陰地区) → our lines (expresses follow the line they run on).
const jrWestTrafficLines = {
  '山陰線': ['tottori.sanin', 'tottori.matsukaze'],
  '因美線': ['tottori.inbi', 'tottori.hakuto'],
  '境線': ['tottori.sakai'],
  '伯備線': ['tottori.hakubi', 'tottori.yakumo'],
};

/// 列車走行位置 pages that cover our lines: 東浜–米子, 鳥取–智頭, 米子–新郷.
const jrWestGuideLines = ['sanin3', 'imbi1', 'hakubi2'];

/// One train seen on 列車走行位置.
@immutable
class LiveTrain {
  const LiveTrain({required this.no, required this.delayMin, required this.dest, required this.at, this.next});

  final String no;
  final int delayMin;
  final String dest;

  /// Station (Japanese name) it is at, or has just left.
  final String at;

  /// Next station (Japanese name) while running between two; null = standing at [at].
  final String? next;
}

/// Reads trafficinfo.json: every listed line of 山陰地区 with its trouble,
/// the others running normally.
Map<String, LineStatus> parseJrWestTraffic(Map<String, dynamic> json) {
  final out = <String, LineStatus>{};
  const normalText = LocalizedText({'ja': '平常どおり運転しています', 'ko': '평소대로 운행 중', 'en': 'Running normally'});
  for (final e in jrWestTrafficLines.entries) {
    for (final id in e.value) {
      out[id] = LineStatus(lineId: id, normal: true, text: normalText);
    }
  }
  for (final area in (json['areaTrafficInfos'] as List? ?? const []).cast<Map<String, dynamic>>()) {
    final days = (area['dailyData'] as List? ?? const []).cast<Map<String, dynamic>>();
    if (days.isEmpty) continue;
    for (final place in (days.first['placeTrafficInfos'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      for (final line in (place['conventionalLineTrafficInfos'] as List? ?? const []).cast<Map<String, dynamic>>()) {
        final ids = jrWestTrafficLines[line['lineName']];
        if (ids == null) continue;
        final details = (line['conventionalLineTrafficInfoDetails'] as List? ?? const []).cast<Map<String, dynamic>>();
        if (details.isEmpty) continue;
        final d = details.first;
        final versions = (d['versionDetail'] as List? ?? const []).cast<Map<String, dynamic>>();
        final body = versions.isEmpty ? null : versions.first['body'] as String?;
        final title = versions.isEmpty ? null : versions.first['title'] as String?;
        final condition = d['conditionName'] as String? ?? '遅れ';
        final cause = d['cause'] as String?;
        final words = (body ?? title ?? '$condition${cause == null ? '' : '（$cause）'}').trim();
        // 「運転見合わせの可能性あり」 is a warning, still a trouble to show.
        for (final id in ids) {
          out[id] = LineStatus(
            lineId: id,
            normal: false,
            text: LocalizedText({'ja': words}),
            status: LocalizedText({'ja': condition}),
          );
        }
      }
    }
  }
  return out;
}

/// Reads one 列車走行位置 page (trains) with its station list (code → name).
List<LiveTrain> parseTrainGuide(Map<String, dynamic> json, Map<String, String> names) {
  final out = <LiveTrain>[];
  for (final t in (json['trains'] as List? ?? const []).cast<Map<String, dynamic>>()) {
    final no = t['no'] as String?;
    final pos = (t['pos'] as String? ?? '').split('_');
    if (no == null || pos.isEmpty) continue;
    final at = names[pos.first];
    if (at == null) continue;
    final next = pos.length > 1 ? names[pos[1]] : null;
    out.add(
      LiveTrain(
        no: no,
        delayMin: (t['delayMinutes'] as num?)?.toInt() ?? 0,
        dest: t['dest'] as String? ?? '',
        at: at,
        next: next,
      ),
    );
  }
  return out;
}

/// Station codes → names of one 列車走行位置 page (…_st.json).
Map<String, String> parseGuideStations(Map<String, dynamic> json) => {
  for (final s in (json['stations'] as List? ?? const []).cast<Map<String, dynamic>>())
    if (s['info'] case {'code': final String code, 'name': final String name}) code: name,
};

/// Polls JR西日本 every minute while Tottori is open: line trouble into
/// [TrainStatusSource] and each train's delay (by train number).
class JrWestLive extends ChangeNotifier {
  JrWestLive({http.Client? client, this.every = const Duration(minutes: 1), this.enabled = jrWestLiveOn})
    : _client = client ?? http.Client();

  final http.Client _client;
  final Duration every;
  final bool enabled;

  Timer? _timer;
  final Map<String, Map<String, String>> _names = {};
  Map<String, LiveTrain> _trains = const {};
  DateTime? _updated;
  TrainStatusSource? _status;

  /// When the train positions last came in.
  DateTime? get updated => _updated;

  /// Live trains by number (fresh within the last few minutes).
  Map<String, LiveTrain> get trains => _fresh ? _trains : const {};

  bool get _fresh => _updated != null && DateTime.now().difference(_updated!).inMinutes < 5;

  /// Minutes [trainNo] runs late (0 when on time or not seen).
  int delayOf(String trainNo) => trains[trainNo]?.delayMin ?? 0;

  void start(TrainStatusSource status) {
    if (!enabled || _timer != null) return;
    _status = status;
    refresh();
    _timer = Timer.periodic(every, (_) => refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _status?.putExtra(const {});
    _trains = const {};
    notifyListeners();
  }

  Future<Map<String, dynamic>?> _get(String url) async {
    try {
      final res = await _client
          .get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      return null; // No network: keep what we had.
    }
  }

  Future<void> refresh() async {
    if (!enabled) return;
    final traffic = await _get('https://trafficinfo.westjr.co.jp/api/v1/trafficinfo.json');
    if (traffic != null) _status?.putExtra(parseJrWestTraffic(traffic));
    final next = <String, LiveTrain>{};
    var any = false;
    for (final line in jrWestGuideLines) {
      final names = _names[line] ??= parseGuideStations(
        await _get('https://www.train-guide.westjr.co.jp/api/v3/${line}_st.json') ?? const {},
      );
      if (names.isEmpty) _names.remove(line);
      final json = await _get('https://www.train-guide.westjr.co.jp/api/v3/$line.json');
      if (json == null) continue;
      any = true;
      for (final t in parseTrainGuide(json, names)) {
        next[t.no] = t;
      }
    }
    if (any) {
      _trains = next;
      _updated = DateTime.now();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _client.close();
    super.dispose();
  }
}
