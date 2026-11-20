import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/localized_text.dart';
import '../data/my_store.dart';

/// 月間乗車レポート: on the 1st of every month at 9:00 Japan time the phone
/// says "last month's ride report is ready", only when the user rode at
/// least once that month (Android and iPhone; elsewhere this does nothing).
///
/// The alarm itself lives in android/.../MonthlyReport.kt (iPhone:
/// ios/Runner/AppDelegate.swift, a local notification), so it rings while
/// the app is closed. This side tells it which months had rides and the
/// texts in the app's language, again whenever the trip log changes.
/// Tapping the notification opens the MY tab.
class MonthlyReport {
  MonthlyReport._();

  static const _channel = MethodChannel('tsugiwa/monthly');

  /// Month names for the English title.
  static const _enMonths = [
    'January', 'February', 'March', 'April', 'May', 'June', //
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const body = LocalizedText({'ja': 'シェアしてみよう', 'ko': '친구에게 공유해 보세요', 'en': 'Share it with your friends'});

  static const channelName = LocalizedText({'ja': '月間乗車レポート', 'ko': '월간 승차 리포트', 'en': 'Monthly ride report'});

  /// The notification title for [month] (1..12) in [lang].
  static String title(String lang, int month) => switch (lang) {
    'ko' => '$month월 승차 리포트가 나왔어요 🚃',
    'en' => 'Your ${_enMonths[month - 1]} ride report is ready 🚃',
    _ => '$month月の乗車レポートができました 🚃',
  };

  /// "yyyy-mm" of every month with at least one finished trip.
  static List<String> rideMonths(Iterable<TripLog> trips) {
    final out = <String>{
      for (final t in trips)
        if (t.day.length >= 7) t.day.substring(0, 7),
    };
    return out.toList()..sort();
  }

  /// When the next notice comes after [now]: the next 1st of a month, 9:00
  /// in Japan (UTC+9, no summer time), as a UTC time.
  static DateTime nextNotice(DateTime now) {
    final jst = now.toUtc().add(const Duration(hours: 9));
    // 9:00 in Japan is 0:00 UTC on the same day.
    var at = DateTime.utc(jst.year, jst.month, 1);
    if (!at.isAfter(now.toUtc())) at = DateTime.utc(jst.year, jst.month + 1, 1);
    return at;
  }

  /// "yyyy-mm" of the month a notice at [at] reports on: the one before.
  static String reportMonth(DateTime at) {
    final jst = at.toUtc().add(const Duration(hours: 9));
    final m = DateTime.utc(jst.year, jst.month - 1, 1);
    return '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}';
  }

  /// Whether the notice at [at] shows: last month had a ride.
  static bool shows(Iterable<TripLog> trips, DateTime at) => rideMonths(trips).contains(reportMonth(at));

  /// The app's language: the phone's, else Japanese (as in app.dart).
  static String deviceLang() {
    final code = PlatformDispatcher.instance.locale.languageCode;
    return const ['ja', 'ko', 'en'].contains(code) ? code : 'ja';
  }

  /// Hands the months with rides and the texts to the phone's alarm.
  static Future<void> schedule(List<TripLog> trips, {String? lang}) async {
    final l = lang ?? deviceLang();
    // Only the recent months matter; keep the saved list small.
    final months = rideMonths(trips);
    await _call('schedule', {
      'months': months.length > 13 ? months.sublist(months.length - 13) : months,
      'titles': [for (var m = 1; m <= 12; m++) title(l, m)],
      'text': body.of(l),
      'channel': channelName.of(l),
    });
  }

  static Future<void> cancel() => _call('cancel', null);

  static String? _sent;

  /// Keeps the alarm in step with [store] (now and on every change), and
  /// calls [openMy] when the user taps the notification.
  static void attach(MyStore store, {required VoidCallback openMy}) {
    void sync() {
      if (!store.loaded) return;
      final lang = deviceLang();
      final key = '$lang|${rideMonths(store.trips).join(',')}';
      if (key == _sent) return;
      _sent = key;
      schedule(store.trips, lang: lang);
    }

    store.addListener(sync);
    sync();
    if (!_isPhone) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openMy') openMy();
    });
    _channel
        .invokeMethod<bool>('takeOpenMy')
        .then((open) {
          if (open == true) openMy();
        })
        .catchError((Object _) {});
  }

  static bool get _isPhone =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> _call(String method, Object? args) async {
    if (!_isPhone) return;
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // Tests and builds without the native part.
    } on PlatformException {
      // A failed notice must never break the app.
    }
  }
}
