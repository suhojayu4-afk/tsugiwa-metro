import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/app_info.dart';
import '../../core/localized_text.dart';
import '../../core/pixel/pixel_ui.dart';
import '../../core/services.dart';
import '../guide/first_ride_data.dart' show firstRideTitle;
import '../guide/first_ride_screen.dart';
import 'app_look.dart';
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
const _groupLook = LocalizedText({'ja': '見た目と音', 'ko': '모양과 소리', 'en': 'Look and sound'});
const _groupData = LocalizedText({'ja': '権限とデータ', 'ko': '권한과 데이터', 'en': 'Permissions and data'});
const _look = LocalizedText({'ja': '見た目', 'ko': '화면 모드', 'en': 'Appearance'});
const _lookNames = {
  'system': _followDevice,
  'light': LocalizedText({'ja': 'ライト', 'ko': '라이트', 'en': 'Light'}),
  'dark': LocalizedText({'ja': 'ダーク', 'ko': '다크', 'en': 'Dark'}),
};
const _lookNote = LocalizedText({
  'ja': '駅の絵や路線図はそのままです。乗車中にスマホが自動で切りかわったときは、降りてから変わります。',
  'ko': '역 그림과 노선도는 그대로예요. 승차 중에 휴대폰이 자동으로 바뀌면 내린 뒤에 적용돼요.',
  'en': 'Station pictures and the route map stay as they are. If the phone switches during a ride, the app follows after it.',
});
const _motion = LocalizedText({'ja': '動きを減らす', 'ko': '움직임 줄이기', 'en': 'Reduce motion'});
const _motionSub = LocalizedText({
  'ja': '絵のアニメーションを止めます（電池の節約にも）',
  'ko': '그림 애니메이션을 멈춰요 (배터리 절약에도 좋아요)',
  'en': 'Stops the picture animations (also saves battery)',
});
const _sound = LocalizedText({'ja': '到着音とメロディ', 'ko': '도착음과 멜로디', 'en': 'Arrival sound and melody'});
const _on = LocalizedText({'ja': 'オン', 'ko': '켬', 'en': 'On'});
const _off = LocalizedText({'ja': 'オフ', 'ko': '끔', 'en': 'Off'});
const _permissions = LocalizedText({
  'ja': '位置情報と通知の設定',
  'ko': '위치·알림 권한 설정',
  'en': 'Location and notification settings',
});
const _permissionsSub = LocalizedText({
  'ja': 'スマホの設定をひらきます',
  'ko': '휴대폰 설정 화면을 열어요',
  'en': "Opens the phone's settings",
});
const _erase = LocalizedText({'ja': 'データをすべて消す', 'ko': '모든 데이터 지우기', 'en': 'Delete all data'});
const _eraseAsk = LocalizedText({
  'ja': 'コイン、スタンプ、買ったアイテム、アルバム、設定がこのスマホから消えます。もとに戻せません。',
  'ko': '코인, 스탬프, 구입한 아이템, 앨범, 설정이 이 휴대폰에서 지워져요. 되돌릴 수 없어요.',
  'en': 'Coins, stamps, items you bought, the album and settings are removed from this phone. This cannot be undone.',
});
const _eraseDo = LocalizedText({'ja': '消す', 'ko': '지우기', 'en': 'Delete'});
const _cancel = LocalizedText({'ja': 'やめる', 'ko': '취소', 'en': 'Cancel'});
const _contact = LocalizedText({'ja': 'お問い合わせ', 'ko': '문의하기', 'en': 'Contact'});
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
      child: SizedBox(width: 44, height: 44, child: Icon(Icons.settings_rounded, size: 24, color: PixelColors.ink)),
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
            _GroupLabel(_groupLook.of(lang)),
            _Group(
              rows: [
                ValueListenableBuilder<String>(
                  valueListenable: AppLook.look,
                  builder: (context, look, _) => _Row(
                    key: const ValueKey('settings.look'),
                    icon: Icons.dark_mode_rounded,
                    label: _look.of(lang),
                    sub: _lookNames[look]!.of(lang),
                    onTap: () => _pickLook(context),
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: AppLook.reduceMotion,
                  builder: (context, on, _) => _Row(
                    key: const ValueKey('settings.motion'),
                    icon: Icons.motion_photos_off_rounded,
                    label: _motion.of(lang),
                    sub: _motionSub.of(lang),
                    value: (on ? _on : _off).of(lang),
                    onTap: () => AppLook.setReduceMotion(!on),
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: AppLook.sound,
                  builder: (context, on, _) => _Row(
                    key: const ValueKey('settings.sound'),
                    icon: on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    label: _sound.of(lang),
                    value: (on ? _on : _off).of(lang),
                    onTap: () => AppLook.setSound(!on),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _GroupLabel(_groupData.of(lang)),
            _Group(
              rows: [
                _Row(
                  key: const ValueKey('settings.permissions'),
                  icon: Icons.my_location_rounded,
                  label: _permissions.of(lang),
                  sub: _permissionsSub.of(lang),
                  onTap: () => Geolocator.openAppSettings(),
                ),
                if (supportContact.isNotEmpty)
                  _Row(
                    key: const ValueKey('settings.contact'),
                    icon: Icons.mail_rounded,
                    label: _contact.of(lang),
                    sub: supportContact,
                    onTap: () async {
                      await Clipboard.setData(const ClipboardData(text: supportContact));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(supportContact)));
                    },
                  ),
                _Row(
                  key: const ValueKey('settings.erase'),
                  icon: Icons.delete_forever_rounded,
                  label: _erase.of(lang),
                  onTap: () => _eraseAll(context),
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

/// 設定 → 見た目: follow the phone, light or dark.
Future<void> _pickLook(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: PixelColors.background,
  shape: const RoundedRectangleBorder(),
  isScrollControlled: true,
  builder: (context) {
    final lang = langOf(context);
    Widget option(String look) {
      final on = AppLook.look.value == look;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          key: ValueKey('settings.look.$look'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Navigator.pop(context);
            AppLook.setLook(look);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: PixelColors.card,
              border: Border.all(color: on ? PixelColors.ink : PixelColors.line, width: on ? 2 : 1),
            ),
            child: Row(
              children: [
                Expanded(child: PixelText(_lookNames[look]!.of(lang), size: 18)),
                if (on) Icon(Icons.check_rounded, size: 20, color: PixelColors.ink),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelText(_look.of(lang), size: 22),
            const SizedBox(height: 12),
            for (final look in AppLook.looks) option(look),
            const SizedBox(height: 4),
            PixelText(_lookNote.of(lang), size: 12, color: PixelColors.muted),
          ],
        ),
      ),
    );
  },
);

/// 設定 → データをすべて消す: asks first, then empties this phone's store
/// and starts the app afresh (first-run tour, Tokyo, no coins).
Future<void> _eraseAll(BuildContext context) async {
  final lang = langOf(context);
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: PixelColors.card,
      shape: const RoundedRectangleBorder(),
      title: PixelText(_erase.of(lang), size: 20),
      content: Text(_eraseAsk.of(lang), style: TextStyle(color: PixelColors.ink, height: 1.5)),
      actions: [
        TextButton(
          key: const ValueKey('settings.erase.cancel'),
          onPressed: () => Navigator.pop(context, false),
          child: Text(_cancel.of(lang), style: TextStyle(color: PixelColors.ink)),
        ),
        TextButton(
          key: const ValueKey('settings.erase.yes'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            _eraseDo.of(lang),
            style: TextStyle(color: PixelColors.danger, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
  if (yes != true) return;
  await eraseAllData();
}

/// Empties everything the app keeps on this phone and builds it again from
/// the top with the settings as on a first start.
Future<void> eraseAllData() async {
  try {
    await (await SharedPreferences.getInstance()).clear();
  } catch (_) {
    // Nothing kept, nothing to clear.
  }
  // What is held in memory goes too: the stores are made anew.
  Services.reset();
  await AppLanguage.load();
  await AppCity.load();
  await AppLook.load();
  AppLook.restart.value++;
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
  'osaka': LocalizedText({
    'ja': '大阪メトロ全線と大阪環状線。大阪城・通天閣・道頓堀の路線図',
    'ko': '오사카 메트로 전 노선과 오사카 순환선. 오사카성·츠텐카쿠·도톤보리의 노선도',
    'en': 'Every Osaka Metro line and the Osaka Loop; Osaka Castle, Tsutenkaku and Dotonbori on the map',
  }),
  'fukuoka': LocalizedText({
    'ja': '福岡市地下鉄 空港線・箱崎線・七隈線。福岡タワー・大濠公園・中洲の屋台',
    'ko': '후쿠오카 지하철 공항선·하코자키선·나나쿠마선. 후쿠오카 타워·오호리 공원·나카스 포장마차',
    'en': 'Fukuoka subway: Airport, Hakozaki and Nanakuma lines; Fukuoka Tower, Ohori Park and the Nakasu stalls',
  }),
  'sendai': LocalizedText({
    'ja': '仙台市地下鉄 南北線・東西線とJR仙石線で松島へ。青葉城・瑞鳳殿',
    'ko': '센다이 지하철 남북선·동서선과 JR 센세키선으로 마쓰시마까지. 아오바성·즈이호덴',
    'en': 'Sendai subway Namboku and Tozai lines, and the JR Senseki Line to Matsushima; Aoba Castle and Zuihoden',
  }),
  'sapporo': LocalizedText({
    'ja': '札幌市営地下鉄3路線・市電とJR函館線で小樽へ。時計台・大通公園・藻岩山',
    'ko': '삿포로 지하철 3개 노선·시덴과 JR 하코다테선으로 오타루까지. 시계탑·오도리 공원·모이와산',
    'en': 'Three Sapporo subway lines, the streetcar and the JR Hakodate Line to Otaru; the Clock Tower, Odori Park, Mt. Moiwa',
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
              if (picked == code) Icon(Icons.check_rounded, size: 22, color: PixelColors.title),
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
            if (widget.onTap != null) Icon(Icons.chevron_right_rounded, size: 22, color: PixelColors.muted),
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
                        Padding(
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

  static TextStyle get _style =>
      TextStyle(fontSize: 13.5, height: 1.65, color: PixelColors.ink, fontWeight: FontWeight.w500);

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
                  Text('・', style: _style),
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
          if (all == null) return Center(child: PixelText('…', size: 22, color: PixelColors.muted));
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
                style: TextStyle(fontSize: 12, height: 1.5, color: PixelColors.ink),
              ),
            );
          },
        ),
      ),
    );
  }
}
