"""Add the Tokyo Metro, Toei and through-service lines to the Tokyo city data.

Reads the station order in tools/data/metro_lines.py and station names /
coordinates cached from Wikidata (CC0) in tools/data/wikidata_tokyo_metro.json,
then rewrites stations.json, lines.json, timetables.json and city.json.
Existing stations (JR / Ginza) keep their ids and coordinates.

Run times are estimated from the distance between stations (approximate,
like the rest of the MVP data).

  python tools/build_metro.py
"""
import json
import math
import os
import re
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CITY = os.path.join(ROOT, 'assets', 'cities', 'tokyo')
sys.path.insert(0, os.path.join(ROOT, 'tools', 'data'))
from metro_lines import LINES, LOOPS  # noqa: E402

wd = [s for f in ('wikidata_tokyo_metro.json', 'wikidata_tokyo_area.json', 'wikidata_narita.json')
      for s in json.load(open(os.path.join(ROOT, 'tools', 'data', f), encoding='utf8'))['stations']]
stations = json.load(open(os.path.join(CITY, 'stations.json'), encoding='utf8'))
lines = json.load(open(os.path.join(CITY, 'lines.json'), encoding='utf8'))
timetables = json.load(open(os.path.join(CITY, 'timetables.json'), encoding='utf8'))
city = json.load(open(os.path.join(CITY, 'city.json'), encoding='utf8'))

# Korean names Wikidata does not have (hangul transcription of the Japanese).
KO_EXTRA = {}
# Fixes where Wikidata's label is not the passenger-facing name.
OVERRIDE = {
    '汐留': {'en': 'Shiodome'},
    '都庁前': {'ko': '도초마에'},
    '羽田空港第1・第2ターミナル': {'en': 'Haneda Airport Terminal 1·2', 'ko': '하네다 공항 제1·제2터미널'},
    '練馬': {'kana': 'ねりま'},
    '空港第2ビル': {'en': 'Airport Terminal 2', 'ko': '공항 제2빌딩'},
    '成田空港': {'en': 'Narita Airport', 'ko': '나리타 공항'},
    '千葉ニュータウン中央': {'en': 'Chiba New Town Chuo'},
}

META = {
    # id: (ja, ko, en, colour)
    'marunouchi': ('丸ノ内線', '마루노우치선', 'Marunouchi Line', '#F62E36'),
    'marunouchi_branch': ('丸ノ内線（方南町支線）', '마루노우치선 (호난초 지선)', 'Marunouchi Line (Honancho branch)', '#F62E36'),
    'hibiya': ('日比谷線', '히비야선', 'Hibiya Line', '#B5B5AC'),
    'tozai': ('東西線', '도자이선', 'Tozai Line', '#009BBF'),
    'chiyoda': ('千代田線', '지요다선', 'Chiyoda Line', '#00BB85'),
    'yurakucho': ('有楽町線', '유라쿠초선', 'Yurakucho Line', '#C1A470'),
    'hanzomon': ('半蔵門線', '한조몬선', 'Hanzomon Line', '#8F76D6'),
    'namboku': ('南北線', '난보쿠선', 'Namboku Line', '#00AC9B'),
    'fukutoshin': ('副都心線', '후쿠토신선', 'Fukutoshin Line', '#9C5E31'),
    'toei_asakusa': ('都営浅草線', '도에이 아사쿠사선', 'Toei Asakusa Line', '#E85298'),
    'toei_mita': ('都営三田線', '도에이 미타선', 'Toei Mita Line', '#0079C2'),
    'toei_shinjuku': ('都営新宿線', '도에이 신주쿠선', 'Toei Shinjuku Line', '#6CBB5A'),
    'toei_oedo': ('都営大江戸線', '도에이 오에도선', 'Toei Oedo Line', '#CE045B'),
    'toei_oedo_branch': ('都営大江戸線（光が丘方面）', '도에이 오에도선 (히카리가오카 방면)', 'Toei Oedo Line (Hikarigaoka)', '#CE045B'),
    'keikyu': ('京急線（羽田空港方面）', '게이큐선 (하네다 공항 방면)', 'Keikyu Line (Haneda Airport)', '#E5171F'),
    'keisei': ('京成線（押上〜江戸川）', '게이세이선 (오시아게~에도가와)', 'Keisei Line (Oshiage–Edogawa)', '#1E50A2'),
    'tokyu_meguro': ('東急目黒線', '도큐 메구로선', 'Tokyu Meguro Line', '#00A0DE'),
    'keio': ('京王線', '게이오선', 'Keio Line', '#DD0077'),
    'skyliner': ('京成スカイライナー', '게이세이 스카이라이너', 'Keisei Skyliner', '#22356B'),
    'access_express': ('アクセス特急（成田スカイアクセス線）', '액세스 특급 (나리타 스카이 액세스선)', 'Access Express (Narita Sky Access)', '#F08300'),
    'narita_express': ('成田エクスプレス', '나리타 익스프레스', "Narita Express (N'EX)", '#B8102C'),
}
# Average speed between stops (m/s) for the airport expresses.
SPEED = {'skyliner': 25.0, 'access_express': 17.0, 'narita_express': 18.0}
# Railways that are mostly above ground (the rest are subways).
SURFACE = {'keikyu', 'keisei', 'tokyu_meguro', 'keio', 'skyliner', 'access_express', 'narita_express'}
# Underground stations on the surface railways.
UNDER = {
    'keikyu': {'泉岳寺', '大鳥居', '天空橋', '羽田空港第3ターミナル', '羽田空港第1・第2ターミナル'},
    'keisei': {'押上'},
    'tokyu_meguro': {'目黒', '武蔵小山', '西小山'},
    'keio': {'新宿', '初台', '幡ヶ谷', '国領', '布田', '調布'},
    'skyliner': {'京成上野', '空港第2ビル', '成田空港'},
    'access_express': {'押上', '空港第2ビル', '成田空港'},
    'narita_express': {'品川', '東京', '空港第2ビル', '成田空港'},
}
# Above ground on these lines (GPS works there).
ABOVE = {
    'tozai': {'西葛西', '葛西', '浦安', '南行徳', '行徳', '妙典', '原木中山', '西船橋', '南砂町'},
    'hibiya': {'中目黒', '南千住', '北千住'},
    'marunouchi': {'四ツ谷', '後楽園', '茗荷谷', '御茶ノ水'},
    'chiyoda': {'綾瀬', '北綾瀬'},
    'toei_mita': {'志村三丁目', '蓮根', '西台', '高島平', '新高島平', '西高島平'},
    'toei_shinjuku': {'東大島', '船堀'},
    'yurakucho': {'和光市'},
    'fukutoshin': {'和光市'},
}
# Typical trains per hour pattern (minutes between trains).
HEADWAY = {
    'marunouchi': (4, 2, 4, 3, 5), 'marunouchi_branch': (10, 6, 10, 8, 12), 'hibiya': (5, 3, 5, 4, 6),
    'tozai': (5, 3, 5, 4, 7), 'chiyoda': (5, 3, 5, 4, 6), 'yurakucho': (6, 4, 6, 5, 8),
    'hanzomon': (5, 3, 5, 4, 7), 'namboku': (6, 4, 6, 5, 8), 'fukutoshin': (6, 4, 6, 5, 8),
    'toei_asakusa': (5, 3, 5, 4, 7), 'toei_mita': (6, 3, 6, 4, 8), 'toei_shinjuku': (6, 3, 6, 4, 8),
    'toei_oedo': (5, 3, 5, 4, 7), 'toei_oedo_branch': (6, 4, 6, 5, 8), 'keikyu': (8, 4, 6, 5, 10),
    'keisei': (8, 4, 8, 6, 10), 'tokyu_meguro': (6, 3, 6, 4, 8), 'keio': (5, 2, 4, 3, 6),
    'skyliner': (40, 20, 20, 20, 40), 'access_express': (40, 40, 40, 40, 40), 'narita_express': (30, 30, 30, 30, 60),
}


def norm(ja):
    ja = ja.replace('ヶ', 'ケ')
    ja = re.sub(r'\s*\(.*\)$', '', ja)
    return ja[:-1] if ja.endswith('駅') else ja


def slug(en):
    s = unicodedata.normalize('NFKD', en).encode('ascii', 'ignore').decode()
    s = re.sub(r'\s+Station$', '', s, flags=re.I)
    return 'tokyo.' + re.sub(r'[^a-z0-9]+', '_', s.lower()).strip('_')


by_ja = {}
for s in wd:
    by_ja.setdefault(norm(s['ja']), []).append(s)
existing = {norm(s['name']['ja']): s for s in stations}


def km(a, b):
    dy = (a['lat'] - b['lat']) * 111.0
    dx = (a['lng'] - b['lng']) * 91.0
    return math.hypot(dx, dy)


def info(ja, near=None):
    """Station record for a Japanese name: existing one, or a new one from
    Wikidata. When several places share the name, the one nearest [near]
    (the previous station on the line) wins."""
    key = norm(ja)
    if key in existing:
        return existing[key]
    cands = by_ja.get(key)
    if not cands:
        raise SystemExit(f'no data for {ja}')
    if near is not None:
        best = min(cands, key=lambda c: km(c, near))
        cands = [c for c in cands if km(c, best) < 1.5]
    lat = sum(c['lat'] for c in cands) / len(cands)
    lng = sum(c['lng'] for c in cands) / len(cands)
    pick = lambda k: next((c[k] for c in cands if c.get(k)), None)  # noqa: E731
    en = re.sub(r'\s+Station$', '', pick('en') or ja)
    en = re.sub(r'\s*\(.*\)$', '', en)
    # Plain letters like the existing names (Otemachi, not Ōtemachi).
    en = unicodedata.normalize('NFKD', en).encode('ascii', 'ignore').decode().strip()
    ko = pick('ko') or KO_EXTRA.get(ja)
    if not ko:
        raise SystemExit(f'no Korean name for {ja} ({en})')
    ko = re.sub(r'\s*\(.*\)$', '', ko)
    ko = (ko[:-1] if ko.endswith('역') else ko).strip()
    kana = pick('kana') or ''
    kana = kana[:-2] if kana.endswith('えき') else kana
    fix = OVERRIDE.get(ja, {})
    en, ko, kana = fix.get('en', en), fix.get('ko', ko), fix.get('kana', kana)
    rec = {
        'id': slug(en.replace('·', '')), 'name': {'ja': ja, 'ko': ko, 'en': en}, 'kana': kana,
        'geo': {'lat': round(lat, 5), 'lng': round(lng, 5)}, 'lines': [], 'underground': [],
    }
    stations.append(rec)
    existing[key] = rec
    return rec


metro_ids = []
for key, names in LINES.items():
    lid = f'tokyo.{key}'
    metro_ids.append(lid)
    recs = []
    for n in names:
        recs.append(info(n, near=recs[-1]['geo'] if recs else None))
    for n, r in zip(names, recs):
        if lid not in r['lines']:
            r['lines'].append(lid)
        under = n in UNDER.get(key, set()) if key in SURFACE else n not in ABOVE.get(key, set())
        if under and lid not in r['underground']:
            r['underground'].append(lid)
    loop = key in LOOPS
    pairs = list(zip(recs, recs[1:])) + ([(recs[-1], recs[0])] if loop else [])
    # ~32 km/h average between stops incl. acceleration (faster on the
    # surface railways' longer gaps), at least a minute.
    speed = SPEED.get(key, 14.0 if key in SURFACE else 11.5)
    run = [max(60, round((30 + km(a['geo'], b['geo']) * 1000 / speed) / 5) * 5) for a, b in pairs]
    ja, ko, en, colour = META[key]
    first, last = recs[0]['name'], recs[-1]['name']
    line = {
        'id': lid, 'name': {'ja': ja, 'ko': ko, 'en': en}, 'color': colour, 'loop': loop, 'dwellSec': 25,
        'directions': {
            'forward': {'ja': f"{last['ja']}方面", 'ko': f"{last['ko']} 방면", 'en': f"for {last['en']}"},
            'reverse': {'ja': f"{first['ja']}方面", 'ko': f"{first['ko']} 방면", 'en': f"for {first['en']}"},
        } if not loop else {
            # Round the loop from Tochomae: via Iidabashi / Ryogoku, or via Roppongi.
            'forward': {'ja': f"{recs[6]['name']['ja']}・{recs[12]['name']['ja']}方面",
                        'ko': f"{recs[6]['name']['ko']}·{recs[12]['name']['ko']} 방면",
                        'en': f"via {recs[6]['name']['en']} / {recs[12]['name']['en']}"},
            'reverse': {'ja': f"{recs[23]['name']['ja']}・{recs[20]['name']['ja']}方面",
                        'ko': f"{recs[23]['name']['ko']}·{recs[20]['name']['ko']} 방면",
                        'en': f"via {recs[23]['name']['en']} / {recs[20]['name']['en']}"},
        },
        'stations': [r['id'] for r in recs], 'runSec': run,
    }
    lines = [l for l in lines if l['id'] != lid] + [line]
    early, rush, day, evening, night = HEADWAY[key]
    timetables[lid] = {
        'firstTrain': '05:00', 'lastTrain': '24:20',
        'weekday': [
            {'from': '05:00', 'to': '07:00', 'everyMin': early}, {'from': '07:00', 'to': '09:30', 'everyMin': rush},
            {'from': '09:30', 'to': '17:00', 'everyMin': day}, {'from': '17:00', 'to': '20:00', 'everyMin': evening},
            {'from': '20:00', 'to': '25:00', 'everyMin': night},
        ],
        'holiday': [
            {'from': '05:00', 'to': '09:00', 'everyMin': early}, {'from': '09:00', 'to': '21:00', 'everyMin': day},
            {'from': '21:00', 'to': '25:00', 'everyMin': night},
        ],
    }

ids = [s['id'] for s in stations]
dup = {i for i in ids if ids.count(i) > 1}
assert not dup, dup
order = ['tokyo.yamanote', 'tokyo.ginza'] + metro_ids
lines.sort(key=lambda l: order.index(l['id']))
city['lines'] = order
city['dataNote'] = ('Station coordinates and names: Wikidata (CC0). Run times and headways are approximate '
                    'estimates for the MVP. Replace with licensed timetable data later.')

dump = lambda obj, name: json.dump(obj, open(os.path.join(CITY, name), 'w', encoding='utf8'), ensure_ascii=False, indent=1)  # noqa: E731
dump(stations, 'stations.json')
dump(lines, 'lines.json')
dump(timetables, 'timetables.json')
dump(city, 'city.json')
print(len(stations), 'stations,', len(lines), 'lines')
