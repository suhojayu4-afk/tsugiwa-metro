"""Download the city (see conf.py in this folder) from OpenStreetMap: the
stations, and the shapes for the pixel map (coast, lakes, rivers, forests,
fields, towns, parks, peaks, airports). Saved in osm/ next to this file so
the builders work offline and always give the same picture.

Two boxes: the detailed ground (conf.GROUND, every town block and park) and
the wide ground round it (the coarse picture past the map's edge: coast,
forests, big towns, peaks).

  python -X utf8 tools/<city>/fetch.py            # every layer
  python -X utf8 tools/<city>/fetch.py coast      # one layer
  python -X utf8 tools/<city>/fetch.py -f coast   # again, though it is already here

When Overpass is busy or refuses (it did on 2026-11-24), from_pbf.py reads
the same layers from a Geofabrik extract. Copied from tools/tottori/fetch.py. Data (c) OpenStreetMap contributors, ODbL.
"""
import json
import os
import sys
import time
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import conf  # noqa: E402

OUT = os.path.join(HERE, 'osm')
URLS = ['https://overpass-api.de/api/interpreter']

S, W, N, E = conf.GROUND
_mlat = (conf.OUTER_MARGIN / conf.UNITS + 3) / 111.0
_mlng = (conf.OUTER_MARGIN / conf.UNITS + 3) / 91.0
B = '(%.4f,%.4f,%.4f,%.4f)' % (S - 0.02, W - 0.02, N + 0.02, E + 0.02)
WB = '(%.4f,%.4f,%.4f,%.4f)' % (S - _mlat, W - _mlng, N + _mlat, E + _mlng)
ST = '|'.join(conf.STATION_TYPES)

LAYERS = {
    'stations': f'node["railway"~"^({ST})$"]{B};out;node["public_transport"="station"]{B};out;',
    'coast': f'way["natural"="coastline"]{WB};out geom;',
    'water': (f'way["natural"="water"](if:length()>300){B};out geom;'
              f'rel["natural"="water"]{B};out geom;'
              f'way["waterway"="riverbank"](if:length()>300){B};out geom;'),
    'water_wide': (f'way["natural"="water"](if:length()>2500){WB};out geom;'
                   f'rel["natural"="water"]["water"!~"^(river|canal)$"]{WB};out geom;'),
    'rivers': f'way["waterway"~"^(river|canal)$"]["name"]{WB};out geom;',
    'forest': (f'way["landuse"="forest"](if:length()>1200){WB};out geom;'
               f'way["natural"="wood"](if:length()>1200){WB};out geom;'
               f'rel["landuse"="forest"]{WB};out geom;rel["natural"="wood"]{WB};out geom;'),
    'fields': f'way["landuse"~"^(farmland|orchard|meadow)$"](if:length()>500){B};out geom;',
    'town': f'way["landuse"~"^(residential|commercial|retail|industrial|port)$"](if:length()>250){B};out geom;',
    'town_wide': f'way["landuse"~"^(residential|commercial|retail|industrial)$"](if:length()>2500){WB};out geom;',
    'sand': f'way["natural"~"^(sand|beach)$"]{B};out geom;',
    'parks': (f'way["leisure"~"^(park|golf_course|garden|pitch)$"](if:length()>350){B};out geom;'
              f'rel["leisure"="park"]{B};out geom;way["landuse"~"^(grass|cemetery|recreation_ground)$"]'
              f'(if:length()>500){B};out geom;'),
    'peaks': f'node["natural"~"^(peak|volcano)$"]["ele"]{WB};out;',
    'places': f'node["place"~"^(city|town|village|suburb|quarter)$"]{WB};out;',
    'aero': f'way["aeroway"~"^(aerodrome|runway|apron)$"]{WB};out geom;',
}


def fetch(name):
    q = f'[out:json][timeout:600][maxsize:1073741824];{LAYERS[name]}'
    data = urllib.parse.urlencode({'data': q}).encode()
    for attempt in range(10):
        req = urllib.request.Request(URLS[attempt % len(URLS)], data=data,
                                     headers={'User-Agent': 'pixel-route-map-builder/1.0'})
        try:
            with urllib.request.urlopen(req, timeout=700) as r:
                res = json.load(r)
            break
        except Exception as e:
            print('  retry', attempt + 1, e)
            time.sleep(15 + 10 * attempt)
    else:
        raise SystemExit('Overpass failed: ' + name)
    res['source'] = '(c) OpenStreetMap contributors, ODbL'
    json.dump(res, open(os.path.join(OUT, name + '.json'), 'w', encoding='utf8'), ensure_ascii=False,
              separators=(',', ':'))
    print(conf.CITY, name, len(res['elements']))


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    force = '-f' in sys.argv
    for n in [a for a in sys.argv[1:] if a != '-f'] or LAYERS:
        if not force and os.path.exists(os.path.join(OUT, n + '.json')):
            continue   # already here (-f fetches it again)
        fetch(n)
        time.sleep(3)
