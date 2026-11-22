"""つぎはさん's guide for Tottori–Yonago: landmark notes, sightseeing
courses, exits of the big stations, station hints and the attendant's
general tips (the Tokyo pool without what only fits Tokyo, plus San'in
ones).

  python -X utf8 tools/tottori/make_guide.py  ->  assets/cities/tottori/*.json
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
CITY = os.path.join(ROOT, 'assets', 'cities', 'tottori')
TOKYO = os.path.join(ROOT, 'assets', 'cities', 'tokyo')

sys.path.insert(0, HERE)
import guide_more as more  # noqa: E402

st = {s['name']['ja']: s['id'] for s in json.load(open(os.path.join(CITY, 'stations.json'), encoding='utf8'))}


def t(ja, ko, en):
    return {'ja': ja, 'ko': ko, 'en': en}


def dump(name, obj):
    json.dump(obj, open(os.path.join(CITY, name), 'w', encoding='utf8'), ensure_ascii=False, indent=1)


# ---------------------------------------------------------------- landmarks
LANDMARKS = {
    'daisen_big': (t('中国地方でいちばん高い山（1,729m）。西から見ると富士山のような形で「伯耆富士」とよばれます。',
                     '주고쿠 지방에서 가장 높은 산(1,729m). 서쪽에서 보면 후지산을 닮아 「호키 후지」라고 불려요.',
                     'The highest peak in the Chugoku region (1,729 m). From the west it looks like Mt. Fuji: "Hoki-Fuji".'),
                   ['伯耆大山', '大山口', '米子']),
    'sakyu': (t('東西およそ16kmの大きな砂丘。風がつくる砂の模様「風紋」や、らくだに乗る体験もあります。',
                '동서로 약 16km 이어진 커다란 사구. 바람이 만드는 모래 무늬 「풍문」과 낙타 타기 체험도 있어요.',
                'Dunes stretching about 16 km along the coast, with wind ripples in the sand and camel rides.'),
              ['鳥取']),
    'jinpukaku': (t('1907年に建てられた白い洋館。鳥取城跡の石垣のふもとに建ち、国の重要文化財です。',
                    '1907년에 지어진 하얀 서양식 저택. 돗토리성 터의 돌담 아래에 있고 국가 중요문화재예요.',
                    'A white Western-style mansion of 1907 below the stone walls of Tottori Castle, an Important Cultural Property.'),
                  ['鳥取']),
    'hakuto': (t('神話「因幡の白うさぎ」の舞台。海岸のそばに白兎神社があります。',
                 '신화 「이나바의 흰 토끼」의 무대. 해안 가까이에 하쿠토 신사가 있어요.',
                 'The setting of the myth of the White Hare of Inaba, with Hakuto Shrine by the shore.'),
               ['末恒', '鳥取大学前']),
    'uradome': (t('白い岩の小島と松が、エメラルド色の海にうかぶ海岸。遊覧船で洞門めぐりもできます。',
                  '하얀 바위섬과 소나무가 에메랄드빛 바다에 떠 있는 해안. 유람선으로 동굴문을 돌아볼 수도 있어요.',
                  'Pale rock islets topped with pines in an emerald sea; sightseeing boats go round the sea caves.'),
                ['岩美']),
    'kurayoshi': (t('白い漆喰の壁と赤い石州瓦の土蔵が、玉川沿いに並ぶ町なみ。駅からバスで約15分。',
                    '하얀 회벽과 붉은 세키슈 기와의 창고가 다마가와 강을 따라 늘어선 거리. 역에서 버스로 약 15분.',
                    'White plaster storehouses with red-brown roofs along the Tamagawa canal, 15 minutes by bus from the station.'),
                  ['倉吉']),
    'nageiredo': (t('断崖のくぼみに建つお堂。どうやって建てたのか今もなぞで、「日本一危ない国宝」ともよばれます。',
                    '절벽의 움푹한 곳에 지어진 법당. 어떻게 지었는지 지금도 수수께끼라 「일본에서 가장 위험한 국보」라고도 불려요.',
                    'A temple hall built into a hollow of a sheer cliff; nobody knows how. Called the most dangerous National Treasure.'),
                  ['倉吉']),
    'sakaiminato': (t('松葉がにやマグロで知られる漁港の町。境線の駅には妖怪の愛称がついています。',
                      '대게와 참치로 유명한 항구 도시. 사카이선 역에는 요괴 애칭이 붙어 있어요.',
                      'A fishing port known for snow crab and tuna. The Sakai Line stations have yokai nicknames.'),
                    ['境港']),
}
LANDMARKS.update(more.LANDMARKS)
dump('landmarks.json', {k: {'about': a, 'stations': [st[n] for n in s]} for k, (a, s) in LANDMARKS.items()})

# ---------------------------------------------------------------- courses
COURSES = [
    ('coast', t('鳥取砂丘と山陰海岸 1日', '돗토리 사구와 산인 해안 하루', 'Sand Dunes & San\'in Coast, a day'), '1d',
     t('砂丘を歩いて、白兎海岸の神話にふれ、浦富海岸のエメラルドの海へ。',
       '사구를 걷고, 하쿠토 해안의 신화를 만나고, 우라도메 해안의 에메랄드빛 바다로.',
       'Walk the dunes, visit the coast of the White Hare myth, then the emerald sea of Uradome.'),
     [('鳥取', 'sakyu'), ('末恒', 'hakuto'), ('岩美', 'uradome')]),
    ('yonago', t('米子・境港 みなとさんぽ', '요나고·사카이미나토 항구 산책', 'Yonago & Sakaiminato harbour walk'), '4h',
     t('米子から境線でのんびり。港の町で海の幸、帰りは大山をながめて。',
       '요나고에서 사카이선으로 느긋하게. 항구 마을에서 해산물을 먹고, 돌아오는 길엔 다이센을 바라보며.',
       'An easy ride on the Sakai Line to the port for seafood, with Mt. Daisen on the way back.'),
     [('米子', 'daisen_big'), ('境港', 'sakaiminato')]),
    ('kurayoshi', t('倉吉 白壁と三徳山', '구라요시 시라카베와 미토쿠산', 'Kurayoshi storehouses & Mt. Mitoku'), '1d',
     t('白壁土蔵の町なみを歩いて、三徳山の投入堂をながめに。三朝温泉で一泊も。',
       '시라카베 창고 거리를 걷고 미토쿠산의 나게이레도를 보러. 미사사 온천에서 하룻밤도 좋아요.',
       'Stroll the white-walled storehouses, then see the Nageiredo of Mt. Mitoku. Stay at Misasa Onsen if you like.'),
     [('倉吉', 'kurayoshi'), ('倉吉', 'nageiredo')]),
    ('tottori_town', t('鳥取のまち 半日', '돗토리 시내 반나절', 'Tottori town, half a day'), '3h',
     t('鳥取城跡と仁風閣から、バスで砂丘へ。夕日の砂丘は特にきれい。',
       '돗토리성 터와 진푸카쿠에서 버스로 사구까지. 노을 지는 사구는 특히 아름다워요.',
       'From the castle ruins and Jinpukaku, then the bus to the dunes. Sunset on the dunes is lovely.'),
     [('鳥取', 'jinpukaku'), ('鳥取', 'sakyu')]),
]
COURSES += more.COURSES
dump('courses.json', [
    {'id': cid, 'name': name, 'time': time, 'about': about,
     'stops': [{'station': st[s], 'landmark': lm} for s, lm in stops]}
    for cid, name, time, about, stops in COURSES])

# ---------------------------------------------------------------- exits
EXITS = {
    '鳥取': [(t('北口', '북쪽 출구', 'North Exit'), t('砂丘ゆきバス・鳥取城跡・県庁', '사구행 버스·돗토리성 터·현청',
                                                   'Buses to the dunes, Tottori Castle ruins, prefectural office'),
              ['sakyu', 'jinpukaku']),
             (t('南口', '남쪽 출구', 'South Exit'), t('ホテル・住宅街', '호텔·주택가', 'Hotels, homes'), [])],
    '米子': [(t('東口（表口）', '동쪽 출구', 'East Exit'), t('米子の中心街・皆生温泉ゆきバス', '요나고 중심가·가이케 온천행 버스',
                                                     'Yonago town centre, buses to Kaike Onsen'), ['daisen_big']),
             (t('境線ホーム', '사카이선 승강장', 'Sakai Line platform'), t('0番のりば。境港ゆき', '0번 승강장. 사카이미나토행',
                                                                'Platform 0, for Sakaiminato'), ['sakaiminato'])],
    '倉吉': [(t('北口', '북쪽 출구', 'North Exit'), t('白壁土蔵群・三朝温泉ゆきバス', '시라카베 창고군·미사사 온천행 버스',
                                                   'Buses to the storehouses and Misasa Onsen'),
              ['kurayoshi', 'nageiredo'])],
    '境港': [(t('駅前', '역 앞', 'Station square'), t('港・水産物直売センター・美保関へのバス',
                                                   '항구·수산물 직판 센터·미호노세키행 버스',
                                                   'The port, the fish market, buses to Mihonoseki'), ['sakaiminato'])],
    '岩美': [(t('駅前', '역 앞', 'Station square'), t('浦富海岸ゆきバス', '우라도메 해안행 버스',
                                                   'Buses to the Uradome Coast'), ['uradome'])],
}
EXITS.update(more.EXITS)
for (name, i), lms in more.ADD_EXIT_LANDMARKS.items():
    EXITS[name][i][2].extend(lms)
dump('exits.json', {st[n]: [{'name': a, 'near': b, 'landmarks': c} for a, b, c in v] for n, v in EXITS.items()})

# ---------------------------------------------------------------- station hints
TIPS = {
    '鳥取': [t('砂丘へは北口からバスで約20分', '사구는 북쪽 출구에서 버스로 약 20분이에요', 'The dunes: about 20 min by bus from the North Exit'),
             t('京都・大阪へは特急スーパーはくと', '교토·오사카는 특급 슈퍼 하쿠토로', 'For Kyoto and Osaka, take the Super Hakuto')],
    '米子': [t('境線は 0番のりばから出ます', '사카이선은 0번 승강장에서 출발해요', 'Sakai Line trains leave from platform 0'),
             t('岡山へは特急やくも', '오카야마는 특급 야쿠모로', 'For Okayama, take the limited express Yakumo')],
    '境港': [t('駅から港まで歩いてすぐ', '역에서 항구까지 걸어서 금방이에요', 'The harbour is a short walk from the station')],
    '倉吉': [t('白壁土蔵群へは北口からバス', '시라카베 창고군은 북쪽 출구에서 버스로', 'Buses to the old storehouses leave from the North Exit')],
    '恋山形': [t('駅じゅうがピンク色の「恋がかなう駅」', '역 전체가 분홍색인 「사랑이 이루어지는 역」', 'The all-pink "station where love comes true"')],
    '若桜': [t('昔ながらの駅舎と 転車台が残っています', '옛날 그대로의 역사와 전차대가 남아 있어요', 'The old station building and turntable still stand')],
    '米子空港': [t('空港ターミナルまで歩いてすぐ', '공항 터미널까지 걸어서 금방이에요', 'A short walk to the airport terminal')],
    '伯耆大山': [t('伯備線と山陰本線が分かれる駅', '하쿠비선과 산인 본선이 갈라지는 역', 'Where the Hakubi Line leaves the San\'in Line')],
}
for name, extra in more.TIPS.items():
    TIPS.setdefault(name, []).extend(extra)
dump('tips.json', {st[n]: v for n, v in TIPS.items()})

# ---------------------------------------------------------------- attendant tips
DROP = ['東京', '山手', 'メトロ', '都営', 'Suica', 'PASMO', '関東', '直通', '地下鉄', '地下通路', '銀座', '新宿', '丸ノ内',
        '大江戸', 'ゆりかもめ', '上野', '目黒', '鎌倉', '渋谷', '高尾', '日光', '明治神宮', '浅草', '神宮外苑', '富士山',
        'ラッシュ', '混み', '混雑', '混んで', '満員', '女性専用', '快速', '各駅停車', '駅ナンバリング', '始発駅から',
        '出口は たくさん', '路線の色', 'ホームの端', '同じ名前でも', '向かい側', '弱冷房', '終夜運転', '季節ごとに飾り',
        '乗換便利号車', 'すぐ来ます', '1本待つ', '地上を走る', '通勤電車では', '高架', 'ホームドアのない']
pool = [x for x in json.load(open(os.path.join(TOKYO, 'attendant_tips.json'), encoding='utf8'))
        if x.get('need') != 'through' and not any(w in x['ja'] for w in DROP)]


def tip(c, k, ja, ko, en, **kw):
    return dict(c=c, k=k, ja=ja, ko=ko, en=en, **kw)


pool += [
    tip('howto', 'help', 'ワンマン列車は うしろのドアから乗って 整理券をとることがあります',
        '원맨 열차는 뒷문으로 타서 정리권을 뽑는 경우가 있어요', 'On one-man trains you may board at the back and take a numbered ticket'),
    tip('howto', 'help', '無人駅でおりるときは 運転士さんの横で運賃を払います',
        '무인역에서 내릴 때는 기관사 옆에서 요금을 내요', 'At unstaffed stations, pay your fare by the driver as you get off'),
    tip('howto', 'help', 'ドアは ボタンを押して開ける車両があります',
        '버튼을 눌러 문을 여는 차량이 있어요', 'On some trains you press a button to open the door'),
    tip('howto', 'help', '本数が少ない路線です。帰りの時刻は先に確認してね',
        '운행 편수가 적은 노선이에요. 돌아오는 시각은 미리 확인하세요', 'Trains are few here. Check your return time first'),
    tip('howto', 'help', '1本のがすと 1時間待つことも。時間に余裕をもって',
        '한 대를 놓치면 1시간을 기다릴 수도 있어요. 여유 있게', 'Miss one and the next may be an hour away. Leave time to spare'),
    tip('howto', 'help', '特急は 乗車券のほかに特急券が必要です',
        '특급은 승차권 외에 특급권이 필요해요', 'Limited expresses need a limited express ticket too'),
    tip('trivia', 'fun', '鳥取県は 日本でいちばん人口が少ない県です',
        '돗토리현은 일본에서 인구가 가장 적은 현이에요', 'Tottori is the least populated prefecture in Japan'),
    tip('trivia', 'fun', '山陰本線は 日本でいちばん長い在来線です',
        '산인 본선은 일본에서 가장 긴 재래선이에요', 'The San\'in Main Line is the longest conventional line in Japan'),
    tip('trivia', 'fun', '大山は 中国地方でいちばん高い山。「伯耆富士」ともよばれます',
        '다이센은 주고쿠 지방에서 가장 높은 산. 「호키 후지」라고도 불려요', 'Mt. Daisen is the highest in Chugoku, "Hoki-Fuji"'),
    tip('trivia', 'fun', '境線の駅には 妖怪の愛称がついています',
        '사카이선 역에는 요괴 애칭이 붙어 있어요', 'Every Sakai Line station has a yokai nickname'),
    tip('trivia', 'fun', '恋山形駅は 駅じゅうがピンク色です',
        '고이야마가타역은 역 전체가 분홍색이에요', 'Koi-Yamagata station is pink all over'),
    tip('trivia', 'fun', '若桜鉄道の駅舎や鉄橋は 登録有形文化財です',
        '와카사 철도의 역사와 철교는 등록 유형문화재예요', 'Wakasa Railway\'s stations and bridges are registered cultural properties'),
    tip('trivia', 'fun', '鳥取砂丘は 東西およそ16km。歩くと足がしずみます',
        '돗토리 사구는 동서로 약 16km. 걸으면 발이 푹푹 빠져요', 'The Tottori Dunes run about 16 km. Your feet sink as you walk'),
    tip('trivia', 'fun', '米子は「山陰の商都」とよばれる商いの町です',
        '요나고는 「산인의 상업 도시」라고 불리는 장사의 도시예요', 'Yonago is known as the merchant town of San\'in'),
    tip('trivia', 'fun', '二十世紀梨は 鳥取の名産。夏の終わりが食べごろ',
        '니짓세이키 배는 돗토리의 명산물. 늦여름이 제철이에요', 'Nijisseiki pears are Tottori\'s pride, best at the end of summer'),
    tip('season', 'fun', '冬は松葉がにの季節。境港があつくなります', '겨울은 대게의 계절. 사카이미나토가 북적여요',
        'Winter is snow crab season. Sakaiminato comes alive', m=[11, 12, 1, 2, 3]),
    tip('season', 'warn', '冬の山陰は 雪や強い風で 列車が遅れることがあります',
        '겨울 산인은 눈이나 강풍으로 열차가 늦어질 수 있어요', 'In winter, snow and strong winds can delay trains in San\'in',
        m=[12, 1, 2]),
    tip('season', 'fun', '大山の紅葉が見ごろの季節です', '다이센 단풍이 한창인 계절이에요',
        'The autumn leaves on Mt. Daisen are at their best', m=[10, 11]),
    tip('season', 'fun', '夏の砂丘は 砂がとても熱くなります。くつで歩いてね',
        '여름 사구는 모래가 아주 뜨거워요. 신발을 신고 걸어요', 'The dune sand gets very hot in summer. Keep your shoes on', m=[7, 8]),
    tip('weather', 'fun', '晴れた日は 車窓から大山がきれいに見えます', '맑은 날에는 차창으로 다이센이 잘 보여요',
        'On clear days Mt. Daisen shows beautifully from the window'),
    tip('weather', 'fun', '晴れた夕方は 日本海に沈む夕日がきれいです', '맑은 저녁에는 동해로 지는 노을이 아름다워요',
        'On a clear evening the sun sets beautifully over the Sea of Japan', h=[16, 19]),
]
pool += more.POOL
dump('attendant_tips.json', pool)
print(len(LANDMARKS), 'landmarks,', len(COURSES), 'courses,', len(EXITS), 'exits,', len(TIPS), 'station hints,',
      len(pool), 'attendant tips')
