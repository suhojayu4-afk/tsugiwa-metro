"""Fukuoka landmarks: where they stand on the map, their names and notes, and
the PixelLab candidate picked for each (docs/art/gen/fukuoka/lm_<name>/c<N>.png,
made with create_image_pro 64x64 and the same style image as the Tottori
landmarks: docs/art/gen/landmarks_raw/hachimangu.png).

Canal City and the Nakasu yatai are moved a little (by eye) off the lines.

LANDMARKS: (file, lat, lng, name, unit)  unit: map units per art pixel (0 = the usual size)
ABOUT: file -> (note, station slugs to go from)
PICKS: file -> (candidate, side thickness in px)
"""

LANDMARKS = [
    ('fukuoka_tower', 33.5933, 130.3515, {'ja': '福岡タワー', 'ko': '후쿠오카 타워', 'en': 'Fukuoka Tower'}, 0),
    ('dome', 33.5954, 130.3622, {'ja': 'みずほPayPayドーム福岡', 'ko': '미즈호 페이페이 돔 후쿠오카',
                                 'en': 'Mizuho PayPay Dome Fukuoka'}, 0),
    ('canal_city', 33.5893, 130.4121, {'ja': 'キャナルシティ博多', 'ko': '캐널시티 하카타', 'en': 'Canal City Hakata'}, 0),
    ('ohori', 33.5880, 130.3760, {'ja': '大濠公園', 'ko': '오호리 공원', 'en': 'Ohori Park'}, 0),
    ('yatai', 33.5935, 130.4018, {'ja': '中洲の屋台', 'ko': '나카스 포장마차', 'en': 'Nakasu Yatai Stalls'}, 0),
    ('dazaifu', 33.5215, 130.5349, {'ja': '太宰府天満宮', 'ko': '다자이후 덴만구', 'en': 'Dazaifu Tenmangu'}, 0),
    ('fukuoka_castle', 33.5845, 130.3830, {'ja': '福岡城跡・舞鶴公園', 'ko': '후쿠오카성 터·마이즈루 공원',
                                           'en': 'Fukuoka Castle Ruins'}, 0),
    ('nokonoshima', 33.6280, 130.3030, {'ja': '能古島', 'ko': '노코노시마', 'en': 'Nokonoshima Island'}, 0),
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
        ['kushida-jinja-mae', 'gion', 'nakasu-kawabata']),
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
        'ja': '学問の神さま・菅原道真をまつる神社。梅の名所で、参道の「梅ヶ枝餅」が名物です（西鉄で）。',
        'ko': '학문의 신 스가와라노 미치자네를 모신 신사. 매화 명소이며 참배길의 「우메가에모치」가 명물(니시테쓰 이용).',
        'en': 'The shrine of Sugawara no Michizane, god of learning: plum blossom and umegae-mochi (by Nishitetsu).'},
        ['tenjin']),
    'fukuoka_castle': ({
        'ja': '黒田家が築いた城の石垣が残る公園。春は桜まつりで、天守台から街を見わたせます。',
        'ko': '구로다 가문이 쌓은 성의 돌담이 남은 공원. 봄에는 벚꽃 축제가 열리고 천수대에서 시내가 보여요.',
        'en': 'The stone walls of the Kuroda clan\'s castle in Maizuru Park, a cherry-blossom favourite.'},
        ['akasaka', 'ohorikoen']),
    'nokonoshima': ({
        'ja': '博多湾にうかぶ島。姪浜からフェリーで10分、季節の花がさく「のこのしまアイランドパーク」があります。',
        'ko': '하카타만에 떠 있는 섬. 메이노하마에서 페리로 10분, 계절 꽃이 피는 「노코노시마 아일랜드 파크」가 있어요.',
        'en': 'An island in Hakata Bay, 10 minutes by ferry from Meinohama, with fields of seasonal flowers.'},
        ['meinohama']),
}

PICKS = {'fukuoka_tower': (6, 4), 'dome': (7, 4), 'canal_city': (4, 4), 'ohori': (13, 4), 'yatai': (0, 4),
         'dazaifu': (6, 4), 'fukuoka_castle': (0, 4), 'nokonoshima': (10, 4)}
