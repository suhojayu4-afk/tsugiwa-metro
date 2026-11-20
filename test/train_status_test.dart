import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/data/realtime/train_status.dart';

import 'trip_logic_test.dart' show loadTokyo;

void main() {
  test('ODPT 運行情報: delays and normal running, by our line ids; others ignored', () {
    final items = [
      {
        'odpt:operator': 'odpt.Operator:TokyoMetro',
        'odpt:railway': 'odpt.Railway:TokyoMetro.Marunouchi',
        'odpt:trainInformationStatus': {'ja': '遅延', 'en': 'Delay'},
        'odpt:trainInformationText': {'ja': '信号確認の影響で、一部列車に遅れが出ています。', 'en': 'Some trains are delayed.'},
      },
      {
        'odpt:operator': 'odpt.Operator:TokyoMetro',
        'odpt:railway': 'odpt.Railway:TokyoMetro.Ginza',
        'odpt:trainInformationText': {'ja': '平常どおり運転しています。', 'en': 'Service is operating normally.'},
      },
      // Not under a licence we may use in the app.
      {
        'odpt:operator': 'odpt.Operator:JR-East',
        'odpt:railway': 'odpt.Railway:JR-East.Yamanote',
        'odpt:trainInformationStatus': {'ja': '運転見合わせ'},
      },
    ];
    final s = parseTrainInformation(items);
    expect(s['tokyo.marunouchi']!.normal, isFalse);
    expect(s['tokyo.marunouchi']!.status!.of('en'), 'Delay');
    expect(s['tokyo.ginza']!.normal, isTrue);
    expect(s.containsKey('tokyo.yamanote'), isFalse);
  });

  test('every ODPT railway we map is a line of ours; no key means no live data', () {
    final city = loadTokyo();
    for (final id in odptRailways.values) {
      expect(city.lines.any((l) => l.id == id), isTrue, reason: id);
    }
    final source = TrainStatusSource(key: '');
    expect(source.enabled, isFalse);
    source.start();
    expect(source.of('tokyo.ginza'), isNull);
    source.dispose();
  });
}
