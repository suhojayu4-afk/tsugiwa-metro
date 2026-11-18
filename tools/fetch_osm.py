"""Download the real shapes of Tokyo from OpenStreetMap (Overpass API) for
the pixel route map, and keep them in tools/data/osm/*.json so
build_map.py works offline and always gives the same picture.

  python -X utf8 tools/fetch_osm.py            # all layers
  python -X utf8 tools/fetch_osm.py parks      # one layer

Data (c) OpenStreetMap contributors, ODbL. The app must credit
"(c) OpenStreetMap contributors".
"""
import json
import os
import sys
import time
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'tools', 'data', 'osm')
URL = 'https://overpass-api.de/api/interpreter'
# The whole railway area (Yokohama - Saitama - Narita - Takao), in detail.
BBOX = (35.30, 139.20, 36.02, 140.42)
B = '(%s,%s,%s,%s)' % BBOX

LAYERS = {
    'coastline': f'way["natural"="coastline"]{B};',
    'water': (f'way["natural"="water"](if:length()>300){B};relation["natural"="water"]{B};'
              f'way["waterway"="riverbank"](if:length()>300){B};relation["waterway"="riverbank"]{B};'),
    'waterways': f'way["waterway"~"^(river|canal)$"]["tunnel"!~"."]["layer"!~"^-"]{B};',
    'parks': (f'way["leisure"~"^(park|garden|golf_course)$"](if:length()>700){B};'
              f'relation["leisure"~"^(park|garden|golf_course)$"]{B};'
              f'way["landuse"~"^(forest|cemetery|grass|recreation_ground)$"](if:length()>700){B};'
              f'relation["landuse"~"^(forest|cemetery)$"]{B};'
              f'way["natural"="wood"](if:length()>700){B};'
              f'way["amenity"="place_of_worship"](if:length()>900){B};'),
    'motorways': f'way["highway"~"^(motorway|trunk)$"]["tunnel"!~"."]["layer"!~"^-"]{B};',
    'landuse': f'way["landuse"~"^(commercial|retail|industrial|port|railway)$"](if:length()>500){B};',
}
# The whole map out to Mt. Takao and Narita: only big shapes (the fish-eye
# squeezes these areas a lot), saved as *_wide.json.
WIDE = (35.40, 139.10, 35.95, 140.50)
BW = '(%s,%s,%s,%s)' % WIDE
LAYERS.update({
    'coastline_wide': f'way["natural"="coastline"]{BW};',
    'water_wide': (f'way["natural"="water"](if:length()>2500){BW};'
                   f'relation["natural"="water"]["water"~"^(river|lake|reservoir|pond)$"]{BW};'
                   f'way["waterway"="riverbank"](if:length()>2500){BW};'),
    'parks_wide': (f'way["leisure"~"^(park|golf_course)$"](if:length()>3000){BW};'
                   f'way["landuse"="forest"](if:length()>3000){BW};way["natural"="wood"](if:length()>3000){BW};'
                   f'relation["leisure"="park"](if:length()>3000){BW};'),
})
# Far round the map (zoomed right out): the Kanto coast from Izu to Choshi
# and the big lakes, as the pale surroundings.
KANTO = (34.55, 138.30, 36.90, 141.10)
BK = '(%s,%s,%s,%s)' % KANTO
LAYERS['coastline_kanto'] = f'way["natural"="coastline"]{BK};'
LAYERS['lakes_kanto'] = (f'way["natural"="water"]["water"~"^(lake|reservoir)$"](if:length()>8000){BK};'
                         f'relation["natural"="water"]["water"~"^(lake|reservoir)$"](if:length()>8000){BK};')
LAYERS['rivers_kanto'] = (f'way["waterway"="river"]["name"~"^(利根川|荒川|多摩川|相模川|鬼怒川|江戸川|小貝川|入間川|'
                          f'酒匂川|中川|綾瀬川|那珂川|渡良瀬川|富士川|桂川|狩野川|久慈川|養老川|小櫃川|印旛放水路)$"]{BK};')
LAYERS['forest_kanto'] = (f'way["landuse"="forest"](if:length()>12000){BK};way["natural"="wood"](if:length()>12000){BK};'
                          f'relation["landuse"="forest"](if:length()>12000){BK};'
                          f'relation["natural"="wood"](if:length()>12000){BK};')
LAYERS['places_far'] = 'node["place"~"^(city|town)$"]["population"](%s,%s,%s,%s);' % (34.20, 137.60, 37.30, 141.60)
LAYERS['peaks_kanto'] = f'node["natural"="peak"]["ele"]{BK};'
# Peaks round the whole outer picture too (Minami Alps, Yatsugatake, Nikko).
FAR = (34.20, 137.60, 37.30, 141.60)
LAYERS['peaks_far'] = 'node["natural"="peak"]["ele"](%s,%s,%s,%s);' % FAR
LAYERS['airports_wide'] = (f'way["aeroway"~"^(runway|apron|aerodrome)$"]{BW};'
                           f'relation["aeroway"="aerodrome"]{BW};')
BBOXES = {n: (KANTO if n.endswith('_kanto') else FAR if n.endswith('_far') else WIDE if n.endswith('_wide') else BBOX)
          for n in LAYERS}
KEEP_TAGS = ('aeroway', 'natural', 'water', 'waterway', 'leisure', 'landuse', 'name', 'name:en', 'highway', 'ref',
             'bridge', 'layer', 'amenity', 'tunnel', 'intermittent', 'ele')


# Tiles (east-west x north-south) per heavy layer; motorways need small ones.
TILES = {'motorways': (8, 6), 'forest_kanto': (4, 3), 'rivers_kanto': (2, 2)}
MIRRORS = [URL, 'https://overpass.kumi.systems/api/interpreter', 'https://overpass.private.coffee/api/interpreter']


def query(body):
    q = f'[out:json][timeout:180];({body});out geom;'
    data = urllib.parse.urlencode({'data': q}).encode()
    # Pieces already downloaded are kept, so a failed run goes on where it stopped.
    import hashlib
    cache = os.path.join(OUT, '_cache', hashlib.sha1(q.encode()).hexdigest() + '.json')
    if os.path.exists(cache):
        return json.load(open(cache, encoding='utf8'))
    for attempt in range(6):
        req = urllib.request.Request(MIRRORS[attempt % len(MIRRORS)], data=data,
                                     headers={'User-Agent': 'pixel-route-map-builder/1.0'})
        try:
            with urllib.request.urlopen(req, timeout=240) as r:
                res = json.load(r)
            os.makedirs(os.path.dirname(cache), exist_ok=True)
            json.dump(res, open(cache, 'w', encoding='utf8'))
            return res
        except Exception as e:  # busy server: wait and retry
            print('  retry', attempt + 1, e)
            time.sleep(10 * (attempt + 1))
    raise SystemExit('Overpass failed')


def pt(n):
    return [round(n['lat'], 5), round(n['lon'], 5)]


def stitch(ways):
    """Join way pieces (lists of points) end to end into rings / long lines."""
    ways = [w[:] for w in ways if len(w) > 1]
    out = []
    while ways:
        cur = ways.pop(0)
        grown = True
        while grown and cur[0] != cur[-1]:
            grown = False
            for i, w in enumerate(ways):
                if w[0] == cur[-1]:
                    cur += w[1:]
                elif w[-1] == cur[-1]:
                    cur += w[::-1][1:]
                elif w[-1] == cur[0]:
                    cur = w[:-1] + cur
                elif w[0] == cur[0]:
                    cur = w[::-1][:-1] + cur
                else:
                    continue
                ways.pop(i)
                grown = True
                break
        out.append(cur)
    return out


def convert(el):
    tags = {k: v for k, v in el.get('tags', {}).items() if k in KEEP_TAGS}
    if el['type'] == 'way':
        g = [pt(n) for n in el.get('geometry', [])]
        return {'id': el['id'], 'tags': tags, 'outer': [g], 'inner': []}
    outer = [[pt(n) for n in m['geometry']] for m in el.get('members', [])
             if m['type'] == 'way' and m.get('role', 'outer') in ('outer', '') and m.get('geometry')]
    inner = [[pt(n) for n in m['geometry']] for m in el.get('members', [])
             if m['type'] == 'way' and m.get('role') == 'inner' and m.get('geometry')]
    return {'id': el['id'], 'tags': tags, 'outer': stitch(outer), 'inner': stitch(inner)}


def main():
    os.makedirs(OUT, exist_ok=True)
    names = sys.argv[1:] or list(LAYERS)
    for name in names:
        print('fetching', name, '...')
        if name not in TILES and (name.endswith(('_wide', '_kanto', '_far')) or name in ('coastline', 'water', 'waterways')):
            res = query(LAYERS[name])
            elements = res['elements']
        else:
            # Big layers over the whole area time out: ask for tiles and merge them.
            elements, seen = [], set()
            s_, w_, n_, e_ = BBOXES[name]
            nx, ny = TILES.get(name, (4, 3))
            for i in range(nx):
                for j in range(ny):
                    tb = '(%s,%s,%s,%s)' % (s_ + (n_ - s_) * j / ny, w_ + (e_ - w_) * i / nx,
                                           s_ + (n_ - s_) * (j + 1) / ny, w_ + (e_ - w_) * (i + 1) / nx)
                    res = query(LAYERS[name].replace(BK if name.endswith('_kanto') else B, tb))
                    for el in res['elements']:
                        if (el['type'], el['id']) not in seen:
                            seen.add((el['type'], el['id']))
                            elements.append(el)
                    print('   tile', i, j, len(elements))
                    time.sleep(3)
        feats = [convert(e) for e in elements if e['type'] in ('way', 'relation')]
        feats += [{'id': e['id'], 'tags': {k: v for k, v in e.get('tags', {}).items()
                                           if k in ('name', 'ele', 'place', 'population')},
                   'outer': [[[round(e['lat'], 5), round(e['lon'], 5)]] * 2], 'inner': []}
                  for e in elements if e['type'] == 'node']
        feats = [f for f in feats if f['outer'] and any(len(r) > 1 for r in f['outer'])]
        json.dump({'source': '(c) OpenStreetMap contributors, ODbL', 'bbox': BBOXES[name],
                   'timestamp': res.get('osm3s', {}).get('timestamp_osm_base'), 'features': feats},
                  open(os.path.join(OUT, name + '.json'), 'w', encoding='utf8'), ensure_ascii=False,
                  separators=(',', ':'))
        print(' ', name, len(feats), 'features')
        time.sleep(5)


if __name__ == '__main__':
    main()
