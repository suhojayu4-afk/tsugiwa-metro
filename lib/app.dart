import 'package:material_ui/material_ui.dart';

import 'core/pixel/pixel_ui.dart';
import 'data/city_repository.dart';
import 'data/models/city.dart';
import 'features/shell/main_shell.dart';
import 'l10n/app_localizations.dart';

const supportedLangs = ['ja', 'ko', 'en'];

class TsugiwaApp extends StatelessWidget {
  const TsugiwaApp({super.key, this.repository});

  final CityRepository? repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
      supportedLocales: [for (final l in supportedLangs) Locale(l)],
      // Main users are Japanese: anything not ko/en falls back to Japanese.
      localeResolutionCallback: (device, supported) {
        final lang = device?.languageCode;
        return Locale(supportedLangs.contains(lang) ? lang! : 'ja');
      },
      home: _CityLoader(repository: repository ?? CityRepository()),
    );
  }
}

ThemeData buildTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: PixelColors.ink, surface: PixelColors.background),
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
  // The city selection screen arrives with the route map step; Tokyo for now.
  late final Future<CityData> _city = widget.repository.loadCity('tokyo');

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CityData>(
      future: _city,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(body: Center(child: PixelText('${snap.error}')));
        }
        if (!snap.hasData) {
          return Scaffold(body: Center(child: PixelText(AppLocalizations.of(context).loading)));
        }
        return MainShell(city: snap.data!);
      },
    );
  }
}
