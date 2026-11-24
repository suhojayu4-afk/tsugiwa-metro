"""Sendai landmarks: where they stand on the map, their names and notes, and
the PixelLab candidate picked for each (docs/art/gen/sendai/lm_<name>/c<N>.png,
made with create_image_pro 64x64 and the same style image as the Tottori
landmarks: docs/art/gen/landmarks_raw/hachimangu.png).

Jozenji-dori, Zuihoden, the Tanabata arcade and Matsushima are moved a few
hundred metres (by eye) off the lines drawn next to them / out onto the bay.

LANDMARKS: (file, lat, lng, name, unit)  unit: map units per art pixel (0 = the usual size)
ABOUT: file -> (note, station slugs to go from)
PICKS: file -> (candidate, side thickness in px)
"""

LANDMARKS = [
    ('aoba_castle', 38.2530, 140.8565, {'ja': '仙台城跡・伊達政宗像', 'ko': '센다이성 터·다테 마사무네 동상',
                                        'en': 'Sendai Castle Ruins & Date Masamune'}, 0),
    ('zuihoden', 38.2510, 140.8722, {'ja': '瑞鳳殿', 'ko': '즈이호덴', 'en': 'Zuihoden Mausoleum'}, 0),
    ('jozenji', 38.2660, 140.8655, {'ja': '定禅寺通', 'ko': '조젠지도리', 'en': 'Jozenji-dori Avenue'}, 0),
    ('matsushima', 38.3650, 141.0710, {'ja': '松島', 'ko': '마쓰시마', 'en': 'Matsushima Bay'}, 0),
    ('osaki_hachimangu', 38.2780, 140.8530, {'ja': '大崎八幡宮', 'ko': '오사키 하치만구', 'en': 'Osaki Hachimangu'}, 0),
    ('daikannon', 38.3010, 140.8460, {'ja': '仙台大観音', 'ko': '센다이 대관음', 'en': 'Sendai Daikannon'}, 0),
    ('tanabata', 38.2605, 140.8815, {'ja': '仙台七夕まつり', 'ko': '센다이 다나바타 축제', 'en': 'Sendai Tanabata Festival'}, 0),
    ('stadium', 38.2563, 140.9026, {'ja': '楽天モバイルパーク宮城', 'ko': '라쿠텐 모바일 파크 미야기',
                                    'en': 'Rakuten Mobile Park Miyagi'}, 0),
]

ABOUT = {
    'aoba_castle': ({
        'ja': '伊達政宗が青葉山に築いた城の跡。馬に乗った政宗の像の前から、仙台の街が一望できます。',
        'ko': '다테 마사무네가 아오바산에 쌓은 성터. 말을 탄 마사무네 동상 앞에서 센다이 시내가 한눈에 보여요.',
        'en': 'Where Date Masamune built his castle on Aobayama; his statue on horseback overlooks the city.'},
        ['international-center', 'aobayama']),
    'zuihoden': ({
        'ja': '伊達政宗のねむる霊屋。杉木立の石段の上に、黒うるしと金色のかざりの華やかな建物が立ちます。',
        'ko': '다테 마사무네가 잠든 영묘. 삼나무 숲 돌계단 위에 검은 옻칠과 금장식의 화려한 건물이 있어요.',
        'en': 'Date Masamune\'s mausoleum: black lacquer and gold at the top of stone steps among cedars.'},
        ['atagobashi', 'itsutsubashi']),
    'jozenji': ({
        'ja': 'ケヤキ並木の大通り。冬は「光のページェント」で、並木いっぱいに明かりがともります。',
        'ko': '느티나무 가로수 큰길. 겨울에는 「빛의 페이전트」로 가로수 가득 불빛이 켜져요.',
        'en': 'An avenue of zelkova trees, lit from end to end by the Pageant of Starlight in December.'},
        ['kotodai-koen']),
    'matsushima': ({
        'ja': '日本三景のひとつ。260あまりの松の島がうかぶ湾を、遊覧船でめぐれます。',
        'ko': '일본 3경 중 하나. 소나무 섬 260여 개가 떠 있는 만을 유람선으로 돌아볼 수 있어요.',
        'en': 'One of Japan\'s Three Views: some 260 pine-clad islets, best seen from a cruise boat.'},
        ['matsushima-kaigan']),
    'osaki_hachimangu': ({
        'ja': '伊達政宗が建てた国宝の社殿。黒うるしに極彩色の「権現造」で、1月の「どんと祭」で知られます。',
        'ko': '다테 마사무네가 세운 국보 사전. 검은 옻칠에 화려한 색의 건물로, 1월 「돈토사이」로 유명해요.',
        'en': 'Masamune\'s National Treasure shrine in black lacquer and bright colours, home of the January Donto-sai.'},
        ['kita-sendai']),
    'daikannon': ({
        'ja': '高さ100mの白い観音像。泉区の丘の上に立ち、遠くからもよく見えます。',
        'ko': '높이 100m의 하얀 관음상. 이즈미구 언덕 위에 서 있어 멀리서도 잘 보여요.',
        'en': 'A 100 m white statue of Kannon on a hill in Izumi ward, seen from far away.'}, ['kuromatsu', 'asahigaoka']),
    'tanabata': ({
        'ja': '毎年8月6〜8日の七夕まつり。商店街のアーケードを色とりどりの大きな吹き流しがうめつくします。',
        'ko': '매년 8월 6~8일의 다나바타 축제. 상점가 아케이드를 알록달록한 커다란 장식이 가득 채워요.',
        'en': 'The Tanabata festival every 6–8 August: huge paper streamers fill the shopping arcades.'},
        ['sendai', 'hirose-dori']),
    'stadium': ({
        'ja': 'プロ野球・東北楽天ゴールデンイーグルスの本拠地。外野スタンドのうしろに観覧車があります。',
        'ko': '프로야구 도호쿠 라쿠텐 골든이글스의 홈구장. 외야 관중석 뒤에 관람차가 있어요.',
        'en': 'Home of the Tohoku Rakuten Golden Eagles, with a Ferris wheel behind the outfield stands.'},
        ['miyaginohara']),
}

PICKS = {'aoba_castle': (0, 4), 'zuihoden': (0, 4), 'jozenji': (5, 4), 'matsushima': (8, 4),
         'osaki_hachimangu': (1, 4), 'daikannon': (7, 4), 'tanabata': (12, 4), 'stadium': (0, 4)}
