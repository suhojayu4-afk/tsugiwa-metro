import 'package:flutter/foundation.dart';

import '../data/realtime/realtime_provider.dart';
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
}
