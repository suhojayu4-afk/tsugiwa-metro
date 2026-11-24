"""Build the city data (assets/cities/<city>: city.json, stations.json,
lines.json, timetables.json, walks.json, through.json) from lines.py and
the OpenStreetMap station nodes (osm/stations.json) of this folder.

  python -X utf8 tools/<city>/build_city.py

Copied from tools/tottori/build_city.py (loop lines added). Data (c)
OpenStreetMap contributors (ODbL). Run times and headways are estimates.
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
import conf  # noqa: E402
from kana import hangul, romaji  # noqa: E402
from lines import EN_FIX, FIRST_LAST, HEADWAY, KANA, KO_FIX, LINES  # noqa: E402
import lines as _L  # noqa: E402
SID_FIX = getattr(_L, 'SID_FIX', {})   # '中津#阪急' -> 'hankyu-nakatsu'
WALKS = getattr(_L, 'WALKS', [])       # (name, name, minutes) changes on foot

CITY = os.path.join(ROOT, 'assets', 'cities', conf.CITY)
OSM = os.path.join(HERE, 'osm')


def km(a, b):
    return math.hypot((a[0] - b[0]) * 111.0, (a[1] - b[1]) * 91.0)


nodes = {}
for e in json.load(open(os.path.join(OSM, 'stations.json'), encoding='utf8'))['elements']:
    t = e.get('tags', {})
    for key in ('name', 'name:ja'):
        n = t.get(key)
        if n:
            nodes.setdefault(n, [])
            if e not in nodes[n]:
                nodes[n].append(e)

names, first_line = [], {}
for l in LINES:
    for n in l['stations']:
        if n not in names:
            names.append(n)
            first_line[n] = l


def pick(key):
    name = key.split('#')[0]    # '琴似#JR': the JR station of a name the subway has too
    c = nodes.get(name) or nodes.get(name.replace('ケ', 'ヶ')) or nodes.get(name.replace('ヶ', 'ケ'))
    assert c, f'no OSM station {name}'
    l = first_line[key]
    want = l.get('operator') or ('JR' if l['group'] == 'jr' else conf.OPERATOR)

    def score(e):
        t = e.get('tags', {})
        op = ' '.join(t.get(k, '') for k in ('operator', 'network', 'operator:en', 'network:en'))
        rail = t.get('railway') in ('station', 'halt', 'tram_stop')
        return (0 if re.search(want, op) else 1, 0 if rail else 1, km((e['lat'], e['lon']), conf.CENTER))

    c.sort(key=score)
    return c[0]


def clean_en(en):
    en = re.sub(r'\s+Station$', '', en, flags=re.I)
    en = re.sub(r'\s*[(（].*[)）]$', '', en)
    return unicodedata.normalize('NFKD', en).encode('ascii', 'ignore').decode().strip()


stations, ids = [], {}
for n in names:
    e = pick(n)
    t = e['tags']
    ja = n.split('#')[0]
    kana = KANA[ja]
    hira = t.get('name:ja-Hira') or t.get('name:ja_kana')
    if hira and hira.replace(' ', '') != kana and not hira.startswith('ｱ'):
        print('  reading differs:', ja, kana, '(OSM:', hira + ')')
    en = EN_FIX.get(n) or clean_en(t.get('name:en', '')) or romaji(kana)
    ko = KO_FIX.get(n) or re.sub(r'역$', '', t.get('name:ko', '')).strip() or hangul(kana)
    sid = conf.CITY + '.' + (SID_FIX.get(n) or re.sub(r'[^a-z0-9]+', '-', en.lower()).strip('-'))
    assert sid not in ids.values(), sid
    ids[n] = sid
    stations.append({'id': sid, 'name': {'ja': ja, 'ko': ko, 'en': en}, 'kana': kana,
                     'geo': {'lat': round(e['lat'], 6), 'lng': round(e['lon'], 6)}, 'lines': []})
by_name = {n: s for n, s in zip(names, stations)}

SPEED = {'metro': 33.0, 'local': 36.0, 'tram': 14.0, 'express': 70.0}   # km/h between stops
EXTRA = {'metro': 30, 'local': 30, 'tram': 20, 'express': 50}           # seconds to start and stop
DWELL = {'metro': 25, 'local': 30, 'tram': 20, 'express': 60}

lines, tables = [], {}
for l in LINES:
    lid = conf.CITY + '.' + l['key']
    st = [by_name[n] for n in l['stations']]
    for s in st:
        s['lines'].append(lid)
    run = []
    pairs = list(zip(st, st[1:])) + ([(st[-1], st[0])] if l.get('loop') else [])
    for a, b in pairs:
        d = km((a['geo']['lat'], a['geo']['lng']), (b['geo']['lat'], b['geo']['lng'])) * 1.1
        run.append(max(60, int(round(d / SPEED[l['kind']] * 3600 + EXTRA[l['kind']], -1))))
    lines.append({'id': lid, 'name': {'ja': l['ja'], 'ko': l['ko'], 'en': l['en']}, 'color': l['color'],
                  'loop': bool(l.get('loop')), 'dwellSec': DWELL[l['kind']], 'group': l['group'],
                  'directions': {'forward': l['forward'], 'reverse': l['reverse']},
                  'stations': [s['id'] for s in st], 'runSec': run})
    first, last = FIRST_LAST[l['key']]
    slots = [{'from': a, 'to': b, 'everyMin': m} for a, b, m in HEADWAY[l['key']]]
    # Weekends and holidays: no rush hour.
    holiday = [dict(s, everyMin=max(s['everyMin'], 5)) for s in slots]
    tables[lid] = {'firstTrain': first, 'lastTrain': last, 'weekday': slots, 'holiday': holiday}

os.makedirs(CITY, exist_ok=True)


def dump(name, obj):
    json.dump(obj, open(os.path.join(CITY, name), 'w', encoding='utf8'), ensure_ascii=False, indent=1)


dump('stations.json', stations)
dump('lines.json', lines)
dump('timetables.json', tables)
dump('walks.json', [{'a': ids[a], 'b': ids[b], 'min': m, 'names': f"{a.split('#')[0]} ↔ {b.split('#')[0]}"}
                   for a, b, m in WALKS])
dump('through.json', [])
dump('city.json', {
    'id': conf.CITY,
    'name': conf.NAME,
    'timezone': 'Asia/Tokyo',
    'center': {'lat': conf.CENTER[0], 'lng': conf.CENTER[1]},
    'lines': [l['id'] for l in lines],
    'weather': conf.WEATHER,
    'dataNote': 'Stations and lines: OpenStreetMap contributors (ODbL). Run times and headways are approximate '
                'estimates. Replace with licensed timetable data later.',
})
print(len(stations), 'stations,', len(lines), 'lines')
for s in stations:
    print(s['id'], s['name']['ja'], s['name']['ko'], s['name']['en'], s['kana'])
