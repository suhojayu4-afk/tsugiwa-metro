// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '츠기와 Metro';

  @override
  String get nearestButton => '현재 위치에서';

  @override
  String get locating => '현재 위치를 찾는 중…';

  @override
  String get nearestNone => '근처에 지원하는 역이 없어요';

  @override
  String get locationOff => '위치 정보가 꺼져 있어요. 설정에서 허용해 주세요';

  @override
  String nearestFound(String station, int meters) {
    return '가장 가까운 역: $station (약 ${meters}m)';
  }

  @override
  String get weatherSunny => '맑음';

  @override
  String get weatherCloudy => '흐림';

  @override
  String get weatherRain => '비';

  @override
  String get weatherSnow => '눈';

  @override
  String get weatherUnknown => '―';

  @override
  String get humidityLabel => '습도';

  @override
  String get rainChanceLabel => '강수확률';

  @override
  String get weatherCredit => '출처: 일본 기상청 (데이터를 가공해 작성)';

  @override
  String get weatherError => '날씨를 불러오지 못했어요';

  @override
  String get platformInfo => '승강장 정보';

  @override
  String nextTrainIn(int minutes) {
    return '다음 전철 $minutes분 뒤';
  }

  @override
  String trainsEvery(int minutes) {
    return '약 $minutes분 간격으로 와요';
  }

  @override
  String lastTrainAbout(String time) {
    return '막차 기준 $time';
  }

  @override
  String outOfService(String time) {
    return '운행 시간이 아니에요 (첫차 기준 $time)';
  }

  @override
  String get estimateBadge => '예상';

  @override
  String get liveBadge => '실시간';

  @override
  String get tabPlatform => '승강장';

  @override
  String get tabMap => '노선도';

  @override
  String get tabMy => 'MY';

  @override
  String get comingSoon => '준비 중…';

  @override
  String get comingSoonMap => '노선도는 다음 단계에서 만들어져요';

  @override
  String get comingSoonMy => 'MY룸은 조금 뒤에 열려요';

  @override
  String get from => '출발';

  @override
  String get to => '도착';

  @override
  String get selectStation => '역 선택';

  @override
  String get searchHint => '역 이름 검색 (한글·일본어·영어)';

  @override
  String get swap => '바꾸기';

  @override
  String get startTrip => '추적 시작';

  @override
  String get endTrip => '종료';

  @override
  String routeSummary(int minutes, int stops, int transfers) {
    String _temp0 = intl.Intl.pluralLogic(
      transfers,
      locale: localeName,
      other: '환승 $transfers회',
      zero: '환승 없음',
    );
    return '약 $minutes분 · $stops정거장 · $_temp0';
  }

  @override
  String stopCount(int count) {
    return '$count정거장';
  }

  @override
  String get nowLabel => '지금';

  @override
  String get nextLabel => '다음 역';

  @override
  String get remainingLabel => '남은 정거장';

  @override
  String get etaLabel => '도착 예정';

  @override
  String betweenStations(String from, String to) {
    return '$from → $to';
  }

  @override
  String get gpsCorrected => 'GPS로 보정 중';

  @override
  String get gpsUnderground => '지하 구간 · 시간표로 추정';

  @override
  String get gpsWaiting => '시간표로 추정 중';

  @override
  String get gpsOff => '위치 꺼짐 · 시간표로 추정';

  @override
  String approachingTitle(String station) {
    return '다음은 $station';
  }

  @override
  String get approachingBody => '곧 도착해요. 내릴 준비를 하세요';

  @override
  String get arrivedTitle => '도착했어요!';

  @override
  String arrivedBody(String station) {
    return '$station에 도착했어요. 수고했어요!';
  }

  @override
  String get backHome => '홈으로';

  @override
  String transferHere(String line) {
    return '여기서 $line으로 환승';
  }

  @override
  String get sameStation => '출발역과 도착역이 같아요';

  @override
  String get noRoute => '경로를 찾을 수 없어요';

  @override
  String get testSpeed => '테스트 속도';

  @override
  String get loading => '불러오는 중…';

  @override
  String get estimateNote => '시각은 시간표 기준 추정치예요';

  @override
  String get destinationLabel => '목적지';

  @override
  String get quickRoutes => '자주 가는 경로';

  @override
  String get recentRoutes => '최근';

  @override
  String get favHome => '집으로';

  @override
  String get favWork => '회사로';

  @override
  String get nextTrainTitle => '다음 열차';

  @override
  String get favHint => '경로를 고르고 ☆ 를 누르면 여기에 등록돼요';

  @override
  String get favChooseTitle => '어떤 경로인가요?';

  @override
  String get favOther => '즐겨찾기';

  @override
  String favRemoveConfirm(String route) {
    return '「$route」를 즐겨찾기에서 뺄까요?';
  }

  @override
  String get remove => '빼기';

  @override
  String get cancel => '취소';

  @override
  String get favAdded => '즐겨찾기에 등록했어요';

  @override
  String liveFar(String dest, int n) {
    return '$dest까지 $n역 남음';
  }

  @override
  String liveNear(int n, String dest) {
    return '$n역 뒤 $dest';
  }

  @override
  String liveNext(String station) {
    return '다음은 $station';
  }

  @override
  String liveArrived(String dest) {
    return '$dest 도착';
  }

  @override
  String liveFlow(String now, String next) {
    return '지금 $now → 다음 $next';
  }

  @override
  String liveSub(String line, String eta) {
    return '$line · $eta 도착';
  }

  @override
  String liveShort(int n) {
    return '$n역 남음';
  }

  @override
  String get liveEnd => '종료';

  @override
  String alertApproachTitle(String dest) {
    return '곧 $dest';
  }

  @override
  String get alertApproachBody => '다음 역에서 내려요. 준비하세요';

  @override
  String alertArrivedTitle(String dest) {
    return '$dest에 도착했어요';
  }

  @override
  String get alertArrivedBody => '수고하셨어요!';

  @override
  String get channelTrip => '이동 중 표시';

  @override
  String get channelApproach => '내릴 역 알림';

  @override
  String get channelArrive => '도착 알림';

  @override
  String get mapFitAll => '전체';

  @override
  String get mapZoomIn => '확대';

  @override
  String get mapZoomOut => '축소';

  @override
  String get mapSearch => '역 찾기';

  @override
  String get mapTransfers => '환승';

  @override
  String get mapTips => '역 안내 팁';

  @override
  String get mapTipsNote => '※ 참고용 정보예요. 현장 안내도 확인하세요';

  @override
  String get mapNoTips => '이 역의 팁은 준비 중이에요';

  @override
  String get mapSetFrom => '출발역으로';

  @override
  String get mapSetTo => '도착역으로';

  @override
  String get mapCourses => '나들이 코스';

  @override
  String get courseHint => '역에 가면 스탬프. 다 모으면 완주!';

  @override
  String get courseDone => '완주!';

  @override
  String get courseGo => '다음 역으로';

  @override
  String courseProgress(int done, int total) {
    return '스탬프 $done/$total';
  }

  @override
  String courseHours(int hours) {
    return '약 $hours시간';
  }

  @override
  String get courseDay => '하루';

  @override
  String get exitGuide => '출구 안내';

  @override
  String get mapStampMode => '스탬프 지도';

  @override
  String mapStampSummary(int visited, int total, int lines, int gold) {
    return '$visited/$total역 · 완주 $lines · ★$gold';
  }

  @override
  String get mapNamesSwap => '역 이름 언어 바꾸기';

  @override
  String get boardSource => '운행 정보: 공공교통 오픈데이터센터';

  @override
  String get boardAllNormal => '지금은 평소대로 운행 중이에요';

  @override
  String get boardDelay => '지연';

  @override
  String get boardTitle => '발차 안내';

  @override
  String get boardSoon => '곧 출발';

  @override
  String get boardNote => '시간표로 추정한 시각이에요. 역 안내도 확인하세요';

  @override
  String get boardPickStation => '출발역을 고르면 다음 열차가 표시돼요';

  @override
  String get boardEnded => '오늘 운행이 끝났어요';

  @override
  String boardBound(String station) {
    return '$station행';
  }

  @override
  String get routeFoldedPick => '출발·도착 고르기';

  @override
  String get mapNightView => '밤 지도';

  @override
  String get mapDayView => '낮 지도';

  @override
  String get mapMyRoute => '내 경로';

  @override
  String get mapRouteShow => '경로 보기';

  @override
  String get mapRouteHide => '경로 숨기기';

  @override
  String get mapTrainsNote => '열차는 시간표로 추정한 위치예요';

  @override
  String get mapLmStations => '가까운 역';

  @override
  String get mapFrom => '출발';

  @override
  String get mapTo => '도착';

  @override
  String transferWalk(int minutes) {
    return '환승 도보 $minutes분';
  }

  @override
  String get myTitle => 'MY 역';

  @override
  String get myTabScene => '역';

  @override
  String get myTabTrain => '전철';

  @override
  String get myTabRoof => '지붕';

  @override
  String get myTabPlatform => '승강장';

  @override
  String get myTabEffect => '연출';

  @override
  String get myTabSky => '하늘';

  @override
  String get myTabMark => '헤드마크';

  @override
  String get myEquipped => '설치 중';

  @override
  String get myOwned => '보유';

  @override
  String get myFree => '무료';

  @override
  String myBuyCoins(int price) {
    return '$price코인으로 사기';
  }

  @override
  String myBuyYen(int price) {
    return '¥$price로 사기';
  }

  @override
  String myNotEnough(int missing) {
    return '코인이 $missing 부족해요';
  }

  @override
  String get myCoinShop => '코인 사기';

  @override
  String get myIapNotReady => '결제는 준비 중이에요 (출시 전에 지원)';

  @override
  String get myTestCoins => '테스트용: 무료로 추가';

  @override
  String myGot(String name) {
    return '$name을(를) 얻었어요!';
  }

  @override
  String myEarnRules(int trip, int visit, int day) {
    return '이동할 때마다 +$trip · 처음 가는 역 +$visit · 그날 첫 이동 +$day';
  }

  @override
  String myCoinsEarned(int coins) {
    return '+$coins 코인';
  }

  @override
  String get myUse => '사용하기';

  @override
  String get myTabPlate => '행선 LED';

  @override
  String get myLocked => '한정';

  @override
  String myUnlockHint(String line) {
    return '$line의 역을 모두 모으면 받을 수 있어요';
  }

  @override
  String get plateTitle => '행선 LED에 역 이름 넣기';

  @override
  String get plateEdit => '역 이름';

  @override
  String get plateName => '역 이름 (6글자까지)';

  @override
  String get plateKana => '읽는 법 (8글자까지)';

  @override
  String get plateKanaHint => '예: 사쿠라';

  @override
  String get plateSave => '저장하기';

  @override
  String get stampTitle => '역 스탬프북';

  @override
  String stayStamped(String station, int coins) {
    return '$station에 5분 머물러서 골드 스탬프! +$coins';
  }

  @override
  String get stampOpen => '스탬프북';

  @override
  String stampTotal(int done, int total) {
    return '$done / $total역 모았어요';
  }

  @override
  String get stampHint => '처음 간 역마다 도장. 역에서 5분 머물면 골드 도장★ 노선을 다 모으면 한정 아이템!';

  @override
  String stampReward(String item) {
    return '다 모으면 「$item」';
  }

  @override
  String stampRewardGot(String item) {
    return '정복! 「$item」 획득';
  }

  @override
  String get shareOpen => '공유';

  @override
  String get shareTitle => '공유 카드';

  @override
  String get shareHeading => '나의 역';

  @override
  String shareStation(String name) {
    return '「$name」에 어서 오세요';
  }

  @override
  String get shareStamps => '스탬프';

  @override
  String get shareStampUnit => '역';

  @override
  String get shareLines => '정복한 노선';

  @override
  String get shareLineUnit => '노선';

  @override
  String get shareButton => '공유하기';

  @override
  String get shareText => '내 역을 만들었어요 #つぎはMetro';

  @override
  String get shareFailed => '공유하지 못했어요';

  @override
  String arrivedStamps(int count) {
    return '스탬프 +$count';
  }

  @override
  String arrivedLineDone(String line, String item) {
    return '$line 정복! 「$item」 획득';
  }

  @override
  String get widgetAdd => '위젯';

  @override
  String get widgetManual => '홈 화면을 길게 누르고 →「위젯」→「츠기와 Metro」에서 추가할 수 있어요';

  @override
  String get plateHint => '전철 행선 표시에 이름과 읽는 법이 번갈아 나와요';

  @override
  String get mapWalkTransfers => '걸어서 갈아타기';

  @override
  String walkMinutes(int minutes) {
    return '도보 $minutes분';
  }

  @override
  String transferWalkTo(String station, String line) {
    return '$station까지 걸어서 $line(으)로 환승';
  }

  @override
  String sceneGet(String name) {
    return '$name 풍경 받기';
  }

  @override
  String lastTrainWarn(int minutes) {
    return '막차까지 $minutes분';
  }

  @override
  String serviceEnded(String time) {
    return '오늘 운행 종료 (첫차 $time)';
  }

  @override
  String get crowdTitle => '혼잡 예상';

  @override
  String get crowdRelaxed => '여유';

  @override
  String get crowdNormal => '보통';

  @override
  String get crowdCrowded => '혼잡';

  @override
  String get crowdPacked => '매우 혼잡';

  @override
  String get umbrellaReminder => '우산 챙기세요';

  @override
  String get lastTrainAlarm => '막차 알림';

  @override
  String lastTrainAlarmBody(String from, String to, String time) {
    return '$from → $to 막차는 $time쯤 출발해요. 슬슬 돌아갈 준비하세요!';
  }

  @override
  String lastTrainAlarmSet(String alarm, String time) {
    return '매일 밤 $alarm에 알려드려요 (막차 $time쯤)';
  }

  @override
  String get lastTrainAlarmOff => '막차 알림을 껐어요';

  @override
  String firstTrainIn(int hours, int minutes, String time) {
    return '첫차까지 $hours시간 $minutes분 ($time 출발)';
  }

  @override
  String get firstTrainAlarm => '첫차 알림';

  @override
  String firstTrainAlarmTitle(int minutes) {
    return '첫차까지 $minutes분';
  }

  @override
  String firstTrainAlarmBody(String from, String to, String time) {
    return '$from → $to 첫차는 $time쯤 출발해요';
  }

  @override
  String firstTrainAlarmSet(String alarm, String time) {
    return '$alarm에 알려드려요 (첫차 $time쯤)';
  }

  @override
  String get firstTrainAlarmOff => '첫차 알림을 껐어요';

  @override
  String taxiFare(String yen) {
    return '택시 약 $yen엔';
  }

  @override
  String taxiFareNight(String yen) {
    return '택시 약 $yen엔 (심야)';
  }

  @override
  String walkTime(int minutes) {
    return '도보 $minutes분';
  }

  @override
  String get nightWays => '전철 말고 가는 법 (예상)';

  @override
  String get serviceEndedShort => '오늘 운행 종료';

  @override
  String get myTabMelody => '멜로디';

  @override
  String get widgetLast => '막차';

  @override
  String get widgetFirst => '첫차';

  @override
  String get widgetChoose => '위젯 고르기';

  @override
  String get widgetKindMy => 'MY역';

  @override
  String get widgetKindMyDesc => '사진 + 오늘 정보';

  @override
  String get widgetKindBoard => '지하철 안내';

  @override
  String get widgetKindBoardDesc => '전광판 스타일, 간단하게';

  @override
  String widgetEvery(int minutes) {
    return '약 $minutes분 간격';
  }

  @override
  String widgetTrip(String dest, int minutes) {
    return '$dest까지 약 $minutes분';
  }

  @override
  String widgetEnded(String time) {
    return '운행 종료 · 첫차 $time';
  }

  @override
  String get widgetKindNext => '다음 전철';

  @override
  String get widgetKindNextDesc => '작게, 운행 간격과 소요 시간';

  @override
  String get routeMissed => '이 경로는 막차를 놓쳤어요';

  @override
  String get altRouteTitle => '다른 경로라면 아직 갈 수 있어요';

  @override
  String altRouteInfo(String time, String via) {
    return '$time까지 출발 · $via';
  }

  @override
  String get altRouteUse => '이 경로로';

  @override
  String throughHere(String line) {
    return '그대로 $line 직통';
  }

  @override
  String get shareStyleTicket => '승차권';

  @override
  String get shareStylePoster => '포스터';

  @override
  String get shareStyleReport => '이번 달 리포트';

  @override
  String get shareTicketHead => '승차 기념';

  @override
  String shareTicketValid(String date) {
    return '$date 당일 한정';
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
  String get shareMyTrain => '내 열차';

  @override
  String get shareLineProgress => '노선 제패';

  @override
  String get shareInvite => '초대 코드';

  @override
  String shareInviteHint(int coins) {
    return '앱에서 입력하면 $coins코인';
  }

  @override
  String shareReportTitle(String month) {
    return '$month월 승차 리포트';
  }

  @override
  String get shareReportTrips => '승차';

  @override
  String get shareReportTripUnit => '번';

  @override
  String get shareReportKm => '이동';

  @override
  String get shareReportStations => '지나간 역';

  @override
  String get shareReportTopLine => '가장 많이 탄 노선';

  @override
  String get shareReportEarliest => '가장 이른 승차';

  @override
  String get shareReportLatest => '가장 늦은 승차';

  @override
  String get shareReportNone => '이번 달은 아직 안 탔어요';

  @override
  String get shareStickers => '스티커';

  @override
  String get shareStickersHint => '탭해서 붙이고, 끌어서 옮기고, 두 번 탭하면 떼요';

  @override
  String get shareAnimated => '움직이는 카드 (GIF)';

  @override
  String get shareMaking => '만드는 중…';

  @override
  String get myInviteEnter => '친구 초대 코드';

  @override
  String get myInviteField => '6자리 코드';

  @override
  String get myInviteUse => '받기';

  @override
  String myInviteOk(int coins) {
    return '$coins코인을 받았어요';
  }

  @override
  String get myInviteOwn => '내 코드는 쓸 수 없어요';

  @override
  String get myInviteUsed => '초대 코드는 이미 사용했어요';

  @override
  String get myInviteInvalid => '코드가 올바르지 않아요';
}
