"""Build a city's route map (the city in conf.py next to this file): station
spots and straight / 45 degree line paths (tools/map_layout.py, the same
engine as Tokyo and Tottori), and the pixel ground painted with the Tokyo
brush (tools/terrain_paint.py) from OpenStreetMap (osm/ next to this file):
the coast and the sea, the big rivers, lakes, forests and hills, parks,
fields, the town blocks (houses, shops, offices, harbour and factories)
and the airports.

Outputs assets/cities/<city>/map.json and landmarks.json,
assets/art/<city>/map_overview.png, map_outer.png and the zoom tiles in
assets/art/<city>/map_tiles/.

  python -X utf8 tools/<city>/build_map.py           # keep the line layout
  MAP_NEW_LAYOUT=1 python -X utf8 tools/<city>/build_map.py
  MAP_PREVIEW=4 python -X utf8 tools/<city>/build_map.py   # a quick coarse picture only

Copied from tools/tottori/build_map.py: a city scale (conf.UNITS), the sea
filled from points out at sea, rivers kept by name, wards, CBD districts,
airports, loop lines. Data (c) OpenStreetMap contributors, ODbL.
"""
import json
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
ROOT = os.path.dirname(TOOLS)
sys.path.insert(0, HERE)
sys.path.insert(1, TOOLS)
import conf  # noqa: E402
import landmarks as LM  # noqa: E402
from map_layout import layout, place, relax, ride_paths, schematize  # noqa: E402
from terrain_paint import CBD as T_CBD, FOREST as T_FOREST, GARDEN as T_GARDEN, PARK as T_PARK  # noqa: E402
from terrain_paint import PORT as T_PORT, RES as T_RES, RURAL as T_RURAL, SHOP as T_SHOP, SUB as T_SUB  # noqa: E402
from terrain_paint import paint as t_paint, _h  # noqa: E402

C = conf.CITY
CITY = os.path.join(ROOT, 'assets', 'cities', C)
ART = os.path.join(ROOT, 'assets', 'art', C)
OSM = os.path.join(HERE, 'osm')
GEN = os.path.join(ROOT, 'docs', 'art', 'gen', C)
PREVIEW = os.environ.get('MAP_PREVIEW')   # a quick, coarse run

CENTER = conf.CENTER
UNITS = conf.UNITS
GROUND = conf.GROUND
SCALE = 3                     # map units per pixel of the zoom tiles
TILE = 512
OVERVIEW_SCALE = 12
OUTER_SCALE = 12
OUTER_MARGIN = conf.OUTER_MARGIN
KX = 90.9 * math.cos(math.radians((GROUND[0] + GROUND[2]) / 2)) / math.cos(math.radians(35.4))   # km per degree east


def to_map(lat, lng):
    return ((lng - GROUND[1]) * KX * UNITS, (GROUND[2] - lat) * 111.0 * UNITS)


def unproject(x, y):
    return GROUND[2] - y / (111.0 * UNITS), GROUND[1] + x / (KX * UNITS)


def px_km(km, scale):
    return km * UNITS / scale


W, H = (int(v) for v in to_map(GROUND[0], GROUND[3]))
W, H = W - W % SCALE, H - H % SCALE

stations = {s['id']: s for s in json.load(open(os.path.join(CITY, 'stations.json'), encoding='utf8'))}
lines = json.load(open(os.path.join(CITY, 'lines.json'), encoding='utf8'))


def load(name):
    p = os.path.join(OSM, name + '.json')
    return json.load(open(p, encoding='utf8'))['elements'] if os.path.exists(p) else []


# ---------------------------------------------------------------- lines
geo = {sid: (s['geo']['lat'], s['geo']['lng']) for sid, s in stations.items()}
rides = ride_paths(lines, geo, {l['id']: l.get('group', 'other') for l in lines})
closed_of = {l['id']: l['loop'] for l in lines}
through = {}
for seq in rides.values():
    for sid in set(seq):
        through[sid] = through.get(sid, 0) + 1
half = {sid: (n - 1) / 2 * 6 for sid, n in through.items()}
# Loops first, then the longest lines.
order = sorted((l['id'] for l in lines), key=lambda lid: (not closed_of[lid], len(rides[lid]) != len(next(
    l for l in lines if l['id'] == lid)['stations']), -len(rides[lid])))
old_path = os.path.join(CITY, 'map.json')
KEEP = os.environ.get('MAP_NEW_LAYOUT') != '1' and os.path.exists(old_path)
if KEEP:
    old = json.load(open(old_path, encoding='utf8'))
    KEEP = (old.get('size') == [W, H] and {l['id'] for l in old['lines']} == {l['id'] for l in lines}
            and all(s in o['stops'] for l in lines for o in old['lines'] if o['id'] == l['id'] for s in l['stations']))
cx, cy = to_map(*CENTER)
if KEEP:
    out_lines = old['lines']
    acc = {}
    for l in out_lines:
        for sid, st in l['stops'].items():
            a = acc.setdefault(sid, [0.0, 0.0, 0])
            a[0], a[1], a[2] = a[0] + st['x'], a[1] + st['y'], a[2] + 1
    pos = {sid: (a[0] / a[2], a[1] / a[2]) for sid, a in acc.items()}
else:
    raw = place({sid: to_map(*geo[sid]) for sid in geo}, half)
    pos, shape = schematize(rides, raw, order, closed_of,
                            eps=lambda sid: 30 + 20 * min(1.0, math.dist(raw[sid], (cx, cy)) / 2500), half=half)
    relax(pos, shape, half)
    laid = layout(lines, pos, {l['id']: i for i, l in enumerate(lines)}, rides, shape)
    out_lines = []
    for l, line in zip(laid, lines):
        sids, closed = line['stations'], line['loop']
        stops = {}
        for i, s in enumerate(sids):
            x, y = l['stops'][s]
            prev = pos[sids[i - 1]] if (i > 0 or closed) else pos[s]
            nxt = pos[sids[(i + 1) % len(sids)]] if (i + 1 < len(sids) or closed) else pos[s]
            dx, dy = nxt[0] - prev[0], nxt[1] - prev[1]
            if abs(dy) > abs(dx):
                side = 'r' if x >= cx else 'l'
            else:
                side = 'b' if y >= cy else 't'
            stops[s] = {'x': x, 'y': y, 'label': side}
        out_lines.append({'id': l['id'], 'closed': closed, 'path': l['path'], 'stops': stops})
print('lines laid out' if not KEEP else 'kept the line layout', f'map {W}x{H}')

# ---------------------------------------------------------------- shapes


def rings_of(elements):
    """Closed rings (lists of (lat, lng)) of ways and multipolygon relations: (outer, inner)."""
    outer, inner = [], []

    def join(parts):
        parts = [p[:] for p in parts if len(p) > 1]
        rings = []
        while parts:
            ring = parts.pop()
            changed = True
            while changed and ring[0] != ring[-1]:
                changed = False
                for i, p in enumerate(parts):
                    if p[0] == ring[-1]:
                        ring += p[1:]
                    elif p[-1] == ring[-1]:
                        ring += p[::-1][1:]
                    elif p[-1] == ring[0]:
                        ring = p[:-1] + ring
                    elif p[0] == ring[0]:
                        ring = p[::-1][:-1] + ring
                    else:
                        continue
                    parts.pop(i)
                    changed = True
                    break
            rings.append(ring)
        return rings

    for e in elements:
        if e['type'] == 'way' and 'geometry' in e:
            outer.append([(g['lat'], g['lon']) for g in e['geometry']])
        elif e['type'] == 'relation':
            for role, dst in (('outer', outer), ('inner', inner)):
                parts = [[(g['lat'], g['lon']) for g in m['geometry']] for m in e.get('members', [])
                         if m.get('role', 'outer') in ((role, '') if role == 'outer' else (role,)) and 'geometry' in m]
                dst.extend(join(parts))
    return outer, inner


def lines_of(elements):
    out = []
    for e in elements:
        if e['type'] == 'way' and 'geometry' in e:
            out.append((e.get('tags', {}), [(g['lat'], g['lon']) for g in e['geometry']]))
    return out


def _area_km2(geom):
    pts = [(g['lon'] * KX, g['lat'] * 111.0) for g in geom]
    return abs(sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(pts, pts[1:] + pts[:1]))) / 2


def _wanted_water(e):
    """Lakes, ponds, moats and the big rivers; not every canal and ditch of the plains.
    Many river areas have no name in OpenStreetMap: those are kept when they are big."""
    t = e.get('tags', {})
    if t.get('covered') == 'yes' or t.get('water') == 'reservoir_covered':
        return False
    if t.get('waterway') == 'riverbank' or t.get('water') in ('river', 'canal', 'stream', 'ditch', 'drain',
                                                               'wastewater', 'oxbow'):
        if t.get('name') in conf.RIVERS or e['type'] == 'relation':
            return True
        return 'geometry' in e and _area_km2(e['geometry']) >= 0.04
    return True


coast = lines_of(load('coast'))
_water = [e for e in load('water') + load('water_wide') if _wanted_water(e)]
_seen = set()
water_o, water_i = rings_of([e for e in _water if not (e['id'] in _seen or _seen.add(e['id']))])
rivers = [(t, p) for t, p in lines_of(load('rivers')) if t.get('name') in conf.RIVERS
          and t.get('tunnel') not in ('yes', 'culvert') and t.get('intermittent') != 'yes']
forest_o, forest_i = rings_of(load('forest'))
town = [e for e in load('town') if e['type'] == 'way' and 'geometry' in e]
town_wide = [e for e in load('town_wide') if e['type'] == 'way' and 'geometry' in e]
fields_o, _ = rings_of(load('fields'))
sand_o, _ = rings_of(load('sand'))
parks_o, parks_i = rings_of(load('parks'))
aero = load('aero')
peaks = sorted(((float(str(e['tags'].get('ele', '0')).split()[0].replace('m', '').replace(',', '.') or 0),
                 (e['lat'], e['lon'])) for e in load('peaks') if e.get('tags', {}).get('ele')
                and str(e['tags']['ele']).split()[0].replace('m', '').replace('.', '', 1).isdigit()), reverse=True)
places = [e for e in load('places') if 'name' in e.get('tags', {})]


def nature(scale, ox, oy, pw, ph):
    """Water, forest, towns, parks and hills of a picture of pw x ph pixels."""
    def tp(lat, lng):
        x, y = to_map(lat, lng)
        return (x - ox) / scale, (y - oy) / scale

    # Sea: the coastline drawn as a wall, then filled from the points out at sea.
    wall = Image.new('L', (pw, ph), 0)
    wd = ImageDraw.Draw(wall)
    for _, pts in coast:
        wd.line([tp(*q) for q in pts], fill=1, width=2)
    arr = np.asarray(wall)
    lab, _ = ndimage.label(arr == 0)
    seeds = set()
    for lat, lng in conf.SEA:
        x, y = tp(lat, lng)
        if 0 <= x < pw and 0 <= y < ph and lab[int(y), int(x)]:
            seeds.add(int(lab[int(y), int(x)]))
    sea = np.isin(lab, list(seeds)) if seeds else np.zeros((ph, pw), bool)
    # The wall itself is sea where it touches the sea (no light line along the shore).
    sea |= (arr == 1) & ndimage.binary_dilation(sea)
    kind = Image.fromarray(sea.astype(np.uint8), 'L')
    kd = ImageDraw.Draw(kind)
    for ring in water_o:
        if len(ring) > 2:
            kd.polygon([tp(*q) for q in ring], fill=1)
    for ring in water_i:
        if len(ring) > 2:
            kd.polygon([tp(*q) for q in ring], fill=0)
    for tags, pts in rivers:
        wpx = conf.RIVERS[tags['name']] / 1000 * UNITS / scale
        if wpx < 0.6:
            continue
        kd.line([tp(*q) for q in pts], fill=1, width=max(1, round(wpx)))
    kind_arr = np.asarray(kind).astype(bool) | sea
    green = Image.new('L', (pw, ph), 0)
    gd = ImageDraw.Draw(green)
    for ring in forest_o:
        if len(ring) > 2:
            gd.polygon([tp(*q) for q in ring], fill=1)
    for ring in forest_i:
        if len(ring) > 2:
            gd.polygon([tp(*q) for q in ring], fill=0)
    urban = Image.new('L', (pw, ph), 0)
    ud = ImageDraw.Draw(urban)
    cls_of = {'commercial': T_SHOP, 'retail': T_SHOP, 'industrial': T_PORT, 'port': T_PORT}
    # Coarse pictures: the big town shapes of the wide area first, then the detailed ones.
    for src in ((town_wide, town) if scale > SCALE else (town,)):
        for e in sorted(src, key=lambda e: e['tags'].get('landuse') != 'residential'):
            c = cls_of.get(e['tags'].get('landuse'), T_RES)
            ud.polygon([tp(g['lat'], g['lon']) for g in e['geometry']], fill=1 + c)
    for lat, lng, km, k in conf.CENTRES:
        x, y = tp(lat, lng)
        r = px_km(km, scale)
        pts = [(x + math.cos(t) * r * (1 + 0.12 * math.sin(3 * t + lat * 50)),
                y + math.sin(t) * r * (1 + 0.12 * math.sin(3 * t + lat * 50)))
               for t in [i / 40 * 2 * math.pi for i in range(40)]]
        ud.polygon(pts, fill=1 + (T_CBD if k == 'cbd' else T_SHOP))
    up = np.asarray(urban).copy()
    # Where OpenStreetMap has no land use (most of these cities' houses are not
    # mapped as areas): houses near the stations, suburbs further out and next
    # to the mapped towns, fields only out in the country.
    spots = np.ones((ph, pw), bool)
    for la, ln in geo.values():
        x, y = tp(la, ln)
        if 0 <= x < pw and 0 <= y < ph:
            spots[int(y), int(x)] = False
    to_st = ndimage.distance_transform_edt(spots) if not spots.all() else np.full((ph, pw), 1e9)
    near = (ndimage.distance_transform_edt(up == 0) <= px_km(0.45, scale)) | (to_st <= px_km(3.2, scale))
    dflt = np.where(to_st <= px_km(1.1, scale), 1 + T_RES, np.where(near, 1 + T_SUB, 0)).astype(np.uint8)
    fields = Image.new('L', (pw, ph), 0)
    fd = ImageDraw.Draw(fields)
    for ring in fields_o:
        if len(ring) > 2:
            fd.polygon([tp(*q) for q in ring], fill=1)
    fm = np.asarray(fields) > 0
    # The towns round the city by population (as on the Tottori map): suburbs.
    pop = Image.new('L', (pw, ph), 0)
    ppd = ImageDraw.Draw(pop)
    towns = []
    for e in places:
        t = e['tags']
        if t.get('place') not in ('city', 'town'):
            continue
        try:
            n = float(str(t.get('population', '0')).replace(',', ''))
        except ValueError:
            continue
        r = px_km(math.sqrt(n) * 0.0058, scale)
        if r >= 4:
            towns.append((tp(e['lat'], e['lon']), r, e['lat'] * 37 + e['lon'] * 11))

    def blob(x, y, r, seed):
        # A town's rough outline (as on the Tottori map), not a circle.
        return [(x + math.cos(t) * r * (1 + 0.16 * math.sin(3 * t + seed) + 0.09 * math.sin(5 * t + seed * 1.7)),
                 y + math.sin(t) * r * (1 + 0.16 * math.sin(3 * t + seed) + 0.09 * math.sin(5 * t + seed * 1.7)))
                for t in [i / 28 * 2 * math.pi for i in range(28)]]

    for k, v in ((1.0, 1), (0.6, 2)):     # suburbs, then the houses in the middle
        for (x, y), r, seed in towns:
            ppd.polygon(blob(x, y, r * k, seed), fill=v)
    pa = np.asarray(pop)
    dflt[(dflt == 0) & (pa == 1)] = 1 + T_SUB
    dflt[(dflt != 1 + T_RES) & (pa == 2)] = 1 + T_RES
    dflt[fm] = 0
    parks = Image.new('L', (pw, ph), 0)
    pd = ImageDraw.Draw(parks)
    for ring in parks_o:
        if len(ring) > 2:
            pd.polygon([tp(*q) for q in ring], fill=1)
    for ring in parks_i:
        if len(ring) > 2:
            pd.polygon([tp(*q) for q in ring], fill=0)
    sand = Image.new('L', (pw, ph), 0)
    sd = ImageDraw.Draw(sand)
    for ring in sand_o:
        if len(ring) > 2:
            sd.polygon([tp(*q) for q in ring], fill=1)
    # Hills: a soft bump round every peak, big for the high ones.
    mm = Image.new('L', (pw, ph), 0)
    md = ImageDraw.Draw(mm)
    for ele, (lat, lng) in peaks:
        if ele < 120:
            continue
        x, y = tp(lat, lng)
        r = px_km(0.35 + min(ele, 1200) / 1200 * 1.5, scale)
        if -r <= x < pw + r and -r <= y < ph + r:
            md.ellipse([x - r, y - r, x + r, y + r], fill=255)
    mblur = mm.filter(ImageFilter.GaussianBlur(px_km(0.35, scale)))
    # A height field for the shading: the higher peaks over the lower ones,
    # softened so ridges run into each other instead of round bumps.
    hm = Image.new('L', (pw, ph), 0)
    hd = ImageDraw.Draw(hm)
    for ele, (lat, lng) in sorted(peaks):
        if ele < 120:
            continue
        x, y = tp(lat, lng)
        r = px_km(0.5 + min(ele, 1500) / 1500 * 1.6, scale)
        if -r <= x < pw + r and -r <= y < ph + r:
            hd.ellipse([x - r, y - r, x + r, y + r], fill=int(60 + min(ele, 1500) / 1500 * 195))
    hblur = hm.filter(ImageFilter.GaussianBlur(px_km(0.7, scale)))
    return {'kind': kind_arr, 'green': np.asarray(green) > 0, 'urban': up, 'default': dflt, 'parks': np.asarray(parks) > 0,
            'sand': np.asarray(sand) > 0, 'mblur': mblur, 'height': hblur, 'mp': np.asarray(mblur) > 110, 'fields': fm, 'tp': tp}


SUNLIT = (250, 250, 205)


def relief(img, nat, forest, scale):
    """Soft hill shading on the woods: light from the upper left, shade below right."""
    rp = np.asarray(nat['height'], dtype=np.float32)
    dd = max(1, round(px_km(0.2, scale)))
    pad = np.pad(rp, dd, mode='edge')
    ph, pw = rp.shape
    d = pad[0:ph, 0:pw] - pad[2 * dd:2 * dd + ph, 2 * dd:2 * dd + pw]
    f = np.clip(d / 28.0, -1, 1)
    arr = np.asarray(img, dtype=np.float32).copy()
    lit = forest & (f < -0.08)
    shade = forest & (f > 0.08)
    arr[lit] += (np.array(SUNLIT, dtype=np.float32) - arr[lit]) * (0.16 * -f[lit])[:, None]
    arr[shade] *= (1 - 0.15 * f[shade])[:, None]
    img.paste(Image.fromarray(np.rint(np.clip(arr, 0, 255)).astype(np.uint8), 'RGB'))


BEACH = [(238, 224, 186), (230, 214, 172)]
AIRFIELD, AIRFIELD_DOT, APRON = (214, 228, 196), (200, 220, 182), (218, 218, 222)
RUNWAY, RUNWAY_MARK = (150, 152, 162), (244, 244, 246)


def beaches(img, nat):
    m = nat['sand'] & ~nat['kind']
    if not m.any():
        return
    px = img.load()
    ys, xs = np.nonzero(m)
    for y, x in zip(ys.tolist(), xs.tolist()):
        px[x, y] = BEACH[1] if _h(x, y, 9) % 9 == 0 else BEACH[0]


def airports(img, nat, scale):
    tp = nat['tp']
    pw, ph = img.size
    field = Image.new('L', (pw, ph), 0)
    df = ImageDraw.Draw(field)
    for e in aero:
        if 'geometry' not in e:
            continue
        t = e.get('tags', {})
        pts = [tp(g['lat'], g['lon']) for g in e['geometry']]
        if t.get('aeroway') == 'aerodrome' and t.get('aerodrome:type', '') != 'private' and len(pts) > 2 \
                and t.get('aerodrome') != 'heliport' and 'ヘリ' not in t.get('name', ''):
            df.polygon(pts, fill=1)
    for e in aero:
        if 'geometry' in e and e['tags'].get('aeroway') == 'apron' and len(e['geometry']) > 2:
            df.polygon([tp(g['lat'], g['lon']) for g in e['geometry']], fill=2)
    for e in aero:
        if 'geometry' in e and e['tags'].get('aeroway') == 'runway':
            wm = float(str(e['tags'].get('width', '45')).split()[0].replace('m', '') or 45) \
                if str(e['tags'].get('width', '45')).split()[0].replace('m', '').replace('.', '', 1).isdigit() else 45
            df.line([tp(g['lat'], g['lon']) for g in e['geometry']], fill=3,
                    width=max(1, round(wm / 1000 * UNITS / scale)))
    fa = np.asarray(field)
    if not fa.any():
        return
    px = img.load()
    water = nat['kind']
    ys, xs = np.nonzero(fa)
    for y, x in zip(ys.tolist(), xs.tolist()):
        if water[y, x]:
            continue
        v = fa[y, x]
        if v == 1:
            px[x, y] = AIRFIELD if _h(x, y, 61) % 7 else AIRFIELD_DOT
        elif v == 2:
            px[x, y] = APRON
        else:
            side = sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                       if 0 <= x + dx < pw and 0 <= y + dy < ph and fa[y + dy, x + dx] == 3)
            px[x, y] = RUNWAY_MARK if side == 4 and (x + y) % 4 < 2 else RUNWAY


def paint_ground(scale, ox, oy, pw, ph):
    nat = nature(scale, ox, oy, pw, ph)
    water = nat['kind']
    up = nat['urban']
    # Woods: the mapped forests, and the hills where no town is.
    forest = ~water & ((nat['green'] & (up == 0)) | (nat['mp'] & (up == 0) & ~nat['fields']) |
                       (nat['green'] & nat['mp']))
    parkm = ~water & ~forest & nat['parks']
    kind = np.where(water, 1, np.where(forest | parkm, T_PARK, 0)).astype(np.uint8)
    up = np.where(up > 0, up, nat['default'])
    cls = np.where(up > 0, up.astype(np.int16) - 1, T_RURAL).astype(np.uint8)
    pcls = np.where(forest, T_FOREST, np.where(parkm, T_GARDEN, 0)).astype(np.uint8)
    img = t_paint(Image.fromarray(kind, 'L'), Image.fromarray(cls, 'L'), Image.fromarray(pcls, 'L'),
                  lambda la, ln: (to_map(la, ln)[0] - ox, to_map(la, ln)[1] - oy), scale, origin=(ox, oy))
    relief(img, nat, forest, scale)
    beaches(img, nat)
    airports(img, nat, scale)
    return img, water


def save_png(img, path):
    img = img.convert('RGB')
    if img.getcolors(256) is not None:
        q = img.convert('P', palette=Image.Palette.ADAPTIVE, colors=256)
    else:
        q = img.quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    q.save(path, optimize=True)


# ---------------------------------------------------------------- landmarks
def landmark_list():
    out = []
    for f, lat, lng, name, unit in LM.LANDMARKS:
        img = f'assets/art/{C}/landmarks/{f}.png'
        if not os.path.exists(os.path.join(ROOT, img)):
            continue
        x, y = to_map(lat, lng)
        lm = {'image': img, 'x': round(x), 'y': round(y), 'name': name}
        if unit:
            lm['unit'] = unit
        out.append(lm)
    return out


def landmark_notes():
    """assets/cities/<city>/landmarks.json: a note on each and the stations to go from."""
    out = {}
    for f, lat, lng, name, unit in LM.LANDMARKS:
        about, near = LM.ABOUT[f]
        out[f] = {'about': about, 'stations': [f'{C}.{s}' for s in near]}
        for s in out[f]['stations']:
            assert s in stations, s
    return out


# ---------------------------------------------------------------- areas
def areas():
    """The ward (区) or city of each station, from OpenStreetMap's place nodes."""
    wards = [e for e in places if e['tags']['name'].endswith('区') and e['tags'].get('place') in
             ('city', 'suburb', 'quarter', 'town')]
    cities = [e for e in places if e['tags'].get('place') in ('city', 'town', 'village')]
    out = {}
    for sid, s in stations.items():
        la, ln = geo[sid]

        def d(e):
            return (e['lat'] - la) ** 2 + ((e['lon'] - ln) * 0.82) ** 2

        best = min(wards, key=d, default=None)
        if best is None or d(best) > 0.04 ** 2:
            best = min(cities, key=d, default=None)
        if not best:
            continue
        t = best['tags']
        ward = {'ja': t['name'], 'ko': t.get('name:ko', ''), 'en': t.get('name:en', '')}
        out[sid] = {'ward': {k: v for k, v in ward.items() if v}}
    return out


# ---------------------------------------------------------------- build
def main():
    os.makedirs(os.path.join(ART, 'map_tiles'), exist_ok=True)
    os.makedirs(GEN, exist_ok=True)
    scale = SCALE * (int(PREVIEW) if PREVIEW else 1)
    pw, ph = W // scale, H // scale
    print('painting', pw, 'x', ph, 'at', scale, 'units/px')
    full, water = paint_ground(scale, 0, 0, pw, ph)
    full.save(os.path.join(GEN, 'map_full.png' if not PREVIEW else 'map_preview.png'))
    if PREVIEW:
        M = OUTER_MARGIN
        outer, _ = paint_ground(OUTER_SCALE * 2, -M, -M, (W + 2 * M) // (OUTER_SCALE * 2),
                                (H + 2 * M) // (OUTER_SCALE * 2))
        outer.save(os.path.join(GEN, 'map_outer_preview.png'))
        return
    tdir = os.path.join(ART, 'map_tiles')
    for f in os.listdir(tdir):
        os.remove(os.path.join(tdir, f))
    have = []
    for ty in range(-(-full.height // TILE)):
        for tx in range(-(-full.width // TILE)):
            part = full.crop((tx * TILE, ty * TILE, min(full.width, (tx + 1) * TILE), min(full.height, (ty + 1) * TILE)))
            save_png(part, os.path.join(tdir, f'g_{tx}_{ty}.png'))
            have.append(f'{tx}_{ty}')
    ov = full.reduce(OVERVIEW_SCALE // SCALE)
    save_png(ov, os.path.join(ART, 'map_overview.png'))
    # Round the map (panned past its edge): the same ground, painted as finely
    # as the tiles and then shrunk like the overview, so the two look the same
    # where they meet (painted coarse, the woods come out darker).
    M = OUTER_MARGIN
    k = OUTER_SCALE // SCALE
    ow, oh = (W + 2 * M) // OUTER_SCALE, (H + 2 * M) // OUTER_SCALE
    outer, _ = paint_ground(SCALE, -M, -M, ow * k, oh * k)
    outer = outer.reduce(k)
    save_png(outer, os.path.join(ART, 'map_outer.png'))
    # Little glints on the open sea (well away from the shore).
    rnd = random.Random(5)
    far = ndimage.distance_transform_edt(water) * scale
    glints, tries = [], 0
    while len(glints) < 70 and tries < 200000 and far.max() > 300:
        tries += 1
        x, y = rnd.randrange(W), rnd.randrange(H)
        if far[min(y // scale, ph - 1), min(x // scale, pw - 1)] > 300:
            glints.append([x, y])
    data = {
        'size': [W, H],
        'terrain': {'image': f'assets/art/{C}/map_overview.png', 'origin': [0, 0], 'scale': OVERVIEW_SCALE,
                    'outer': {'image': f'assets/art/{C}/map_outer.png', 'origin': [-M, -M], 'scale': OUTER_SCALE},
                    'sets': [{'dir': f'assets/art/{C}/map_tiles', 'prefix': 'g_', 'origin': [0, 0], 'scale': SCALE,
                              'size': TILE, 'from': 0.12, 'have': have}]},
        'lines': out_lines,
        'landmarks': landmark_list(),
        'decor': [],
        'areas': areas(),
        'glints': glints,
    }
    json.dump(data, open(os.path.join(CITY, 'map.json'), 'w', encoding='utf8'), ensure_ascii=False,
              separators=(',', ':'))
    json.dump(landmark_notes(), open(os.path.join(CITY, 'landmarks.json'), 'w', encoding='utf8'), ensure_ascii=False,
              indent=1)
    sz = sum(os.path.getsize(os.path.join(tdir, f)) for f in os.listdir(tdir))
    print(f'{len(have)} tiles {sz / 1e6:.1f} MB, overview {ov.size}, {len(data["landmarks"])} landmarks')


if __name__ == '__main__':
    main()
