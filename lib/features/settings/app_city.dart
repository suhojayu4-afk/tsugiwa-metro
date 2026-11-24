import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/localized_text.dart';

/// The city shown (設定 → 都市): Tokyo comes with the app; other cities'
/// route maps are received there first (Tottori–Yonago), then can be
/// switched to. Coins and MY items are shared, stamps belong to each
/// city's stations. (Later all cities become one map.)
class AppCity {
  static const key = 'settings.city';
  static const receivedKey = 'settings.cities';
  static const choices = ['tokyo', 'tottori', 'osaka', 'fukuoka', 'sendai', 'sapporo'];
  static const names = {
    'tokyo': LocalizedText({'ja': '東京・関東', 'ko': '도쿄·간토', 'en': 'Tokyo & Kanto'}),
    'tottori': LocalizedText({'ja': '鳥取・米子', 'ko': '돗토리·요나고', 'en': 'Tottori & Yonago'}),
    'osaka': LocalizedText({'ja': '大阪', 'ko': '오사카', 'en': 'Osaka'}),
    'fukuoka': LocalizedText({'ja': '福岡', 'ko': '후쿠오카', 'en': 'Fukuoka'}),
    'sendai': LocalizedText({'ja': '仙台・松島', 'ko': '센다이·마쓰시마', 'en': 'Sendai & Matsushima'}),
    'sapporo': LocalizedText({'ja': '札幌・小樽', 'ko': '삿포로·오타루', 'en': 'Sapporo & Otaru'}),
  };

  /// Listened to by the city loader (lib/app.dart).
  static final ValueNotifier<String> current = ValueNotifier<String>('tokyo');

  /// Cities the user has received (Tokyo always).
  static final ValueNotifier<Set<String>> received = ValueNotifier<Set<String>>({'tokyo'});

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      received.value = {'tokyo', ...?prefs.getStringList(receivedKey)?.where(choices.contains)};
      final saved = prefs.getString(key);
      current.value = choices.contains(saved) && received.value.contains(saved) ? saved! : 'tokyo';
    } catch (_) {
      // Storage not ready: Tokyo.
    }
  }

  /// Gets [city] ready (its data is read once, so the first switch is
  /// quick) and keeps it as received.
  static Future<void> receive(String city, {AssetBundle? bundle}) async {
    if (!choices.contains(city) || received.value.contains(city)) return;
    final b = bundle ?? rootBundle;
    try {
      for (final f in ['city.json', 'stations.json', 'lines.json', 'map.json']) {
        jsonDecode(await b.loadString('assets/cities/$city/$f'));
      }
    } catch (_) {
      // The data is in the app; a read problem shows later when it opens.
    }
    received.value = {...received.value, city};
    try {
      await (await SharedPreferences.getInstance()).setStringList(receivedKey, received.value.toList());
    } catch (_) {
      // Not saved: received until the app closes.
    }
  }

  static Future<void> set(String city) async {
    if (!choices.contains(city) || !received.value.contains(city) || city == current.value) return;
    current.value = city;
    try {
      await (await SharedPreferences.getInstance()).setString(key, city);
    } catch (_) {
      // Not saved: the choice still holds until the app closes.
    }
  }
}
