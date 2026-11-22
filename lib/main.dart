import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'features/settings/app_city.dart';
import 'features/settings/app_language.dart';
import 'features/settings/font_licenses.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  await AppLanguage.load();
  await AppCity.load();
  runApp(const TsugiwaApp());
}
