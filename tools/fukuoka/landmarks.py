"""Fukuoka landmarks: where they stand on the map, their names and notes, and
the PixelLab candidate picked for each (docs/art/gen/fukuoka/lm_<name>/c<N>.png,
made with create_image_pro 64x64 and the same style image as the Tottori
landmarks: docs/art/gen/landmarks_raw/hachimangu.png).

Canal City, Kushida Shrine, Hakata Station and the Nakasu yatai are moved a
little (by eye) off the lines.

LANDMARKS: (file, lat, lng, name, unit)  unit: map units per art pixel (0 = the usual size)
ABOUT: file -> (note, station slugs to go from; the first is the one the "go here" button uses)
PICKS: file -> (candidate, side thickness in px[, candidate folder])
"""

LANDMARKS = [
    ('fukuoka_tower', 33.5933, 130.3515, {'ja': '福岡タワー', 'ko': '후쿠오카 타워', 'en': 'Fukuoka Tower'}, 0),
    ('dome', 33.5954, 130.3622, {'ja': 'みずほPayPayドーム福岡', 'ko': '미즈호 페이페이 돔 후쿠오카',
                                 'en': 'Mizuho PayPay Dome Fukuoka'}, 0),
    ('canal_city', 33.5850, 130.4150, {'ja': 'キャナルシティ博多', 'ko': '캐널시티 하카타', 'en': 'Canal City Hakata'}, 0),
    ('ohori', 33.5880, 130.3760, {'ja': '大濠公園', 'ko': '오호리 공원', 'en': 'Ohori Park'}, 0),
    ('yatai', 33.5935, 130.4018, {'ja': '中洲の屋台', 'ko': '나카스 포장마차', 'en': 'Nakasu Yatai Stalls'}, 0),
    ('dazaifu', 33.5215, 130.5349, {'ja': '太宰府天満宮', 'ko': '다자이후 덴만구', 'en': 'Dazaifu Tenmangu'}, 0),
    ('fukuoka_castle', 33.5845, 130.3830, {'ja': '福岡城跡・舞鶴公園', 'ko': '후쿠오카성 터·마이즈루 공원',
                                           'en': 'Fukuoka Castle Ruins'}, 0),
    ('nokonoshima', 33.6280, 130.3030, {'ja': '能古島', 'ko': '노코노시마', 'en': 'Nokonoshima Island'}, 0),
    ('kushida', 33.5902, 130.4111, {'ja': '櫛田神社', 'ko': '구시다 신사', 'en': 'Kushida Shrine'}, 0),
    ('hakata_station', 33.5850, 130.4285, {'ja': '博多駅', 'ko': '하카타역', 'en': 'Hakata Station'}, 0),
    ('port_tower', 33.6040, 130.4010, {'ja': '博多ポートタワー', 'ko': '하카타 포트 타워', 'en': 'Hakata Port Tower'}, 0),
    ('uminonakamichi', 33.6560, 130.3620, {'ja': '海の中道海浜公園', 'ko': '우미노나카미치 해변공원',
                                           'en': 'Uminonakamichi Seaside Park'}, 0),
]

ABOUT = {
    'fukuoka_tower': ({
        'ja': '高さ234mの海辺のタワー。8000枚のハーフミラーにおおわれ、展望室から博多湾と街が見わたせます。',
        'ko': '높이 234m의 바닷가 타워. 8,000장의 하프 미러로 덮여 있고, 전망실에서 하카타만과 시내가 보여요.',
        'en': 'A 234 m seaside tower clad in 8,000 half-mirrors, looking over Hakata Bay and the city.'},
        ['nishijin', 'fujisaki']),
    'dome': ({
        'ja': '日本で初めての開閉式屋根のドーム球場。プロ野球・福岡ソフトバンクホークスの本拠地です。',
        'ko': '일본 최초의 개폐식 지붕 돔 구장. 프로야구 후쿠오카 소프트뱅크 호크스의 홈구장이에요.',
        'en': 'Japan\'s first dome with an opening roof, home of the Fukuoka SoftBank Hawks.'}, ['tojinmachi']),
    'canal_city': ({
        'ja': '建物のあいだを運河が流れる大きなショッピングモール。噴水ショーやラーメンスタジアムが人気です。',
        'ko': '건물 사이로 운하가 흐르는 커다란 쇼핑몰. 분수 쇼와 라멘 스타디움이 인기예요.',
        'en': 'A big mall built round a canal, with fountain shows and the Ramen Stadium.'},
        ['kushida-jinja-mae', 'gion', 'nakasu-kawabata', 'hakata']),
    'ohori': ({
        'ja': '福岡城の堀をいかした大きな池の公園。池のまん中の島を橋でわたって一周できます。',
        'ko': '후쿠오카성 해자를 살린 커다란 연못 공원. 연못 가운데 섬을 다리로 건너며 한 바퀴 돌 수 있어요.',
        'en': 'A large pond park made from the castle moat; bridges cross its islands for a walk round.'},
        ['ohorikoen']),
    'yatai': ({
        'ja': '夜になると中洲の川ぞいにならぶ屋台。ラーメンやおでん、焼き鳥を肩をならべて味わえます。',
        'ko': '밤이 되면 나카스 강변에 늘어서는 포장마차. 라멘과 오뎅, 야키토리를 나란히 앉아 맛봐요.',
        'en': 'Street food stalls along the Nakasu riverside at night: ramen, oden and yakitori.'},
        ['nakasu-kawabata', 'tenjin']),
    'dazaifu': ({
        'ja': '学問の神さま・菅原道真をまつる神社。梅の名所で、参道の「梅ヶ枝餅」が名物です。西鉄太宰府駅から歩いてすぐ。',
        'ko': '학문의 신 스가와라노 미치자네를 모신 신사. 매화 명소이며 참배길의 「우메가에모치」가 명물. 니시테쓰 다자이후역에서 걸어서 금방이에요.',
        'en': 'The shrine of Sugawara no Michizane, god of learning: plum blossom and umegae-mochi cakes, a short '
              'walk from Nishitetsu Dazaifu station.'}, ['dazaifu', 'nishitetsu-futsukaichi']),
    'fukuoka_castle': ({
        'ja': '黒田家が築いた城の石垣が残る公園。春は桜まつりで、天守台から街を見わたせます。',
        'ko': '구로다 가문이 쌓은 성의 돌담이 남은 공원. 봄에는 벚꽃 축제가 열리고 천수대에서 시내가 보여요.',
        'en': 'The stone walls of the Kuroda clan\'s castle in Maizuru Park, a cherry-blossom favourite.'},
        ['ohorikoen', 'akasaka']),
    'nokonoshima': ({
        'ja': '博多湾にうかぶ島。姪浜からフェリーで10分、季節の花がさく「のこのしまアイランドパーク」があります。',
        'ko': '하카타만에 떠 있는 섬. 메이노하마에서 페리로 10분, 계절 꽃이 피는 「노코노시마 아일랜드 파크」가 있어요.',
        'en': 'An island in Hakata Bay, 10 minutes by ferry from Meinohama, with fields of seasonal flowers.'},
        ['meinohama']),
    'kushida': ({
        'ja': '「お櫛田さん」とよばれる博多の総鎮守。7月の博多祇園山笠の舞台で、境内には一年中かざり山笠が立ちます。',
        'ko': '「오쿠시다상」이라 불리는 하카타의 수호 신사. 7월 하카타 기온 야마카사 축제의 무대로, 경내에 장식 가마가 일 년 내내 서 있어요.',
        'en': 'Hakata\'s guardian shrine and home of the Hakata Gion Yamakasa festival in July; a tall festival float '
              'stands here all year.'}, ['kushida-jinja-mae', 'gion', 'nakasu-kawabata']),
    'hakata_station': ({
        'ja': '九州の玄関口となる大きな駅。新幹線や地下鉄が集まり、駅ビルの屋上には線路が見える庭園があります。',
        'ko': '규슈의 관문인 큰 역. 신칸센과 지하철이 모이고, 역 빌딩 옥상에는 선로가 내려다보이는 정원이 있어요.',
        'en': 'Kyushu\'s great gateway station for the shinkansen and the subway, with a rooftop garden over the '
              'tracks.'}, ['hakata']),
    'port_tower': ({
        'ja': '博多ふ頭に立つ赤い鉄塔（1964年）。展望室は無料で、博多湾を行き来する船が見えます。',
        'ko': '하카타 부두에 선 붉은 철탑(1964년). 전망실은 무료이고 하카타만을 오가는 배가 보여요.',
        'en': 'The red lattice tower (1964) on Hakata Pier; its free deck looks over the ferries on Hakata Bay.'},
        ['gofukumachi', 'nakasu-kawabata']),
    'uminonakamichi': ({
        'ja': '博多湾と玄界灘にはさまれた砂州の大きな公園。季節の花畑と海辺のサイクリングが楽しめます。JR香椎で香椎線に乗りかえ。',
        'ko': '하카타만과 겐카이나다 사이 모래톱의 넓은 공원. 계절 꽃밭과 바닷가 자전거길을 즐길 수 있어요. JR 가시이역에서 가시이선으로 환승.',
        'en': 'A big park on the sand spit between Hakata Bay and the open sea: seasonal flower fields and seaside '
              'cycling. Change at JR Kashii for the Kashii Line.'}, ['kashii']),
}

PICKS = {'fukuoka_tower': (6, 4), 'dome': (7, 4), 'canal_city': (4, 4), 'ohori': (13, 4), 'yatai': (0, 4),
         'dazaifu': (6, 4), 'fukuoka_castle': (0, 4), 'nokonoshima': (10, 4), 'kushida': (14, 4),
         'hakata_station': (8, 4), 'port_tower': (0, 4), 'uminonakamichi': (13, 4)}
