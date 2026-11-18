"""Which ward / city (区・市) and neighbourhood (町, e.g. 銀座) each station
is in, from OpenStreetMap administrative areas (Overpass is_in), saved to
tools/data/osm/station_areas.json. build_map.py copies it into map.json
"areas" for the station card.

  python -X utf8 tools/fetch_station_areas.py

Data (c) OpenStreetMap contributors, ODbL.
"""
import json
import os
import time
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CITY = os.path.join(ROOT, 'assets', 'cities', 'tokyo')
OUT = os.path.join(ROOT, 'tools', 'data', 'osm', 'station_areas.json')
URL = 'https://overpass-api.de/api/interpreter'
CHUNK = 40


def query(q):
    data = urllib.parse.urlencode({'data': q}).encode()
    req = urllib.request.Request(URL, data=data, headers={'User-Agent': 'pixel-route-map-builder/1.0'})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=240) as r:
                return json.load(r)
        except Exception as e:
            print('  retry', attempt + 1, e)
            time.sleep(15 * (attempt + 1))
    raise SystemExit('Overpass failed')


def names(tags):
    out = {'ja': tags.get('name', '')}
    ko = tags.get('name:ko')
    en = tags.get('name:en') or tags.get('name:ja-Latn') or tags.get('name:ja_rm')
    if ko:
        out['ko'] = ko
    if en:
        out['en'] = en
    return out


def main():
    lines = json.load(open(os.path.join(CITY, 'lines.json'), encoding='utf8'))
    used = {s for l in lines for s in l['stations']}
    stations = [s for s in json.load(open(os.path.join(CITY, 'stations.json'), encoding='utf8')) if s['id'] in used]
    # Keep what was fetched before; ask only for the new stations.
    result = json.load(open(OUT, encoding='utf8'))['areas'] if os.path.exists(OUT) else {}
    result = {k: v for k, v in result.items() if k in used}
    stations = [s for s in stations if not result.get(s['id'], {}).get('ward')]
    print(len(stations), 'stations to look up')
    for i in range(0, len(stations), CHUNK):
        part = stations[i:i + CHUNK]
        body = ''.join(
            f'make mark sid="{s["id"]}";out;'
            f'is_in({s["geo"]["lat"]},{s["geo"]["lng"]})->.a;'
            f'rel(pivot.a)["boundary"="administrative"]["admin_level"~"^(7|8|9)$"];out tags;'
            for s in part)
        res = query(f'[out:json][timeout:200];{body}')
        sid = None
        for e in res['elements']:
            if e['type'] == 'mark':
                sid = e['tags']['sid']
                result[sid] = {}
                continue
            t = e.get('tags', {})
            lvl = t.get('admin_level')
            key = 'ward' if lvl in ('7', '8') else 'town'
            # The smallest ward-level area wins (a 区 inside a 市 is never the case in Tokyo,
            # but keep level 7 over 8 when both exist).
            if key == 'ward' and 'ward' in result[sid] and lvl == '8':
                continue
            result[sid][key] = names(t)
        print(f'  {min(i + CHUNK, len(stations))}/{len(stations)}')
        json.dump({'source': '(c) OpenStreetMap contributors, ODbL', 'areas': result},
                  open(OUT, 'w', encoding='utf8'), ensure_ascii=False, indent=0)   # progress survives a failure
        time.sleep(3)
    json.dump({'source': '(c) OpenStreetMap contributors, ODbL', 'areas': result},
              open(OUT, 'w', encoding='utf8'), ensure_ascii=False, indent=0)
    missing = [s['id'] for s in stations if not result.get(s['id'], {}).get('ward')]
    stations = stations  # (only the ones asked this run)
    print(len(result), 'stations;', len(missing), 'without a ward:', missing[:10])


if __name__ == '__main__':
    main()
