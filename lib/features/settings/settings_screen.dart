import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/app_info.dart';
import '../../core/localized_text.dart';
import '../../core/pixel/pixel_ui.dart';
import '../guide/first_ride_data.dart' show firstRideTitle;
import '../guide/first_ride_screen.dart';
import 'app_city.dart';
import 'app_language.dart';
import 'font_licenses.dart';
import 'legal_texts.dart';

const settingsTitle = LocalizedText({'ja': '設定', 'ko': '설정', 'en': 'Settings'});
const _language = LocalizedText({'ja': '言語', 'ko': '언어', 'en': 'Language'});
const _followDevice = LocalizedText({'ja': 'スマホの設定にあわせる', 'ko': '휴대폰 설정에 맞추기', 'en': 'Same as the phone'});
const _languageNote = LocalizedText({
  'ja': 'ホーム画面のウィジェットはスマホの言語で表示されます。',
  'ko': '홈 화면 위젯은 휴대폰의 언어로 표시돼요.',
  'en': 'Home screen widgets stay in the phone\'s language.',
});
const _city = LocalizedText({'ja': '都市', 'ko': '도시', 'en': 'City'});
const _cityNote = LocalizedText({
  'ja': 'コインとMYのアイテムはどの都市でも同じです。スタンプは都市ごとに集まります。',
  'ko': '코인과 MY 아이템은 어느 도시에서나 같아요. 스탬프는 도시마다 모여요.',
  'en': 'Coins and MY items are shared; each city has its own stamps.',
});
const _languageNames = {'ja': '日本語', 'ko': '한국어', 'en': 'English'};
const _groupApp = LocalizedText({'ja': 'アプリ', 'ko': '앱', 'en': 'App'});
const _groupAbout = LocalizedText({'ja': 'このアプリについて', 'ko': '이 앱에 대하여', 'en': 'About'});
const licensesTitle = LocalizedText({'ja': 'ライセンス', 'ko': '라이선스', 'en': 'Licences'});
const _version = LocalizedText({'ja': 'バージョン', 'ko': '버전', 'en': 'Version'});
const _licensesLead = LocalizedText({
  'ja': 'このアプリは、次のフォントとオープンソースのソフトウェアを使っています。',
  'ko': '이 앱은 다음 글꼴과 오픈소스 소프트웨어를 쓰고 있어요.',
  'en': 'The app uses the following fonts and open-source software.',
});
const _fonts = LocalizedText({'ja': 'フォント', 'ko': '글꼴', 'en': 'Fonts'});
const _software = LocalizedText({'ja': 'ソフトウェア', 'ko': '소프트웨어', 'en': 'Software'});
const _licenseCount = LocalizedText({'ja': '件', 'ko': '건', 'en': ''});
const _footer = LocalizedText({
  'ja': '鉄道会社とは関係のない非公式アプリです。',
  'ko': '철도 회사와 관계없는 비공식 앱이에요.',
  'en': 'An unofficial app, not connected to the railway companies.',
});

String _appName(String lang) => switch (lang) {
  'ko' => AppInfo.nameKo,
  'en' => AppInfo.nameEn,
  _ => AppInfo.nameJa,
};

PreferredSizeWidget _bar(String title) => AppBar(
  backgroundColor: PixelColors.background,
  surfaceTintColor: Colors.transparent,
  title: PixelText(title, size: 22),
);

void _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

/// The small gear that opens 設定 (in the MY tab's header).
class SettingsGearButton extends StatelessWidget {
  const SettingsGearButton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: settingsTitle.of(langOf(context)),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _push(context, const SettingsScreen()),
      child: const SizedBox(
        width: 44,
        height: 44,
        child: Icon(Icons.settings_rounded, size: 24, color: PixelColors.ink),
      ),
    ),
  );
}

/// 設定: language, the privacy policy, terms, data credits, licences and the
/// app version.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = langOf(context);
    return Scaffold(
      backgroundColor: PixelColors.background,
      appBar: _bar(settingsTitle.of(lang)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GroupLabel(_groupApp.of(lang)),
            _Group(
              rows: [
                ValueListenableBuilder<String?>(
                  valueListenable: AppLanguage.override,
                  builder: (context, picked, _) => _Row(
                    key: const ValueKey('settings.language'),
                    icon: Icons.language_rounded,
                    label: _language.of(lang),
                    sub: picked == null ? _followDevice.of(lang) : _languageNames[picked],
                    onTap: () => _pickLanguage(context),
                  ),
                ),
                _Row(
                  key: const ValueKey('settings.firstRide'),
                  icon: Icons.school_rounded,
                  label: firstRideTitle.of(lang),
                  onTap: () => _push(context, FirstRideGuideScreen(cityId: AppCity.current.value)),
                ),
                ValueListenableBuilder<String>(
                  valueListenable: AppCity.current,
                  builder: (context, city, _) => _Row(
                    key: const ValueKey('settings.city'),
                    icon: Icons.map_rounded,
                    label: _city.of(lang),
                    sub: AppCity.names[city]!.of(lang),
                    onTap: () => openCities(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _GroupLabel(_groupAbout.of(lang)),
            _Group(
              rows: [
                _Row(
                  key: const ValueKey('settings.privacy'),
                  icon: Icons.lock_rounded,
                  label: privacyDoc.title.of(lang),
                  onTap: () => _push(context, const LegalPage(doc: privacyDoc)),
                ),
                _Row(
                  key: const ValueKey('settings.terms'),
                  icon: Icons.description_rounded,
                  label: termsDoc.title.of(lang),
                  onTap: () => _push(context, const LegalPage(doc: termsDoc)),
                ),
                _Row(
                  key: const ValueKey('settings.credits'),
                  icon: Icons.favorite_rounded,
                  label: creditsDoc.title.of(lang),
                  onTap: () => _push(context, const LegalPage(doc: creditsDoc)),
                ),
                _Row(
                  key: const ValueKey('settings.licenses'),
                  icon: Icons.menu_book_rounded,
                  label: licensesTitle.of(lang),
                  onTap: () => _push(context, const LicensesPage()),
                ),
                _Row(
                  key: const ValueKey('settings.version'),
                  icon: Icons.train_rounded,
                  label: _version.of(lang),
                  value: appVersion,
                ),
              ],
            ),
            const SizedBox(height: 22),
            PixelText(_appName(lang), size: 16, align: TextAlign.center, color: PixelColors.muted),
            const SizedBox(height: 4),
            PixelText(_footer.of(lang), size: 12, align: TextAlign.center, color: PixelColors.muted),
          ],
        ),
      ),
    );
  }
}

/// 設定 → 都市 (also opened by the city chip on のりば).
void openCities(BuildContext context) => _push(context, const CitiesPage());

const _received = LocalizedText({'ja': '受け取り済み', 'ko': '받음', 'en': 'Received'});
const _receive = LocalizedText({'ja': '受け取る', 'ko': '받기', 'en': 'Get'});
const _preparing = LocalizedText({'ja': '準備中…', 'ko': '준비 중…', 'en': 'Getting ready…'});
const _use = LocalizedText({'ja': 'この都市にする', 'ko': '이 도시로 바꾸기', 'en': 'Use this city'});
const _inUse = LocalizedText({'ja': '使用中', 'ko': '사용 중', 'en': 'In use'});
const _citiesLead = LocalizedText({
  'ja': '路線図を受け取ると、その都市ののりば・路線図・ガイドが使えます。',
  'ko': '노선도를 받으면 그 도시의 승강장·노선도·가이드를 쓸 수 있어요.',
  'en': 'Get a city to use its platform, route map and guide.',
});
const _cityAbout = {
  'tokyo': LocalizedText({'ja': '関東の169路線', 'ko': '간토의 169개 노선', 'en': '169 lines round Kanto'}),
  'tottori': LocalizedText({
    'ja': '山陰本線・境線・因美線・若桜鉄道・智頭急行・伯備線と特急。いなかの駅と大山の路線図',
    'ko': '산인 본선·사카이선·인비선·와카사 철도·지즈 급행·하쿠비선과 특급. 시골 역과 다이센의 노선도',
    'en': "San'in, Sakai, Inbi, Wakasa, Chizu and Hakubi lines and limited expresses; country stations and Mt. Daisen",
  }),
};

/// The cities: Tokyo comes with the app; other route maps are received
/// here first, then can be switched to. (All cities will be one map later.)
class CitiesPage extends StatefulWidget {
  const CitiesPage({super.key});

  @override
  State<CitiesPage> createState() => _CitiesPageState();
}

class _CitiesPageState extends State<CitiesPage> {
  String? _busy;

  Future<void> _get(String code) async {
    setState(() => _busy = code);
    await AppCity.receive(code);
    if (mounted) setState(() => _busy = null);
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(context);
    return Scaffold(
      backgroundColor: PixelColors.background,
      appBar: _bar(_city.of(lang)),
      body: ValueListenableBuilder<Set<String>>(
        valueListenable: AppCity.received,
        builder: (context, have, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            PixelText(_citiesLead.of(lang), size: 13, color: PixelColors.muted),
            const SizedBox(height: 12),
            for (final code in AppCity.choices) ...[
              _cityCard(context, code, have.contains(code), lang),
              const SizedBox(height: 10),
            ],
            PixelText(_cityNote.of(lang), size: 12, color: PixelColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _cityCard(BuildContext context, String code, bool got, String lang) {
    final current = AppCity.current.value == code;
    final Widget action;
    if (current) {
      action = PixelText(_inUse.of(lang), size: 14, color: PixelColors.title);
    } else if (_busy == code) {
      action = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          PixelText(_preparing.of(lang), size: 14, color: PixelColors.muted),
        ],
      );
    } else if (!got) {
      action = FilledButton.icon(
        key: ValueKey('settings.city.get.$code'),
        onPressed: _busy == null ? () => _get(code) : null,
        icon: const Icon(Icons.download_rounded, size: 18),
        label: Text(_receive.of(lang)),
      );
    } else {
      action = FilledButton(
        key: ValueKey('settings.city.use.$code'),
        onPressed: () {
          // Back to the tabs, which then show the new city.
          Navigator.of(context).popUntil((r) => r.isFirst);
          AppCity.set(code);
        },
        child: Text(_use.of(lang)),
      );
    }
    return PixelBox(
      key: ValueKey('settings.city.$code'),
      borderColor: current ? PixelColors.ink : null,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PixelText(AppCity.names[code]!.of(lang), size: 18),
                    if (got && !current) ...[
                      const SizedBox(width: 6),
                      PixelText(_received.of(lang), size: 11, color: PixelColors.muted),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                PixelText(_cityAbout[code]!.of(lang), size: 12, color: PixelColors.muted, maxLines: 3),
              ],
            ),
          ),
          const SizedBox(width: 10),
          action,
        ],
      ),
    );
  }
}

Future<void> _pickLanguage(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: PixelColors.background,
  shape: const RoundedRectangleBorder(),
  isScrollControlled: true,
  builder: (context) {
    // Rebuilt by the app when the language changes, so the sheet follows too.
    final lang = langOf(context);
    final picked = AppLanguage.override.value;
    Widget option(String? code, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        key: ValueKey('settings.lang.${code ?? 'device'}'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AppLanguage.set(code);
          Navigator.pop(context);
        },
        child: PixelBox(
          borderColor: picked == code ? PixelColors.ink : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(child: PixelText(label, size: 18)),
              if (picked == code) const Icon(Icons.check_rounded, size: 22, color: PixelColors.title),
            ],
          ),
        ),
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelText(_language.of(lang), size: 20),
            const SizedBox(height: 12),
            option(null, _followDevice.of(lang)),
            for (final code in AppLanguage.choices) option(code, _languageNames[code]!),
            PixelText(_languageNote.of(lang), size: 12, color: PixelColors.muted),
          ],
        ),
      ),
    );
  },
);

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
    child: PixelText(text, size: 13, color: PixelColors.muted),
  );
}

/// A card of rows with hairlines between them.
class _Group extends StatelessWidget {
  const _Group({required this.rows});
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => PixelBox(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (final (i, row) in rows.indexed) ...[
          if (i > 0) Container(height: pu, margin: const EdgeInsets.symmetric(horizontal: 12), color: PixelColors.line),
          row,
        ],
      ],
    ),
  );
}

class _Row extends StatefulWidget {
  const _Row({super.key, required this.icon, required this.label, this.sub, this.value, this.count, this.onTap});
  final IconData? icon;
  final String label;

  /// Small line under the label.
  final String? sub;

  /// Short text at the right (rows that open nothing).
  final String? value;
  final String? count;
  final VoidCallback? onTap;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final row = ColoredBox(
      color: _down ? PixelColors.soft : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 20, color: PixelColors.ink),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PixelText(widget.label, size: 16),
                  if (widget.sub != null) ...[
                    const SizedBox(height: 2),
                    PixelText(widget.sub!, size: 12, color: PixelColors.muted),
                  ],
                ],
              ),
            ),
            if (widget.value != null) ...[
              const SizedBox(width: 8),
              PixelText(widget.value!, size: 16, color: PixelColors.muted),
            ],
            if (widget.count != null) ...[
              const SizedBox(width: 8),
              PixelText(widget.count!, size: 12, color: PixelColors.muted),
            ],
            if (widget.onTap != null) const Icon(Icons.chevron_right_rounded, size: 22, color: PixelColors.muted),
          ],
        ),
      ),
    );
    if (widget.onTap == null) return row;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: row,
      ),
    );
  }
}

/// One of the text pages: privacy policy, terms or data credits.
class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.doc});
  final LegalDoc doc;

  @override
  Widget build(BuildContext context) {
    final lang = langOf(context);
    final contact = contactFor(lang);
    return Scaffold(
      backgroundColor: PixelColors.background,
      appBar: _bar(doc.title.of(lang)),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            if (doc.dated)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: PixelText('${effectiveLabel.of(lang)} $legalEffectiveDate', size: 12, color: PixelColors.muted),
              ),
            Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 14), child: _Body(doc.lead.of(lang))),
            for (final s in doc.sections) ...[
              PixelBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 5, right: 8),
                          child: PixelSquare(color: PixelColors.title, size: 10),
                        ),
                        Expanded(child: PixelText(s.heading.of(lang), size: 17)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _Body(s.body.of(lang).replaceAll('{contact}', contact)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

/// Body text: paragraphs split by a blank line, "・" lines as a hanging list.
class _Body extends StatelessWidget {
  const _Body(this.text);
  final String text;

  static const _style = TextStyle(fontSize: 13.5, height: 1.65, color: PixelColors.ink, fontWeight: FontWeight.w500);

  @override
  Widget build(BuildContext context) {
    final paragraphs = text.split('\n\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, p) in paragraphs.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          for (final line in p.split('\n'))
            if (line.startsWith('・'))
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('・', style: _style),
                  Expanded(child: Text(line.substring(1), style: _style)),
                ],
              )
            else
              Text(line, style: _style),
        ],
      ],
    );
  }
}

/// Licence texts by package, read once from Flutter's [LicenseRegistry]
/// (the packages' licences plus the fonts added by [registerFontLicenses] when
/// the app starts).
Future<Map<String, List<LicenseEntry>>> _collectLicenses() async {
  final byPackage = <String, List<LicenseEntry>>{};
  try {
    await for (final entry in LicenseRegistry.licenses) {
      for (final package in entry.packages) {
        byPackage.putIfAbsent(package, () => []).add(entry);
      }
    }
  } catch (_) {
    // A licence file that cannot be read: show the ones that could.
  }
  return byPackage;
}

/// ライセンス: the bundled fonts first, then every open-source package.
class LicensesPage extends StatefulWidget {
  const LicensesPage({super.key});

  @override
  State<LicensesPage> createState() => _LicensesPageState();
}

class _LicensesPageState extends State<LicensesPage> {
  late final Future<Map<String, List<LicenseEntry>>> _licenses = _collectLicenses();

  @override
  Widget build(BuildContext context) {
    final lang = langOf(context);
    return Scaffold(
      backgroundColor: PixelColors.background,
      appBar: _bar(licensesTitle.of(lang)),
      body: FutureBuilder<Map<String, List<LicenseEntry>>>(
        future: _licenses,
        builder: (context, snap) {
          final all = snap.data;
          if (all == null) return const Center(child: PixelText('…', size: 22, color: PixelColors.muted));
          final fonts = [
            for (final name in fontLicenses.keys)
              if (all.containsKey(name)) name,
          ];
          final packages = [
            for (final name in all.keys)
              if (!fontLicenses.containsKey(name)) name,
          ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          Widget group(List<String> names) => _Group(
            rows: [
              for (final name in names)
                _Row(
                  key: ValueKey('license.$name'),
                  icon: null,
                  label: name,
                  count: all[name]!.length > 1 ? '${all[name]!.length}${_licenseCount.of(lang)}' : null,
                  onTap: () => _push(context, LicenseTextPage(name: name, entries: all[name]!)),
                ),
            ],
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 6), child: _Body(_licensesLead.of(lang))),
              if (fonts.isNotEmpty) ...[_GroupLabel(_fonts.of(lang)), group(fonts), const SizedBox(height: 18)],
              if (packages.isNotEmpty) ...[_GroupLabel(_software.of(lang)), group(packages)],
            ],
          );
        },
      ),
    );
  }
}

/// The full licence text(s) of one font or package.
class LicenseTextPage extends StatelessWidget {
  const LicenseTextPage({super.key, required this.name, required this.entries});
  final String name;
  final List<LicenseEntry> entries;

  @override
  Widget build(BuildContext context) {
    // Flat list (text, indent) with null between licences, built lazily:
    // Flutter itself carries hundreds of them.
    final lines = <LicenseParagraph?>[];
    for (final (i, e) in entries.indexed) {
      if (i > 0) lines.add(null);
      lines.addAll(e.paragraphs);
    }
    return Scaffold(
      backgroundColor: PixelColors.background,
      appBar: _bar(name),
      body: SelectionArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          itemCount: lines.length,
          itemBuilder: (context, i) {
            final p = lines[i];
            if (p == null) {
              return Container(height: pu, margin: const EdgeInsets.symmetric(vertical: 14), color: PixelColors.line);
            }
            final centered = p.indent == LicenseParagraph.centeredIndent;
            return Padding(
              padding: EdgeInsets.only(bottom: 8, left: centered ? 0 : 12.0 * p.indent),
              child: Text(
                p.text,
                textAlign: centered ? TextAlign.center : TextAlign.start,
                style: const TextStyle(fontSize: 12, height: 1.5, color: PixelColors.ink),
              ),
            );
          },
        ),
      ),
    );
  }
}
