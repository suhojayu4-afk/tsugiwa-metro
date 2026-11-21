import '../../core/localized_text.dart';

// The words of プライバシーポリシー / 利用規約 / データ・クレジット.
//
// Keep these TRUE: every sentence here describes what the code really does.
// When the app starts doing something new with data (an account, analytics,
// ads, real purchases, a server), change the text and [legalEffectiveDate]
// in the same commit.

/// App version shown in 設定. Keep the same as `version:` in pubspec.yaml
/// (test/settings_test.dart checks it).
const appVersion = '0.1.0';

/// The day the texts below took effect.
const legalEffectiveDate = '2026-11-22';

// TODO(owner): fill in before the store launch — the e-mail address (or
// contact form URL) users write to about privacy and the app. It is shown in
// the privacy policy, the terms and the ODPT credit. While it is empty those
// pages point to "the contact on the app's store page" instead.
const supportContact = '';

const _contactFallback = LocalizedText({
  'ja': 'アプリのストアページにある連絡先',
  'ko': '앱 스토어 페이지에 적힌 연락처',
  'en': 'the contact shown on the app\'s store page',
});

/// What `{contact}` in the texts becomes.
String contactFor(String lang) => supportContact.isEmpty ? _contactFallback.of(lang) : supportContact;

class LegalSection {
  const LegalSection(this.heading, this.body);
  final LocalizedText heading;

  /// Paragraphs separated by a blank line; lines starting with "・" are a list.
  final LocalizedText body;
}

class LegalDoc {
  const LegalDoc({required this.title, required this.lead, required this.sections, this.dated = true});
  final LocalizedText title;
  final LocalizedText lead;
  final List<LegalSection> sections;

  /// Whether to show [legalEffectiveDate] under the title.
  final bool dated;
}

const effectiveLabel = LocalizedText({'ja': '施行日', 'ko': '시행일', 'en': 'Effective'});

// ---------------------------------------------------------------------------
// Privacy policy
// ---------------------------------------------------------------------------

const privacyDoc = LegalDoc(
  title: LocalizedText({'ja': 'プライバシーポリシー', 'ko': '개인정보 처리방침', 'en': 'Privacy Policy'}),
  lead: LocalizedText({
    'ja':
        '「つぎは Metro」は、アカウント登録なしで使えるアプリです。名前・メールアドレス・電話番号などは集めていません。'
        'このアプリが何を使い、どこに保存しているかを、短く正直に書きます。',
    'ko':
        '「츠기와 Metro」는 계정 등록 없이 쓰는 앱이에요. 이름·이메일 주소·전화번호 같은 정보는 모으지 않아요. '
        '이 앱이 무엇을 쓰고 어디에 저장하는지 짧고 솔직하게 적었어요.',
    'en':
        'Tsugiwa Metro works without an account. It does not collect your name, e-mail address or phone number. '
        'This page says, briefly and honestly, what the app uses and where it is kept.',
  }),
  sections: [
    LegalSection(
      LocalizedText({'ja': '位置情報', 'ko': '위치 정보', 'en': 'Location'}),
      LocalizedText({
        'ja':
            '位置情報は、次の2つのためだけに使います。\n'
            '・いちばん近い駅をさがす\n'
            '・乗車中に、いまどの駅のあたりかを追って、到着を知らせる\n\n'
            '位置（緯度・経度）はスマホの中だけで計算に使います。開発者や外部のサーバーには送りません。位置そのものを保存することもありません。\n\n'
            '乗車中は、画面を消していても案内を続けられるよう、通知を出したまま位置情報を使います。乗車を終えると止まります。'
            '「常に許可」は求めません。\n\n'
            '位置情報を許可しなくても、駅を自分で選べばアプリを使えます。許可はスマホの設定からいつでも取り消せます。',
        'ko':
            '위치 정보는 다음 두 가지에만 써요.\n'
            '・가장 가까운 역 찾기\n'
            '・승차 중에 지금 어느 역 근처인지 따라가며 도착을 알리기\n\n'
            '위치(위도·경도)는 휴대폰 안에서만 계산에 써요. 개발자나 외부 서버로 보내지 않아요. 위치 자체를 저장하지도 않아요.\n\n'
            '승차 중에는 화면을 꺼도 안내가 이어지도록 알림을 띄운 채 위치 정보를 써요. 승차를 마치면 멈춰요. '
            '「항상 허용」은 요청하지 않아요.\n\n'
            '위치 정보를 허용하지 않아도 역을 직접 고르면 앱을 쓸 수 있어요. 허용은 휴대폰 설정에서 언제든 취소할 수 있어요.',
        'en':
            'Location is used for two things only.\n'
            '・Finding the station nearest to you\n'
            '・Following your ride, to tell you where you are and when you arrive\n\n'
            'Your position (latitude and longitude) is used for calculations on your phone only. It is not sent to the '
            'developer or to any outside server, and the position itself is not saved.\n\n'
            'During a ride the app keeps using location with a notification showing, so the guidance goes on with the '
            'screen off. It stops when the ride ends. The app never asks for "Allow all the time".\n\n'
            'You can use the app without location by choosing stations yourself, and you can take the permission back '
            'in your phone\'s settings at any time.',
      }),
    ),
    LegalSection(
      LocalizedText({'ja': 'インターネット通信', 'ko': '인터넷 통신', 'en': 'Internet connections'}),
      LocalizedText({
        'ja':
            'このアプリが通信する相手は次の2つだけです。\n'
            '・公共交通オープンデータセンター（api.odpt.org）— 運行情報\n'
            '・気象庁（www.jma.go.jp）— 天気\n\n'
            '送るのは「どの鉄道会社の運行情報か」「どの地域の天気か」と、アプリ用のアクセスキーだけです。'
            '天気の地域は東京などあらかじめ決まった地域で、あなたの位置ではありません。'
            '位置情報・乗車記録・あなたを特定する情報は送りません。\n\n'
            'インターネット通信なので、通信先にはIPアドレスなどふつうの接続情報が伝わります。',
        'ko':
            '이 앱이 통신하는 곳은 다음 두 곳뿐이에요.\n'
            '・공공교통 오픈데이터센터(api.odpt.org) — 운행 정보\n'
            '・일본 기상청(www.jma.go.jp) — 날씨\n\n'
            '보내는 것은 「어느 철도 회사의 운행 정보인지」, 「어느 지역의 날씨인지」와 앱용 접속 키뿐이에요. '
            '날씨 지역은 도쿄처럼 미리 정해진 지역이며, 내 위치가 아니에요. '
            '위치 정보·승차 기록·나를 알아볼 수 있는 정보는 보내지 않아요.\n\n'
            '인터넷 통신이므로 통신 상대에게는 IP 주소 같은 일반적인 접속 정보가 전달돼요.',
        'en':
            'The app connects to these two services only.\n'
            '・Public Transportation Open Data Center (api.odpt.org) — train service status\n'
            '・Japan Meteorological Agency (www.jma.go.jp) — weather\n\n'
            'It sends only which railway operator\'s status it wants, which region\'s weather it wants, and the app\'s '
            'access key. The weather region is a fixed one such as Tokyo, not your position. Your location, your rides '
            'and anything that identifies you are not sent.\n\n'
            'As with any internet connection, those services see ordinary connection details such as your IP address.',
      }),
    ),
    LegalSection(
      LocalizedText({'ja': 'スマホに保存するデータ', 'ko': '휴대폰에 저장하는 데이터', 'en': 'Data kept on your phone'}),
      LocalizedText({
        'ja':
            '次のデータは、あなたのスマホの中だけに保存します。開発者は見ることができません。\n'
            '・乗車記録（乗った駅・路線・日時）、駅スタンプ、駅印\n'
            '・コイン、アイテム、ステッカー、バッジ\n'
            '・MY駅の駅名標の文字、よく使う経路\n'
            '・終電・始発アラームの設定、言語の設定\n\n'
            'スマホのバックアップ機能を使っている場合は、OSがあなた自身のアカウント（Googleアカウントなど）に'
            'アプリのデータをバックアップすることがあります。これはスマホの設定で管理できます。',
        'ko':
            '다음 데이터는 내 휴대폰 안에만 저장해요. 개발자는 볼 수 없어요.\n'
            '・승차 기록(탄 역·노선·날짜와 시간), 역 스탬프, 역 도장\n'
            '・코인, 아이템, 스티커, 배지\n'
            '・MY역 역명판의 글자, 자주 쓰는 경로\n'
            '・막차·첫차 알람 설정, 언어 설정\n\n'
            '휴대폰의 백업 기능을 쓰고 있다면 OS가 내 계정(Google 계정 등)에 앱 데이터를 백업할 수 있어요. '
            '이것은 휴대폰 설정에서 관리할 수 있어요.',
        'en':
            'The following is saved on your phone only. The developer cannot see it.\n'
            '・Your rides (stations, lines, date and time), station stamps and seals\n'
            '・Coins, items, stickers and badges\n'
            '・The text on your MY station sign and your usual routes\n'
            '・Last-train and first-train alarm settings, and the language setting\n\n'
            'If you use your phone\'s backup feature, the operating system may back up the app\'s data to your own '
            'account (for example your Google account). You control that in your phone\'s settings.',
      }),
    ),
    LegalSection(
      LocalizedText({'ja': '広告・アクセス解析', 'ko': '광고·접속 분석', 'en': 'Ads and analytics'}),
      LocalizedText({
        'ja': '広告、アクセス解析、行動を追跡するしくみは入っていません。',
        'ko': '광고, 접속 분석, 행동을 추적하는 기능은 들어 있지 않아요.',
        'en': 'The app contains no ads, no analytics and no tracking.',
      }),
    ),
    LegalSection(
      LocalizedText({'ja': '通知', 'ko': '알림', 'en': 'Notifications'}),
      LocalizedText({
        'ja':
            '乗車中の案内、終電・始発アラーム、月ごとの乗車レポートを通知します。'
            '通知はすべてスマホの中で作られ、外のサーバーから送られるものではありません。通知はスマホの設定でオフにできます。',
        'ko':
            '승차 중 안내, 막차·첫차 알람, 월간 승차 리포트를 알림으로 보내요. '
            '알림은 모두 휴대폰 안에서 만들어지며, 외부 서버에서 보내는 것이 아니에요. 알림은 휴대폰 설정에서 끌 수 있어요.',
        'en':
            'The app notifies you about your ride, the last-train and first-train alarms, and a monthly ride report. '
            'All notifications are made on your phone; none are sent from a server. You can turn them off in your '
            'phone\'s settings.',
      }),
    ),
    LegalSection(
      LocalizedText({'ja': 'シェア', 'ko': '공유', 'en': 'Sharing'}),
      LocalizedText({
        'ja':
            'シェア用の画像は、あなたが「シェア」を押したときだけスマホの外に出ます。送り先はあなたが選んだアプリです。'
            '画像には、乗車の記録や招待コード（スマホの中で作ったランダムな6文字）が入ることがあります。',
        'ko':
            '공유용 이미지는 「공유」를 눌렀을 때만 휴대폰 밖으로 나가요. 보내는 곳은 내가 고른 앱이에요. '
            '이미지에는 승차 기록이나 초대 코드(휴대폰 안에서 만든 무작위 6글자)가 들어갈 수 있어요.',
        'en':
            'Share images leave your phone only when you press Share, and they go to the app you choose. An image may '
            'show your ride records and your invite code (six random characters made on your phone).',
      }),
    ),
    LegalSection(
      LocalizedText({'ja': 'お子さまの利用', 'ko': '어린이의 이용', 'en': 'Children'}),
      LocalizedText({
        'ja': '年齢にかかわらず使えます。上に書いたとおり、お子さまからも個人情報を集めません。',
        'ko': '나이에 관계없이 쓸 수 있어요. 위에 적은 대로 어린이에게서도 개인정보를 모으지 않아요.',
        'en': 'The app can be used at any age. As written above, it does not collect personal information from children either.',
      }),
    ),
    LegalSection(
      LocalizedText({'ja': 'データを消す', 'ko': '데이터 지우기', 'en': 'Deleting your data'}),
      LocalizedText({
        'ja':
            'アプリをアンインストールすると、スマホに保存したデータは消えます。'
            'アプリを残したまま消したいときは、スマホの設定でこのアプリのデータ（ストレージ）を消去してください。'
            '開発者の側に消すデータはありません。',
        'ko':
            '앱을 삭제하면 휴대폰에 저장한 데이터는 지워져요. '
            '앱을 남긴 채 지우고 싶을 때는 휴대폰 설정에서 이 앱의 데이터(저장공간)를 삭제해 주세요. '
            '개발자 쪽에는 지울 데이터가 없어요.',
        'en':
            'Uninstalling the app removes the data saved on your phone. To erase it while keeping the app, clear this '
            'app\'s data (storage) in your phone\'s settings. There is nothing to delete on the developer\'s side.',
      }),
    ),
    LegalSection(
      LocalizedText({'ja': '変更とお問い合わせ', 'ko': '변경과 문의', 'en': 'Changes and contact'}),
      LocalizedText({
        'ja': 'データの扱いが変わるときは、このページを書きかえ、施行日を新しくします。\n\nお問い合わせ：{contact}',
        'ko': '데이터를 다루는 방식이 바뀌면 이 페이지를 고치고 시행일을 새로 적어요.\n\n문의: {contact}',
        'en':
            'If the way the app handles data changes, this page is rewritten and given a new date.\n\n'
            'Contact: {contact}',
      }),
    ),
  ],
);

// ---------------------------------------------------------------------------
// Terms
// ---------------------------------------------------------------------------

const termsDoc = LegalDoc(
  title: LocalizedText({'ja': '利用規約', 'ko': '이용약관', 'en': 'Terms of Use'}),
  lead: LocalizedText({
    'ja': '「つぎは Metro」は、鉄道会社とは関係のない非公式の案内アプリです。使う前に、次のことをご了承ください。',
    'ko': '「츠기와 Metro」는 철도 회사와 관계없는 비공식 안내 앱이에요. 쓰기 전에 다음 내용을 확인해 주세요.',
    'en':
        'Tsugiwa Metro is an unofficial guide app with no connection to the railway companies. Please read the '
        'following before you use it.',
  }),
  sections: [
    LegalSection(
      LocalizedText({'ja': '案内は目安です', 'ko': '안내는 참고용이에요', 'en': 'The information is a guide'}),
      LocalizedText({
        'ja':
            '時刻、終電・始発、乗りかえ、号車の位置、列車の位置、混雑、運行情報、天気は、どれも目安です。'
            '実際とちがうことがあります。\n\n'
            '大事な移動のときや終電の前には、駅の案内や鉄道会社の公式情報を確かめてください。',
        'ko':
            '시각, 막차·첫차, 환승, 칸 위치, 열차 위치, 혼잡도, 운행 정보, 날씨는 모두 참고용이에요. '
            '실제와 다를 수 있어요.\n\n'
            '중요한 이동이나 막차 전에는 역의 안내와 철도 회사의 공식 정보를 확인해 주세요.',
        'en':
            'Times, last and first trains, transfers, car positions, train positions, crowding, service status and '
            'weather are all a guide. They can differ from reality.\n\n'
            'For an important journey, and before the last train, check the station\'s signs and the railway '
            'company\'s official information.',
      }),
    ),
    LegalSection(
      LocalizedText({'ja': '責任について', 'ko': '책임에 대하여', 'en': 'Responsibility'}),
      LocalizedText({
        'ja':
            'このアプリの案内やアラーム・通知がもとで起きた、乗りおくれ・遅刻・乗りまちがいなどの損害について、'
            '開発者は、法律で認められる範囲で責任を負いません。',
        'ko':
            '이 앱의 안내나 알람·알림 때문에 생긴 열차 놓침·지각·잘못 탐 등의 손해에 대해, '
            '개발자는 법이 허용하는 범위에서 책임을 지지 않아요.',
        'en':
            'To the extent the law allows, the developer is not responsible for missed trains, lateness, wrong '
            'trains or other loss caused by the app\'s guidance, alarms or notifications.',
      }),
    ),
    LegalSection(
      LocalizedText({'ja': 'コインとアイテム', 'ko': '코인과 아이템', 'en': 'Coins and items'}),
      LocalizedText({
        'ja':
            'コイン、アイテム、ステッカー、スタンプは、このアプリの中だけで楽しむものです。'
            'お金やほかのものに換えることはできず、金銭的な価値はありません。\n\n'
            'データはスマホの中だけにあるため、アプリを消したり機種を変えたりすると、元にもどせないことがあります。',
        'ko':
            '코인, 아이템, 스티커, 스탬프는 이 앱 안에서만 즐기는 것이에요. '
            '돈이나 다른 것으로 바꿀 수 없고, 금전적 가치가 없어요.\n\n'
            '데이터는 휴대폰 안에만 있어서, 앱을 지우거나 기기를 바꾸면 되돌리지 못할 수 있어요.',
        'en':
            'Coins, items, stickers and stamps are for fun inside this app only. They cannot be exchanged for money '
            'or anything else and have no cash value.\n\n'
            'Because the data lives only on your phone, it may not be recoverable after you delete the app or change '
            'phones.',
      }),
    ),
    LegalSection(
      LocalizedText({'ja': '安全のために', 'ko': '안전을 위해', 'en': 'For your safety'}),
      LocalizedText({
        'ja': 'ホームや階段、歩いているときは、画面を見つづけないでください。',
        'ko': '승강장이나 계단, 걷는 중에는 화면을 계속 보지 마세요.',
        'en': 'Do not keep looking at the screen on platforms, on stairs or while walking.',
      }),
    ),
    LegalSection(
      LocalizedText({'ja': '変更とお問い合わせ', 'ko': '변경과 문의', 'en': 'Changes and contact'}),
      LocalizedText({
        'ja': 'アプリの内容やこの規約は、変わることがあります。変えたときはこのページを新しくします。\n\nお問い合わせ：{contact}',
        'ko': '앱의 내용이나 이 약관은 바뀔 수 있어요. 바뀌면 이 페이지를 새로 고쳐요.\n\n문의: {contact}',
        'en': 'The app and these terms may change. When they do, this page is updated.\n\nContact: {contact}',
      }),
    ),
  ],
);

// ---------------------------------------------------------------------------
// Data credits
// ---------------------------------------------------------------------------

/// Sites the 乗換便利号車 entries were taken from (the `source` hosts of
/// assets/cities/*/cars.json; test/settings_test.dart checks none is
/// missing here).
const carGuideSources = ['wadattsu261.com', 'yamanote-line-transfer.info'];

const creditsDoc = LegalDoc(
  dated: false,
  title: LocalizedText({'ja': 'データ・クレジット', 'ko': '데이터·크레딧', 'en': 'Data & Credits'}),
  lead: LocalizedText({
    'ja': 'このアプリは、次のデータや素材のおかげで動いています。',
    'ko': '이 앱은 다음 데이터와 소재 덕분에 움직여요.',
    'en': 'The app runs thanks to the following data and materials.',
  }),
  sections: [
    LegalSection(
      LocalizedText({'ja': '天気', 'ko': '날씨', 'en': 'Weather'}),
      LocalizedText({
        'ja': '出典：気象庁ホームページ（https://www.jma.go.jp/）\n気象庁のデータを加工して作成しています。',
        'ko': '출처: 일본 기상청 홈페이지(https://www.jma.go.jp/)\n기상청의 데이터를 가공해 만들었어요.',
        'en':
            'Source: Japan Meteorological Agency website (https://www.jma.go.jp/)\n'
            'Made by processing the agency\'s data.',
      }),
    ),
    LegalSection(
      LocalizedText({'ja': '運行情報', 'ko': '운행 정보', 'en': 'Train service status'}),
      LocalizedText({
        'ja':
            '本アプリケーション等が利用する公共交通データは、公共交通オープンデータセンターにおいて提供されるものです。\n\n'
            '公共交通事業者により提供されたデータを元にしていますが、必ずしも正確・完全なものとは限りません。'
            '本アプリケーションの表示内容について、公共交通事業者への直接の問合せは行わないでください。\n\n'
            '本アプリケーションに関するお問い合わせ：{contact}',
        'ko':
            '이 앱이 이용하는 대중교통 데이터는 공공교통 오픈데이터센터(公共交通オープンデータセンター)에서 제공하는 것이에요.\n\n'
            '대중교통 사업자가 제공한 데이터를 바탕으로 하지만, 반드시 정확하고 완전하다고는 할 수 없어요. '
            '이 앱에 표시된 내용에 대해 대중교통 사업자에게 직접 문의하지 말아 주세요.\n\n'
            '이 앱에 관한 문의: {contact}',
        'en':
            'The source of the public transportation data in this app is the Public Transportation Open Data Center '
            '(公共交通オープンデータセンター).\n\n'
            'It is based on data provided by the public transportation operators, but its accuracy and integrity are '
            'not guaranteed. Please do not contact the public transportation operators directly about what this app '
            'shows.\n\n'
            'For inquiries about this app: {contact}',
      }),
    ),
    LegalSection(
      LocalizedText({'ja': '地図・駅・路線', 'ko': '지도·역·노선', 'en': 'Map, stations and lines'}),
      LocalizedText({
        'ja':
            '© OpenStreetMap contributors\n'
            'Open Database License (ODbL) 1.0 のもとで利用しています。\n'
            'https://www.openstreetmap.org/copyright\n\n'
            '駅や路線の名前・つながりの一部は Wikidata（CC0）を利用しています。\n\n'
            '路線図と列車の位置は、これらをもとにこのアプリが描いた絵と、時刻表からの推定です。',
        'ko':
            '© OpenStreetMap contributors\n'
            'Open Database License (ODbL) 1.0에 따라 이용해요.\n'
            'https://www.openstreetmap.org/copyright\n\n'
            '역과 노선의 이름·연결 일부는 Wikidata(CC0)를 이용해요.\n\n'
            '노선도와 열차 위치는 이를 바탕으로 이 앱이 그린 그림과, 시간표로 추정한 것이에요.',
        'en':
            '© OpenStreetMap contributors\n'
            'Used under the Open Database License (ODbL) 1.0.\n'
            'https://www.openstreetmap.org/copyright\n\n'
            'Some station and line names and connections come from Wikidata (CC0).\n\n'
            'The route map is this app\'s own drawing based on them, and train positions are estimated from '
            'timetables.',
      }),
    ),
    LegalSection(
      LocalizedText({'ja': '乗りかえに便利な号車', 'ko': '환승이 편한 칸', 'en': 'Best car for transfers'}),
      LocalizedText({
        'ja':
            '次のサイトで公開されている情報を参考にしています。\n'
            '・wadattsu261.com\n'
            '・yamanote-line-transfer.info\n\n'
            '駅の工事などで実際とちがうことがあります。',
        'ko':
            '다음 사이트에 공개된 정보를 참고했어요.\n'
            '・wadattsu261.com\n'
            '・yamanote-line-transfer.info\n\n'
            '역 공사 등으로 실제와 다를 수 있어요.',
        'en':
            'Based on information published on these sites.\n'
            '・wadattsu261.com\n'
            '・yamanote-line-transfer.info\n\n'
            'It can differ from reality, for example during station works.',
      }),
    ),
    LegalSection(
      LocalizedText({'ja': '音とドット絵', 'ko': '소리와 도트 그림', 'en': 'Sounds and pixel art'}),
      LocalizedText({
        'ja':
            '発車メロディや効果音、ドット絵は、このアプリのために作ったオリジナルです。'
            '実際の駅の発車メロディや、鉄道会社の公式の絵ではありません。',
        'ko':
            '발차 멜로디와 효과음, 도트 그림은 이 앱을 위해 만든 오리지널이에요. '
            '실제 역의 발차 멜로디나 철도 회사의 공식 그림이 아니에요.',
        'en':
            'The departure melodies, sound effects and pixel art were made for this app. They are not the real '
            'station melodies or the railway companies\' official artwork.',
      }),
    ),
    LegalSection(
      LocalizedText({'ja': 'フォント', 'ko': '글꼴', 'en': 'Fonts'}),
      LocalizedText({
        'ja':
            'DotGothic16、Galmuri11、Yuji Boku（いずれも SIL Open Font License 1.1）。'
            'ライセンスの全文は「ライセンス」のページにあります。',
        'ko':
            'DotGothic16, Galmuri11, Yuji Boku(모두 SIL Open Font License 1.1). '
            '라이선스 전문은 「라이선스」 페이지에 있어요.',
        'en':
            'DotGothic16, Galmuri11 and Yuji Boku (all under the SIL Open Font License 1.1). The full licence texts '
            'are on the Licences page.',
      }),
    ),
    LegalSection(
      LocalizedText({'ja': '鉄道会社の名前など', 'ko': '철도 회사의 이름 등', 'en': 'Railway names'}),
      LocalizedText({
        'ja': '鉄道会社・路線・駅の名前や路線の色は、それぞれの会社のものです。このアプリは各社の公式アプリではありません。',
        'ko': '철도 회사·노선·역의 이름과 노선 색은 각 회사의 것이에요. 이 앱은 각 회사의 공식 앱이 아니에요.',
        'en':
            'The names of railway companies, lines and stations, and the line colours, belong to their companies. '
            'This is not an official app of any of them.',
      }),
    ),
  ],
);
