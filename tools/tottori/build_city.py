"""Build the Tottori–Yonago city data (assets/cities/tottori: city.json,
stations.json, lines.json, timetables.json, walks.json, through.json)
from tools/tottori/lines.py and the OpenStreetMap station nodes.

  python -X utf8 tools/tottori/build_city.py

Data (c) OpenStreetMap contributors (ODbL). Run times and headways are
estimates.
"""
import json
import math
import os
import re
import sys
import unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
from kana import hangul, romaji  # noqa: E402
from lines import EN_FIX, FIRST_LAST, HEADWAY, KANA, KO_FIX, LINES  # noqa: E402

CITY = os.path.join(ROOT, 'assets', 'cities', 'tottori')
OSM = os.path.join(ROOT, 'tools', 'data', 'osm_tottori')


def km(a, b):
    return math.hypot((a[0] - b[0]) * 111.0, (a[1] - b[1]) * 91.0)


nodes = {}
for e in json.load(open(os.path.join(OSM, 'stations.json'), encoding='utf8'))['elements']:
    t = e.get('tags', {})
    if 'name' in t:
        nodes.setdefault(t['name'], []).append(e)

# Stations shared by lines (鳥取, 米子 ...) are one station.
names = []
for l in LINES:
    for n in l['stations']:
        if n not in names:
            names.append(n)


def pick(name):
    c = nodes.get(name)
    assert c, f'no OSM station {name}'
    # The prefecture's own (there is a 河原 and a 中山口 elsewhere, too).
    c.sort(key=lambda e: km((e['lat'], e['lon']), (35.45, 133.8)))
    return c[0]


def clean_en(en):
    en = re.sub(r'\s+Station$', '', en, flags=re.I)
    en = re.sub(r'\s*[(（].*[)）]$', '', en)
    return unicodedata.normalize('NFKD', en).encode('ascii', 'ignore').decode().strip()


stations, ids = [], {}
for n in names:
    e = pick(n)
    t = e['tags']
    kana = KANA[n]
    en = EN_FIX.get(n) or clean_en(t.get('name:en', '')) or romaji(kana)
    ko = KO_FIX.get(n) or re.sub(r'역$', '', t.get('name:ko', '')).strip() or hangul(kana)
    sid = 'tottori.' + re.sub(r'[^a-z0-9]+', '_', en.lower()).strip('_')
    assert sid not in ids.values(), sid
    ids[n] = sid
    stations.append({'id': sid, 'name': {'ja': n, 'ko': ko, 'en': en}, 'kana': kana,
                     'geo': {'lat': round(e['lat'], 6), 'lng': round(e['lon'], 6)}, 'lines': []})
by_name = {s['name']['ja']: s for s in stations}

SPEED = {'local': 52.0, 'private': 45.0, 'express': 85.0}     # km/h between stops, by line kind
EXTRA = {'local': 40, 'private': 40, 'express': 60}           # seconds to start and stop
DWELL = {'local': 30, 'private': 30, 'express': 60}

lines, tables = [], {}
for l in LINES:
    lid = 'tottori.' + l['key']
    st = [by_name[n] for n in l['stations']]
    for s in st:
        s['lines'].append(lid)
    run = []
    for a, b in zip(st, st[1:]):
        d = km((a['geo']['lat'], a['geo']['lng']), (b['geo']['lat'], b['geo']['lng'])) * 1.15   # track is not straight
        run.append(int(round(d / SPEED[l['kind']] * 3600 + EXTRA[l['kind']], -1)))
    lines.append({'id': lid, 'name': {'ja': l['ja'], 'ko': l['ko'], 'en': l['en']}, 'color': l['color'],
                  'loop': False, 'dwellSec': DWELL[l['kind']], 'group': l['group'],
                  'directions': {'forward': l['forward'], 'reverse': l['reverse']},
                  'stations': [s['id'] for s in st], 'runSec': run})
    first, last = FIRST_LAST[l['key']]
    slots = [{'from': a, 'to': b, 'everyMin': m} for a, b, m in HEADWAY[l['key']]]
    # Weekends: the same rural service, the morning rush a little thinner.
    holiday = [dict(s, everyMin=max(s['everyMin'], 60) if s['from'] == '07:00' else s['everyMin']) for s in slots]
    tables[lid] = {'firstTrain': first, 'lastTrain': last, 'weekday': slots, 'holiday': holiday}

os.makedirs(CITY, exist_ok=True)


def dump(name, obj):
    json.dump(obj, open(os.path.join(CITY, name), 'w', encoding='utf8'), ensure_ascii=False, indent=1)


dump('stations.json', stations)
dump('lines.json', lines)
dump('timetables.json', tables)
dump('walks.json', [])
dump('through.json', [])
dump('city.json', {
    'id': 'tottori',
    'name': {'ja': '鳥取・米子', 'ko': '돗토리·요나고', 'en': 'Tottori & Yonago'},
    'timezone': 'Asia/Tokyo',
    'center': {'lat': 35.47, 'lng': 133.75},
    'lines': [l['id'] for l in lines],
    'weather': {'forecastOffice': '310000', 'forecastArea': '310010', 'amedas': '69122'},
    'dataNote': 'Stations and lines: OpenStreetMap contributors (ODbL). Run times and headways are approximate '
                'estimates (rural lines run about once an hour). Replace with licensed timetable data later.',
})
print(len(stations), 'stations,', len(lines), 'lines')
for s in stations:
    print(s['id'], s['name']['ja'], s['name']['ko'], s['name']['en'], s['kana'])
