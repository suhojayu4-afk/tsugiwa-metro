import 'package:material_ui/material_ui.dart';

import '../../core/localized_text.dart';

LocalizedText _t(String ja, String ko, String en) => LocalizedText({'ja': ja, 'ko': ko, 'en': en});

/// One chapter of 「日本の電車はじめて」: a title, a line about it and the
/// steps in order.
class FirstRideChapter {
  const FirstRideChapter({
    required this.id,
    required this.icon,
    required this.color,
    required this.title,
    required this.lead,
    this.steps = const [],
    this.phrases = const [],
    this.country = false,
  });
  final String id;
  final IconData icon;
  final Color color;
  final LocalizedText title;
  final LocalizedText lead;
  final List<LocalizedText> steps;

  /// Words to say at the station: Japanese, how it sounds, and what it means.
  final List<({String ja, String roma, LocalizedText means})> phrases;

  /// About country lines (shown early where the city has them).
  final bool country;
}

final firstRideTitle = _t('日本の電車はじめて', '일본 전철 첫걸음', 'First Time on Japanese Trains');
final firstRideIntro = _t(
  'はじめての電車も だいじょうぶ。のる前に ひとつずつ見ていきましょう。',
  '처음 타는 전철도 괜찮아요. 타기 전에 하나씩 같이 볼까요?',
  'Your first train ride will be fine. Let\'s go through it step by step.',
);

final firstRideChapters = <FirstRideChapter>[
  FirstRideChapter(
    id: 'ic',
    icon: Icons.credit_card_rounded,
    color: const Color(0xFF2E9E5B),
    title: _t('ICカードときっぷ', 'IC카드와 승차권', 'IC cards and tickets'),
    lead: _t(
      'いちばん楽なのはICカード。タッチするだけで のれます。',
      '가장 편한 건 IC카드예요. 찍기만 하면 탈 수 있어요.',
      'An IC card is the easiest: just tap and go.',
    ),
    steps: [
      _t(
        'Suica・PASMO・ICOCAなどのICカードは 全国の大きな都市で使えます',
        'Suica·PASMO·ICOCA 같은 IC카드는 전국 큰 도시에서 쓸 수 있어요',
        'Suica, PASMO, ICOCA and other IC cards work in the big cities all over Japan',
      ),
      _t(
        '駅の券売機で買って、お金をチャージします（スマホのICカードも使えます）',
        '역 발매기에서 사서 돈을 충전해요 (스마트폰 IC카드도 돼요)',
        'Buy one at a ticket machine and top it up (phone IC cards work too)',
      ),
      _t(
        'きっぷは 路線図で運賃をたしかめてから 券売機で買います',
        '승차권은 노선도에서 요금을 확인한 뒤 발매기에서 사요',
        'For a paper ticket, check the fare on the fare map, then buy it at the machine',
      ),
      _t(
        'いなかの駅では ICカードが使えないことも。きっぷか現金を用意してね',
        '시골 역에서는 IC카드를 못 쓰기도 해요. 승차권이나 현금을 준비하세요',
        'Some country stations take no IC cards: have a ticket or cash ready',
      ),
    ],
  ),
  FirstRideChapter(
    id: 'gate',
    icon: Icons.sensor_door_rounded,
    color: const Color(0xFF1E73BE),
    title: _t('改札をとおる', '개찰구 지나기', 'Through the ticket gates'),
    lead: _t('「ピッ」と鳴ったら OK です。', '"삑" 소리가 나면 OK예요.', 'A beep means you are through.'),
    steps: [
      _t('ICカードは 光っているところに しっかりタッチ', 'IC카드는 빛나는 부분에 꾹 찍어요', 'Hold the IC card flat on the glowing reader'),
      _t('きっぷは 入れて、出てきたら 忘れずに取ります', '승차권은 넣고, 나오면 잊지 말고 챙겨요', 'Feed your ticket in and take it back as it pops out'),
      _t(
        '赤く光ったり 扉が閉まったら、あわてず 駅員のいる窓口へ',
        '빨갛게 빛나거나 문이 닫히면 당황하지 말고 역무원 창구로',
        'Red light or closed flaps? No panic: go to the staffed window',
      ),
      _t(
        '大きな荷物やベビーカーは はばの広い改札がべんりです',
        '큰 짐이나 유모차는 폭이 넓은 개찰구가 편해요',
        'With big luggage or a stroller, use the wide gate',
      ),
    ],
  ),
  FirstRideChapter(
    id: 'platform',
    icon: Icons.signpost_rounded,
    color: const Color(0xFFE8892B),
    title: _t('のりばをさがす', '승강장 찾기', 'Finding your platform'),
    lead: _t(
      '路線の色・番線・「〇〇方面」を見ます。',
      '노선 색·승강장 번호·"○○ 방면"을 봐요.',
      'Look for the line colour, the platform number and the direction.',
    ),
    steps: [
      _t(
        '案内板で 路線の色と「〇〇方面」をさがします',
        '안내판에서 노선 색과 "○○ 방면"을 찾아요',
        'Follow the line colour and the "for ○○" direction on the signs',
      ),
      _t(
        'ホームの電光掲示板で 行き先と発車時刻をたしかめます',
        '승강장 전광판에서 행선지와 출발 시각을 확인해요',
        'Check the destination and time on the platform display',
      ),
      _t(
        '「各駅停車」は全部の駅に、「快速」「急行」は一部の駅だけに止まります',
        '"각역정차"는 모든 역에, "쾌속"·"급행"은 일부 역에만 서요',
        'Local trains stop everywhere; rapid and express trains skip some stations',
      ),
      _t('「特急」は 乗車券のほかに 特急券がいります', '"특급"은 승차권 외에 특급권이 필요해요', 'Limited expresses need a limited express ticket as well'),
    ],
  ),
  FirstRideChapter(
    id: 'change',
    icon: Icons.alt_route_rounded,
    color: const Color(0xFF8A5CB8),
    title: _t('乗りかえ', '환승', 'Changing trains'),
    lead: _t('色と矢印をたどれば だいじょうぶ。', '색과 화살표만 따라가면 괜찮아요.', 'Follow the colours and arrows and you will be fine.'),
    steps: [
      _t(
        '「のりかえ」の案内と 乗りたい路線の色をたどります',
        '"환승" 안내와 탈 노선 색을 따라가요',
        'Follow the "transfer" signs in the colour of your next line',
      ),
      _t(
        '会社がちがう路線は 一度 改札を出ることがあります',
        '회사가 다른 노선은 한 번 개찰구를 나가기도 해요',
        'Between different companies you may have to exit the gates first',
      ),
      _t(
        '乗りかえは 時間に余裕をもって。このアプリが歩く時間も教えます',
        '환승은 여유 있게. 이 앱이 걷는 시간도 알려 줘요',
        'Give yourself time; this app tells you how long the walk is',
      ),
    ],
  ),
  FirstRideChapter(
    id: 'manners',
    icon: Icons.volunteer_activism_rounded,
    color: const Color(0xFFD23F57),
    title: _t('ホームと車内のマナー', '승강장과 차내 매너', 'Manners on the platform and the train'),
    lead: _t('みんなが気持ちよく乗るための やくそくです。', '모두가 기분 좋게 타기 위한 약속이에요.', 'Small habits that keep everyone comfortable.'),
    steps: [
      _t(
        'ホームでは 足元の印にそって並び、黄色い線の内側で待ちます',
        '승강장에서는 바닥 표시를 따라 줄 서고, 노란 선 안쪽에서 기다려요',
        'Queue at the floor marks and wait behind the yellow line',
      ),
      _t('おりる人が先。のるのは そのあとです', '내리는 사람이 먼저, 타는 건 그다음이에요', 'Let people off first, then get on'),
      _t('車内での通話はひかえて、スマホはマナーモードに', '차내 통화는 삼가고, 휴대폰은 매너 모드로', 'No phone calls on board; switch your phone to silent'),
      _t(
        '混んでいるときは リュックを前に。優先席は 必要な人にゆずります',
        '붐빌 때는 배낭을 앞으로. 우선석은 필요한 분께 양보해요',
        'In crowds, wear your backpack on the front; give priority seats to those who need them',
      ),
      _t(
        '朝の「女性専用車」は 案内のある号車です。表示をたしかめてね',
        '아침의 "여성 전용칸"은 안내가 있는 호차예요. 표시를 확인하세요',
        'Some cars are women-only in the morning rush: check the signs',
      ),
    ],
  ),
  FirstRideChapter(
    id: 'country',
    icon: Icons.agriculture_rounded,
    color: const Color(0xFF12998A),
    country: true,
    title: _t('いなかの電車', '시골 전철', 'Country trains'),
    lead: _t(
      '1両の ワンマン列車も。のり方が少しちがいます。',
      '1량짜리 원맨 열차도 있어요. 타는 법이 조금 달라요.',
      'One-car trains with just a driver work a little differently.',
    ),
    steps: [
      _t(
        '無人駅では うしろのドアから乗り、整理券を1枚とります',
        '무인역에서는 뒷문으로 타서 정리권을 한 장 뽑아요',
        'At unstaffed stations, board at the back and take a numbered ticket',
      ),
      _t(
        'おりるときは 前へ。運賃表で整理券の番号の運賃を見て、運転士さんの横で払います',
        '내릴 때는 앞으로. 운임표에서 정리권 번호의 요금을 보고 기관사 옆에서 내요',
        'To get off, go to the front, find your ticket number on the fare board and pay by the driver',
      ),
      _t('ドアは ボタンを押して開ける車両があります', '버튼을 눌러 문을 여는 차량이 있어요', 'On some trains you press a button to open the door'),
      _t(
        '1時間に1本のことも。帰りの時刻は 先にたしかめておきます',
        '1시간에 1대일 때도 있어요. 돌아오는 시각은 미리 확인해요',
        'Sometimes only one train an hour: check your way back first',
      ),
    ],
  ),
  FirstRideChapter(
    id: 'trouble',
    icon: Icons.support_agent_rounded,
    color: const Color(0xFFB7791F),
    title: _t('こまったときは', '곤란할 때는', 'If something goes wrong'),
    lead: _t('駅員さんに聞くのが いちばんの近道です。', '역무원에게 묻는 게 가장 빠른 길이에요.', 'Asking the station staff is always the quickest way.'),
    steps: [
      _t(
        '忘れ物は 乗った時刻と号車を伝えると 見つかりやすいです',
        '분실물은 탄 시각과 호차를 알려 주면 찾기 쉬워요',
        'Lost something? The time and car number help staff find it',
      ),
      _t(
        '電車が遅れたら 改札で「遅延証明書」をもらえます',
        '열차가 늦으면 개찰구에서 "지연 증명서"를 받을 수 있어요',
        'If trains are late, you can get a delay certificate at the gate',
      ),
      _t(
        '終電は 早めにたしかめて。のりばの「終電アラーム」が知らせます',
        '막차는 미리 확인하세요. 승강장 화면의 "막차 알림"이 알려 줘요',
        'Check the last train early; the last-train alert on のりば tells you',
      ),
      _t(
        '乗りこしたら 精算機か 窓口で 差額を払えば だいじょうぶ',
        '더 멀리 왔다면 정산기나 창구에서 차액만 내면 돼요',
        'Went too far? Pay the difference at a fare adjustment machine or the window',
      ),
    ],
  ),
  FirstRideChapter(
    id: 'words',
    icon: Icons.record_voice_over_rounded,
    color: const Color(0xFF4A5A86),
    title: _t('駅で使えることば', '역에서 쓰는 말', 'Handy words at the station'),
    lead: _t('ひとことで 気持ちはつたわります。', '한마디면 마음이 전해져요.', 'A few words go a long way.'),
    phrases: [
      (
        ja: '〇〇まで いくらですか？',
        roma: 'maru-maru made ikura desu ka?',
        means: _t('〇〇まで いくらですか？', '○○까지 얼마예요?', 'How much is it to ○○?'),
      ),
      (
        ja: 'この電車は 〇〇に止まりますか？',
        roma: 'kono densha wa maru-maru ni tomarimasu ka?',
        means: _t('この電車は 〇〇に止まりますか？', '이 전철은 ○○에 서나요?', 'Does this train stop at ○○?'),
      ),
      (
        ja: '〇〇線は どこですか？',
        roma: 'maru-maru sen wa doko desu ka?',
        means: _t('〇〇線は どこですか？', '○○선은 어디예요?', 'Where is the ○○ Line?'),
      ),
      (
        ja: 'すみません、おります',
        roma: 'sumimasen, orimasu',
        means: _t('すみません、おります', '죄송해요, 내릴게요', 'Excuse me, I\'m getting off'),
      ),
      (ja: 'ありがとうございます', roma: 'arigatou gozaimasu', means: _t('ありがとうございます', '고맙습니다', 'Thank you')),
    ],
  ),
];

/// Chapters in reading order for [cityId]: the country chapter early where
/// country lines run (Tottori), late in Tokyo.
List<FirstRideChapter> firstRideChaptersFor(String cityId) {
  final country = firstRideChapters.where((c) => c.country).toList();
  final rest = firstRideChapters.where((c) => !c.country).toList();
  if (cityId == 'tokyo') return [...rest.take(rest.length - 1), ...country, rest.last];
  return [...rest.take(2), ...country, ...rest.skip(2)];
}
