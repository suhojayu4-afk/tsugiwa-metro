import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:material_ui/material_ui.dart';

import 'core/pixel/pixel_ui.dart';
import 'data/city_repository.dart';
import 'data/models/city.dart';
import 'core/services.dart';
import 'data/route_store.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/settings/app_city.dart';
import 'features/settings/app_language.dart';
import 'features/settings/app_look.dart';
import 'features/shell/main_shell.dart';
import 'l10n/app_localizations.dart';

const supportedLangs = ['ja', 'ko', 'en'];

class TsugiwaApp extends StatefulWidget {
  const TsugiwaApp({super.key, this.repository});

  final CityRepository? repository;

  @override
  State<TsugiwaApp> createState() => _TsugiwaAppState();
}

class _TsugiwaAppState extends State<TsugiwaApp> with WidgetsBindingObserver {
  CityRepository? get repository => widget.repository;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppLook.restart.addListener(_again);
    AppLook.reduceMotion.addListener(_again);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppLook.restart.removeListener(_again);
    AppLook.reduceMotion.removeListener(_again);
    super.dispose();
  }

  void _again() => setState(() {});

  /// The phone went dark or light by itself (設定 → 見た目: スマホにあわせる).
  @override
  void didChangePlatformBrightness() => AppLook.phoneLookChanged();

  @override
  Widget build(BuildContext context) {
    // The colours are read while the screens build, so they are set first.
    final dark = AppLook.darkFor(WidgetsBinding.instance.platformDispatcher.platformBrightness);
    PixelColors.dark = dark;
    // Kept outside the builder so a language change does not restart the app.
    final home = OnboardingGate(child: _CityLoader(repository: repository ?? CityRepository()));
    return ValueListenableBuilder<String?>(
      valueListenable: AppLanguage.override,
      builder: (context, picked, _) => MaterialApp(
        // A new look (or all data deleted) builds everything again from the
        // top: screens keep their colours in widgets that would not rebuild.
        key: ValueKey('app.${AppLook.restart.value}.$dark'),
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        // The language picked in 設定; null follows the phone.
        locale: picked == null ? null : Locale(picked),
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        supportedLocales: [for (final l in supportedLangs) Locale(l)],
        // Main users are Japanese: anything not ko/en falls back to Japanese.
        localeResolutionCallback: (device, supported) {
          final lang = device?.languageCode;
          return Locale(supportedLangs.contains(lang) ? lang! : 'ja');
        },
        // Very large system text breaks the pixel layouts: follow it up to 1.3x.
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return AnnotatedRegion<SystemUiOverlayStyle>(
            // Status bar icons that read on the app's ground.
            value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            child: MediaQuery(
              // 設定 → 動きを減らす, on top of the phone's own setting.
              data: mq.copyWith(disableAnimations: mq.disableAnimations || AppLook.reduceMotion.value),
              child: MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: child ?? const SizedBox.shrink()),
            ),
          );
        },
        // The first-run tour shows once, before the app.
        home: home,
      ),
    );
  }
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: PixelColors.dark ? Brightness.dark : Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: PixelColors.ink,
      surface: PixelColors.background,
      brightness: PixelColors.dark ? Brightness.dark : Brightness.light,
    ),
    scaffoldBackgroundColor: PixelColors.background,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: PixelColors.ink, displayColor: PixelColors.ink),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: PixelColors.ink,
      contentTextStyle: pixelStyle(size: 16, color: PixelColors.card),
      shape: const RoundedRectangleBorder(),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

String langOf(BuildContext context) {
  final code = Localizations.localeOf(context).languageCode;
  return supportedLangs.contains(code) ? code : 'ja';
}

class _CityLoader extends StatefulWidget {
  const _CityLoader({required this.repository});
  final CityRepository repository;

  @override
  State<_CityLoader> createState() => _CityLoaderState();
}

class _CityLoaderState extends State<_CityLoader> {
  late String _id = AppCity.current.value;
  late Future<CityData> _city = _load(_id);

  /// The city picked in 設定 (Tokyo by default). Saved routes belong to a
  /// city: Tokyo keeps its old store, other cities get their own.
  Future<CityData> _load(String id) {
    Services.routes = RouteStore(prefix: id == 'tokyo' ? 'routes' : 'routes.$id');
    return widget.repository.loadCity(id);
  }

  @override
  void initState() {
    super.initState();
    AppCity.current.addListener(_onCity);
  }

  @override
  void dispose() {
    AppCity.current.removeListener(_onCity);
    super.dispose();
  }

  void _onCity() {
    if (AppCity.current.value == _id) return;
    setState(() {
      _id = AppCity.current.value;
      _city = _load(_id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CityData>(
      future: _city,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(body: Center(child: PixelText('${snap.error}')));
        }
        if (!snap.hasData || snap.data!.id != _id) {
          return Scaffold(body: Center(child: PixelText(AppLocalizations.of(context).loading)));
        }
        // A new city starts the tabs afresh.
        return MainShell(key: ValueKey(_id), city: snap.data!);
      },
    );
  }
}
