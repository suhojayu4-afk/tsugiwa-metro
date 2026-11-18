import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tsugiwa_metro/platform/live_status_bridge.dart';

LiveStatus status(int left, {String lang = 'ja'}) => LiveStatus(
  currentStation: '秋葉原',
  nextStation: '御徒町',
  destination: '上野',
  remainingStops: left,
  eta: DateTime(2026, 11, 17, 17, 44),
  progress: 0.5,
  lineColor: const Color(0xFF80C241),
  atStation: false,
  lineLabel: '山手線 内回り',
  lang: lang,
  currentIndex: 2,
  stopFractions: const [0, 0.3, 0.6, 1],
  segmentColors: const [Color(0xFF80C241), Color(0xFF80C241), Color(0xFFFF9500)],
);

void main() {
  test('wording follows the distance: far → near → last stop → arrived', () {
    String title(int left) => MethodChannelLiveStatusBridge.payload(status(left))['title'] as String;
    expect(title(6), '上野まで あと6駅');
    expect(title(2), 'あと2駅で 上野');
    expect(title(1), 'つぎは 上野');
    expect(title(0), '上野に到着');
    expect(MethodChannelLiveStatusBridge.payload(status(6))['text'], 'いま 秋葉原 → つぎ 御徒町');
  });

  test('payload carries the bar layout and line colours for the native view', () {
    final p = MethodChannelLiveStatusBridge.payload(status(3));
    expect(p['stops'], [0, 0.3, 0.6, 1]);
    expect(p['colors'], [0xFF80C241, 0xFF80C241, 0xFFFF9500]);
    expect(p['phase'], 'far');
    expect(p['sub'], '山手線 内回り · 17:44着');
    expect(p['short'], 'あと3駅');
  });

  test('Korean and English texts', () {
    expect(MethodChannelLiveStatusBridge.payload(status(2, lang: 'ko'))['title'], '2역 뒤 上野');
    expect(MethodChannelLiveStatusBridge.payload(status(1, lang: 'en'))['title'], 'Next: 上野');
  });
}
