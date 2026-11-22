"""Build the Tottori–Yonago route map: station spots and straight / 45° line
paths (tools/map_layout.py, the same engine as Tokyo), and the pixel ground
painted with the Tokyo brush (tools/terrain_paint.py) from OpenStreetMap
(tools/data/osm_tottori): the Sea of Japan coast, the Tottori Sand Dunes,
Lake Koyama, Lake Togo, Nakaumi, rivers, the forested mountains with Daisen,
towns and rice fields. The ground reaches past the prefecture (Yasugi,
Matsue) so Yonago is not on the edge; the lines stay in Tottori.

Outputs assets/cities/tottori/map.json, assets/art/tottori/map_overview.png
and the zoom tiles in assets/art/tottori/map_tiles/.

  python -X utf8 tools/tottori/build_map.py           # keep the line layout
  MAP_NEW_LAYOUT=1 python -X utf8 tools/tottori/build_map.py

Data (c) OpenStreetMap contributors, ODbL.
"""
import json
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
ROOT = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
from map_layout import layout, place, relax, ride_paths, schematize  # noqa: E402
from terrain_paint import FOREST as T_FOREST, GARDEN as T_GARDEN, PARK as T_PARK  # noqa: E402
from terrain_paint import RES as T_RES, RURAL as T_RURAL, SHOP as T_SHOP, SUB as T_SUB  # noqa: E402
from terrain_paint import paint as t_paint, _h  # noqa: E402

CITY = os.path.join(ROOT, 'assets', 'cities', 'tottori')
ART = os.path.join(ROOT, 'assets', 'art', 'tottori')
OSM = os.path.join(ROOT, 'tools', 'data', 'osm_tottori')
GEN = os.path.join(ROOT, 'docs', 'art', 'gen', 'tottori')
PREVIEW = os.environ.get('MAP_PREVIEW')   # a quick, coarse run

CENTER = (35.40, 133.78)
UNITS = 55.0                  # map units per km (one flat scale: the prefecture is long, not crowded)
# The ground: Matsue / Shimane Peninsula in the west to Iwami in the east.
GROUND = (35.06, 133.02, 35.66, 134.40)
SCALE = 3                     # map units per pixel of the zoom tiles
TILE = 512
OVERVIEW_SCALE = 12
OUTER_SCALE = 12
OUTER_MARGIN = 5000            # map units of ground drawn round the map


def to_map(lat, lng):
    return ((lng - GROUND[1]) * 90.9 * UNITS, (GROUND[2] - lat) * 111.0 * UNITS)


def unproject(x, y):
    return GROUND[2] - y / (111.0 * UNITS), GROUND[1] + x / (90.9 * UNITS)


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
# Limited expresses skip long stretches of winding country track: draw them
# along the local line between their stops, however far round it goes.
from map_layout import _shortest, km as _km  # noqa: E402
_adj = {}
for _l in lines:
    if _l['dwellSec'] >= 60:
        continue
    for _a, _b in zip(_l['stations'], _l['stations'][1:]):
        _w = _km(geo[_a], geo[_b])
        _adj.setdefault(_a, set()).add((_b, _w))
        _adj.setdefault(_b, set()).add((_a, _w))
for _l in lines:
    if _l['dwellSec'] < 60:
        continue
    _seq = [_l['stations'][0]]
    for _a, _b in zip(_l['stations'], _l['stations'][1:]):
        _r = _shortest(_adj, _a, _b, 1e9, frozenset())
        _seq += (_r[1][1:] if _r else [_b])
    rides[_l['id']] = _seq
through = {}
for seq in rides.values():
    for sid in set(seq):
        through[sid] = through.get(sid, 0) + 1
half = {sid: (n - 1) / 2 * 6 for sid, n in through.items()}
order = sorted((l['id'] for l in lines), key=lambda lid: (len(rides[lid]) != len(next(
    l for l in lines if l['id'] == lid)['stations']), -len(rides[lid])))
old_path = os.path.join(CITY, 'map.json')
KEEP = os.environ.get('MAP_NEW_LAYOUT') != '1' and os.path.exists(old_path)
if KEEP:
    old = json.load(open(old_path, encoding='utf8'))
    KEEP = old.get('size') == [W, H] and {l['id'] for l in old['lines']} == {l['id'] for l in lines}
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
    pos, shape = schematize(rides, raw, order, {l['id']: False for l in lines}, eps=lambda sid: 40, half=half)
    relax(pos, shape, half)
    laid = layout(lines, pos, {l['id']: i for i, l in enumerate(lines)}, rides, shape)
    out_lines = []
    for l, line in zip(laid, lines):
        sids = line['stations']
        stops = {}
        for i, s in enumerate(sids):
            x, y = l['stops'][s]
            prev = pos[sids[i - 1]] if i > 0 else pos[s]
            nxt = pos[sids[i + 1]] if i + 1 < len(sids) else pos[s]
            dx, dy = nxt[0] - prev[0], nxt[1] - prev[1]
            # Names on the land side: the coast is to the north.
            side = ('r' if x >= cx else 'l') if abs(dy) > abs(dx) else 'b'
            stops[s] = {'x': x, 'y': y, 'label': side}
        out_lines.append({'id': l['id'], 'closed': False, 'path': l['path'], 'stops': stops})
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


coast = lines_of(load('coast'))
MAIN_RIVERS = {'千代川', '天神川', '日野川', '斐伊川'}


def _wanted_water(e):
    # Lakes, ponds, lagoons and the big rivers; not every canal and ditch of the plains.
    t = e.get('tags', {})
    if t.get('waterway') == 'riverbank' or t.get('water') in ('river', 'canal', 'stream', 'ditch', 'drain', 'moat',
                                                                  'wastewater', 'basin'):
        return t.get('name') in MAIN_RIVERS
    return True


water_o, water_i = rings_of([e for e in load('water') if _wanted_water(e)])
rivers = lines_of(load('rivers'))
forest_o, forest_i = rings_of(load('forest'))
town = load('town')
sand_o, _ = rings_of(load('sand'))
parks_o, _ = rings_of(load('parks'))
peaks = sorted(((float(str(e['tags'].get('ele', '0')).split()[0].replace('m', '') or 0), (e['lat'], e['lon']))
                for e in load('peaks') if e.get('tags', {}).get('ele')), reverse=True)
places = [e for e in load('places') if 'name' in e.get('tags', {})]
BIG_RIVERS = {'千代川', '天神川', '日野川', '斐伊川', '八東川'}


def nature(scale, ox, oy, pw, ph):
    """Water, forest, towns and mountain ground of a picture of pw x ph pixels."""
    def tp(lat, lng):
        x, y = to_map(lat, lng)
        return (x - ox) / scale, (y - oy) / scale

    K = 8 / scale
    # Sea: the coastline drawn as a wall, then filled from the open sea in the north.
    wall = Image.new('L', (pw, ph), 0)
    wd = ImageDraw.Draw(wall)
    for _, pts in coast:
        wd.line([tp(*q) for q in pts], fill=1, width=2)
    # Fill the sea from the north inside the area the coast data covers
    # only (the picture round the map reaches past it).
    arr = np.asarray(wall).copy()
    from scipy import ndimage
    gx0, gy0 = to_map(GROUND[2], GROUND[1])
    gx1, gy1 = to_map(GROUND[0], GROUND[3])
    c0, r0 = max(0, int((gx0 - ox) / scale)), max(0, int((gy0 - oy) / scale))
    c1, r1 = min(pw, int((gx1 - ox) / scale)), min(ph, int((gy1 - oy) / scale))
    sea = np.zeros((ph, pw), dtype=bool)
    sub = arr[r0:r1, c0:c1]
    lab, _ = ndimage.label(sub == 0)
    seeds = {v for v in lab[0, :].tolist() if v}
    sea[r0:r1, c0:c1] = np.isin(lab, list(seeds)) | (sub == 1)
    # Outside the area: sea in the north, land elsewhere.
    ys, xs = np.mgrid[0:ph, 0:pw]
    outside = (xs < c0) | (xs >= c1) | (ys < r0) | (ys >= r1)
    north = (oy + (ys + 0.5) * scale) < to_map(35.60, GROUND[1])[1]
    sea = np.where(outside, north, sea)
    kind = Image.fromarray(sea.astype(np.uint8), 'L')
    kd = ImageDraw.Draw(kind)
    for ring in water_o:
        if len(ring) > 2:
            kd.polygon([tp(*q) for q in ring], fill=1)
    for ring in water_i:
        if len(ring) > 2:
            kd.polygon([tp(*q) for q in ring], fill=0)
    for tags, pts in rivers:
        # Only the rivers people know by name; the thousands of mountain streams would cover the hills.
        if tags.get('name') not in BIG_RIVERS:
            continue
        # Only the river itself (OSM also names its side channels after it).
        if tags.get('waterway', 'river') != 'river' or tags.get('intermittent') == 'yes':
            continue
        main = tags['name'] != '八東川'
        kd.line([tp(*q) for q in pts], fill=1, width=max(1, round((2.2 if main else 1.2) * K / 1.33)))
    # The sea stays sea even where a river line crossed the coast wall.
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
    for e in town:
        if e['type'] != 'way' or 'geometry' not in e:
            continue
        lu = e['tags'].get('landuse')
        c = T_SHOP if lu in ('commercial', 'retail') else T_RES
        ud.polygon([tp(g['lat'], g['lon']) for g in e['geometry']], fill=1 + c)
    # The real towns by population: shops in the middle, then houses, then suburbs.
    def blob(x, y, r, seed):
        return [(x + math.cos(t) * r * (1 + 0.16 * math.sin(3 * t + seed) + 0.09 * math.sin(5 * t + seed * 1.7)),
                 y + math.sin(t) * r * (1 + 0.16 * math.sin(3 * t + seed) + 0.09 * math.sin(5 * t + seed * 1.7)))
                for t in [i / 28 * 2 * math.pi for i in range(28)]]

    for ring_k, c in ((1.0, T_SUB), (0.62, T_RES), (0.3, T_SHOP)):
        for e in places:
            t = e['tags']
            if t.get('place') not in ('city', 'town'):
                continue
            try:
                popn = float(t.get('population', '0'))
            except ValueError:
                continue
            R = math.sqrt(popn) * 0.32 / scale
            if R * ring_k < 1.5:
                continue
            x, y = tp(e['lat'], e['lon'])
            ud.polygon(blob(x, y, R * ring_k, e['lat'] * 37 + e['lon'] * 11), fill=1 + c)
    # A little town round every station, bigger where lines meet.
    for sid, (qx, qy) in pos.items():
        r = (16 + 10 * min(through.get(sid, 1), 4)) / scale
        x, y = (qx - ox) / scale, (qy - oy) / scale
        ud.ellipse([x - r, y - r, x + r, y + r], fill=1 + T_SUB)
    parks = Image.new('L', (pw, ph), 0)
    pd = ImageDraw.Draw(parks)
    for ring in parks_o:
        if len(ring) > 2:
            pd.polygon([tp(*q) for q in ring], fill=1)
    sand = Image.new('L', (pw, ph), 0)
    sd = ImageDraw.Draw(sand)
    for ring in sand_o:
        if len(ring) > 2:
            sd.polygon([tp(*q) for q in ring], fill=1)
    mm = Image.new('L', (pw, ph), 0)
    md = ImageDraw.Draw(mm)
    # Past the area the data covers: made-up hills on a jittered grid, so the
    # shading carries on into the Chugoku mountains round the map.
    fake = []
    for gy in range(-6, 14):
        for gx in range(-6, 26):
            hh = _h(gx, gy, 31)
            lat = GROUND[0] - 0.25 + gy * 0.06 + (hh % 100) / 100 * 0.04
            lng = GROUND[1] - 0.35 + gx * 0.07 + ((hh >> 8) % 100) / 100 * 0.05
            inside = GROUND[0] <= lat <= GROUND[2] and GROUND[1] <= lng <= GROUND[3]
            if not inside and lat < 35.58:
                fake.append((500 + (hh >> 16) % 900, (lat, lng)))
    for ele, (lat, lng) in peaks + fake:
        if ele < 250:
            continue
        x, y = tp(lat, lng)
        r = (3 + min(ele, 1800) / 1800 * 12) * K
        if -r <= x < pw + r and -r <= y < ph + r:
            md.ellipse([x - r, y - r, x + r, y + r], fill=255)
    mblur = mm.filter(ImageFilter.GaussianBlur(5 * K))
    return {'outside': outside, 'kind': kind, 'green': green, 'urban': urban, 'parks': parks, 'sand': sand, 'mblur': mblur,
            'mp': np.asarray(mblur) > 110, 'K': K}


SUNLIT = (250, 250, 205)
DUNE = [(236, 214, 170), (228, 203, 156), (243, 226, 188), (219, 192, 146)]   # sand, ripples, crests, shade


def relief(img, nat, forest):
    K = nat['K']
    rp = np.asarray(nat['mblur'].filter(ImageFilter.GaussianBlur(3 * K)), dtype=np.int16)
    dd = max(1, round(2 * K))
    pad = np.pad(rp, dd, mode='edge')
    ph, pw = rp.shape
    d = pad[0:ph, 0:pw] - pad[2 * dd:2 * dd + ph, 2 * dd:2 * dd + pw]
    arr = np.asarray(img, dtype=np.float32).copy()
    on = nat['mp'] & forest
    lit, shade = on & (d < -18), on & (d > 18)
    arr[lit] += (np.array(SUNLIT, dtype=np.float32) - arr[lit]) * 0.14
    arr[shade] *= 0.85
    img.paste(Image.fromarray(np.rint(arr).astype(np.uint8), 'RGB'))


def dunes(img, nat, ox, oy, scale):
    """The Tottori Sand Dunes and the sandy beaches: warm sand with wind ripples."""
    m = np.asarray(nat['sand']) > 0
    m &= np.asarray(nat['kind']) == 0
    if not m.any():
        return
    px = img.load()
    ys, xs = np.nonzero(m)
    for y, x in zip(ys.tolist(), xs.tolist()):
        mx, my = ox + x * scale, oy + y * scale
        # Ripples run across the wind (from the north-west): diagonal bands.
        band = int((mx * 0.8 + my * 0.45) / 7) + (_h(int(mx) // 23, int(my) // 23, 3) % 3)
        c = DUNE[0]
        if band % 5 == 0:
            c = DUNE[1]
        elif band % 5 == 1:
            c = DUNE[2]
        if _h(x, y, 9) % 41 == 0:
            c = DUNE[3]
        px[x, y] = c


def paint_ground(scale, ox, oy, pw, ph):
    nat = nature(scale, ox, oy, pw, ph)
    water = np.asarray(nat['kind']) == 1
    up = np.asarray(nat['urban'])
    sandm = np.asarray(nat['sand']) > 0
    # Past the area the data covers: the forested Chugoku mountains.
    forest = ~water & (up == 0) & ~sandm & ((np.asarray(nat['green']) > 0) | nat['outside'])
    parkm = ~water & ~forest & (np.asarray(nat['parks']) > 0)
    kind = np.where(water, 1, np.where(forest | parkm, T_PARK, 0)).astype(np.uint8)
    cls = np.where(up > 0, up - 1, T_RURAL).astype(np.uint8)
    pcls = np.where(forest, T_FOREST, np.where(parkm, T_GARDEN, 0)).astype(np.uint8)
    img = t_paint(Image.fromarray(kind, 'L'), Image.fromarray(cls, 'L'), Image.fromarray(pcls, 'L'),
                  lambda la, ln: (to_map(la, ln)[0] - ox, to_map(la, ln)[1] - oy), scale, origin=(ox, oy))
    relief(img, nat, forest)
    dunes(img, nat, ox, oy, scale)
    return img, water


def save_png(img, path):
    img = img.convert('RGB')
    if img.getcolors(256) is not None:
        q = img.convert('P', palette=Image.Palette.ADAPTIVE, colors=256)
    else:
        q = img.quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    q.save(path, optimize=True)


# ---------------------------------------------------------------- landmarks
LANDMARKS = [
    # (file, lat, lng, name, unit)  unit: map units per art pixel (0 = the usual size)
    ('daisen_big', 35.3712, 133.5463, {'ja': '大山', 'ko': '다이센', 'en': 'Mt. Daisen'}, 6),
    ('sakyu', 35.5414, 134.2312, {'ja': '鳥取砂丘', 'ko': '돗토리 사구', 'en': 'Tottori Sand Dunes'}, 0),
    ('jinpukaku', 35.5085, 134.2400, {'ja': '仁風閣・鳥取城跡', 'ko': '진푸카쿠·돗토리성 터', 'en': 'Jinpukaku & Tottori Castle'}, 0),
    ('hakuto', 35.5155, 134.0730, {'ja': '白兎海岸', 'ko': '하쿠토 해안', 'en': 'Hakuto Coast'}, 0),
    ('uradome', 35.5900, 134.3260, {'ja': '浦富海岸', 'ko': '우라도메 해안', 'en': 'Uradome Coast'}, 0),
    ('kurayoshi', 35.4280, 133.8240, {'ja': '倉吉 白壁土蔵群', 'ko': '구라요시 시라카베 도조군', 'en': 'Kurayoshi White-Walled Storehouses'}, 0),
    ('nageiredo', 35.3880, 133.9440, {'ja': '三徳山 投入堂', 'ko': '미토쿠산 나게이레도', 'en': 'Mitokusan Nageiredo'}, 0),
    ('sakaiminato', 35.5380, 133.2500, {'ja': '境港', 'ko': '사카이미나토 항', 'en': 'Sakaiminato Port'}, 0),
    # 2026-11-23: placed by eye on the drawn layout (clear of the lines), so the positions are near, not exact.
    ('yonago_castle', 35.4150, 133.3000, {'ja': '米子城跡', 'ko': '요나고성 터', 'en': 'Yonago Castle Ruins'}, 0),
    ('kaike', 35.4574, 133.3620, {'ja': '皆生温泉', 'ko': '가이케 온천', 'en': 'Kaike Onsen'}, 0),
    ('misasa', 35.4086, 133.8931, {'ja': '三朝温泉', 'ko': '미사사 온천', 'en': 'Misasa Onsen'}, 0),
    ('wakasa_sl', 35.3242, 134.3741, {'ja': '若桜駅のSLと転車台', 'ko': '와카사역 SL과 전차대', 'en': 'Wakasa Station Steam Engine'}, 0),
    ('koi_yamagata', 35.2603, 134.3101, {'ja': '恋山形駅', 'ko': '고이야마가타역', 'en': 'Koi-Yamagata Station'}, 0),
    ('chizu', 35.2751, 134.1841, {'ja': '智頭宿・石谷家住宅', 'ko': '지즈 역참 마을·이시타니가 주택', 'en': 'Chizu Post Town'}, 0),
    ('koyamaike', 35.4946, 134.1421, {'ja': '湖山池', 'ko': '고야마이케', 'en': 'Koyama-ike'}, 0),
    ('togo', 35.4905, 133.8631, {'ja': '東郷池・はわい温泉', 'ko': '도고 호수·하와이 온천', 'en': 'Lake Togo & Hawai Onsen'}, 0),
    ('mukibanda', 35.4569, 133.5040, {'ja': '妻木晩田遺跡', 'ko': '무키반다 유적', 'en': 'Mukibanda Yayoi Site'}, 0),
    ('eshima', 35.5180, 133.2010, {'ja': '江島大橋', 'ko': '에시마 대교', 'en': 'Eshima Bridge'}, 0),
    ('hanakairo', 35.3455, 133.3560, {'ja': 'とっとり花回廊', 'ko': '돗토리 하나카이로', 'en': 'Tottori Hanakairo Flower Park'}, 0),
    ('nagashibina', 35.3430, 134.1631, {'ja': '用瀬の流しびな', 'ko': '모치가세 나가시비나', 'en': 'Mochigase Nagashi-bina'}, 0),
    ('hokuei_wind', 35.4708, 133.7721, {'ja': '北条砂丘の風車', 'ko': '호조 사구 풍차', 'en': 'Hojo Dunes Wind Farm'}, 0),
    ('hayabusa', 35.4045, 134.3001, {'ja': '隼駅', 'ko': '하야부사역', 'en': 'Hayabusa Station'}, 0),
]


def landmark_list():
    out = []
    for f, lat, lng, name, unit in LANDMARKS:
        img = f'assets/art/tottori/landmarks/{f}.png'
        if not os.path.exists(os.path.join(ROOT, img)):
            continue
        x, y = to_map(lat, lng)
        lm = {'image': img, 'x': round(x), 'y': round(y), 'name': name}
        if unit:
            lm['unit'] = unit
        out.append(lm)
    return out


# ---------------------------------------------------------------- areas
def areas():
    cities = [e for e in places if e['tags'].get('place') in ('city', 'town', 'village')]
    out = {}
    for sid, s in stations.items():
        la, ln = geo[sid]
        best = min(cities, key=lambda e: (e['lat'] - la) ** 2 + ((e['lon'] - ln) * 0.82) ** 2, default=None)
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
    # Round the map (panned past its edge): the same ground, coarse.
    M = OUTER_MARGIN
    outer, _ = paint_ground(OUTER_SCALE, -M, -M, (W + 2 * M) // OUTER_SCALE, (H + 2 * M) // OUTER_SCALE)
    save_png(outer, os.path.join(ART, 'map_outer.png'))
    # Little glints on the open sea.
    rnd = random.Random(5)
    glints = []
    while len(glints) < 90:
        x, y = rnd.randrange(W), rnd.randrange(H // 3)
        if water[min(y // scale, ph - 1), min(x // scale, pw - 1)]:
            glints.append([x, y])
    data = {
        'size': [W, H],
        'terrain': {'image': 'assets/art/tottori/map_overview.png', 'origin': [0, 0], 'scale': OVERVIEW_SCALE,
                    'outer': {'image': 'assets/art/tottori/map_outer.png', 'origin': [-M, -M], 'scale': OUTER_SCALE},
                    'sets': [{'dir': 'assets/art/tottori/map_tiles', 'prefix': 'g_', 'origin': [0, 0], 'scale': SCALE,
                              'size': TILE, 'from': 0.12, 'have': have}]},
        'lines': out_lines,
        'landmarks': landmark_list(),
        'decor': [],
        'areas': areas(),
        'glints': [p for i, p in enumerate(glints) if i % 1 == 0],
    }
    json.dump(data, open(os.path.join(CITY, 'map.json'), 'w', encoding='utf8'), ensure_ascii=False,
              separators=(',', ':'))
    sz = sum(os.path.getsize(os.path.join(tdir, f)) for f in os.listdir(tdir))
    print(f'{len(have)} tiles {sz / 1e6:.1f} MB, overview {ov.size}, {len(data["landmarks"])} landmarks')


if __name__ == '__main__':
    main()
