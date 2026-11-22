// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'つぎは Metro';

  @override
  String get nearestButton => '現在地から';

  @override
  String get locating => '現在地をさがしています…';

  @override
  String get nearestNone => '近くに対応している駅がありません';

  @override
  String get locationOff => '位置情報がオフです。設定で許可してください';

  @override
  String nearestFound(String station, int meters) {
    return 'いちばん近い駅：$station（約${meters}m）';
  }

  @override
  String get weatherSunny => '晴れ';

  @override
  String get weatherCloudy => 'くもり';

  @override
  String get weatherRain => '雨';

  @override
  String get weatherSnow => '雪';

  @override
  String get weatherUnknown => '―';

  @override
  String get humidityLabel => '湿度';

  @override
  String get rainChanceLabel => '降水確率';

  @override
  String get weatherCredit => '出典：気象庁（データを加工して作成）';

  @override
  String get weatherError => '天気を取得できませんでした';

  @override
  String get platformInfo => 'のりば情報';

  @override
  String nextTrainIn(int minutes) {
    return 'つぎの電車 $minutes分後';
  }

  @override
  String trainsEvery(int minutes) {
    return '約$minutes分おきに来ます';
  }

  @override
  String lastTrainAbout(String time) {
    return '終電の目安 $time';
  }

  @override
  String outOfService(String time) {
    return '運転時間外です（始発の目安 $time）';
  }

  @override
  String get estimateBadge => '予想';

  @override
  String get liveBadge => 'リアルタイム';

  @override
  String get tabPlatform => 'のりば';

  @override
  String get tabMap => '路線図';

  @override
  String get tabMy => 'MY';

  @override
  String get comingSoon => 'じゅんび中…';

  @override
  String get comingSoonMap => '路線図は次のステップでできあがります';

  @override
  String get comingSoonMy => 'MYルームは もうすこし先で 開きます';

  @override
  String get from => '出発';

  @override
  String get to => '到着';

  @override
  String get selectStation => '駅をえらぶ';

  @override
  String get searchHint => '駅名で検索（ひらがな・ローマ字もOK）';

  @override
  String get swap => '入れかえ';

  @override
  String get startTrip => '追跡スタート';

  @override
  String get endTrip => '終了する';

  @override
  String routeSummary(int minutes, int stops, int transfers) {
    String _temp0 = intl.Intl.pluralLogic(
      transfers,
      locale: localeName,
      other: '乗換$transfers回',
      zero: '乗換なし',
    );
    return '約$minutes分 · $stops駅 · $_temp0';
  }

  @override
  String stopCount(int count) {
    return '$count駅';
  }

  @override
  String get nowLabel => 'いま';

  @override
  String get nextLabel => 'つぎは';

  @override
  String get remainingLabel => 'のこり';

  @override
  String get etaLabel => '到着予定';

  @override
  String betweenStations(String from, String to) {
    return '$from → $to';
  }

  @override
  String get gpsCorrected => 'GPSで補正中';

  @override
  String get gpsUnderground => '地下区間・時刻表で推定';

  @override
  String get gpsWaiting => '時刻表で推定中';

  @override
  String get gpsOff => '位置情報オフ・時刻表で推定';

  @override
  String approachingTitle(String station) {
    return 'つぎは $station';
  }

  @override
  String get approachingBody => 'まもなく到着です。降りる準備をしましょう';

  @override
  String get arrivedTitle => '到着しました！';

  @override
  String arrivedBody(String station) {
    return '$stationに着きました。おつかれさま！';
  }

  @override
  String get backHome => 'ホームへ';

  @override
  String transferHere(String line) {
    return 'ここで$lineに乗り換え';
  }

  @override
  String get sameStation => '出発駅と到着駅が同じです';

  @override
  String get noRoute => '経路が見つかりません';

  @override
  String get testSpeed => 'テスト速度';

  @override
  String get loading => '読み込み中…';

  @override
  String get estimateNote => '時刻は時刻表からの推定です';

  @override
  String get destinationLabel => '行き先';

  @override
  String get quickRoutes => 'よく使うルート';

  @override
  String get recentRoutes => 'さいきん';

  @override
  String get favHome => '自宅へ';

  @override
  String get favWork => '会社へ';

  @override
  String get nextTrainTitle => 'つぎの電車';

  @override
  String get favHint => '経路をえらんで ☆ をおすと、ここに登録されます';

  @override
  String get favChooseTitle => 'どんなルート？';

  @override
  String get favOther => 'お気に入り';

  @override
  String favRemoveConfirm(String route) {
    return '「$route」をお気に入りから外しますか？';
  }

  @override
  String get remove => '外す';

  @override
  String get cancel => 'キャンセル';

  @override
  String get favAdded => 'お気に入りに登録しました';

  @override
  String liveFar(String dest, int n) {
    return '$destまで あと$n駅';
  }

  @override
  String liveNear(int n, String dest) {
    return 'あと$n駅で $dest';
  }

  @override
  String liveNext(String station) {
    return 'つぎは $station';
  }

  @override
  String liveArrived(String dest) {
    return '$destに到着';
  }

  @override
  String liveFlow(String now, String next) {
    return 'いま $now → つぎ $next';
  }

  @override
  String liveSub(String line, String eta) {
    return '$line · $eta着';
  }

  @override
  String liveShort(int n) {
    return 'あと$n駅';
  }

  @override
  String get liveEnd => '終了';

  @override
  String alertApproachTitle(String dest) {
    return 'まもなく $dest';
  }

  @override
  String get alertApproachBody => 'つぎで降ります。準備してね';

  @override
  String alertArrivedTitle(String dest) {
    return '$destに到着しました';
  }

  @override
  String get alertArrivedBody => 'おつかれさま！';

  @override
  String get channelTrip => '移動中の表示';

  @override
  String get channelApproach => '降りる駅のお知らせ';

  @override
  String get channelArrive => '到着のお知らせ';

  @override
  String get mapFitAll => '全体';

  @override
  String get mapZoomIn => '拡大';

  @override
  String get mapZoomOut => '縮小';

  @override
  String get mapSearch => '駅をさがす';

  @override
  String get mapTransfers => 'のりかえ';

  @override
  String get mapTips => '駅のヒント';

  @override
  String get mapTipsNote => '※ 情報は目安です。現地の案内も確認してね';

  @override
  String get mapNoTips => 'この駅のヒントは じゅんび中です';

  @override
  String get mapSetFrom => '出発にする';

  @override
  String get mapSetTo => '到着にする';

  @override
  String get mapCourses => 'おでかけコース';

  @override
  String get courseHint => '駅に行くとスタンプ。ぜんぶ集めると制覇！';

  @override
  String get courseDone => '制覇！';

  @override
  String get courseGo => '次の駅へ';

  @override
  String courseProgress(int done, int total) {
    return 'スタンプ $done/$total';
  }

  @override
  String courseHours(int hours) {
    return '約$hours時間';
  }

  @override
  String get courseDay => '1日';

  @override
  String get exitGuide => '出口ガイド';

  @override
  String get mapStampMode => 'スタンプ地図';

  @override
  String mapStampSummary(int visited, int total, int lines, int gold) {
    return '$visited/$total駅・制覇$lines路線・★$gold';
  }

  @override
  String get mapNamesSwap => '駅名の言語';

  @override
  String get boardSource => '運行情報：公共交通オープンデータセンター';

  @override
  String get boardAllNormal => '現在、平常どおり運転しています';

  @override
  String get boardDelay => '遅延';

  @override
  String get boardTitle => '発車標';

  @override
  String get boardSoon => 'まもなく';

  @override
  String get boardNote => '時刻は時刻表からの目安です。駅の案内も確認してね';

  @override
  String get boardPickStation => '出発駅をえらぶと、次の電車が表示されます';

  @override
  String get boardEnded => '本日の運転は終了しました';

  @override
  String boardBound(String station) {
    return '$station 行';
  }

  @override
  String get routeFoldedPick => '出発と到着をえらぶ';

  @override
  String get mapNightView => '夜の地図';

  @override
  String get mapDayView => '昼の地図';

  @override
  String get mapMyRoute => 'マイルート';

  @override
  String get mapRouteShow => 'ルートを見る';

  @override
  String get mapRouteHide => 'ルートを隠す';

  @override
  String get mapTrainsNote => '列車は時刻表からの推定位置です';

  @override
  String get mapLmStations => '最寄り駅';

  @override
  String get mapFrom => '出発';

  @override
  String get mapTo => '到着';

  @override
  String transferWalk(int minutes) {
    return '乗換 徒歩$minutes分';
  }

  @override
  String get myTitle => 'MY駅';

  @override
  String get myTabScene => '駅';

  @override
  String get myTabTrain => '電車';

  @override
  String get myTabRoof => '屋根';

  @override
  String get myTabPlatform => 'ホーム';

  @override
  String get myTabEffect => '演出';

  @override
  String get myTabSky => '空';

  @override
  String get myTabMark => 'ヘッドマーク';

  @override
  String get myEquipped => '設置中';

  @override
  String get myOwned => 'もってる';

  @override
  String get myFree => '無料';

  @override
  String myBuyCoins(int price) {
    return '$priceコインで買う';
  }

  @override
  String myBuyYen(int price) {
    return '¥$priceで買う';
  }

  @override
  String myNotEnough(int missing) {
    return 'コインが あと$missingたりません';
  }

  @override
  String get myCoinShop => 'コインを買う';

  @override
  String get myIapNotReady => 'お支払いは じゅんび中です（リリース前に対応）';

  @override
  String get myTestCoins => 'テスト用：無料で追加';

  @override
  String myGot(String name) {
    return '$name を手に入れた！';
  }

  @override
  String myEarnRules(int trip, int visit, int day) {
    return '移動するたびに +$trip・はじめての駅 +$visit・その日はじめて +$day';
  }

  @override
  String myCoinsEarned(int coins) {
    return '+$coins コイン';
  }

  @override
  String get myUse => 'つかう';

  @override
  String get myTabPlate => '行先LED';

  @override
  String get myLocked => '限定';

  @override
  String myUnlockHint(String line) {
    return '$lineの駅をぜんぶ集めると もらえます';
  }

  @override
  String get plateTitle => '行先LEDに駅名を';

  @override
  String get plateEdit => '駅名';

  @override
  String get plateName => '駅の名前（6文字まで）';

  @override
  String get plateKana => 'よみがな（8文字まで）';

  @override
  String get plateKanaHint => 'れい：さくら';

  @override
  String get plateSave => '保存する';

  @override
  String get stampTitle => '駅スタンプ帳';

  @override
  String stayStamped(String station, int coins) {
    return '$stationに5分いたので ゴールドスタンプ！ +$coins';
  }

  @override
  String get stampOpen => 'スタンプ帳';

  @override
  String stampTotal(int done, int total) {
    return '$done / $total 駅 あつめた';
  }

  @override
  String get stampHint => 'はじめて行った駅にスタンプ。駅で5分すごすと ゴールドスタンプ★ 路線をぜんぶ集めると 限定アイテム！';

  @override
  String stampReward(String item) {
    return 'ぜんぶ集めると「$item」';
  }

  @override
  String stampRewardGot(String item) {
    return '制覇！「$item」ゲット';
  }

  @override
  String get shareOpen => 'シェア';

  @override
  String get shareTitle => 'シェアカード';

  @override
  String get shareHeading => 'わたしの駅';

  @override
  String shareStation(String name) {
    return 'ようこそ「$name」へ';
  }

  @override
  String get shareStamps => 'スタンプ';

  @override
  String get shareStampUnit => '駅';

  @override
  String get shareLines => '制覇した路線';

  @override
  String get shareLineUnit => '路線';

  @override
  String get shareButton => 'シェアする';

  @override
  String get shareText => 'わたしの駅をつくったよ #つぎはMetro';

  @override
  String get shareFailed => 'シェアできませんでした';

  @override
  String arrivedStamps(int count) {
    return 'スタンプ +$count';
  }

  @override
  String arrivedLineDone(String line, String item) {
    return '$line 制覇！「$item」ゲット';
  }

  @override
  String get widgetAdd => 'ウィジェット';

  @override
  String get widgetManual => 'ホーム画面を長押し →「ウィジェット」→「つぎは Metro」から追加できます';

  @override
  String get plateHint => '電車の行先表示に、名前とよみがなが 交互に出ます';

  @override
  String get mapWalkTransfers => '徒歩でのりかえ';

  @override
  String walkMinutes(int minutes) {
    return '徒歩$minutes分';
  }

  @override
  String transferWalkTo(String station, String line) {
    return '$stationまで歩いて $lineにのりかえ';
  }

  @override
  String sceneGet(String name) {
    return '$nameの景色をGET';
  }

  @override
  String lastTrainWarn(int minutes) {
    return '終電まであと$minutes分';
  }

  @override
  String serviceEnded(String time) {
    return '本日の運行は終了（始発 $time）';
  }

  @override
  String get crowdTitle => '混雑予想';

  @override
  String get crowdRelaxed => 'すいてる';

  @override
  String get crowdNormal => 'ふつう';

  @override
  String get crowdCrowded => '混雑';

  @override
  String get crowdPacked => '大混雑';

  @override
  String get umbrellaReminder => '傘を忘れずに';

  @override
  String get lastTrainAlarm => '終電アラーム';

  @override
  String lastTrainAlarmBody(String from, String to, String time) {
    return '$from → $to の終電は $timeごろ発。そろそろ帰る準備を！';
  }

  @override
  String lastTrainAlarmSet(String alarm, String time) {
    return '毎晩 $alarm にお知らせします（終電 $timeごろ）';
  }

  @override
  String get lastTrainAlarmOff => '終電アラームをオフにしました';

  @override
  String firstTrainIn(int hours, int minutes, String time) {
    return '始発まで $hours時間$minutes分（$time発）';
  }

  @override
  String get firstTrainAlarm => '始発アラーム';

  @override
  String firstTrainAlarmTitle(int minutes) {
    return '始発まであと$minutes分';
  }

  @override
  String firstTrainAlarmBody(String from, String to, String time) {
    return '$from → $to の始発は $timeごろ発です';
  }

  @override
  String firstTrainAlarmSet(String alarm, String time) {
    return '$alarm にお知らせします（始発 $timeごろ）';
  }

  @override
  String get firstTrainAlarmOff => '始発アラームをオフにしました';

  @override
  String taxiFare(String yen) {
    return 'タクシー 約$yen円';
  }

  @override
  String taxiFareNight(String yen) {
    return 'タクシー 約$yen円（深夜）';
  }

  @override
  String walkTime(int minutes) {
    return '徒歩 $minutes分';
  }

  @override
  String get nightWays => '電車以外の目安';

  @override
  String get serviceEndedShort => '本日の運行は終了';

  @override
  String get myTabMelody => 'メロディ';

  @override
  String get widgetLast => '終電';

  @override
  String get widgetFirst => '始発';

  @override
  String get widgetChoose => 'ウィジェットをえらぶ';

  @override
  String get widgetKindMy => 'MY駅';

  @override
  String get widgetKindMyDesc => '写真と きょうの情報';

  @override
  String get widgetKindBoard => '地下鉄案内';

  @override
  String get widgetKindBoardDesc => '電光掲示板ふう シンプル';

  @override
  String widgetEvery(int minutes) {
    return '約$minutes分おき';
  }

  @override
  String widgetTrip(String dest, int minutes) {
    return '$destまで 約$minutes分';
  }

  @override
  String widgetEnded(String time) {
    return '運行終了 · 始発 $time';
  }

  @override
  String get widgetKindNext => 'つぎの電車';

  @override
  String get widgetKindNextDesc => '小さく 電車の間隔と所要時間';

  @override
  String get routeMissed => 'このルートは終電に間に合いません';

  @override
  String get altRouteTitle => '別ルートならまだ間に合う';

  @override
  String altRouteInfo(String time, String via) {
    return '$timeまでに出発 · $via';
  }

  @override
  String get altRouteUse => 'このルートにする';

  @override
  String throughHere(String line) {
    return 'そのまま$lineへ直通';
  }

  @override
  String get shareStyleTicket => 'きっぷ';

  @override
  String get shareStylePoster => 'ポスター';

  @override
  String get shareStyleReport => '今月のレポート';

  @override
  String get shareTicketHead => '乗車記念';

  @override
  String shareTicketValid(String date) {
    return '$date 当日限り有効';
  }

  @override
  String shareTicketNo(String n) {
    return 'No.$n';
  }

  @override
  String shareLevel(int n) {
    return 'Lv.$n';
  }

  @override
  String get shareMyTrain => 'MY列車';

  @override
  String get shareLineProgress => '路線の制覇';

  @override
  String get shareInvite => '招待コード';

  @override
  String shareInviteHint(int coins) {
    return 'アプリで入力すると $coinsコイン';
  }

  @override
  String shareReportTitle(String month) {
    return '$month月の乗車レポート';
  }

  @override
  String get shareReportTrips => '乗車';

  @override
  String get shareReportTripUnit => '回';

  @override
  String get shareReportKm => '移動';

  @override
  String get shareReportStations => '通った駅';

  @override
  String get shareReportTopLine => 'いちばん乗った路線';

  @override
  String get shareReportEarliest => 'いちばん早い乗車';

  @override
  String get shareReportLatest => 'いちばん遅い乗車';

  @override
  String get shareReportNone => '今月はまだ乗っていません';

  @override
  String get shareStickers => 'ステッカー';

  @override
  String get shareStickersHint => 'タップで貼る・ドラッグで動かす・ダブルタップで外す';

  @override
  String get shareAnimated => '動くカード（GIF）';

  @override
  String get shareMaking => '作成中…';

  @override
  String get myInviteEnter => '友だちの招待コード';

  @override
  String get myInviteField => '6文字のコード';

  @override
  String get myInviteUse => 'もらう';

  @override
  String myInviteOk(int coins) {
    return '$coinsコインもらいました';
  }

  @override
  String get myInviteOwn => '自分のコードは使えません';

  @override
  String get myInviteUsed => '招待コードはもう使いました';

  @override
  String get myInviteInvalid => 'コードが正しくありません';
}
