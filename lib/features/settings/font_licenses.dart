import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The fonts shipped inside the app and their licence texts (all SIL Open
/// Font License 1.1). The texts sit in assets/fonts/licenses/.
///
/// - DotGothic16: assets/fonts/DotGothic16-Regular.ttf
/// - Galmuri11: assets/fonts/Galmuri11.ttf, Galmuri11-Bold.ttf
/// - Yuji Boku: assets/art/eki_in/yuji_boku_eki.ttf (station names of the
///   駅印帳, a subset made by tools/gen_eki_in_gpt.py)
const fontLicenses = {
  'DotGothic16 (font)': 'assets/fonts/licenses/DotGothic16-OFL.txt',
  'Galmuri11 (font)': 'assets/fonts/licenses/Galmuri-OFL.md',
  'Yuji Boku (font)': 'assets/fonts/licenses/YujiBoku-OFL.txt',
};

/// Adds the font licences to Flutter's [LicenseRegistry], so they show on the
/// ライセンス page beside the packages. Called once when the app starts.
void registerFontLicenses() => LicenseRegistry.addLicense(_fontLicenses);

Stream<LicenseEntry> _fontLicenses() async* {
  for (final e in fontLicenses.entries) {
    final text = await rootBundle.loadString(e.value, cache: false);
    // Galmuri's file is Markdown: show the © sign, not its HTML name.
    yield LicenseEntryWithLineBreaks([e.key], text.replaceAll('&copy;', '©'));
  }
}
