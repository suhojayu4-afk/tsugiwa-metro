"""Stations of railway lines that OpenStreetMap has no passenger route
relation for (Chichibu Railway, Joshin, Watarase Keikoku, Agatsuma ...):
the stations within 120 m of the line's named tracks. Saved to
tools/data/osm/rail_tracks.json; build_rail.py puts them in running order.

  python -X utf8 tools/fetch_rail_tracks.py

Data (c) OpenStreetMap contributors, ODbL.
"""
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from fetch_rail import AREA  # noqa: E402
import fetch_osm  # noqa: E402

OUT = os.path.join(ROOT, 'tools', 'data', 'osm', 'rail_tracks.json')
B = '(%s,%s,%s,%s)' % AREA
# key: regular expression for the track name
TRACKS = {
    'chichibu': '秩父本線|秩父鉄道',
    'joshin': '上信',
    'watarase': 'わたらせ渓谷',
    'agatsuma': '吾妻線',
    'choshi': '銚子電',
}


def _near_track(lat, lng, segs, km=0.15):
    x, y = lng * 90.9, lat * 111.0
    for (ax, ay), (bx, by) in segs:
        l2 = (bx - ax) ** 2 + (by - ay) ** 2
        t = 0 if l2 == 0 else max(0, min(1, ((x - ax) * (bx - ax) + (y - ay) * (by - ay)) / l2))
        if math.hypot(x - ax - t * (bx - ax), y - ay - t * (by - ay)) < km:
            return True
    return False


def main():
    # Stations with names and places: Wikidata (tools/fetch_wikidata_rail.py).
    wd = json.load(open(os.path.join(ROOT, 'tools', 'data', 'wikidata_rail.json'), encoding='utf8'))['stations']
    out = {}
    for key, rx in TRACKS.items():
        res = fetch_osm.query(f'way["railway"="rail"]["name"~"{rx}"]{B};')
        segs = []
        for e in res['elements']:
            g = [(n['lon'] * 90.9, n['lat'] * 111.0) for n in e.get('geometry', [])]
            segs += list(zip(g, g[1:]))
        st = []
        for s_ in wd.values():
            if 'lat' in s_ and s_.get('ja') and _near_track(s_['lat'], s_['lng'], segs):
                tags = {'name:ko': s_.get('ko', ''), 'name:en': s_.get('en', ''), 'name:ja-Hira': s_.get('kana', '')}
                st.append({'name': s_['ja'], 'lat': s_['lat'], 'lng': s_['lng'],
                           'tags': {k: v for k, v in tags.items() if v}})
        out[key] = st
        print(key, len(segs), 'track pieces,', len(st), 'stations:', ' '.join(s_['name'] for s_ in st))
    json.dump(out, open(OUT, 'w', encoding='utf8'), ensure_ascii=False, indent=0)


if __name__ == '__main__':
    main()
