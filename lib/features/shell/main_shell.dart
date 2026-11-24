import '../../data/achievements.dart' show RareSightings;

import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/pixel/pixel_scene.dart' show DayPart, tottoriDieselArt;
import '../../core/pixel/scene_events.dart' show rareTrainArt, tottoriSlArt, yellowTrainArt;
import '../../core/pixel/pixel_ui.dart';
import '../../core/services.dart';
import '../../data/models/city.dart';
import '../../data/weather/weather_source.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/home_widget_bridge.dart';
import '../../platform/monthly_report.dart';
import '../album/postcard_book.dart';
import '../my_room/my_room_screen.dart';
import '../my_room/station_plate.dart';
import '../platform/platform_screen.dart';
import '../route_map/route_map_screen.dart';
import '../trip/stay_watcher.dart';

/// Bottom tabs, left to right: のりば (set where you go) / 路線図 / MY.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.city});
  final CityData city;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  final _platform = GlobalKey<PlatformScreenState>();
  final _my = GlobalKey<MyRoomScreenState>();

  /// のりば → MY: the MY tab, then an item's sheet or the coin shop.
  void _openMy(String? itemId) {
    setState(() => _tab = 2);
    if (itemId == null) return;
    // Let the tab switch show first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final my = _my.currentState;
      if (my == null) return;
      if (itemId == PlatformScreen.coinShop) {
        my.openCoinShop();
      } else {
        my.openItem(itemId);
      }
    });
  }

  HomeWidgetSync? _widgetSync;
  StayWatcher? _stay;

  /// Stayed 5 minutes at a station: gold stamp and a note at the bottom.
  Future<void> _onStay(String stationId) async {
    final my = Services.my;
    if (!my.loaded || my.stayed(stationId)) return;
    final coins = await my.stampStay(stationId);
    if (coins > 0) {
      await PostcardBook.instance.add(my: my, station: stationId, weather: Services.weatherNow.value?.kind, gold: true);
    }
    if (coins == 0 || !mounted) return;
    final t = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t.stayStamped(widget.city.station(stationId).name.of(_lang), coins)),
        backgroundColor: const Color(0xFFB9861A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _lang = 'ja';

  @override
  void initState() {
    super.initState();
    final my = Services.my;
    my.lines = {for (final l in widget.city.lines) l.id: l.stations};
    my.cityId = widget.city.id;
    // Tottori's country lines run diesel railcars.
    my.cityTrainArt = widget.city.id == 'tottori' ? tottoriDieselArt : null;
    rareTrainArt = widget.city.id == 'tottori' ? tottoriSlArt : yellowTrainArt;
    // Each city's own platform picture, until one of its station scenes is bought.
    final cityScene = switch (widget.city.id) {
      'tottori' => 'assets/art/tottori/rural',
      'osaka' => 'assets/art/cities/scenes/osaka_umeda',
      'fukuoka' => 'assets/art/cities/scenes/fukuoka_nakasu',
      'sendai' => 'assets/art/cities/scenes/sendai_aoba',
      'sapporo' => 'assets/art/cities/scenes/sapporo_odori',
      _ => null,
    };
    my.cityScene = cityScene == null ? const {} : {for (final p in DayPart.values) p: '${cityScene}_${p.name}.webp'};
    if (!my.loaded) my.load();
    // 月間乗車レポート on the 1st; tapping it opens MY.
    MonthlyReport.attach(my, openMy: () => mounted ? _openMy(null) : null);
    // The rare yellow train on のりば gives a badge.
    RareSightings.attach();
    _stay = StayWatcher(city: widget.city, location: Services.location, onStay: _onStay)..start();
    Services.status.start();
    // Tottori: JR西日本's 運行情報 and how late each train is.
    if (widget.city.trains.isNotEmpty) Services.jrwest.start(Services.status);
    // Keep the home screen widget's pictures in step with MY駅.
    _widgetSync = HomeWidgetSync(
      bridge: Services.homeWidget,
      listenable: Listenable.merge([my, Services.weatherNow]),
      // The widget shows today's weather too: rain, snow, rain or snow on
      // the way, winter coats (the same pictures as のりば).
      render: (part) => renderMyStationPng(
        look: my.look,
        plate: _plateData(),
        part: part,
        lineColor: myDefaultLine,
        scale: 3,
        weather: Services.weatherNow.value?.kind ?? WeatherKind.sunny,
        sky: _widgetSky(),
      ),
    )..start(() => my.loaded ? '${my.look.key}|${_plateData().hashCode}|$_lang|${_widgetSky()}' : '');
  }

  String? _widgetSky() {
    final w = Services.weatherNow.value;
    return w == null ? null : sceneSky(w);
  }

  PlateData _plateData() => PlateData.of(Services.my, fallbackName: Services.my.sceneItem?.name.of(_lang) ?? '');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lang = langOf(context);
  }

  @override
  void dispose() {
    _widgetSync?.dispose();
    _stay?.stop();
    Services.status.stop();
    Services.jrwest.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      body: PixelBackground(
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _tab,
            children: [
              PlatformScreen(key: _platform, city: widget.city, onOpenMy: _openMy),
              RouteMapScreen(
                city: widget.city,
                // 出発にする / 到着にする on the map: fill it in and go to のりば.
                onUseStation: (id, {required from}) {
                  _platform.currentState?.setStation(id, from: from);
                  setState(() => _tab = 0);
                },
              ),
              MyRoomScreen(key: _my, city: widget.city),
            ],
          ),
        ),
      ),
      bottomNavigationBar: PixelNavBar(
        index: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: [
          ('assets/art/tab_platform.png', t.tabPlatform),
          ('assets/art/tab_map.png', t.tabMap),
          ('assets/art/tab_my.png', t.tabMy),
        ],
      ),
    );
  }
}

class PixelNavBar extends StatelessWidget {
  const PixelNavBar({super.key, required this.index, required this.onTap, required this.items});

  final int index;
  final ValueChanged<int> onTap;
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PixelColors.card,
        border: Border(top: BorderSide(color: PixelColors.line, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == index,
                    button: true,
                    label: items[i].$2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _NavItem(icon: items[i].$1, label: items[i].$2, selected: i == index),
                      ),
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

/// Colour pixel icon + label. The selected tab sits on a soft green pill;
/// the others are faded so the current tab is obvious at a glance.
class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected});
  final String icon;
  final String label;
  final bool selected;

  static const _greyscale = ColorFilter.matrix([
    0.33,
    0.59,
    0.11,
    0,
    0,
    0.33,
    0.59,
    0.11,
    0,
    0,
    0.33,
    0.59,
    0.11,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // 32px art, whole device pixels per art pixel.
    final size = 32 * (36 / 32 * dpr).round().clamp(1, 8) / dpr;
    Widget image = Image.asset(icon, width: size, height: size, fit: BoxFit.fill, filterQuality: FilterQuality.none);
    if (!selected) {
      image = Opacity(
        opacity: 0.6,
        child: ColorFiltered(colorFilter: _greyscale, child: image),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 64,
          height: size + 8,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFDDF1E1) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: image,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            height: 1.2,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? PixelColors.ink : PixelColors.muted,
          ),
        ),
      ],
    );
  }
}
