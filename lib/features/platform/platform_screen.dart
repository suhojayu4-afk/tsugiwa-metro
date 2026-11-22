import '../../data/car_guide.dart';
import 'car_guide_card.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/japan_time.dart';
import '../../core/pixel/pixel_scene.dart' show DayPart, StationSign, dayPartOf;
import '../../core/pixel/pixel_ui.dart';
import '../../core/services.dart';
import '../../data/congestion/congestion_source.dart';
import '../../data/congestion/estimate_congestion.dart';
import '../../data/last_train_alarm.dart';
import '../../platform/next_widget_art.dart';
import '../../data/models/city.dart';
import '../../data/models/timetable.dart';
import '../../data/weather/weather_source.dart';
import '../../l10n/app_localizations.dart';
import '../my_room/my_room_screen.dart' show CoinIcon;
import '../my_room/station_plate.dart';
import '../settings/settings_screen.dart' show openCities;
import 'led_destination.dart';
import '../../data/models/station.dart';
import '../trip/route_finder.dart';
import '../trip/trip_controller.dart';
import '../trip/trip_plan.dart';
import '../trip/trip_screen.dart';
import 'context_card.dart';
import 'departure_board.dart';
import '../guide/guide_card.dart';
import '../guide/guide_data.dart';
import '../guide/guide_tips.dart';
import '../../data/route_store.dart';
import 'nearest_station.dart';
import 'platform_texts.dart';
import 'station_picker.dart';
import 'weather_card.dart';

/// のりば tab: choose where you leave from and where you are going.
class PlatformScreen extends StatefulWidget {
  const PlatformScreen({super.key, required this.city, this.onOpenMy});
  final CityData city;

  /// Go to MY: with an item id to open its purchase sheet, [coinShop] for
  /// the coin shop, or null for the MY screen itself.
  final ValueChanged<String?>? onOpenMy;

  static const coinShop = 'coins';

  @override
  State<PlatformScreen> createState() => PlatformScreenState();
}

/// Short weather line for the home screen widget, e.g. 「雨 9.8°C」.
String _weatherText(AppLocalizations t, WeatherNow w) {
  final label = switch (w.kind) {
    WeatherKind.sunny => t.weatherSunny,
    WeatherKind.cloudy => t.weatherCloudy,
    WeatherKind.rain => t.weatherRain,
    WeatherKind.snow => t.weatherSnow,
    WeatherKind.unknown => t.weatherUnknown,
  };
  return w.tempC == null ? label : '$label ${w.tempC!.toStringAsFixed(1)}°C';
}

class PlatformScreenState extends State<PlatformScreen> {
  /// 乗換便利号車 data for this city (`assets/cities/<id>/cars.json`).
  late final Future<CarGuide> _cars = CarGuide.load(cityId: widget.city.id);

  /// From the route map: use [stationId] as the start or the destination.
  void setStation(String stationId, {required bool from}) {
    setState(() {
      if (from) {
        _fromId = stationId;
      } else {
        _toId = stationId;
      }
      _locationNote = null;
    });
  }

  String? _fromId;
  String? _toId;

  /// Exits and courses for the attendant's tips.
  GuideData _guide = const GuideData();

  /// Lines to avoid for this from → to, set by 「このルートにする」 after a
  /// last train has gone.
  Set<String> _avoid = const {};
  String? _avoidFor;

  RouteResult? get _route => (_fromId != null && _toId != null)
      ? RouteFinder(widget.city).find(_fromId!, _toId!, avoid: _avoidFor == '$_fromId>$_toId' ? _avoid : const {})
      : null;

  WeatherNow? _weather;

  /// Header picture shape: width / height. 2.0 = wide, smaller = taller.
  static const _sceneAspect = 1.8;

  RouteStore get _store => Services.routes;

  @override
  void initState() {
    super.initState();
    _sheet.addListener(_onSheet);
    GuideData.load(widget.city.id).then((g) {
      if (mounted) setState(() => _guide = g);
    });
    _store.addListener(_onStore);
    Services.my.addListener(_onStore);
    if (!Services.my.loaded) Services.my.load();
    // The stations chosen last time come back at launch.
    if (_store.loaded) {
      _restoreLast();
    } else {
      _store.load().then((_) {
        if (mounted) setState(_restoreLast);
      });
    }
    _alarm.addListener(_onStore);
    // Set the alarm again with today's texts (the language may have changed).
    // Never asks for the notification permission here: only the bell does.
    (_alarm.loaded ? Future<void>.value() : _alarm.load()).then((_) {
      if (mounted) _alarm.refresh(widget.city, _alarmTexts);
    });
    _alarm.loadFirst();
  }

  LastTrainAlarm get _alarm => Services.lastTrain;

  /// Whether the last choice has been put back (from then on every change
  /// is remembered; see [build]).
  bool _restored = false;

  void _restoreLast() {
    if (_restored) return;
    _restored = true;
    // Already chosen (from the route map): keep that.
    if (_fromId != null || _toId != null) return;
    final stations = widget.city.stations;
    final from = _store.lastFromId, to = _store.lastToId;
    if (from != null && stations.containsKey(from)) _fromId = from;
    if (to != null && stations.containsKey(to)) _toId = to;
  }

  LastTrainTexts _alarmTexts(int lastDep) {
    final t = AppLocalizations.of(context);
    final lang = langOf(context);
    final from = widget.city.station(_alarm.fromId ?? _fromId!).name.of(lang);
    final to = widget.city.station(_alarm.toId ?? _toId!).name.of(lang);
    return (
      title: t.lastTrainWarn(LastTrainAlarm.leadMin),
      body: t.lastTrainAlarmBody(from, to, LastTrainAlarm.clock(lastDep)),
      channel: t.lastTrainAlarm,
    );
  }

  /// 🔔 next to 「始発まで…」: remind me once before the first train.
  Future<void> _toggleFirstAlarm() async {
    final from = _fromId, to = _toId;
    final route = _route;
    if (from == null || to == null || route == null) return;
    final tt = widget.city.timetables[route.legs.first.lineId];
    final jst = japanNow();
    final away = tt?.minutesToFirstTrain(jst);
    if (tt == null || away == null) return;
    final t = AppLocalizations.of(context);
    final lang = langOf(context);
    final messenger = ScaffoldMessenger.of(context);
    final first = LineTimetable.clock(tt.firstTrainMin);
    String text;
    var seconds = 3;
    if (_alarm.firstOnFor(from, to)) {
      await _alarm.turnOffFirst();
      text = t.firstTrainAlarmOff;
    } else {
      // Waits for the answer to the notification question, so the message
      // comes after it and says what really happened.
      final notice = await _alarm.turnOnFirst(
        from: from,
        to: to,
        firstMin: tt.firstTrainMin,
        minutesAway: away,
        texts: (
          title: t.firstTrainAlarmTitle(LastTrainAlarm.leadMin),
          body: t.firstTrainAlarmBody(
            widget.city.station(from).name.of(lang),
            widget.city.station(to).name.of(lang),
            first,
          ),
          channel: t.lastTrainAlarm,
        ),
      );
      final at = LineTimetable.clock(tt.firstTrainMin - LastTrainAlarm.leadMin);
      text = switch (notice) {
        AlarmNotice.on => t.firstTrainAlarmSet(at, first),
        AlarmNotice.off => fill(firstAlarmNotificationsOff, lang, {'alarm': at, 'time': first}),
        AlarmNotice.unsure => '${t.firstTrainAlarmSet(at, first)}\n${alarmNeedsNotifications.of(lang)}',
      };
      if (notice != AlarmNotice.on) seconds = 6;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: Duration(seconds: seconds),
        ),
      );
  }

  /// 🔔 on the next-train card: remind me every night before the last train.
  Future<void> _toggleAlarm() async {
    final from = _fromId, to = _toId;
    if (from == null || to == null) return;
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    String text;
    var seconds = 3;
    if (_alarm.isOnFor(from, to)) {
      await _alarm.turnOff();
      text = t.lastTrainAlarmOff;
    } else {
      final lang = langOf(context);
      // Waits for the answer to the notification question: the message comes
      // after it, and never says "set" when notifications are off.
      final set = await _alarm.turnOn(widget.city, from, to, (d) {
        return (
          title: t.lastTrainWarn(LastTrainAlarm.leadMin),
          body: t.lastTrainAlarmBody(
            widget.city.station(from).name.of(lang),
            widget.city.station(to).name.of(lang),
            LastTrainAlarm.clock(d),
          ),
          channel: t.lastTrainAlarm,
        );
      });
      if (set == null) return;
      final at = LastTrainAlarm.clock(set.lastDep - LastTrainAlarm.leadMin), last = LastTrainAlarm.clock(set.lastDep);
      text = switch (set.notice) {
        AlarmNotice.on => t.lastTrainAlarmSet(at, last),
        AlarmNotice.off => fill(alarmNotificationsOff, lang, {'alarm': at, 'time': last}),
        AlarmNotice.unsure => '${t.lastTrainAlarmSet(at, last)}\n${alarmNeedsNotifications.of(lang)}',
      };
      if (set.notice != AlarmNotice.on) seconds = 6;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: Duration(seconds: seconds),
        ),
      );
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    Services.my.removeListener(_onStore);
    _alarm.removeListener(_onStore);
    _noteTimer?.cancel();
    _sheet.removeListener(_onSheet);
    _sheet.dispose();
    super.dispose();
  }

  void _onStore() {
    if (mounted) {
      setState(() {});
      _syncWidgetInfo();
    }
  }

  String? _widgetInfoKey;

  /// [hour]:30 today in Japan (as a plain DateTime, like the timetables use).
  static DateTime _jstToday(int hour) {
    final j = japanNow();
    return DateTime.utc(j.year, j.month, j.day, hour, 30);
  }

  /// Both home screen widgets show today's information: the weather and the
  /// usual route (the 終電アラーム one, else the first favourite, else the
  /// latest) with its last and first train.
  void _syncWidgetInfo() {
    final t = AppLocalizations.of(context);
    final lang = langOf(context);
    final city = widget.city;
    final w = Services.weatherNow.value;
    final alarmFrom = _alarm.fromId, alarmTo = _alarm.toId;
    final saved = alarmFrom != null && alarmTo != null
        ? SavedRoute(alarmFrom, alarmTo)
        : (_store.favourites.firstOrNull ?? _store.recents.firstOrNull);
    final info = <String, Object?>{
      'weather': w == null ? '' : _weatherText(t, w),
      'rain': w == null
          ? ''
          : w.wetLater || w.kind == WeatherKind.rain || w.kind == WeatherKind.snow
          ? t.umbrellaReminder
          : (w.rainChance == null ? '' : '${t.rainChanceLabel} ${w.rainChance}%'),
      'wet': w != null && (w.wetLater || w.kind == WeatherKind.rain || w.kind == WeatherKind.snow),
      'route': '',
    };
    final ok = saved != null && city.stations.containsKey(saved.fromId) && city.stations.containsKey(saved.toId);
    final route = ok ? RouteFinder(city).find(saved.fromId, saved.toId) : null;
    if (route != null) {
      final leg = route.legs.first;
      final line = city.line(leg.lineId);
      final last = lastDepartureMin(city, route);
      final tt = city.timetables[leg.lineId];
      info.addAll({
        'route': '${city.station(saved!.fromId).name.of(lang)} → ${city.station(saved.toId).name.of(lang)}',
        'line': '${line.name.of(lang)} ${line.directionName(leg.forward).of(lang)}',
        'lineColor': line.color.toARGB32(),
        'lastLabel': t.widgetLast,
        'lastTime': last == null ? '―' : LastTrainAlarm.clock(last),
        'firstLabel': t.widgetFirst,
        'firstTime': tt == null ? '' : LineTimetable.clock(tt.firstTrainMin),
        'alarm': _alarm.isOnFor(saved.fromId, saved.toId),
        // つぎの電車: the ride and how often trains come, hour by hour today
        // (the widget picks the hour itself).
        'tripText': t.widgetTrip(
          city.station(saved.toId).name.of(lang),
          (TripPlan.build(city, route, japanNow()).totalSec / 60).ceil() +
              route.headWalkMin(city) +
              route.tailWalkMin(city),
        ),
        'everyFormat': t.widgetEvery(999).replaceAll('999', '%d'),
        'endedText': tt == null ? '' : t.widgetEnded(LineTimetable.clock(tt.firstTrainMin)),
        'firstMin': tt?.firstTrainMin ?? -1,
        'lastMin': tt?.lastTrainMin ?? -1,
        'headways': [for (var h = 0; h < 24; h++) tt?.headwayMinAt(_jstToday(h)) ?? 0],
      });
    }
    final key = info.toString();
    if (key == _widgetInfoKey) return;
    _widgetInfoKey = key;
    Services.homeWidget.setInfo(info);
    if (route != null) {
      final leg = route.legs.first;
      // The widget's sky: what is falling now, what is coming, else the clouds.
      final month = japanNow().month;
      final winter = month == 12 || month <= 2;
      final sky = w == null
          ? 'clear'
          : w.kind == WeatherKind.rain
          ? 'rain'
          : w.kind == WeatherKind.snow
          ? 'snow'
          : w.wetLater
          ? (winter && (w.tempC == null || w.tempC! <= 3) ? 'snowsoon' : 'rainsoon')
          : w.kind == WeatherKind.cloudy
          ? 'cloudy'
          : 'clear';
      _syncNextArt(
        NextWidgetData(
          fromName: city.station(saved!.fromId).name.of(lang),
          toName: city.station(saved.toId).name.of(lang),
          fromColor: city.line(leg.lineId).color,
          toColor: city.line(route.legs.last.lineId).color,
          lineColor: city.line(leg.lineId).color,
          trip: info['tripText']! as String,
          last: '${info['lastLabel']} ${info['lastTime']}',
          alarm: info['alarm']! as bool,
          sky: sky,
          lineLabel: info['line']! as String,
          first: '${info['firstLabel']} ${info['firstTime']}',
          weather: info['weather']! as String,
          temp: w?.tempC == null ? '' : '${w!.tempC!.round()}°',
          rain: w?.rainChance == null ? '' : '${w!.rainChance}%',
        ),
        headways: info['headways']! as List<int>,
        t: t,
        route: info['route']! as String,
        rainText: info['rain']! as String,
      );
    }
  }

  String? _nextArtKey;

  /// つぎの電車 is one pixel picture per hour of the day (its sky — day,
  /// evening or night — and its "every N min"), plus one for after the last
  /// train; the widget picks the one for now. Redrawn only when something on
  /// it changes.
  Future<void> _syncNextArt(
    NextWidgetData d, {
    required List<int> headways,
    required AppLocalizations t,
    required String route,
    required String rainText,
  }) async {
    final key =
        '${d.fromName}|${d.toName}|${d.lineColor}|${d.trip}|${d.last}|${d.alarm}|${d.sky}|${d.temp}|${d.rain}|'
        '${d.weather}|$route|$rainText|'
        '$headways|${t.localeName}';
    if (key == _nextArtKey) return;
    _nextArtKey = key;
    try {
      final pngs = <String, Uint8List>{
        // 地下鉄案内: one per time of day.
        for (final part in DayPart.values) 'board_${part.name}': await renderBoardWidget(d, part),
        // MY駅: the info band, one per time of day.
        for (final part in DayPart.values) 'band_${part.name}': await renderMyBand(d, route, rainText, part),
        'full_end': await renderNextWidget(d, t.serviceEndedShort, DayPart.night),
        for (var h = 0; h < 24; h++)
          'full_h$h': await renderNextWidget(
            d,
            headways[h] > 0 ? t.widgetEvery(headways[h]) : t.serviceEndedShort,
            dayPartOf(DateTime(2026, 1, 1, h)),
          ),
      };
      await Services.homeWidget.setNextArt(pngs);
    } catch (e) {
      _nextArtKey = null;
      debugPrint('next widget art: $e');
    }
  }

  /// ☆ on the next-train card: save this route (asking what it is for), or
  /// remove it when it is already saved.
  Future<void> _toggleFavourite() async {
    final from = _fromId, to = _toId;
    if (from == null || to == null) return;
    if (_store.favouriteFor(from, to) != null) {
      await _store.removeFavourite(from, to);
      return;
    }
    final t = AppLocalizations.of(context);
    final kind = await showModalBottomSheet<FavouriteKind>(
      context: context,
      showDragHandle: true,
      backgroundColor: PixelColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PixelText(t.favChooseTitle, size: 18),
              const SizedBox(height: 12),
              for (final k in FavouriteKind.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: const Color(0xFFEFF7F1),
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: Icon(favouriteIcon(k), color: const Color(0xFF2E9447)),
                      title: PixelText(favouriteLabel(t, k), size: 17),
                      onTap: () => Navigator.pop(context, k),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (kind == null || !mounted) return;
    await _store.addFavourite(SavedRoute(from, to, kind: kind));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t.favAdded), duration: const Duration(seconds: 2)));
  }

  /// Long-press a favourite: confirm, then remove it.
  Future<void> _confirmRemove(SavedRoute f) async {
    final t = AppLocalizations.of(context);
    final lang = langOf(context);
    final name =
        '${widget.city.station(f.fromId).name.of(lang)} → '
        '${widget.city.station(f.toId).name.of(lang)}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PixelColors.card,
        content: PixelText(t.favRemoveConfirm(name), size: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel, style: const TextStyle(color: PixelColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.remove, style: const TextStyle(color: PixelColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) await _store.removeFavourite(f.fromId, f.toId);
  }

  bool _locating = false;
  String? _locationNote;

  /// The departure the note was written for: once another one is chosen the
  /// note ("nearest station: …") is no longer true and goes away.
  String? _locationNoteFrom;
  Timer? _noteTimer;

  /// 現在地から: put the nearest station into the departure field.
  Future<void> _useMyLocation() async {
    final t = AppLocalizations.of(context);
    final lang = langOf(context);
    _noteTimer?.cancel();
    setState(() {
      _locating = true;
      _locationNote = t.locating;
      _locationNoteFrom = _fromId;
    });
    final location = Services.location;
    final allowed = await location.ensurePermission();
    final fix = allowed ? await location.currentFix() : null;
    if (!mounted) return;
    final near = fix == null ? null : nearestStation(widget.city, fix.lat, fix.lng);
    setState(() {
      _locating = false;
      if (!allowed) {
        _locationNote = t.locationOff;
      } else if (near == null) {
        _locationNote = t.nearestNone;
      } else {
        _fromId = near.station.id;
        _locationNote = t.nearestFound(near.station.name.of(lang), near.meters.round());
      }
      _locationNoteFrom = _fromId;
    });
    // The distance is only true for a moment (you walk on): a short note.
    _noteTimer = Timer(const Duration(seconds: 12), () {
      if (mounted) setState(() => _locationNote = null);
    });
  }

  Future<void> _pick(bool isFrom) async {
    final id = await pickStation(context, widget.city);
    if (id == null || !mounted) return;
    setState(() => isFrom ? _fromId = id : _toId = id);
  }

  /// Expected crowding on the first line now (for the attendant's tips).
  CongestionLevel? _crowdNow(RouteResult? route) {
    final lineId = route?.legs.first.lineId ?? (_fromId == null ? null : widget.city.station(_fromId!).lines.first);
    if (lineId == null) return null;
    return EstimateCongestionSource.levelAt(lineId, japanNow());
  }

  /// Share the route with the route map (drawn boldly there).
  void _publishRoute(RouteResult? route) {
    if (Services.chosenRoute.value?.key == route?.key) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Services.chosenRoute.value = route;
    });
  }

  void _start(RouteResult route) {
    final from = _fromId, to = _toId;
    if (from != null && to != null) _store.addRecent(from, to);
    final plan = TripPlan.build(widget.city, route, japanNow());
    final controller = TripController(city: widget.city, plan: plan, lang: langOf(context));
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TripScreen(controller: controller)));
  }

  /// Height of the route panel when it is folded down: just enough for the
  /// two stations, one message line and the start button.
  static const _panelHeight = 232.0;

  /// The panel pulled all the way down: a slim bar (from → to and ▶).
  static const _barHeight = 78.0;
  final _sheet = DraggableScrollableController();
  bool _folded = false;
  String? _sheetKey;
  double _openF = 0.3;

  void _onSheet() {
    if (!_sheet.isAttached) return;
    final folded = _sheet.size < _openF - 0.02;
    if (folded == _folded) return;
    // The sheet reports its size while it is being laid out: change the
    // panel's content after this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _folded != folded) setState(() => _folded = folded);
    });
  }

  void _unfold() {
    if (_sheet.isAttached) {
      _sheet.animateTo(_openF, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final route = _route;
    _publishRoute(route);
    // Remember the choice for the next launch (only once the last one is back).
    if (_restored) _store.setLast(_fromId, _toId);
    final sameStation = _fromId != null && _fromId == _toId;
    final trainColor = route == null ? widget.city.lines.first.color : widget.city.line(route.legs.first.lineId).color;

    // One small line under the stations: errors first, then location news.
    final (String? message, bool isError) = sameStation
        ? (t.sameStation, true)
        : (_fromId != null && _toId != null && route == null)
        ? (t.noRoute, true)
        // Location news belongs to the departure it was written for.
        : (_locationNoteFrom == _fromId ? _locationNote : null, false);

    // A new route opens the panel again.
    final sheetKey = route == null ? 'none' : '$_fromId>$_toId';
    if (sheetKey != _sheetKey) {
      final first = _sheetKey == null;
      _sheetKey = sheetKey;
      if (!first) WidgetsBinding.instance.addPostFrameCallback((_) => _unfold());
    }
    return LayoutBuilder(
      builder: (context, box) {
        final minF = (_panelHeight / box.maxHeight).clamp(0.15, 0.7);
        _openF = minF;
        final barF = (_barHeight / box.maxHeight).clamp(0.05, minF - 0.01);
        // With a route the panel can be pulled up to show the details.
        final maxF = route == null ? minF : 0.86.clamp(minF, 1.0);
        return Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, (_folded ? _barHeight : _panelHeight) + 16),
              children: [
                Row(
                  children: [
                    // One line in every language (English is longer than つぎは Metro).
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: AppTitle(text: t.appTitle),
                      ),
                    ),
                    // The title shrinks; it never touches the coins.
                    const SizedBox(width: 10),
                    _CoinChip(coins: Services.my.coins, onTap: () => widget.onOpenMy?.call(PlatformScreen.coinShop)),
                    const SizedBox(width: 8),
                    // The city: tap to see the cities in 設定.
                    Semantics(
                      button: true,
                      child: GestureDetector(
                        key: const ValueKey('platform.city'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => openCities(context),
                        child: PixelBox(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          child: PixelText(widget.city.name.of(langOf(context)), size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _Banner(
                  city: widget.city,
                  fromId: _fromId,
                  route: route,
                  trainColor: trainColor,
                  weather: _weather,
                  aspect: _sceneAspect,
                  onOpenMy: widget.onOpenMy,
                ),
                // 「つぎはさん」: the station attendant's tip for now.
                GuideCard(
                  tips: guideTips(
                    city: widget.city,
                    data: _guide,
                    // The instant; the tips turn it into Japan time.
                    now: japanClock(),
                    lang: langOf(context),
                    route: route,
                    fromId: _fromId,
                    toId: _toId,
                    weather: _weather,
                    crowd: _crowdNow(route),
                    stamped: Services.my.loaded ? Services.my.stamped : null,
                    stayed: Services.my.loaded ? Services.my.stayed : null,
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.city.weather != null)
                  WeatherCard(
                    area: widget.city.weather!,
                    onWeather: (w) {
                      setState(() => _weather = w);
                      Services.homeWidget.setWeather(_weatherText(t, w));
                      Services.weatherNow.value = w;
                      _syncWidgetInfo();
                    },
                  ),
                const SizedBox(height: 12),
                ContextCard(
                  city: widget.city,
                  route: route,
                  fromId: _fromId,
                  toId: _toId,
                  store: _store,
                  onPick: (q) => setState(() {
                    _fromId = q.fromId;
                    _toId = q.toId;
                    _locationNote = null;
                  }),
                  onToggleFavourite: _toggleFavourite,
                  onRemoveFavourite: _confirmRemove,
                  alarmOn: _fromId != null && _toId != null && _alarm.isOnFor(_fromId!, _toId!),
                  firstAlarmOn: _fromId != null && _toId != null && _alarm.firstOnFor(_fromId!, _toId!),
                  onFirstBell: _toggleFirstAlarm,
                  onUseAlt: (avoid) => setState(() {
                    _avoid = avoid;
                    _avoidFor = '$_fromId>$_toId';
                  }),
                  onBell: route != null && lastDepartureMin(widget.city, route) != null ? _toggleAlarm : null,
                ),
                // 発車標: the next trains from the start station (shown in
                // full when the panel is pulled down).
                const SizedBox(height: 12),
                DepartureBoard(city: widget.city, stationId: _fromId),
              ],
            ),
            DraggableScrollableSheet(
              // One sheet for good (its controller stays attached); a new
              // route opens it to its usual size again (see _unfold).
              controller: _sheet,
              initialChildSize: minF,
              minChildSize: barF,
              maxChildSize: maxF,
              snap: true,
              snapSizes: [if (maxF > minF) minF],
              builder: (context, scroll) => _Panel(
                child: Stack(
                  children: [
                    ListView(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        const _Handle(),
                        _StationsCard(
                          city: widget.city,
                          fromId: _fromId,
                          toId: _toId,
                          locating: _locating,
                          onPickFrom: () => _pick(true),
                          onPickTo: () => _pick(false),
                          onLocate: _useMyLocation,
                          onSwap: () => setState(() {
                            final f = _fromId;
                            _fromId = _toId;
                            _toId = f;
                          }),
                        ),
                        // One line with air above and below: errors, or
                        // news from 現在地から.
                        SizedBox(
                          height: 28,
                          child: message == null
                              ? null
                              : Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isError ? Icons.error_outline_rounded : Icons.my_location,
                                        size: 14,
                                        color: isError ? PixelColors.danger : PixelColors.muted,
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: PixelText(
                                            message,
                                            key: const ValueKey('routeMessage'),
                                            size: 13,
                                            maxLines: 1,
                                            color: isError ? PixelColors.danger : PixelColors.muted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        _StartButton(label: t.startTrip, onPressed: route == null ? null : () => _start(route)),
                        if (route != null) ...[
                          const SizedBox(height: 16),
                          _RoutePreview(city: widget.city, route: route),
                          // Which car is handy for the change or the exit (目安).
                          const SizedBox(height: 12),
                          FutureBuilder<CarGuide>(
                            future: _cars,
                            builder: (context, snap) => snap.hasData
                                ? CarGuideCard(city: widget.city, advice: snap.data!.forRoute(route))
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                    // Pulled down: a slim bar over the top of the panel (its own
                    // content stays the same while it is dragged).
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: IgnorePointer(
                        ignoring: !_folded,
                        child: AnimatedOpacity(
                          opacity: _folded ? 1 : 0,
                          duration: const Duration(milliseconds: 160),
                          child: Container(
                            color: PixelColors.card,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const _Handle(),
                                _FoldedBar(
                                  city: widget.city,
                                  fromId: _fromId,
                                  toId: _toId,
                                  hint: t.routeFoldedPick,
                                  onOpen: _unfold,
                                  onStart: route == null ? null : () => _start(route),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The route panel pulled down: from → to in one line (tap to open the
/// panel again) and a small ▶ to start following the trip.
class _FoldedBar extends StatelessWidget {
  const _FoldedBar({
    required this.city,
    required this.fromId,
    required this.toId,
    required this.hint,
    required this.onOpen,
    required this.onStart,
  });
  final CityData city;
  final String? fromId;
  final String? toId;
  final String hint;
  final VoidCallback onOpen;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = langOf(context);
    String name(String? id) => id == null ? '…' : city.station(id).name.of(lang);
    final text = fromId == null && toId == null ? hint : '${name(fromId)} → ${name(toId)}';
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: text,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpen,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: PixelColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: PixelColors.line),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.train_rounded, size: 18, color: PixelColors.muted),
                    const SizedBox(width: 8),
                    Expanded(child: PixelText(text, size: 16, maxLines: 1)),
                    const Icon(Icons.keyboard_arrow_up_rounded, color: PixelColors.muted),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (onStart != null) ...[
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: t.startTrip,
            child: GestureDetector(
              onTap: onStart,
              child: Container(
                width: 52,
                height: 44,
                decoration: BoxDecoration(color: PixelColors.title, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.play_arrow_rounded, color: PixelColors.card, size: 28),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// White panel that rises from the bottom, like a sheet.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: PixelColors.card,
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      boxShadow: [BoxShadow(color: Color(0x1F1C1E24), blurRadius: 16, offset: Offset(0, -2))],
    ),
    child: ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: child,
    ),
  );
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 8, bottom: 10),
      width: 36,
      height: 4,
      decoration: BoxDecoration(color: PixelColors.line, borderRadius: BorderRadius.circular(2)),
    ),
  );
}

/// "つぎは Metro" with the Latin word in the line colour.
class AppTitle extends StatelessWidget {
  const AppTitle({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cut = text.lastIndexOf(' ');
    if (cut < 0) return PixelText(text, size: 30);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, cut + 1), style: pixelStyle(size: 30)),
          TextSpan(
            text: text.substring(cut + 1),
            style: pixelStyle(size: 30, color: PixelColors.title),
          ),
        ],
      ),
    );
  }
}

/// From / to like a route in a transit app: a green dot (from) and a red
/// dot (to) joined by a dotted line. Tap a row to choose a station; the
/// round buttons find the nearest station and swap the two.
class _StationsCard extends StatelessWidget {
  const _StationsCard({
    required this.city,
    required this.fromId,
    required this.toId,
    required this.locating,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onLocate,
    required this.onSwap,
  });

  final CityData city;
  final String? fromId;
  final String? toId;
  final bool locating;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onLocate;
  final VoidCallback onSwap;

  static const fromColor = Color(0xFF2E9447);
  static const toColor = Color(0xFFE0513F);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: PixelColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PixelColors.line),
      ),
      child: Stack(
        children: [
          // Dotted line between the two dots.
          const Positioned(left: 22, top: 36, bottom: 36, child: _DottedLine()),
          Column(
            children: [
              _StationRow(
                label: t.from,
                dot: fromColor,
                station: fromId == null ? null : city.station(fromId!),
                placeholder: t.selectStation,
                onTap: onPickFrom,
                trailing: _RoundButton(
                  icon: Icons.my_location,
                  label: t.nearestButton,
                  busy: locating,
                  onTap: onLocate,
                ),
              ),
              Container(height: 1, margin: const EdgeInsets.only(left: 44, right: 60), color: PixelColors.line),
              _StationRow(
                label: t.to,
                dot: toColor,
                station: toId == null ? null : city.station(toId!),
                placeholder: t.selectStation,
                onTap: onPickTo,
                trailing: _RoundButton(icon: Icons.swap_vert, label: t.swap, onTap: onSwap),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DottedLine extends StatelessWidget {
  const _DottedLine();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final n = (box.maxHeight / 6).floor();
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [for (var i = 0; i < n; i++) Container(width: 2, height: 2, color: PixelColors.muted)],
      );
    },
  );
}

class _StationRow extends StatelessWidget {
  const _StationRow({
    required this.label,
    required this.dot,
    required this.station,
    required this.placeholder,
    required this.onTap,
    required this.trailing,
  });

  final String label;
  final Color dot;
  final Station? station;
  final String placeholder;
  final VoidCallback onTap;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final lang = langOf(context);
    final s = station;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: dot,
                shape: BoxShape.circle,
                border: Border.all(color: PixelColors.card, width: 3),
                boxShadow: [BoxShadow(color: dot.withValues(alpha: 0.35), blurRadius: 0, spreadRadius: 1.5)],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PixelText(label, size: 11, color: PixelColors.muted),
                  const SizedBox(height: 1),
                  if (s == null)
                    PixelText(placeholder, size: 18, color: const Color(0xFFB4B7BD), maxLines: 1)
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        PixelText(s.name.ja, size: 20, maxLines: 1),
                        const SizedBox(width: 6),
                        Flexible(
                          child: PixelText(
                            lang == 'ja' ? s.kana : s.name.of(lang),
                            size: 12,
                            color: PixelColors.muted,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            trailing,
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

/// Small round icon button (nearest station, swap).
class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.onTap, this.busy = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(color: PixelColors.background, shape: BoxShape.circle),
        child: busy
            ? const Padding(
                padding: EdgeInsets.all(11),
                child: CircularProgressIndicator(strokeWidth: 2, color: PixelColors.muted),
              )
            : Icon(icon, size: 20, color: PixelColors.ink),
      ),
    ),
  );
}

/// Big rounded start button: green when a route is ready, grey before.
class _StartButton extends StatefulWidget {
  const _StartButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final color = enabled ? _StationsCard.fromColor : PixelColors.soft;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                widget.onPressed!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: const Duration(milliseconds: 90),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: enabled
                  ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: enabled ? 1 : 0.35,
                  child: Image.asset(
                    'assets/art/tab_platform.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.none,
                  ),
                ),
                const SizedBox(width: 10),
                PixelText(widget.label, size: 20, color: enabled ? PixelColors.card : PixelColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoutePreview extends StatelessWidget {
  const _RoutePreview({required this.city, required this.route});
  final CityData city;
  final RouteResult route;

  /// 「明治神宮前まで歩く　約3分」: the line does not stop where you are.
  Widget _walk(String lang, String toStation, int minutes) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        const Icon(Icons.directions_walk_rounded, size: 17, color: PixelColors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: PixelText(
            fill(walkToStation, lang, {'station': city.station(toStation).name.of(lang)}),
            size: 16,
            maxLines: 1,
          ),
        ),
        PixelText(fill(walkAboutMinutes, lang, {'min': minutes}), size: 16, color: PixelColors.muted),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = langOf(context);
    final plan = TripPlan.build(city, route, japanNow());
    final headWalk = route.headWalkMin(city), tailWalk = route.tailWalkMin(city);
    final minutes = (plan.totalSec / 60).ceil() + headWalk + tailWalk;
    return PixelBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PixelText(t.routeSummary(minutes, route.stopCount, route.transferCount), size: 18),
          const SizedBox(height: 10),
          if (route.walkFromId != null) _walk(lang, route.fromId, headWalk),
          for (final (i, leg) in route.legs.indexed) ...[
            // A change at a station with another name: on foot.
            if (i > 0 && route.legs[i - 1].stationIds.last != leg.stationIds.first)
              _walk(
                lang,
                leg.stationIds.first,
                city.walkMin(route.legs[i - 1].stationIds.last, leg.stationIds.first) ?? 5,
              ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  PixelSquare(color: city.line(leg.lineId).color, size: 15),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PixelText(
                      '${city.line(leg.lineId).name.of(lang)} '
                      '${city.line(leg.lineId).directionName(leg.forward).of(lang)}',
                      size: 16,
                    ),
                  ),
                  PixelText(t.stopCount(leg.stopCount), size: 16, color: PixelColors.muted),
                ],
              ),
            ),
          ],
          if (route.walkToId != null) _walk(lang, route.walkToId!, tailWalk),
        ],
      ),
    );
  }
}

/// The MY station at the top of のりば.
/// - Leaving from a station whose scene you own shows that station.
/// - With a route, the train's LED shows where it goes (「各停 浅草」).
/// - Tap the picture to decorate it in MY; a station scene you do not have
///   yet gets a small 「…の景色をGET」 button.
/// Which weather picture to show: rain / snow now, or umbrellas in hand
/// when rain is likely (50% or more).
/// In winter (December to February, Japan time) dry days get the
/// 'winter' picture: everyone in thick coats and scarves.
/// Otherwise the picture follows how crowded the platform is likely to be
/// ([crowd], from the crowding estimate).
/// Weather pictures come with few or many people: '{sky}_few' when the
/// platform is likely calm, '{sky}_many' when crowded.
/// In winter, when it is cold (3 °C or less) and rain is likely, snow is
/// what is coming: 'snowsoon'.
String? sceneSky(WeatherNow? w, {DateTime? now, CongestionLevel? crowd, bool closed = false}) {
  final month = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 9)).month;
  final winter = month == 12 || month <= 2;
  String? sky;
  if (w != null) {
    if (w.kind == WeatherKind.rain) {
      sky = 'rain';
    } else if (w.kind == WeatherKind.snow) {
      sky = 'snow';
    } else if (w.wetLater) {
      sky = winter && (w.tempC == null || w.tempC! <= 3) ? 'snowsoon' : 'umbrella';
    }
  }
  // After the last train: the empty, half-lit platform; the train shows 運行終了.
  if (closed) return 'closed';
  if (sky == null && winter) sky = 'winter';
  // A quiet or ordinary platform is the scene itself (its people move); only
  // busy platforms switch to their own (still) pictures.
  if (sky == null) return crowd == null || crowd.index <= CongestionLevel.normal.index ? null : crowd.name;
  if (crowd == null) return sky;
  return '${sky}_${crowd.index >= CongestionLevel.crowded.index ? 'many' : 'few'}';
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.city,
    required this.fromId,
    required this.route,
    required this.trainColor,
    required this.weather,
    required this.aspect,
    required this.onOpenMy,
  });

  final CityData city;
  final String? fromId;
  final RouteResult? route;
  final Color trainColor;
  final WeatherNow? weather;
  final double aspect;
  final ValueChanged<String?>? onOpenMy;

  /// Crowding at the departure station now: the line you ride, or the
  /// station's first line before a route is chosen.
  /// No trains on the departure line now (after the last, before the first).
  bool _closed() {
    final lineId = route?.legs.first.lineId ?? (fromId == null ? null : city.station(fromId!).lines.first);
    final tt = lineId == null ? null : city.timetables[lineId];
    return tt != null && !tt.inService(DateTime.now().toUtc().add(const Duration(hours: 9)));
  }

  CongestionLevel? _crowd() {
    final lineId = route?.legs.first.lineId ?? (fromId == null ? null : city.station(fromId!).lines.first);
    if (lineId == null) return null;
    return EstimateCongestionSource.levelAt(lineId, DateTime.now().toUtc().add(const Duration(hours: 9)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = langOf(context);
    final my = Services.my;
    final stationScene = my.sceneForStation(fromId);
    final owned = stationScene != null && my.owns(stationScene.id);
    final shownScene = owned ? stationScene : my.sceneItem;
    final view = MyStationView(
      aspect: aspect,
      lineColor: trainColor,
      weather: weather?.kind,
      // The line you ride (else the station's first) runs underground here:
      // the built-in scene becomes the subway platform.
      look: my
          .lookFor(fromId)
          .withUnderground(
            fromId != null &&
                city.station(fromId!).isUndergroundOn(route?.legs.first.lineId ?? city.station(fromId!).lines.first),
            // The equipped scene is another station's view: underground it would show sky.
            overScene: !owned,
          ),
      // A new route: the train pulls in. Rain: umbrellas.
      arrivalKey: route == null ? null : '${route!.fromId}>${route!.toId}',
      sign: fromId == null
          ? null
          : StationSign(
              name: city.station(fromId!).name.ja,
              sub: city.station(fromId!).name.of('en').toUpperCase(),
              // The line you ride, or the station's own line before a route is set.
              band: route != null ? trainColor : city.line(city.station(fromId!).lines.first).color,
            ),
      sky: sceneSky(weather, crowd: _crowd(), closed: _closed()),
      plate: PlateData.of(my, fallbackName: shownScene?.name.of(lang) ?? ''),
      led: route == null ? null : destinationLed(city, route!.legs.first),
      onTap: () => onOpenMy?.call(null),
      // The train pulls in with a quiet arrival sound, then the MY departure
      // melody once it has stopped (not after the last train).
      onArrive: () {
        if (!_closed()) Services.melody.arrive(my.melody);
      },
    );
    if (stationScene == null || owned) return view;
    return Stack(
      children: [
        view,
        Positioned(
          left: 8,
          bottom: 8,
          child: GestureDetector(
            onTap: () => onOpenMy?.call(stationScene.id),
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
              decoration: BoxDecoration(color: const Color(0xE61E2230), borderRadius: BorderRadius.circular(14)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_rounded, size: 15, color: Color(0xFFFFD25E)),
                  const SizedBox(width: 5),
                  Text(
                    t.sceneGet(stationScene.name.of(lang)),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Coins at the top of のりば; tap for the coin shop in MY.
class _CoinChip extends StatelessWidget {
  const _CoinChip({required this.coins, required this.onTap});
  final int coins;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: PixelBox(
      padding: const EdgeInsets.fromLTRB(6, 2, 8, 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [const CoinIcon(size: 16), const SizedBox(width: 5), PixelText('$coins', size: 16, bold: true)],
      ),
    ),
  );
}
