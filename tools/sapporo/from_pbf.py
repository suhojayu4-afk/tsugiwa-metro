"""The same layers as fetch.py, read from a Geofabrik extract instead of the
Overpass API (for when Overpass is busy or refuses): writes osm/<layer>.json
next to this file in Overpass's JSON form (ways and relations with their
geometry), so build_map.py reads them the same way.

  python -X utf8 tools/<city>/from_pbf.py PATH/TO/<region>-latest.osm.pbf [layer ...]

Needs pyosmium (pip install osmium). Regions: osaka kansai, fukuoka kyushu,
sendai tohoku, sapporo hokkaido (https://download.geofabrik.de/asia/japan/).
Layers already in osm/ are kept unless named. Data (c) OpenStreetMap
contributors, ODbL.
"""
import json
import math
import os
import re
import sys

import osmium

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import conf  # noqa: E402

OUT = os.path.join(HERE, 'osm')
S, W, N, E = conf.GROUND
_mlat = (conf.OUTER_MARGIN / conf.UNITS + 3) / 111.0
_mlng = (conf.OUTER_MARGIN / conf.UNITS + 3) / 91.0
B = (S - 0.02, W - 0.02, N + 0.02, E + 0.02)
WB = (S - _mlat, W - _mlng, N + _mlat, E + _mlng)


def tag(t, k, pat):
    v = t.get(k)
    return v is not None and re.search(pat, v) is not None


# layer: (box, kind, test(tags), min length in m)  -- the same as fetch.py
WAYS = {
    'coast': (WB, lambda t: t.get('natural') == 'coastline', 0),
    'water': (B, lambda t: t.get('natural') == 'water' or t.get('waterway') == 'riverbank', 300),
    'water_wide': (WB, lambda t: t.get('natural') == 'water', 2500),
    'rivers': (WB, lambda t: tag(t, 'waterway', '^(river|canal)$') and 'name' in t, 0),
    'forest': (WB, lambda t: t.get('landuse') == 'forest' or t.get('natural') == 'wood', 1200),
    'fields': (B, lambda t: tag(t, 'landuse', '^(farmland|orchard|meadow)$'), 500),
    'town': (B, lambda t: tag(t, 'landuse', '^(residential|commercial|retail|industrial|port)$'), 250),
    'town_wide': (WB, lambda t: tag(t, 'landuse', '^(residential|commercial|retail|industrial)$'), 2500),
    'sand': (B, lambda t: tag(t, 'natural', '^(sand|beach)$'), 0),
    'parks': (B, lambda t: tag(t, 'leisure', '^(park|golf_course|garden|pitch)$') or
              tag(t, 'landuse', '^(grass|cemetery|recreation_ground)$'), 350),
    'aero': (WB, lambda t: tag(t, 'aeroway', '^(aerodrome|runway|apron)$'), 0),
}
RELS = {
    'water': (B, lambda t: t.get('natural') == 'water'),
    'water_wide': (WB, lambda t: t.get('natural') == 'water' and not tag(t, 'water', '^(river|canal)$')),
    'forest': (WB, lambda t: t.get('landuse') == 'forest' or t.get('natural') == 'wood'),
    'parks': (B, lambda t: t.get('leisure') == 'park'),
}
NODES = {
    'peaks': (WB, lambda t: tag(t, 'natural', '^(peak|volcano)$') and 'ele' in t),
    'places': (WB, lambda t: tag(t, 'place', '^(city|town|village|suburb|quarter)$')),
}


def inside(box, lat, lon):
    return box[0] <= lat <= box[2] and box[1] <= lon <= box[3]


def length(pts):
    return sum(math.hypot((a[0] - b[0]) * 111000, (a[1] - b[1]) * 91000) for a, b in zip(pts, pts[1:]))


class Rels(osmium.SimpleHandler):
    def __init__(self, want):
        super().__init__()
        self.want, self.rels, self.members = want, {}, {}

    def relation(self, r):
        t = {k: v for k, v in r.tags}
        if t.get('type') not in ('multipolygon', 'boundary'):
            return
        hit = [n for n in self.want if n in RELS and RELS[n][1](t)]
        if not hit:
            return
        mem = [(m.ref, m.role) for m in r.members if m.type == 'w']
        self.rels[r.id] = (t, mem, hit)
        for ref, _ in mem:
            self.members.setdefault(ref, None)


class Ways(osmium.SimpleHandler):
    def __init__(self, want, members):
        super().__init__()
        self.want, self.members = want, members
        self.out = {n: [] for n in want}

    def node(self, n):
        if not n.tags:
            return
        t = None
        for name in self.want:
            if name in NODES:
                t = t or {k: v for k, v in n.tags}
                box, test = NODES[name]
                if test(t) and inside(box, n.location.lat, n.location.lon):
                    self.out[name].append({'type': 'node', 'id': n.id, 'lat': n.location.lat, 'lon': n.location.lon,
                                           'tags': t})

    def way(self, w):
        need = w.id in self.members
        if not w.tags and not need:
            return
        try:
            pts = [(nd.location.lat, nd.location.lon) for nd in w.nodes]
        except osmium.InvalidLocationError:
            pts = [(nd.location.lat, nd.location.lon) for nd in w.nodes if nd.location.valid()]
        if len(pts) < 2:
            return
        if need:
            self.members[w.id] = pts
        t = None
        for name in self.want:
            if name not in WAYS:
                continue
            box, test, minlen = WAYS[name]
            t = t or {k: v for k, v in w.tags}
            if not t or not test(t):
                continue
            if not any(inside(box, la, lo) for la, lo in pts[::max(1, len(pts) // 50)] + [pts[-1]]):
                continue
            if minlen and length(pts) <= minlen:
                continue
            self.out[name].append({'type': 'way', 'id': w.id, 'tags': t,
                                   'geometry': [{'lat': la, 'lon': lo} for la, lo in pts]})


def main():
    pbf = sys.argv[1]
    want = [a for a in sys.argv[2:]] or [n for n in list(WAYS) + list(NODES)
                                         if not os.path.exists(os.path.join(OUT, n + '.json'))]
    want = list(dict.fromkeys(want))
    if not want:
        print('nothing to do')
        return
    print(conf.CITY, 'reading', os.path.basename(pbf), 'for', ' '.join(want))
    rh = Rels(want)
    rh.apply_file(pbf)
    wh = Ways(want, rh.members)
    wh.apply_file(pbf, locations=True, idx='flex_mem')
    for rid, (t, mem, hit) in rh.rels.items():
        members = [{'type': 'way', 'ref': ref, 'role': role or 'outer',
                    'geometry': [{'lat': la, 'lon': lo} for la, lo in rh.members[ref]]}
                   for ref, role in mem if rh.members.get(ref)]
        if not members:
            continue
        for name in hit:
            box = RELS[name][0]
            if any(inside(box, g['lat'], g['lon']) for m in members for g in m['geometry'][::20]):
                wh.out[name].append({'type': 'relation', 'id': rid, 'tags': t, 'members': members})
    os.makedirs(OUT, exist_ok=True)
    for name in want:
        res = {'elements': wh.out[name], 'source': '(c) OpenStreetMap contributors, ODbL (Geofabrik extract)'}
        json.dump(res, open(os.path.join(OUT, name + '.json'), 'w', encoding='utf8'), ensure_ascii=False,
                  separators=(',', ':'))
        print(conf.CITY, name, len(wh.out[name]))


if __name__ == '__main__':
    main()
