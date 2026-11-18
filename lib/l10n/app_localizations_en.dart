// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Tsugiwa Metro';

  @override
  String get nearestButton => 'From my location';

  @override
  String get locating => 'Finding your location…';

  @override
  String get nearestNone => 'No supported station nearby';

  @override
  String get locationOff => 'Location is off. Please allow it in Settings';

  @override
  String nearestFound(String station, int meters) {
    return 'Nearest station: $station (about $meters m)';
  }

  @override
  String get weatherSunny => 'Sunny';

  @override
  String get weatherCloudy => 'Cloudy';

  @override
  String get weatherRain => 'Rain';

  @override
  String get weatherSnow => 'Snow';

  @override
  String get weatherUnknown => '―';

  @override
  String get humidityLabel => 'Humidity';

  @override
  String get rainChanceLabel => 'Rain';

  @override
  String get weatherCredit => 'Source: Japan Meteorological Agency (processed)';

  @override
  String get weatherError => 'Couldn\'t load the weather';

  @override
  String get platformInfo => 'Platform info';

  @override
  String nextTrainIn(int minutes) {
    return 'Next train in $minutes min';
  }

  @override
  String trainsEvery(int minutes) {
    return 'A train about every $minutes min';
  }

  @override
  String lastTrainAbout(String time) {
    return 'Last train around $time';
  }

  @override
  String outOfService(String time) {
    return 'No trains now (first train around $time)';
  }

  @override
  String get estimateBadge => 'Estimate';

  @override
  String get liveBadge => 'Live';

  @override
  String get tabPlatform => 'Platform';

  @override
  String get tabMap => 'Map';

  @override
  String get tabMy => 'MY';

  @override
  String get comingSoon => 'Coming soon…';

  @override
  String get comingSoonMap => 'The route map arrives in the next step';

  @override
  String get comingSoonMy => 'Your MY room opens a little later';

  @override
  String get from => 'From';

  @override
  String get to => 'To';

  @override
  String get selectStation => 'Choose a station';

  @override
  String get searchHint => 'Search stations (any language)';

  @override
  String get swap => 'Swap';

  @override
  String get startTrip => 'Start tracking';

  @override
  String get endTrip => 'End trip';

  @override
  String routeSummary(int minutes, int stops, int transfers) {
    String _temp0 = intl.Intl.pluralLogic(
      stops,
      locale: localeName,
      other: '$stops stops',
      one: '1 stop',
    );
    String _temp1 = intl.Intl.pluralLogic(
      transfers,
      locale: localeName,
      other: '$transfers transfers',
      one: '1 transfer',
      zero: 'direct',
    );
    return 'About $minutes min · $_temp0 · $_temp1';
  }

  @override
  String stopCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stops',
      one: '1 stop',
    );
    return '$_temp0';
  }

  @override
  String get nowLabel => 'Now';

  @override
  String get nextLabel => 'Next';

  @override
  String get remainingLabel => 'Stops left';

  @override
  String get etaLabel => 'Arrival';

  @override
  String betweenStations(String from, String to) {
    return '$from → $to';
  }

  @override
  String get gpsCorrected => 'Corrected by GPS';

  @override
  String get gpsUnderground => 'Underground · timetable estimate';

  @override
  String get gpsWaiting => 'Timetable estimate';

  @override
  String get gpsOff => 'Location off · timetable estimate';

  @override
  String approachingTitle(String station) {
    return 'Next: $station';
  }

  @override
  String get approachingBody => 'Arriving soon. Get ready to get off';

  @override
  String get arrivedTitle => 'You\'ve arrived!';

  @override
  String arrivedBody(String station) {
    return 'Welcome to $station. Nice ride!';
  }

  @override
  String get backHome => 'Home';

  @override
  String transferHere(String line) {
    return 'Change to the $line here';
  }

  @override
  String get sameStation => 'Start and destination are the same';

  @override
  String get noRoute => 'No route found';

  @override
  String get testSpeed => 'Test speed';

  @override
  String get loading => 'Loading…';

  @override
  String get estimateNote => 'Times are estimated from the timetable';

  @override
  String get destinationLabel => 'Destination';

  @override
  String get quickRoutes => 'Your routes';

  @override
  String get recentRoutes => 'Recent';

  @override
  String get favHome => 'Home';

  @override
  String get favWork => 'Work';

  @override
  String get nextTrainTitle => 'Next train';

  @override
  String get favHint => 'Pick a route and tap ☆ to save it here';

  @override
  String get favChooseTitle => 'What is this route?';

  @override
  String get favOther => 'Favourite';

  @override
  String favRemoveConfirm(String route) {
    return 'Remove “$route” from favourites?';
  }

  @override
  String get remove => 'Remove';

  @override
  String get cancel => 'Cancel';

  @override
  String get favAdded => 'Saved to favourites';

  @override
  String liveFar(String dest, int n) {
    return '$n stops to $dest';
  }

  @override
  String liveNear(int n, String dest) {
    return '$dest in $n stops';
  }

  @override
  String liveNext(String station) {
    return 'Next: $station';
  }

  @override
  String liveArrived(String dest) {
    return 'Arrived at $dest';
  }

  @override
  String liveFlow(String now, String next) {
    return 'Now $now → next $next';
  }

  @override
  String liveSub(String line, String eta) {
    return '$line · arrive $eta';
  }

  @override
  String liveShort(int n) {
    return '$n stops';
  }

  @override
  String get liveEnd => 'End';

  @override
  String alertApproachTitle(String dest) {
    return '$dest is next';
  }

  @override
  String get alertApproachBody => 'Get off at the next stop';

  @override
  String alertArrivedTitle(String dest) {
    return 'You\'ve arrived at $dest';
  }

  @override
  String get alertArrivedBody => 'Nice ride!';

  @override
  String get channelTrip => 'Trip in progress';

  @override
  String get channelApproach => 'Your stop is next';

  @override
  String get channelArrive => 'Arrived';

  @override
  String get mapFitAll => 'Whole map';

  @override
  String get mapZoomIn => 'Zoom in';

  @override
  String get mapZoomOut => 'Zoom out';

  @override
  String get mapSearch => 'Find a station';

  @override
  String get mapTransfers => 'Transfers';

  @override
  String get mapTips => 'Station tips';

  @override
  String get mapTipsNote =>
      '* For guidance only — check the signs at the station';

  @override
  String get mapNoTips => 'Tips for this station are coming soon';

  @override
  String get mapSetFrom => 'Set as start';

  @override
  String get mapSetTo => 'Set as destination';

  @override
  String transferWalk(int minutes) {
    return '$minutes min walk to change';
  }

  @override
  String get myTitle => 'MY Station';

  @override
  String get myTabScene => 'Station';

  @override
  String get myTabTrain => 'Train';

  @override
  String get myTabRoof => 'Roof';

  @override
  String get myTabPlatform => 'Platform';

  @override
  String get myTabEffect => 'Effects';

  @override
  String get myEquipped => 'In use';

  @override
  String get myOwned => 'Owned';

  @override
  String get myFree => 'Free';

  @override
  String myBuyCoins(int price) {
    return 'Buy for $price coins';
  }

  @override
  String myBuyYen(int price) {
    return 'Buy for ¥$price';
  }

  @override
  String myNotEnough(int missing) {
    return '$missing more coins needed';
  }

  @override
  String get myCoinShop => 'Get coins';

  @override
  String get myIapNotReady => 'Payments are coming soon (before release)';

  @override
  String get myTestCoins => 'Test: add for free';

  @override
  String myGot(String name) {
    return 'You got $name!';
  }

  @override
  String myEarnRules(int trip, int visit, int day) {
    return 'Every trip +$trip · new station +$visit · first trip of the day +$day';
  }

  @override
  String myCoinsEarned(int coins) {
    return '+$coins coins';
  }

  @override
  String get myUse => 'Use';

  @override
  String get myTabPlate => 'LED';

  @override
  String get myLocked => 'Limited';

  @override
  String myUnlockHint(String line) {
    return 'Collect every station on the $line to get this';
  }

  @override
  String get plateTitle => 'Name on the LED';

  @override
  String get plateEdit => 'Name';

  @override
  String get plateName => 'Station name (up to 6)';

  @override
  String get plateKana => 'Reading (up to 8)';

  @override
  String get plateKanaHint => 'e.g. sakura';

  @override
  String get plateSave => 'Save';

  @override
  String get stampTitle => 'Station stamps';

  @override
  String get stampOpen => 'Stamps';

  @override
  String stampTotal(int done, int total) {
    return '$done of $total stations';
  }

  @override
  String get stampHint =>
      'A stamp for every new station. Finish a line for a limited item!';

  @override
  String stampReward(String item) {
    return 'Finish for \"$item\"';
  }

  @override
  String stampRewardGot(String item) {
    return 'Done! Got \"$item\"';
  }

  @override
  String get shareOpen => 'Share';

  @override
  String get shareTitle => 'Share card';

  @override
  String get shareHeading => 'My station';

  @override
  String shareStation(String name) {
    return 'Welcome to $name';
  }

  @override
  String get shareStamps => 'Stamps';

  @override
  String get shareStampUnit => 'stations';

  @override
  String get shareLines => 'Lines done';

  @override
  String get shareLineUnit => 'lines';

  @override
  String get shareButton => 'Share';

  @override
  String get shareText => 'I built my own station #つぎはMetro';

  @override
  String get shareFailed => 'Couldn\'t share';

  @override
  String arrivedStamps(int count) {
    return '+$count stamps';
  }

  @override
  String arrivedLineDone(String line, String item) {
    return '$line done! Got \"$item\"';
  }

  @override
  String get widgetAdd => 'Widget';

  @override
  String get widgetManual =>
      'Long-press the home screen → Widgets → Tsugiwa Metro';

  @override
  String get plateHint => 'The train shows the name and reading in turn';

  @override
  String get mapWalkTransfers => 'Transfer on foot';

  @override
  String walkMinutes(int minutes) {
    return '$minutes min walk';
  }

  @override
  String transferWalkTo(String station, String line) {
    return 'Walk to $station, change to the $line';
  }

  @override
  String sceneGet(String name) {
    return 'Get the $name scene';
  }

  @override
  String lastTrainWarn(int minutes) {
    return 'Last train in $minutes min';
  }

  @override
  String serviceEnded(String time) {
    return 'Service ended today (first train $time)';
  }

  @override
  String get crowdTitle => 'Crowding';

  @override
  String get crowdRelaxed => 'Quiet';

  @override
  String get crowdNormal => 'Normal';

  @override
  String get crowdCrowded => 'Busy';

  @override
  String get crowdPacked => 'Packed';

  @override
  String get umbrellaReminder => 'Take an umbrella';

  @override
  String get lastTrainAlarm => 'Last-train alert';

  @override
  String lastTrainAlarmBody(String from, String to, String time) {
    return 'The last train $from → $to leaves around $time. Time to head home!';
  }

  @override
  String lastTrainAlarmSet(String alarm, String time) {
    return 'We\'ll remind you every night at $alarm (last train ~$time)';
  }

  @override
  String get lastTrainAlarmOff => 'Last-train alert turned off';

  @override
  String firstTrainIn(int hours, int minutes, String time) {
    return 'First train in ${hours}h ${minutes}m ($time)';
  }

  @override
  String get firstTrainAlarm => 'First-train alert';

  @override
  String firstTrainAlarmTitle(int minutes) {
    return 'First train in $minutes min';
  }

  @override
  String firstTrainAlarmBody(String from, String to, String time) {
    return 'The first train $from → $to leaves around $time';
  }

  @override
  String firstTrainAlarmSet(String alarm, String time) {
    return 'We\'ll remind you at $alarm (first train ~$time)';
  }

  @override
  String get firstTrainAlarmOff => 'First-train alert turned off';

  @override
  String taxiFare(String yen) {
    return 'Taxi about ¥$yen';
  }

  @override
  String taxiFareNight(String yen) {
    return 'Taxi about ¥$yen (late night)';
  }

  @override
  String walkTime(int minutes) {
    return '$minutes min walk';
  }

  @override
  String get nightWays => 'Without trains (estimate)';

  @override
  String get serviceEndedShort => 'Service ended for today';
}
