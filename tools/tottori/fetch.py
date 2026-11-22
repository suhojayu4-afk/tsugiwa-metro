"""Download Tottori Prefecture (and the shores round Yonago) from
OpenStreetMap for the second city: railway routes with their stops, the
stations, named tracks, and the shapes for the pixel map (coast, lakes,
rivers, forests, fields, towns, peaks). Saved in tools/data/osm_tottori/
so the builders work offline and always give the same picture.

  python -X utf8 tools/tottori/fetch.py            # every layer
  python -X utf8 tools/tottori/fetch.py coast      # one layer

Data (c) OpenStreetMap contributors, ODbL.
"""
import json
import os
import sys
import time
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'tools', 'data', 'osm_tottori')
URL = 'https://overpass-api.de/api/interpreter'

# Tottori Prefecture from Iwami to Sakaiminato, plus Nakaumi, Yasugi and
# Matsue across the border (drawn, not on the route map).
AREA = (35.05, 132.95, 35.72, 134.55)
B = '(%s,%s,%s,%s)' % AREA

LAYERS = {
    'rail': (f'rel["type"="route"]["route"~"^(train|light_rail)$"]{B}->.r;.r out body;'
             f'rel(br.r)["type"="route_master"];out body;node(r.r);out;'),
    'stations': f'node["railway"~"^(station|halt)$"]{B};out;',
    'tracks': f'way["railway"="rail"]["service"!~"."]{B};out geom;',
    'coast': f'way["natural"="coastline"]{B};out geom;',
    'water': (f'way["natural"="water"](if:length()>400){B};out geom;'
              f'rel["natural"="water"]{B};out geom;'
              f'way["waterway"="riverbank"](if:length()>400){B};out geom;'),
    'rivers': f'way["waterway"="river"]{B};out geom;',
    'forest': (f'way["landuse"="forest"](if:length()>1500){B};out geom;'
               f'way["natural"="wood"](if:length()>1500){B};out geom;'
               f'rel["landuse"="forest"]{B};out geom;rel["natural"="wood"]{B};out geom;'),
    'fields': (f'way["landuse"~"^(farmland|orchard|meadow)$"](if:length()>600){B};out geom;'),
    'town': (f'way["landuse"~"^(residential|commercial|retail|industrial)$"](if:length()>300){B};out geom;'),
    'sand': f'way["natural"~"^(sand|beach|dune)$"]{B};out geom;rel["natural"~"^(sand|beach|dune)$"]{B};out geom;',
    'parks': f'way["leisure"~"^(park|golf_course)$"](if:length()>500){B};out geom;',
    'peaks': f'node["natural"~"^(peak|volcano)$"]["ele"]{B};out;',
    'places': f'node["place"~"^(city|town|village|suburb)$"]{B};out;',
    'roads': f'way["highway"~"^(motorway|trunk)$"]["tunnel"!~"."]{B};out geom;',
}


def fetch(name):
    q = f'[out:json][timeout:300];{LAYERS[name]}'
    data = urllib.parse.urlencode({'data': q}).encode()
    req = urllib.request.Request(URL, data=data, headers={'User-Agent': 'pixel-route-map-builder/1.0'})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=400) as r:
                res = json.load(r)
            break
        except Exception as e:
            print('  retry', attempt + 1, e)
            time.sleep(20 * (attempt + 1))
    else:
        raise SystemExit('Overpass failed: ' + name)
    res['source'] = '(c) OpenStreetMap contributors, ODbL'
    json.dump(res, open(os.path.join(OUT, name + '.json'), 'w', encoding='utf8'), ensure_ascii=False,
              separators=(',', ':'))
    print(name, len(res['elements']))


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for n in sys.argv[1:] or LAYERS:
        fetch(n)
        time.sleep(3)
