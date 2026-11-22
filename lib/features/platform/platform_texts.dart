import '../../core/localized_text.dart';

/// Texts of the のりば tab that are not in the ARB files (ja / ko / en).
/// `{name}` parts are filled in with [fill].
String fill(LocalizedText text, String lang, [Map<String, Object> values = const {}]) {
  var s = text.of(lang);
  for (final e in values.entries) {
    s = s.replaceAll('{${e.key}}', '${e.value}');
  }
  return s;
}

/// 終電アラーム was set but the phone will not show it.
const alarmNotificationsOff = LocalizedText({
  'ja': '通知がオフです。端末の設定で通知をオンにすると、毎晩 {alarm} にお知らせします（終電 {time}ごろ）',
  'ko': '알림이 꺼져 있어요. 휴대폰 설정에서 알림을 켜면 매일 밤 {alarm}에 알려드려요 (막차 {time}쯤)',
  'en': 'Notifications are off. Turn them on in your phone\'s settings to be reminded every night at {alarm} (last train ~{time})',
});

/// 始発アラーム was set but the phone will not show it.
const firstAlarmNotificationsOff = LocalizedText({
  'ja': '通知がオフです。端末の設定で通知をオンにすると、{alarm} にお知らせします（始発 {time}ごろ）',
  'ko': '알림이 꺼져 있어요. 휴대폰 설정에서 알림을 켜면 {alarm}에 알려드려요 (첫차 {time}쯤)',
  'en': 'Notifications are off. Turn them on in your phone\'s settings to be reminded at {alarm} (first train ~{time})',
});

/// Added to "we'll remind you…" when the phone cannot say whether
/// notifications are allowed.
const alarmNeedsNotifications = LocalizedText({
  'ja': '※通知がオフのときは届きません',
  'ko': '※알림이 꺼져 있으면 오지 않아요',
  'en': 'It will not arrive while notifications are off.',
});

/// A walk to another station at the start, at a change or at the end.
const walkToStation = LocalizedText({'ja': '{station}まで歩く', 'ko': '{station}까지 걷기', 'en': 'Walk to {station}'});

const walkAboutMinutes = LocalizedText({'ja': '約{min}分', 'ko': '약 {min}분', 'en': 'about {min} min'});

/// The station search found nothing.
const searchNoMatch = LocalizedText({'ja': '見つかりませんでした', 'ko': '찾지 못했어요', 'en': 'No stations found'});

const searchNoMatchHint = LocalizedText({
  'ja': 'ひらがなやローマ字でも さがせます（例：しぶや / shibuya）',
  'ko': '한글·히라가나·로마자로 검색해 보세요 (예: 시부야 / shibuya)',
  'en': 'Try hiragana or romaji (e.g. しぶや / shibuya)',
});
