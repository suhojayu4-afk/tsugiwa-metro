import 'package:flutter/foundation.dart';

import '../data/realtime/jrwest_live.dart';
import '../data/realtime/realtime_provider.dart';
import '../data/realtime/train_status.dart';
import '../data/last_train_alarm.dart';
import '../data/sticker_marks.dart';
import '../data/my_store.dart';
import '../data/route_store.dart';
import '../platform/home_widget_bridge.dart';
import '../platform/melody_player.dart';
import '../platform/purchases.dart';
import '../platform/live_status_bridge.dart';
import '../data/weather/weather_source.dart';
import '../features/trip/location_source.dart';
import '../features/trip/route_finder.dart';

/// Swappable outside services. Tests replace these with fakes; later steps
/// swap in ODPT for [realtime] without touching screen code.
class Services {
  static LocationSource location = const GeolocatorLocationSource();
  static WeatherSource weather = JmaWeatherSource();
  static RealtimeProvider realtime = const TimetableOnlyProvider();

  /// Live 運行情報 (ODPT); quiet without an access key.
  static TrainStatusSource status = TrainStatusSource();

  /// JR西日本's 運行情報 and train delays (Tottori only).
  static JrWestLive jrwest = JrWestLive();
  static RouteStore routes = RouteStore();
  static MyStore my = MyStore();

  /// Stickers stuck on route-map stations after trips.
  static StickerMarks stickers = StickerMarks();
  static LastTrainAlarm lastTrain = LastTrainAlarm();

  /// The latest weather from のりば, shared with the home screen widget.
  static final weatherNow = ValueNotifier<WeatherNow?>(null);

  /// The route set on のりば (from → to), drawn boldly on the route map.
  static final chosenRoute = ValueNotifier<RouteResult?>(null);
  static Purchases purchases = const NotReadyPurchases();
  static HomeWidgetBridge homeWidget = MethodChannelHomeWidget();
  static LiveStatusBridge live = MethodChannelLiveStatusBridge();
  static MelodyPlayer melody = const MelodyPlayer();

  /// After 設定 → データをすべて消す: what was read from the phone's store is
  /// dropped, so the screens built next start empty.
  static void reset() {
    my = MyStore();
    routes = RouteStore();
    stickers = StickerMarks();
    lastTrain = LastTrainAlarm();
    chosenRoute.value = null;
  }
}
