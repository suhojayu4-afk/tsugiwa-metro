"""Osaka landmarks: where they stand on the map, their names and notes, and
the PixelLab candidate picked for each (docs/art/gen/osaka/lm_<name>/c<N>.png,
made with create_image_pro 64x64 and the same style image as the Tottori
landmarks: docs/art/gen/landmarks_raw/hachimangu.png).

Tsutenkaku and Abeno Harukas are moved a few hundred metres (by eye) off the
lines drawn next to them.

LANDMARKS: (file, lat, lng, name, unit)  unit: map units per art pixel (0 = the usual size)
ABOUT: file -> (note, station slugs to go from)
PICKS: file -> (candidate, side thickness in px)
"""

LANDMARKS = [
    ('osaka_castle', 34.6873, 135.5259, {'ja': '大阪城', 'ko': '오사카성', 'en': 'Osaka Castle'}, 0),
    ('tsutenkaku', 34.6530, 135.5110, {'ja': '通天閣・新世界', 'ko': '쓰텐카쿠·신세카이', 'en': 'Tsutenkaku & Shinsekai'}, 0),
    ('dotonbori', 34.6687, 135.5013, {'ja': '道頓堀', 'ko': '도톤보리', 'en': 'Dotonbori'}, 0),
    ('umeda_sky', 34.7053, 135.4906, {'ja': '梅田スカイビル', 'ko': '우메다 스카이 빌딩', 'en': 'Umeda Sky Building'}, 0),
    ('usj', 34.6654, 135.4323, {'ja': 'ユニバーサル・スタジオ・ジャパン', 'ko': '유니버설 스튜디오 재팬', 'en': 'Universal Studios Japan'}, 0),
    ('kaiyukan', 34.6545, 135.4290, {'ja': '海遊館・天保山', 'ko': '가이유칸·덴포잔', 'en': 'Kaiyukan & Tempozan'}, 0),
    ('abeno_harukas', 34.6470, 135.5193, {'ja': 'あべのハルカス', 'ko': '아베노 하루카스', 'en': 'Abeno Harukas'}, 0),
    ('sumiyoshi', 34.6125, 135.4930, {'ja': '住吉大社', 'ko': '스미요시 다이샤', 'en': 'Sumiyoshi Taisha'}, 0),
]

ABOUT = {
    'osaka_castle': ({
        'ja': '豊臣秀吉が建てた城。いまの天守閣は1931年に建て直されたもので、まわりの公園は春の桜の名所です。',
        'ko': '도요토미 히데요시가 세운 성. 지금의 천수각은 1931년에 다시 지은 것으로, 주변 공원은 봄 벚꽃 명소예요.',
        'en': 'The castle of Toyotomi Hideyoshi. Today\'s keep was rebuilt in 1931; the park round it is a famous '
              'cherry-blossom spot.'}, ['tanimachi-4-chome', 'osakajokoen', 'morinomiya']),
    'tsutenkaku': ({
        'ja': '新世界の真ん中に立つ展望塔。足の裏をなでると幸せになる「ビリケンさん」と、串カツのお店が名物です。',
        'ko': '신세카이 한가운데 선 전망탑. 발바닥을 쓰다듬으면 행운이 온다는 「빌리켄」과 꼬치튀김 가게가 명물이에요.',
        'en': 'The tower in the middle of Shinsekai, home of the lucky Billiken and the kushikatsu stalls.'},
        ['ebisucho', 'dobutsuen-mae', 'shin-imamiya']),
    'dotonbori': ({
        'ja': '大きなカニや走る人の看板がならぶ川ぞいの繁華街。たこ焼きやお好み焼きの食べ歩きが楽しい街です。',
        'ko': '커다란 게와 달리는 사람 간판이 늘어선 강변 번화가. 다코야키와 오코노미야키를 먹으며 걷기 좋아요.',
        'en': 'The canal-side nightlife street of giant crab and running-man signs, takoyaki and okonomiyaki.'},
        ['namba', 'nippombashi']),
    'umeda_sky': ({
        'ja': '2つの高層ビルを空中でつないだビル。屋上の「空中庭園展望台」から大阪の街と夕日が見わたせます。',
        'ko': '두 고층 빌딩을 공중에서 이은 건물. 옥상 「공중정원 전망대」에서 오사카 시내와 노을이 보여요.',
        'en': 'Twin towers joined at the top by the Floating Garden Observatory, with views over Osaka at sunset.'},
        ['umeda', 'osaka', 'nishi-umeda']),
    'usj': ({
        'ja': '映画の世界を楽しめる大きなテーマパーク。JRゆめ咲線のユニバーサルシティ駅のすぐ前です。',
        'ko': '영화 속 세계를 즐기는 커다란 테마파크. JR 유메사키선 유니버설시티역 바로 앞이에요.',
        'en': 'The big movie theme park, right in front of Universal City station on the JR Yumesaki Line.'},
        ['universal-city']),
    'kaiyukan': ({
        'ja': '世界最大級の水族館。ジンベエザメが泳ぐ大水槽と、となりの天保山の大観覧車が人気です。',
        'ko': '세계 최대급 수족관. 고래상어가 헤엄치는 큰 수조와 옆 덴포잔 대관람차가 인기예요.',
        'en': 'One of the world\'s largest aquariums, with whale sharks, next to the Tempozan Ferris wheel.'},
        ['osakako']),
    'abeno_harukas': ({
        'ja': '高さ300mの超高層ビル。60階の展望台「ハルカス300」からは晴れた日に明石海峡大橋まで見えます。',
        'ko': '높이 300m의 초고층 빌딩. 60층 전망대 「하루카스 300」에서는 맑은 날 아카시 해협 대교까지 보여요.',
        'en': 'A 300 m skyscraper; on a clear day the Harukas 300 deck sees as far as the Akashi Kaikyo Bridge.'},
        ['tennoji', 'abeno']),
    'sumiyoshi': ({
        'ja': '全国の住吉神社の総本社。急な反り橋「太鼓橋」と、古い形の本殿「住吉造」で知られます。',
        'ko': '전국 스미요시 신사의 총본사. 가파르게 휜 다리 「다이코바시」와 옛 양식의 본전으로 유명해요.',
        'en': 'Head shrine of all Sumiyoshi shrines, known for its steep arched Taikobashi bridge.'}, ['tamade']),
}

PICKS = {'osaka_castle': (8, 4), 'tsutenkaku': (4, 4), 'dotonbori': (7, 4), 'umeda_sky': (7, 4), 'usj': (7, 4),
         'kaiyukan': (7, 4), 'abeno_harukas': (12, 4), 'sumiyoshi': (9, 4)}
