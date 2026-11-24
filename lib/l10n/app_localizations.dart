import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ja, this message translates to:
  /// **'つぎは Metro'**
  String get appTitle;

  /// No description provided for @nearestButton.
  ///
  /// In ja, this message translates to:
  /// **'現在地から'**
  String get nearestButton;

  /// No description provided for @locating.
  ///
  /// In ja, this message translates to:
  /// **'現在地をさがしています…'**
  String get locating;

  /// No description provided for @nearestNone.
  ///
  /// In ja, this message translates to:
  /// **'近くに対応している駅がありません'**
  String get nearestNone;

  /// No description provided for @locationOff.
  ///
  /// In ja, this message translates to:
  /// **'位置情報がオフです。設定で許可してください'**
  String get locationOff;

  /// No description provided for @nearestFound.
  ///
  /// In ja, this message translates to:
  /// **'いちばん近い駅：{station}（約{meters}m）'**
  String nearestFound(String station, int meters);

  /// No description provided for @weatherSunny.
  ///
  /// In ja, this message translates to:
  /// **'晴れ'**
  String get weatherSunny;

  /// No description provided for @weatherCloudy.
  ///
  /// In ja, this message translates to:
  /// **'くもり'**
  String get weatherCloudy;

  /// No description provided for @weatherRain.
  ///
  /// In ja, this message translates to:
  /// **'雨'**
  String get weatherRain;

  /// No description provided for @weatherSnow.
  ///
  /// In ja, this message translates to:
  /// **'雪'**
  String get weatherSnow;

  /// No description provided for @weatherUnknown.
  ///
  /// In ja, this message translates to:
  /// **'―'**
  String get weatherUnknown;

  /// No description provided for @humidityLabel.
  ///
  /// In ja, this message translates to:
  /// **'湿度'**
  String get humidityLabel;

  /// No description provided for @rainChanceLabel.
  ///
  /// In ja, this message translates to:
  /// **'降水確率'**
  String get rainChanceLabel;

  /// No description provided for @weatherCredit.
  ///
  /// In ja, this message translates to:
  /// **'出典：気象庁（データを加工して作成）'**
  String get weatherCredit;

  /// No description provided for @weatherError.
  ///
  /// In ja, this message translates to:
  /// **'天気を取得できませんでした'**
  String get weatherError;

  /// No description provided for @platformInfo.
  ///
  /// In ja, this message translates to:
  /// **'のりば情報'**
  String get platformInfo;

  /// No description provided for @nextTrainIn.
  ///
  /// In ja, this message translates to:
  /// **'つぎの電車 {minutes}分後'**
  String nextTrainIn(int minutes);

  /// No description provided for @trainsEvery.
  ///
  /// In ja, this message translates to:
  /// **'約{minutes}分おきに来ます'**
  String trainsEvery(int minutes);

  /// No description provided for @lastTrainAbout.
  ///
  /// In ja, this message translates to:
  /// **'終電の目安 {time}'**
  String lastTrainAbout(String time);

  /// No description provided for @outOfService.
  ///
  /// In ja, this message translates to:
  /// **'運転時間外です（始発の目安 {time}）'**
  String outOfService(String time);

  /// No description provided for @estimateBadge.
  ///
  /// In ja, this message translates to:
  /// **'予想'**
  String get estimateBadge;

  /// No description provided for @liveBadge.
  ///
  /// In ja, this message translates to:
  /// **'リアルタイム'**
  String get liveBadge;

  /// No description provided for @tabPlatform.
  ///
  /// In ja, this message translates to:
  /// **'のりば'**
  String get tabPlatform;

  /// No description provided for @tabMap.
  ///
  /// In ja, this message translates to:
  /// **'路線図'**
  String get tabMap;

  /// No description provided for @tabMy.
  ///
  /// In ja, this message translates to:
  /// **'MY'**
  String get tabMy;

  /// No description provided for @comingSoon.
  ///
  /// In ja, this message translates to:
  /// **'じゅんび中…'**
  String get comingSoon;

  /// No description provided for @comingSoonMap.
  ///
  /// In ja, this message translates to:
  /// **'路線図は次のステップでできあがります'**
  String get comingSoonMap;

  /// No description provided for @comingSoonMy.
  ///
  /// In ja, this message translates to:
  /// **'MYルームは もうすこし先で 開きます'**
  String get comingSoonMy;

  /// No description provided for @from.
  ///
  /// In ja, this message translates to:
  /// **'出発'**
  String get from;

  /// No description provided for @to.
  ///
  /// In ja, this message translates to:
  /// **'到着'**
  String get to;

  /// No description provided for @selectStation.
  ///
  /// In ja, this message translates to:
  /// **'駅をえらぶ'**
  String get selectStation;

  /// No description provided for @searchHint.
  ///
  /// In ja, this message translates to:
  /// **'駅名で検索（ひらがな・ローマ字もOK）'**
  String get searchHint;

  /// No description provided for @swap.
  ///
  /// In ja, this message translates to:
  /// **'入れかえ'**
  String get swap;

  /// No description provided for @startTrip.
  ///
  /// In ja, this message translates to:
  /// **'追跡スタート'**
  String get startTrip;

  /// No description provided for @endTrip.
  ///
  /// In ja, this message translates to:
  /// **'終了する'**
  String get endTrip;

  /// No description provided for @routeSummary.
  ///
  /// In ja, this message translates to:
  /// **'約{minutes}分 · {stops}駅 · {transfers, plural, =0{乗換なし} other{乗換{transfers}回}}'**
  String routeSummary(int minutes, int stops, int transfers);

  /// No description provided for @stopCount.
  ///
  /// In ja, this message translates to:
  /// **'{count}駅'**
  String stopCount(int count);

  /// No description provided for @nowLabel.
  ///
  /// In ja, this message translates to:
  /// **'いま'**
  String get nowLabel;

  /// No description provided for @nextLabel.
  ///
  /// In ja, this message translates to:
  /// **'つぎは'**
  String get nextLabel;

  /// No description provided for @remainingLabel.
  ///
  /// In ja, this message translates to:
  /// **'のこり'**
  String get remainingLabel;

  /// No description provided for @etaLabel.
  ///
  /// In ja, this message translates to:
  /// **'到着予定'**
  String get etaLabel;

  /// No description provided for @betweenStations.
  ///
  /// In ja, this message translates to:
  /// **'{from} → {to}'**
  String betweenStations(String from, String to);

  /// No description provided for @gpsCorrected.
  ///
  /// In ja, this message translates to:
  /// **'GPSで補正中'**
  String get gpsCorrected;

  /// No description provided for @gpsUnderground.
  ///
  /// In ja, this message translates to:
  /// **'地下区間・時刻表で推定'**
  String get gpsUnderground;

  /// No description provided for @gpsWaiting.
  ///
  /// In ja, this message translates to:
  /// **'時刻表で推定中'**
  String get gpsWaiting;

  /// No description provided for @gpsOff.
  ///
  /// In ja, this message translates to:
  /// **'位置情報オフ・時刻表で推定'**
  String get gpsOff;

  /// No description provided for @approachingTitle.
  ///
  /// In ja, this message translates to:
  /// **'つぎは {station}'**
  String approachingTitle(String station);

  /// No description provided for @approachingBody.
  ///
  /// In ja, this message translates to:
  /// **'まもなく到着です。降りる準備をしましょう'**
  String get approachingBody;

  /// No description provided for @arrivedTitle.
  ///
  /// In ja, this message translates to:
  /// **'到着しました！'**
  String get arrivedTitle;

  /// No description provided for @arrivedBody.
  ///
  /// In ja, this message translates to:
  /// **'{station}に着きました。おつかれさま！'**
  String arrivedBody(String station);

  /// No description provided for @backHome.
  ///
  /// In ja, this message translates to:
  /// **'ホームへ'**
  String get backHome;

  /// No description provided for @transferHere.
  ///
  /// In ja, this message translates to:
  /// **'ここで{line}に乗り換え'**
  String transferHere(String line);

  /// No description provided for @sameStation.
  ///
  /// In ja, this message translates to:
  /// **'出発駅と到着駅が同じです'**
  String get sameStation;

  /// No description provided for @noRoute.
  ///
  /// In ja, this message translates to:
  /// **'経路が見つかりません'**
  String get noRoute;

  /// No description provided for @testSpeed.
  ///
  /// In ja, this message translates to:
  /// **'テスト速度'**
  String get testSpeed;

  /// No description provided for @loading.
  ///
  /// In ja, this message translates to:
  /// **'読み込み中…'**
  String get loading;

  /// No description provided for @estimateNote.
  ///
  /// In ja, this message translates to:
  /// **'時刻は時刻表からの推定です'**
  String get estimateNote;

  /// No description provided for @destinationLabel.
  ///
  /// In ja, this message translates to:
  /// **'行き先'**
  String get destinationLabel;

  /// No description provided for @quickRoutes.
  ///
  /// In ja, this message translates to:
  /// **'よく使うルート'**
  String get quickRoutes;

  /// No description provided for @recentRoutes.
  ///
  /// In ja, this message translates to:
  /// **'さいきん'**
  String get recentRoutes;

  /// No description provided for @favHome.
  ///
  /// In ja, this message translates to:
  /// **'自宅へ'**
  String get favHome;

  /// No description provided for @favWork.
  ///
  /// In ja, this message translates to:
  /// **'会社へ'**
  String get favWork;

  /// No description provided for @nextTrainTitle.
  ///
  /// In ja, this message translates to:
  /// **'つぎの電車'**
  String get nextTrainTitle;

  /// No description provided for @favHint.
  ///
  /// In ja, this message translates to:
  /// **'経路をえらんで ☆ をおすと、ここに登録されます'**
  String get favHint;

  /// No description provided for @favChooseTitle.
  ///
  /// In ja, this message translates to:
  /// **'どんなルート？'**
  String get favChooseTitle;

  /// No description provided for @favOther.
  ///
  /// In ja, this message translates to:
  /// **'お気に入り'**
  String get favOther;

  /// No description provided for @favRemoveConfirm.
  ///
  /// In ja, this message translates to:
  /// **'「{route}」をお気に入りから外しますか？'**
  String favRemoveConfirm(String route);

  /// No description provided for @remove.
  ///
  /// In ja, this message translates to:
  /// **'外す'**
  String get remove;

  /// No description provided for @cancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get cancel;

  /// No description provided for @favAdded.
  ///
  /// In ja, this message translates to:
  /// **'お気に入りに登録しました'**
  String get favAdded;

  /// No description provided for @liveFar.
  ///
  /// In ja, this message translates to:
  /// **'{dest}まで あと{n}駅'**
  String liveFar(String dest, int n);

  /// No description provided for @liveNear.
  ///
  /// In ja, this message translates to:
  /// **'あと{n}駅で {dest}'**
  String liveNear(int n, String dest);

  /// No description provided for @liveNext.
  ///
  /// In ja, this message translates to:
  /// **'つぎは {station}'**
  String liveNext(String station);

  /// No description provided for @liveArrived.
  ///
  /// In ja, this message translates to:
  /// **'{dest}に到着'**
  String liveArrived(String dest);

  /// No description provided for @liveFlow.
  ///
  /// In ja, this message translates to:
  /// **'いま {now} → つぎ {next}'**
  String liveFlow(String now, String next);

  /// No description provided for @liveSub.
  ///
  /// In ja, this message translates to:
  /// **'{line} · {eta}着'**
  String liveSub(String line, String eta);

  /// No description provided for @liveShort.
  ///
  /// In ja, this message translates to:
  /// **'あと{n}駅'**
  String liveShort(int n);

  /// No description provided for @liveEnd.
  ///
  /// In ja, this message translates to:
  /// **'終了'**
  String get liveEnd;

  /// No description provided for @alertApproachTitle.
  ///
  /// In ja, this message translates to:
  /// **'まもなく {dest}'**
  String alertApproachTitle(String dest);

  /// No description provided for @alertApproachBody.
  ///
  /// In ja, this message translates to:
  /// **'つぎで降ります。準備してね'**
  String get alertApproachBody;

  /// No description provided for @alertArrivedTitle.
  ///
  /// In ja, this message translates to:
  /// **'{dest}に到着しました'**
  String alertArrivedTitle(String dest);

  /// No description provided for @alertArrivedBody.
  ///
  /// In ja, this message translates to:
  /// **'おつかれさま！'**
  String get alertArrivedBody;

  /// No description provided for @channelTrip.
  ///
  /// In ja, this message translates to:
  /// **'移動中の表示'**
  String get channelTrip;

  /// No description provided for @channelApproach.
  ///
  /// In ja, this message translates to:
  /// **'降りる駅のお知らせ'**
  String get channelApproach;

  /// No description provided for @channelArrive.
  ///
  /// In ja, this message translates to:
  /// **'到着のお知らせ'**
  String get channelArrive;

  /// No description provided for @mapFitAll.
  ///
  /// In ja, this message translates to:
  /// **'全体'**
  String get mapFitAll;

  /// No description provided for @mapZoomIn.
  ///
  /// In ja, this message translates to:
  /// **'拡大'**
  String get mapZoomIn;

  /// No description provided for @mapZoomOut.
  ///
  /// In ja, this message translates to:
  /// **'縮小'**
  String get mapZoomOut;

  /// No description provided for @mapSearch.
  ///
  /// In ja, this message translates to:
  /// **'駅をさがす'**
  String get mapSearch;

  /// No description provided for @mapTransfers.
  ///
  /// In ja, this message translates to:
  /// **'のりかえ'**
  String get mapTransfers;

  /// No description provided for @mapTips.
  ///
  /// In ja, this message translates to:
  /// **'駅のヒント'**
  String get mapTips;

  /// No description provided for @mapTipsNote.
  ///
  /// In ja, this message translates to:
  /// **'※ 情報は目安です。現地の案内も確認してね'**
  String get mapTipsNote;

  /// No description provided for @mapNoTips.
  ///
  /// In ja, this message translates to:
  /// **'この駅のヒントは じゅんび中です'**
  String get mapNoTips;

  /// No description provided for @mapSetFrom.
  ///
  /// In ja, this message translates to:
  /// **'出発にする'**
  String get mapSetFrom;

  /// No description provided for @mapSetTo.
  ///
  /// In ja, this message translates to:
  /// **'到着にする'**
  String get mapSetTo;

  /// No description provided for @mapCourses.
  ///
  /// In ja, this message translates to:
  /// **'おでかけコース'**
  String get mapCourses;

  /// No description provided for @courseHint.
  ///
  /// In ja, this message translates to:
  /// **'駅に行くとスタンプ。ぜんぶ集めると制覇！'**
  String get courseHint;

  /// No description provided for @courseDone.
  ///
  /// In ja, this message translates to:
  /// **'制覇！'**
  String get courseDone;

  /// No description provided for @courseGo.
  ///
  /// In ja, this message translates to:
  /// **'次の駅へ'**
  String get courseGo;

  /// No description provided for @courseProgress.
  ///
  /// In ja, this message translates to:
  /// **'スタンプ {done}/{total}'**
  String courseProgress(int done, int total);

  /// No description provided for @courseHours.
  ///
  /// In ja, this message translates to:
  /// **'約{hours}時間'**
  String courseHours(int hours);

  /// No description provided for @courseDay.
  ///
  /// In ja, this message translates to:
  /// **'1日'**
  String get courseDay;

  /// No description provided for @exitGuide.
  ///
  /// In ja, this message translates to:
  /// **'出口ガイド'**
  String get exitGuide;

  /// No description provided for @mapStampMode.
  ///
  /// In ja, this message translates to:
  /// **'スタンプ地図'**
  String get mapStampMode;

  /// No description provided for @mapStampSummary.
  ///
  /// In ja, this message translates to:
  /// **'{visited}/{total}駅・制覇{lines}路線・★{gold}'**
  String mapStampSummary(int visited, int total, int lines, int gold);

  /// No description provided for @mapNamesSwap.
  ///
  /// In ja, this message translates to:
  /// **'駅名の言語'**
  String get mapNamesSwap;

  /// No description provided for @boardSource.
  ///
  /// In ja, this message translates to:
  /// **'運行情報：公共交通オープンデータセンター'**
  String get boardSource;

  /// No description provided for @boardAllNormal.
  ///
  /// In ja, this message translates to:
  /// **'現在、平常どおり運転しています'**
  String get boardAllNormal;

  /// No description provided for @boardDelay.
  ///
  /// In ja, this message translates to:
  /// **'遅延'**
  String get boardDelay;

  /// No description provided for @boardTitle.
  ///
  /// In ja, this message translates to:
  /// **'発車標'**
  String get boardTitle;

  /// No description provided for @boardSoon.
  ///
  /// In ja, this message translates to:
  /// **'まもなく'**
  String get boardSoon;

  /// No description provided for @boardNote.
  ///
  /// In ja, this message translates to:
  /// **'時刻は時刻表からの目安です。駅の案内も確認してね'**
  String get boardNote;

  /// No description provided for @boardPickStation.
  ///
  /// In ja, this message translates to:
  /// **'出発駅をえらぶと、次の電車が表示されます'**
  String get boardPickStation;

  /// No description provided for @boardEnded.
  ///
  /// In ja, this message translates to:
  /// **'本日の運転は終了しました'**
  String get boardEnded;

  /// No description provided for @boardBound.
  ///
  /// In ja, this message translates to:
  /// **'{station} 行'**
  String boardBound(String station);

  /// No description provided for @routeFoldedPick.
  ///
  /// In ja, this message translates to:
  /// **'出発と到着をえらぶ'**
  String get routeFoldedPick;

  /// No description provided for @mapNightView.
  ///
  /// In ja, this message translates to:
  /// **'夜の地図'**
  String get mapNightView;

  /// No description provided for @mapDayView.
  ///
  /// In ja, this message translates to:
  /// **'昼の地図'**
  String get mapDayView;

  /// No description provided for @mapMyRoute.
  ///
  /// In ja, this message translates to:
  /// **'マイルート'**
  String get mapMyRoute;

  /// No description provided for @mapRouteShow.
  ///
  /// In ja, this message translates to:
  /// **'ルートを見る'**
  String get mapRouteShow;

  /// No description provided for @mapRouteHide.
  ///
  /// In ja, this message translates to:
  /// **'ルートを隠す'**
  String get mapRouteHide;

  /// No description provided for @mapTrainsNote.
  ///
  /// In ja, this message translates to:
  /// **'列車は時刻表からの推定位置です'**
  String get mapTrainsNote;

  /// No description provided for @mapLmStations.
  ///
  /// In ja, this message translates to:
  /// **'最寄り駅'**
  String get mapLmStations;

  /// No description provided for @mapFrom.
  ///
  /// In ja, this message translates to:
  /// **'出発'**
  String get mapFrom;

  /// No description provided for @mapTo.
  ///
  /// In ja, this message translates to:
  /// **'到着'**
  String get mapTo;

  /// No description provided for @transferWalk.
  ///
  /// In ja, this message translates to:
  /// **'乗換 徒歩{minutes}分'**
  String transferWalk(int minutes);

  /// No description provided for @myTitle.
  ///
  /// In ja, this message translates to:
  /// **'MY駅'**
  String get myTitle;

  /// No description provided for @myTabScene.
  ///
  /// In ja, this message translates to:
  /// **'駅'**
  String get myTabScene;

  /// No description provided for @myTabTrain.
  ///
  /// In ja, this message translates to:
  /// **'電車'**
  String get myTabTrain;

  /// No description provided for @myTabRoof.
  ///
  /// In ja, this message translates to:
  /// **'屋根'**
  String get myTabRoof;

  /// No description provided for @myTabPlatform.
  ///
  /// In ja, this message translates to:
  /// **'ホーム'**
  String get myTabPlatform;

  /// No description provided for @myTabEffect.
  ///
  /// In ja, this message translates to:
  /// **'演出'**
  String get myTabEffect;

  /// No description provided for @myTabSky.
  ///
  /// In ja, this message translates to:
  /// **'空'**
  String get myTabSky;

  /// No description provided for @myTabMark.
  ///
  /// In ja, this message translates to:
  /// **'ヘッドマーク'**
  String get myTabMark;

  /// No description provided for @myEquipped.
  ///
  /// In ja, this message translates to:
  /// **'設置中'**
  String get myEquipped;

  /// No description provided for @myOwned.
  ///
  /// In ja, this message translates to:
  /// **'もってる'**
  String get myOwned;

  /// No description provided for @myFree.
  ///
  /// In ja, this message translates to:
  /// **'無料'**
  String get myFree;

  /// No description provided for @myBuyCoins.
  ///
  /// In ja, this message translates to:
  /// **'{price}コインで買う'**
  String myBuyCoins(int price);

  /// No description provided for @myBuyYen.
  ///
  /// In ja, this message translates to:
  /// **'¥{price}で買う'**
  String myBuyYen(int price);

  /// No description provided for @myNotEnough.
  ///
  /// In ja, this message translates to:
  /// **'コインが あと{missing}たりません'**
  String myNotEnough(int missing);

  /// No description provided for @myCoinShop.
  ///
  /// In ja, this message translates to:
  /// **'コインを買う'**
  String get myCoinShop;

  /// No description provided for @myIapNotReady.
  ///
  /// In ja, this message translates to:
  /// **'お支払いは じゅんび中です（リリース前に対応）'**
  String get myIapNotReady;

  /// No description provided for @myTestCoins.
  ///
  /// In ja, this message translates to:
  /// **'テスト用：無料で追加'**
  String get myTestCoins;

  /// No description provided for @myGot.
  ///
  /// In ja, this message translates to:
  /// **'{name} を手に入れた！'**
  String myGot(String name);

  /// No description provided for @myEarnRules.
  ///
  /// In ja, this message translates to:
  /// **'移動するたびに +{trip}・はじめての駅 +{visit}・その日はじめて +{day}'**
  String myEarnRules(int trip, int visit, int day);

  /// No description provided for @myCoinsEarned.
  ///
  /// In ja, this message translates to:
  /// **'+{coins} コイン'**
  String myCoinsEarned(int coins);

  /// No description provided for @myCoinsLimited.
  ///
  /// In ja, this message translates to:
  /// **'今日のコインは上限に達しました'**
  String get myCoinsLimited;

  /// No description provided for @myUse.
  ///
  /// In ja, this message translates to:
  /// **'つかう'**
  String get myUse;

  /// No description provided for @myTabPlate.
  ///
  /// In ja, this message translates to:
  /// **'行先LED'**
  String get myTabPlate;

  /// No description provided for @myLocked.
  ///
  /// In ja, this message translates to:
  /// **'限定'**
  String get myLocked;

  /// No description provided for @myUnlockHint.
  ///
  /// In ja, this message translates to:
  /// **'{line}の駅をぜんぶ集めると もらえます'**
  String myUnlockHint(String line);

  /// No description provided for @plateTitle.
  ///
  /// In ja, this message translates to:
  /// **'行先LEDに駅名を'**
  String get plateTitle;

  /// No description provided for @plateEdit.
  ///
  /// In ja, this message translates to:
  /// **'駅名'**
  String get plateEdit;

  /// No description provided for @plateName.
  ///
  /// In ja, this message translates to:
  /// **'駅の名前（6文字まで）'**
  String get plateName;

  /// No description provided for @plateKana.
  ///
  /// In ja, this message translates to:
  /// **'よみがな（8文字まで）'**
  String get plateKana;

  /// No description provided for @plateKanaHint.
  ///
  /// In ja, this message translates to:
  /// **'れい：さくら'**
  String get plateKanaHint;

  /// No description provided for @plateSave.
  ///
  /// In ja, this message translates to:
  /// **'保存する'**
  String get plateSave;

  /// No description provided for @stampTitle.
  ///
  /// In ja, this message translates to:
  /// **'駅スタンプ帳'**
  String get stampTitle;

  /// No description provided for @stayStamped.
  ///
  /// In ja, this message translates to:
  /// **'{station}に5分いたので ゴールドスタンプ！ +{coins}'**
  String stayStamped(String station, int coins);

  /// No description provided for @stampOpen.
  ///
  /// In ja, this message translates to:
  /// **'スタンプ帳'**
  String get stampOpen;

  /// No description provided for @stampTotal.
  ///
  /// In ja, this message translates to:
  /// **'{done} / {total} 駅 あつめた'**
  String stampTotal(int done, int total);

  /// No description provided for @stampHint.
  ///
  /// In ja, this message translates to:
  /// **'はじめて行った駅にスタンプ。駅で5分すごすと ゴールドスタンプ★ 路線をぜんぶ集めると 限定アイテム！'**
  String get stampHint;

  /// No description provided for @stampReward.
  ///
  /// In ja, this message translates to:
  /// **'ぜんぶ集めると「{item}」'**
  String stampReward(String item);

  /// No description provided for @stampRewardGot.
  ///
  /// In ja, this message translates to:
  /// **'制覇！「{item}」ゲット'**
  String stampRewardGot(String item);

  /// No description provided for @shareOpen.
  ///
  /// In ja, this message translates to:
  /// **'シェア'**
  String get shareOpen;

  /// No description provided for @shareTitle.
  ///
  /// In ja, this message translates to:
  /// **'シェアカード'**
  String get shareTitle;

  /// No description provided for @shareHeading.
  ///
  /// In ja, this message translates to:
  /// **'わたしの駅'**
  String get shareHeading;

  /// No description provided for @shareStation.
  ///
  /// In ja, this message translates to:
  /// **'ようこそ「{name}」へ'**
  String shareStation(String name);

  /// No description provided for @shareStamps.
  ///
  /// In ja, this message translates to:
  /// **'スタンプ'**
  String get shareStamps;

  /// No description provided for @shareStampUnit.
  ///
  /// In ja, this message translates to:
  /// **'駅'**
  String get shareStampUnit;

  /// No description provided for @shareLines.
  ///
  /// In ja, this message translates to:
  /// **'制覇した路線'**
  String get shareLines;

  /// No description provided for @shareLineUnit.
  ///
  /// In ja, this message translates to:
  /// **'路線'**
  String get shareLineUnit;

  /// No description provided for @shareButton.
  ///
  /// In ja, this message translates to:
  /// **'シェアする'**
  String get shareButton;

  /// No description provided for @shareText.
  ///
  /// In ja, this message translates to:
  /// **'わたしの駅をつくったよ #つぎはMetro'**
  String get shareText;

  /// No description provided for @shareFailed.
  ///
  /// In ja, this message translates to:
  /// **'シェアできませんでした'**
  String get shareFailed;

  /// No description provided for @arrivedStamps.
  ///
  /// In ja, this message translates to:
  /// **'スタンプ +{count}'**
  String arrivedStamps(int count);

  /// No description provided for @arrivedLineDone.
  ///
  /// In ja, this message translates to:
  /// **'{line} 制覇！「{item}」ゲット'**
  String arrivedLineDone(String line, String item);

  /// No description provided for @widgetAdd.
  ///
  /// In ja, this message translates to:
  /// **'ウィジェット'**
  String get widgetAdd;

  /// No description provided for @widgetManual.
  ///
  /// In ja, this message translates to:
  /// **'ホーム画面を長押し →「ウィジェット」→「つぎは Metro」から追加できます'**
  String get widgetManual;

  /// No description provided for @plateHint.
  ///
  /// In ja, this message translates to:
  /// **'電車の行先表示に、名前とよみがなが 交互に出ます'**
  String get plateHint;

  /// No description provided for @mapWalkTransfers.
  ///
  /// In ja, this message translates to:
  /// **'徒歩でのりかえ'**
  String get mapWalkTransfers;

  /// No description provided for @walkMinutes.
  ///
  /// In ja, this message translates to:
  /// **'徒歩{minutes}分'**
  String walkMinutes(int minutes);

  /// No description provided for @transferWalkTo.
  ///
  /// In ja, this message translates to:
  /// **'{station}まで歩いて {line}にのりかえ'**
  String transferWalkTo(String station, String line);

  /// No description provided for @sceneGet.
  ///
  /// In ja, this message translates to:
  /// **'{name}の景色をGET'**
  String sceneGet(String name);

  /// No description provided for @lastTrainWarn.
  ///
  /// In ja, this message translates to:
  /// **'終電まであと{minutes}分'**
  String lastTrainWarn(int minutes);

  /// No description provided for @serviceEnded.
  ///
  /// In ja, this message translates to:
  /// **'本日の運行は終了（始発 {time}）'**
  String serviceEnded(String time);

  /// No description provided for @crowdTitle.
  ///
  /// In ja, this message translates to:
  /// **'混雑予想'**
  String get crowdTitle;

  /// No description provided for @crowdRelaxed.
  ///
  /// In ja, this message translates to:
  /// **'すいてる'**
  String get crowdRelaxed;

  /// No description provided for @crowdNormal.
  ///
  /// In ja, this message translates to:
  /// **'ふつう'**
  String get crowdNormal;

  /// No description provided for @crowdCrowded.
  ///
  /// In ja, this message translates to:
  /// **'混雑'**
  String get crowdCrowded;

  /// No description provided for @crowdPacked.
  ///
  /// In ja, this message translates to:
  /// **'大混雑'**
  String get crowdPacked;

  /// No description provided for @umbrellaReminder.
  ///
  /// In ja, this message translates to:
  /// **'傘を忘れずに'**
  String get umbrellaReminder;

  /// No description provided for @lastTrainAlarm.
  ///
  /// In ja, this message translates to:
  /// **'終電アラーム'**
  String get lastTrainAlarm;

  /// No description provided for @lastTrainAlarmBody.
  ///
  /// In ja, this message translates to:
  /// **'{from} → {to} の終電は {time}ごろ発。そろそろ帰る準備を！'**
  String lastTrainAlarmBody(String from, String to, String time);

  /// No description provided for @lastTrainAlarmSet.
  ///
  /// In ja, this message translates to:
  /// **'毎晩 {alarm} にお知らせします（終電 {time}ごろ）'**
  String lastTrainAlarmSet(String alarm, String time);

  /// No description provided for @lastTrainAlarmOff.
  ///
  /// In ja, this message translates to:
  /// **'終電アラームをオフにしました'**
  String get lastTrainAlarmOff;

  /// No description provided for @firstTrainIn.
  ///
  /// In ja, this message translates to:
  /// **'始発まで {hours}時間{minutes}分（{time}発）'**
  String firstTrainIn(int hours, int minutes, String time);

  /// No description provided for @firstTrainAlarm.
  ///
  /// In ja, this message translates to:
  /// **'始発アラーム'**
  String get firstTrainAlarm;

  /// No description provided for @firstTrainAlarmTitle.
  ///
  /// In ja, this message translates to:
  /// **'始発まであと{minutes}分'**
  String firstTrainAlarmTitle(int minutes);

  /// No description provided for @firstTrainAlarmBody.
  ///
  /// In ja, this message translates to:
  /// **'{from} → {to} の始発は {time}ごろ発です'**
  String firstTrainAlarmBody(String from, String to, String time);

  /// No description provided for @firstTrainAlarmSet.
  ///
  /// In ja, this message translates to:
  /// **'{alarm} にお知らせします（始発 {time}ごろ）'**
  String firstTrainAlarmSet(String alarm, String time);

  /// No description provided for @firstTrainAlarmOff.
  ///
  /// In ja, this message translates to:
  /// **'始発アラームをオフにしました'**
  String get firstTrainAlarmOff;

  /// No description provided for @taxiFare.
  ///
  /// In ja, this message translates to:
  /// **'タクシー 約{yen}円'**
  String taxiFare(String yen);

  /// No description provided for @taxiFareNight.
  ///
  /// In ja, this message translates to:
  /// **'タクシー 約{yen}円（深夜）'**
  String taxiFareNight(String yen);

  /// No description provided for @walkTime.
  ///
  /// In ja, this message translates to:
  /// **'徒歩 {minutes}分'**
  String walkTime(int minutes);

  /// No description provided for @nightWays.
  ///
  /// In ja, this message translates to:
  /// **'電車以外の目安'**
  String get nightWays;

  /// No description provided for @serviceEndedShort.
  ///
  /// In ja, this message translates to:
  /// **'本日の運行は終了'**
  String get serviceEndedShort;

  /// No description provided for @myTabMelody.
  ///
  /// In ja, this message translates to:
  /// **'メロディ'**
  String get myTabMelody;

  /// No description provided for @widgetLast.
  ///
  /// In ja, this message translates to:
  /// **'終電'**
  String get widgetLast;

  /// No description provided for @widgetFirst.
  ///
  /// In ja, this message translates to:
  /// **'始発'**
  String get widgetFirst;

  /// No description provided for @widgetChoose.
  ///
  /// In ja, this message translates to:
  /// **'ウィジェットをえらぶ'**
  String get widgetChoose;

  /// No description provided for @widgetKindMy.
  ///
  /// In ja, this message translates to:
  /// **'MY駅'**
  String get widgetKindMy;

  /// No description provided for @widgetKindMyDesc.
  ///
  /// In ja, this message translates to:
  /// **'写真と きょうの情報'**
  String get widgetKindMyDesc;

  /// No description provided for @widgetKindBoard.
  ///
  /// In ja, this message translates to:
  /// **'地下鉄案内'**
  String get widgetKindBoard;

  /// No description provided for @widgetKindBoardDesc.
  ///
  /// In ja, this message translates to:
  /// **'電光掲示板ふう シンプル'**
  String get widgetKindBoardDesc;

  /// No description provided for @widgetEvery.
  ///
  /// In ja, this message translates to:
  /// **'約{minutes}分おき'**
  String widgetEvery(int minutes);

  /// No description provided for @widgetTrip.
  ///
  /// In ja, this message translates to:
  /// **'{dest}まで 約{minutes}分'**
  String widgetTrip(String dest, int minutes);

  /// No description provided for @widgetEnded.
  ///
  /// In ja, this message translates to:
  /// **'運行終了 · 始発 {time}'**
  String widgetEnded(String time);

  /// No description provided for @widgetKindNext.
  ///
  /// In ja, this message translates to:
  /// **'つぎの電車'**
  String get widgetKindNext;

  /// No description provided for @widgetKindNextDesc.
  ///
  /// In ja, this message translates to:
  /// **'小さく 電車の間隔と所要時間'**
  String get widgetKindNextDesc;

  /// No description provided for @routeMissed.
  ///
  /// In ja, this message translates to:
  /// **'このルートは終電に間に合いません'**
  String get routeMissed;

  /// No description provided for @altRouteTitle.
  ///
  /// In ja, this message translates to:
  /// **'別ルートならまだ間に合う'**
  String get altRouteTitle;

  /// No description provided for @altRouteInfo.
  ///
  /// In ja, this message translates to:
  /// **'{time}までに出発 · {via}'**
  String altRouteInfo(String time, String via);

  /// No description provided for @altRouteUse.
  ///
  /// In ja, this message translates to:
  /// **'このルートにする'**
  String get altRouteUse;

  /// No description provided for @throughHere.
  ///
  /// In ja, this message translates to:
  /// **'そのまま{line}へ直通'**
  String throughHere(String line);

  /// No description provided for @shareStyleTicket.
  ///
  /// In ja, this message translates to:
  /// **'きっぷ'**
  String get shareStyleTicket;

  /// No description provided for @shareStylePoster.
  ///
  /// In ja, this message translates to:
  /// **'ポスター'**
  String get shareStylePoster;

  /// No description provided for @shareStyleReport.
  ///
  /// In ja, this message translates to:
  /// **'今月のレポート'**
  String get shareStyleReport;

  /// No description provided for @shareTicketHead.
  ///
  /// In ja, this message translates to:
  /// **'乗車記念'**
  String get shareTicketHead;

  /// No description provided for @shareTicketValid.
  ///
  /// In ja, this message translates to:
  /// **'{date} 当日限り有効'**
  String shareTicketValid(String date);

  /// No description provided for @shareTicketNo.
  ///
  /// In ja, this message translates to:
  /// **'No.{n}'**
  String shareTicketNo(String n);

  /// No description provided for @shareLevel.
  ///
  /// In ja, this message translates to:
  /// **'Lv.{n}'**
  String shareLevel(int n);

  /// No description provided for @shareMyTrain.
  ///
  /// In ja, this message translates to:
  /// **'MY列車'**
  String get shareMyTrain;

  /// No description provided for @shareLineProgress.
  ///
  /// In ja, this message translates to:
  /// **'路線の制覇'**
  String get shareLineProgress;

  /// No description provided for @shareInvite.
  ///
  /// In ja, this message translates to:
  /// **'招待コード'**
  String get shareInvite;

  /// No description provided for @shareInviteHint.
  ///
  /// In ja, this message translates to:
  /// **'アプリで入力すると {coins}コイン'**
  String shareInviteHint(int coins);

  /// No description provided for @shareReportTitle.
  ///
  /// In ja, this message translates to:
  /// **'{month}月の乗車レポート'**
  String shareReportTitle(String month);

  /// No description provided for @shareReportTrips.
  ///
  /// In ja, this message translates to:
  /// **'乗車'**
  String get shareReportTrips;

  /// No description provided for @shareReportTripUnit.
  ///
  /// In ja, this message translates to:
  /// **'回'**
  String get shareReportTripUnit;

  /// No description provided for @shareReportKm.
  ///
  /// In ja, this message translates to:
  /// **'移動'**
  String get shareReportKm;

  /// No description provided for @shareReportStations.
  ///
  /// In ja, this message translates to:
  /// **'通った駅'**
  String get shareReportStations;

  /// No description provided for @shareReportTopLine.
  ///
  /// In ja, this message translates to:
  /// **'いちばん乗った路線'**
  String get shareReportTopLine;

  /// No description provided for @shareReportEarliest.
  ///
  /// In ja, this message translates to:
  /// **'いちばん早い乗車'**
  String get shareReportEarliest;

  /// No description provided for @shareReportLatest.
  ///
  /// In ja, this message translates to:
  /// **'いちばん遅い乗車'**
  String get shareReportLatest;

  /// No description provided for @shareReportNone.
  ///
  /// In ja, this message translates to:
  /// **'今月はまだ乗っていません'**
  String get shareReportNone;

  /// No description provided for @shareStickers.
  ///
  /// In ja, this message translates to:
  /// **'ステッカー'**
  String get shareStickers;

  /// No description provided for @shareStickersHint.
  ///
  /// In ja, this message translates to:
  /// **'タップで貼る・ドラッグで動かす・ダブルタップで外す'**
  String get shareStickersHint;

  /// No description provided for @shareAnimated.
  ///
  /// In ja, this message translates to:
  /// **'動くカード（GIF）'**
  String get shareAnimated;

  /// No description provided for @shareMaking.
  ///
  /// In ja, this message translates to:
  /// **'作成中…'**
  String get shareMaking;

  /// No description provided for @myInviteEnter.
  ///
  /// In ja, this message translates to:
  /// **'友だちの招待コード'**
  String get myInviteEnter;

  /// No description provided for @myInviteField.
  ///
  /// In ja, this message translates to:
  /// **'6文字のコード'**
  String get myInviteField;

  /// No description provided for @myInviteUse.
  ///
  /// In ja, this message translates to:
  /// **'もらう'**
  String get myInviteUse;

  /// No description provided for @myInviteOk.
  ///
  /// In ja, this message translates to:
  /// **'{coins}コインもらいました'**
  String myInviteOk(int coins);

  /// No description provided for @myInviteOwn.
  ///
  /// In ja, this message translates to:
  /// **'自分のコードは使えません'**
  String get myInviteOwn;

  /// No description provided for @myInviteUsed.
  ///
  /// In ja, this message translates to:
  /// **'招待コードはもう使いました'**
  String get myInviteUsed;

  /// No description provided for @myInviteInvalid.
  ///
  /// In ja, this message translates to:
  /// **'コードが正しくありません'**
  String get myInviteInvalid;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
