import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/localized_text.dart';

/// Access token for the ODPT Center (公共交通オープンデータセンター), given at
/// build time: `flutter run --dart-define-from-file=secrets.json` with
/// `{"ODPT_KEY": "…"}` (secrets.json is not in git). Empty = no live data.
const odptKey = String.fromEnvironment('ODPT_KEY');

/// How a line runs now (運行情報).
@immutable
class LineStatus {
  const LineStatus({required this.lineId, required this.normal, required this.text, this.status});

  final String lineId;

  /// Running as usual (平常運転).
  final bool normal;

  /// The operator's own words, e.g. 「人身事故の影響で、遅れが出ています。」.
  final LocalizedText text;

  /// Short status when not normal, e.g. 「遅延」「運転見合わせ」.
  final LocalizedText? status;
}

/// ODPT railways we may use in a released app (公共交通オープンデータ基本ライセンス
/// or CC BY 4.0, checked 2026-11-19 in the ODPT catalogue) → our line ids.
/// JR East, Tokyu, Tobu, Seibu, Keio and Keikyu publish their live data only
/// under the Challenge *limited* licence (contest only), so they are left out.
const odptRailways = {
  'odpt.Railway:TokyoMetro.Ginza': 'tokyo.ginza',
  'odpt.Railway:TokyoMetro.Marunouchi': 'tokyo.marunouchi',
  'odpt.Railway:TokyoMetro.MarunouchiBranch': 'tokyo.marunouchi_branch',
  'odpt.Railway:TokyoMetro.Hibiya': 'tokyo.hibiya',
  'odpt.Railway:TokyoMetro.Tozai': 'tokyo.tozai',
  'odpt.Railway:TokyoMetro.Chiyoda': 'tokyo.chiyoda',
  'odpt.Railway:TokyoMetro.Yurakucho': 'tokyo.yurakucho',
  'odpt.Railway:TokyoMetro.Hanzomon': 'tokyo.hanzomon',
  'odpt.Railway:TokyoMetro.Namboku': 'tokyo.namboku',
  'odpt.Railway:TokyoMetro.Fukutoshin': 'tokyo.fukutoshin',
  'odpt.Railway:Toei.Asakusa': 'tokyo.toei_asakusa',
  'odpt.Railway:Toei.Mita': 'tokyo.toei_mita',
  'odpt.Railway:Toei.Shinjuku': 'tokyo.toei_shinjuku',
  'odpt.Railway:Toei.Oedo': 'tokyo.toei_oedo',
  'odpt.Railway:Toei.Arakawa': 'tokyo.toden_arakawa',
  'odpt.Railway:Toei.NipporiToneri': 'tokyo.nippori_toneri',
  'odpt.Railway:YokohamaMunicipal.Blue': 'tokyo.yokohama_blue',
  'odpt.Railway:YokohamaMunicipal.Green': 'tokyo.yokohama_green',
  'odpt.Railway:TWR.Rinkai': 'tokyo.rinkai',
  'odpt.Railway:MIR.TsukubaExpress': 'tokyo.tsukuba_express',
  'odpt.Railway:TamaMonorail.TamaMonorail': 'tokyo.tama_monorail',
};

/// Operators asked for (one request each).
const odptOperators = [
  'odpt.Operator:TokyoMetro',
  'odpt.Operator:Toei',
  'odpt.Operator:YokohamaMunicipal',
  'odpt.Operator:TWR',
  'odpt.Operator:MIR',
  'odpt.Operator:TamaMonorail',
];

/// Reads ODPT `odpt:TrainInformation` items into [LineStatus] by our line id.
/// Items for railways not in [odptRailways] are ignored. An item whose
/// `odpt:railway` is missing applies to all the operator's lines we know.
Map<String, LineStatus> parseTrainInformation(List<dynamic> items) {
  final out = <String, LineStatus>{};
  LocalizedText? text(Object? v) => switch (v) {
    final Map<String, dynamic> m when m.isNotEmpty => LocalizedText({
      for (final e in m.entries)
        if (e.value is String) e.key: e.value as String,
    }),
    final String s when s.isNotEmpty => LocalizedText({'ja': s}),
    _ => null,
  };
  for (final raw in items.whereType<Map<String, dynamic>>()) {
    final railway = raw['odpt:railway'] as String?;
    final operator = raw['odpt:operator'] as String?;
    final lines = railway != null
        ? [?odptRailways[railway]]
        : [
            for (final e in odptRailways.entries)
              if (operator != null && e.key.startsWith('odpt.Railway:${operator.split(':').last}.')) e.value,
          ];
    if (lines.isEmpty) continue;
    final status = text(raw['odpt:trainInformationStatus']);
    final words = text(raw['odpt:trainInformationText']) ?? const LocalizedText({'ja': '平常どおり運転しています'});
    // ODPT leaves the status out (or says 平常運転) when all is well.
    final normal = status == null || status.ja.contains('平常');
    for (final id in lines) {
      out[id] = LineStatus(lineId: id, normal: normal, text: words, status: normal ? null : status);
    }
  }
  return out;
}

/// Live 運行情報 from the ODPT Center, refreshed every few minutes while the
/// app runs. Without a key ([odptKey] empty) it stays empty and quiet.
class TrainStatusSource extends ChangeNotifier {
  TrainStatusSource({this.key = odptKey, http.Client? client, this.every = const Duration(minutes: 3)})
    : _client = client ?? http.Client();

  final String key;
  final http.Client _client;
  final Duration every;

  Map<String, LineStatus> _status = const {};
  DateTime? _updated;
  Timer? _timer;

  bool get enabled => key.isNotEmpty;

  /// When the data last came in (null = never).
  DateTime? get updated => _updated;

  /// Status of [lineId], or null when it is not a line with live data.
  LineStatus? of(String lineId) => _status[lineId] ?? _extra[lineId];

  /// 運行情報 from another source (JR西日本 for Tottori), shown alongside ODPT's.
  Map<String, LineStatus> _extra = const {};

  void putExtra(Map<String, LineStatus> status) {
    _extra = status;
    if (status.isNotEmpty) _updated = DateTime.now();
    notifyListeners();
  }

  void start() {
    if (!enabled || _timer != null) return;
    refresh();
    _timer = Timer.periodic(every, (_) => refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() async {
    if (!enabled) return;
    final next = <String, LineStatus>{};
    for (final op in odptOperators) {
      try {
        final uri = Uri.https('api.odpt.org', '/api/v4/odpt:TrainInformation', {
          'odpt:operator': op,
          'acl:consumerKey': key,
        });
        final res = await _client.get(uri).timeout(const Duration(seconds: 12));
        if (res.statusCode != 200) continue;
        next.addAll(parseTrainInformation(jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>));
      } catch (_) {
        // No network, or the service is busy: keep what we had.
      }
    }
    if (next.isEmpty) return;
    _status = next;
    _updated = DateTime.now();
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    _client.close();
    super.dispose();
  }
}
