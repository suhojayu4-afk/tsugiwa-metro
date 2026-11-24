"""Sapporo landmarks: where they stand on the map, their names and notes, and
the PixelLab candidate picked for each (docs/art/gen/sapporo/lm_<name>/c<N>.png,
made with create_image_pro 64x64 and the same style image as the Tottori
landmarks: docs/art/gen/landmarks_raw/hachimangu.png).

The middle of Sapporo has five of them within a kilometre: they are moved a
little apart (by eye, a few hundred metres at most) so they do not cover
each other.

LANDMARKS: (file, lat, lng, name, unit)  unit: map units per art pixel (0 = the usual size)
ABOUT: file -> (note, station slugs to go from)
PICKS: file -> (candidate, side thickness in px)
"""

LANDMARKS = [
    ('clock_tower', 43.0632, 141.3540, {'ja': '札幌市時計台', 'ko': '삿포로 시계탑', 'en': 'Sapporo Clock Tower'}, 0),
    ('tv_tower', 43.0627, 141.3606, {'ja': 'さっぽろテレビ塔', 'ko': '삿포로 TV탑', 'en': 'Sapporo TV Tower'}, 0),
    ('odori_snow', 43.0622, 141.3445, {'ja': '大通公園・さっぽろ雪まつり', 'ko': '오도리 공원·삿포로 눈축제',
                                       'en': 'Odori Park & Snow Festival'}, 0),
    ('moiwa', 43.0230, 141.3220, {'ja': '藻岩山', 'ko': '모이와산', 'en': 'Mt. Moiwa'}, 0),
    ('susukino', 43.0551, 141.3593, {'ja': 'すすきの', 'ko': '스스키노', 'en': 'Susukino'}, 0),
    ('okurayama', 43.0450, 141.3085, {'ja': '大倉山ジャンプ競技場', 'ko': '오쿠라야마 점프 경기장',
                                      'en': 'Okurayama Ski Jump'}, 0),
    ('red_brick', 43.0648, 141.3470, {'ja': '北海道庁旧本庁舎（赤れんが庁舎）', 'ko': '홋카이도청 구 본청사(아카렌가)',
                                      'en': 'Former Hokkaido Government Office'}, 0),
    ('sapporo_dome', 43.0151, 141.4097, {'ja': '大和ハウス プレミストドーム（札幌ドーム）', 'ko': '삿포로 돔',
                                         'en': 'Sapporo Dome'}, 0),
]

ABOUT = {
    'clock_tower': ({
        'ja': '1878年に建てられた札幌農学校の演武場。いまも時計が鐘で時を知らせる、札幌のシンボルです。',
        'ko': '1878년에 지은 삿포로 농학교의 연무장. 지금도 시계가 종소리로 시간을 알리는 삿포로의 상징이에요.',
        'en': 'The 1878 drill hall of the Sapporo Agricultural College, its clock still ringing the hours.'},
        ['odori', 'sapporo']),
    'tv_tower': ({
        'ja': '大通公園の東のはしに立つ高さ147mのタワー。大きなデジタル時計と、公園を見おろす展望台があります。',
        'ko': '오도리 공원 동쪽 끝에 선 높이 147m의 타워. 커다란 디지털 시계와 공원을 내려다보는 전망대가 있어요.',
        'en': 'A 147 m tower at the east end of Odori Park, with a big digital clock and a deck above the park.'},
        ['odori', 'bus-center-mae']),
    'odori_snow': ({
        'ja': '街のまん中を東西にのびる公園。2月の「さっぽろ雪まつり」では大きな雪像がならびます。',
        'ko': '도심 한가운데를 동서로 가로지르는 공원. 2월 「삿포로 눈축제」에는 커다란 눈 조각이 늘어서요.',
        'en': 'The long park across the city centre; in February the Snow Festival fills it with giant snow statues.'},
        ['odori', 'nishi-11-chome']),
    'moiwa': ({
        'ja': '市街の南西の山（531m）。ロープウェイで山頂へ、夜景は「日本新三大夜景」のひとつです。',
        'ko': '시가지 남서쪽의 산(531m). 로프웨이로 정상까지 오르며, 야경은 「일본 신 3대 야경」 중 하나예요.',
        'en': 'A 531 m mountain south-west of the centre; a ropeway climbs to one of Japan\'s finest night views.'},
        ['ropeway-iriguchi']),
    'susukino': ({
        'ja': '北日本でいちばん大きな繁華街。ネオンの交差点のまわりにラーメン横丁やジンギスカンの店がならびます。',
        'ko': '북일본에서 가장 큰 번화가. 네온 교차로 주변에 라멘 골목과 징기스칸 가게가 늘어서 있어요.',
        'en': 'The biggest nightlife district in northern Japan: neon, Ramen Alley and Genghis Khan grills.'},
        ['susukino', 'hosui-susukino']),
    'okurayama': ({
        'ja': '1972年冬季オリンピックのジャンプ台。リフトで上がるスタートの場所から札幌の街が見わたせます。',
        'ko': '1972년 동계 올림픽의 점프대. 리프트로 오르는 출발 지점에서 삿포로 시내가 한눈에 보여요.',
        'en': 'The ski jump of the 1972 Winter Olympics; a chairlift climbs to the start, high over the city.'},
        ['maruyama-koen']),
    'red_brick': ({
        'ja': '1888年に建てられた赤れんがの旧道庁。八角形の塔があり、前庭の池と花がきれいです。',
        'ko': '1888년에 지은 붉은 벽돌의 옛 도청. 팔각형 탑이 있고 앞뜰의 연못과 꽃이 아름다워요.',
        'en': 'The red-brick government office of 1888 with its octagonal tower, ponds and flower beds.'},
        ['sapporo', 'odori']),
    'sapporo_dome': ({
        'ja': '銀色の大きなドーム。サッカーのときは天然芝のピッチが外から動いて入ってくる、めずらしい競技場です。',
        'ko': '은색의 커다란 돔. 축구 경기 때는 천연 잔디 피치가 밖에서 움직여 들어오는 독특한 경기장이에요.',
        'en': 'A great silver dome whose natural-grass football pitch slides in from outside.'},
        ['fukuzumi']),
}

PICKS = {'clock_tower': (1, 4), 'tv_tower': (7, 4), 'odori_snow': (11, 4), 'moiwa': (1, 4), 'susukino': (2, 4),
         'okurayama': (5, 4), 'red_brick': (2, 4), 'sapporo_dome': (2, 4)}
