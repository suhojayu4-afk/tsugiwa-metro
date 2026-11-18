"""Paint the route map's ground from real Tokyo shapes (OpenStreetMap).

build_map.py calls `build_kinds` (what each terrain pixel is: land, water,
park) and `paint` (the pixel picture). Everything is drawn in terrain
pixels (TERRAIN_SCALE map units each) after the same fish-eye projection
as the stations, so the real coast, rivers and parks sit right next to
the lines.

Look: a calm daytime pixel city in the spirit of
docs/art/ref/style_shinjuku_platform.png -- soft lavender office blocks,
warm low-rise towns with little roofs, round dark-green tree crowns,
clear water with a crisp bank. Low contrast so the coloured lines stay
the main thing.
"""
import json
import math
import os
import random

from PIL import Image, ImageDraw

from tokyo_geo import DISTRICTS, SUBURB_KM

HERE = os.path.dirname(os.path.abspath(__file__))
OSM = os.path.join(HERE, 'data', 'osm')

LAND, WATER, PARK = 0, 1, 2
# land classes
RES, SUB, SHOP, CBD, PORT, RAIL, RURAL = 0, 1, 2, 3, 4, 5, 6   # RURAL: fields with a farmhouse here and there
# park classes
LAWN, GARDEN, FOREST = 1, 2, 3


def _load(name):
    path = os.path.join(OSM, name + '.json')
    if not os.path.exists(path):
        return None
    return json.load(open(path, encoding='utf8'))


def _h(x, y, s=0):
    """Small integer hash, stable between runs."""
    n = (x * 374761393 + y * 668265263 + s * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return n ^ (n >> 16)


class Geo:
    def __init__(self, to_map, scale, w, h, center):
        self.to_map, self.scale, self.w, self.h, self.center = to_map, scale, w, h, center

    def tp(self, p):
        x, y = self.to_map(p[0], p[1])
        return (x / self.scale, y / self.scale)

    def circle(self, lat, lng, km, n=40, wobble=0.0):
        """Projected circle; [wobble] (0..1) makes the edge irregular like a real district."""
        pts = []
        for i in range(n):
            a = i / n * 2 * math.pi
            r = km * (1 + wobble * (0.6 * math.sin(a * 3 + lat * 97) + 0.4 * math.sin(a * 5 + lng * 53)))
            pts.append(self.tp((lat + math.sin(a) * r / 111.0, lng + math.cos(a) * r / 90.9)))
        return pts


def build_kinds(to_map, scale, w, h, center, fallback):
    """Return (kind, land_class, park_class) as 'L' images of w x h.

    [fallback] is the old hand-drawn kind image, used outside the OSM area."""
    g = Geo(to_map, scale, w, h, center)
    osm = {n: _load(n) for n in ('coastline', 'water', 'waterways', 'parks', 'landuse',
                                  'coastline_wide', 'water_wide', 'parks_wide', 'forest_kanto')}
    kind = fallback.copy()
    if not osm['coastline']:
        print('  (no OSM data: run tools/fetch_osm.py) -- using the hand-drawn shapes')
        return kind, Image.new('L', (w, h), RES), Image.new('L', (w, h), 0)

    def feats(name):
        """Features of a layer: the detailed centre plus the big shapes of the wide area."""
        out = list(osm[name]['features']) if osm.get(name) else []
        if osm.get(name + '_wide'):
            out += osm[name + '_wide']['features']
        if name == 'parks' and osm.get('forest_kanto'):
            # Big forests of all Kanto (Okutama, Tanzawa ...) so the hills match the outer picture.
            out += osm['forest_kanto']['features']
        return out

    # The area OSM covers: the detailed one and the wide one together
    # (the detailed coastline reaches further south, to Yokosuka).
    boxes = [osm[k]['bbox'] for k in ('coastline', 'coastline_wide') if osm.get(k)]
    s, wst = min(b[0] for b in boxes), min(b[1] for b in boxes)
    n, e = max(b[2] for b in boxes), max(b[3] for b in boxes)

    # The OSM area, as projected (its edges bend with the fish-eye).
    edge = ([(s + (n - s) * i / 100, wst) for i in range(101)] + [(n, wst + (e - wst) * i / 100) for i in range(101)] +
            [(n - (n - s) * i / 100, e) for i in range(101)] + [(s, e - (e - wst) * i / 100) for i in range(101)])
    inside = Image.new('L', (w, h), 0)
    ImageDraw.Draw(inside).polygon([g.tp(p) for p in edge], fill=1)

    # Sea: flood the bay from open water, stopped by the coastline.
    sea = Image.new('L', (w, h), 0)
    ds = ImageDraw.Draw(sea)
    ds.line([g.tp(p) for p in edge] + [g.tp(edge[0])], fill=2, width=1)
    for f in feats('coastline'):
        for ring in f['outer']:
            ds.line([g.tp(p) for p in ring], fill=2, width=1)
    for seed in ((35.620, 139.860), (35.560, 139.850), (35.600, 139.880)):
        x, y = g.tp(seed)
        if 0 <= x < w and 0 <= y < h and sea.getpixel((int(x), int(y))) == 0:
            ImageDraw.floodfill(sea, (int(x), int(y)), 1)

    osm_kind = Image.new('L', (w, h), LAND)
    dk = ImageDraw.Draw(osm_kind)
    park_cls = Image.new('L', (w, h), 0)
    dp = ImageDraw.Draw(park_cls)

    def pclass(t):
        if t.get('landuse') == 'forest' or t.get('natural') == 'wood' or t.get('amenity') == 'place_of_worship':
            return FOREST
        if t.get('landuse') in ('grass', 'recreation_ground') or t.get('leisure') == 'golf_course':
            return LAWN
        return GARDEN

    park_feats = sorted(feats('parks'), key=lambda f: pclass(f['tags']))
    for f in park_feats:
        c = pclass(f['tags'])
        for ring in f['outer']:
            if len(ring) > 2:
                pts = [g.tp(p) for p in ring]
                dk.polygon(pts, fill=PARK)
                dp.polygon(pts, fill=c)
        for ring in f['inner']:
            if len(ring) > 2:
                pts = [g.tp(p) for p in ring]
                dk.polygon(pts, fill=LAND)
                dp.polygon(pts, fill=0)
    for f in feats('water'):
        for ring in f['outer']:
            if len(ring) > 2:
                dk.polygon([g.tp(p) for p in ring], fill=WATER)
        for ring in f['inner']:
            if len(ring) > 2:
                dk.polygon([g.tp(p) for p in ring], fill=LAND)
    for f in osm['waterways']['features']:
        wpx = 2 if f['tags'].get('waterway') == 'river' else 1
        for ring in f['outer']:
            pts = [g.tp(p) for p in ring]
            # Only where no water polygon is drawn already (those are wider).
            line = Image.new('L', (w, h), 0)
            ImageDraw.Draw(line).line(pts, fill=1, width=wpx)
            bb = line.getbbox()
            if not bb:
                continue
            lp, kp = line.load(), osm_kind.load()
            for y in range(bb[1], bb[3]):
                for x in range(bb[0], bb[2]):
                    if lp[x, y] and kp[x, y] != WATER:
                        kp[x, y] = WATER
    kp, sp_, ip, fp = osm_kind.load(), sea.load(), inside.load(), kind.load()
    pcp = park_cls.load()
    for y in range(h):
        for x in range(w):
            if ip[x, y]:
                v = WATER if sp_[x, y] == 1 else kp[x, y]
                fp[x, y] = v
                if v != PARK:
                    pcp[x, y] = 0
            elif fp[x, y] == PARK:
                pcp[x, y] = GARDEN

    # Land classes: town / suburbs by distance, then OSM land use, then districts.
    cls = Image.new('L', (w, h), SUB)
    dc = ImageDraw.Draw(cls)
    dc.polygon(g.circle(center[0], center[1], SUBURB_KM, 90), fill=RES)
    if osm['landuse']:
        for f in osm['landuse']['features']:
            lu = f['tags'].get('landuse')
            c = {'industrial': PORT, 'port': PORT, 'railway': RAIL, 'commercial': SHOP, 'retail': SHOP}.get(lu)
            for ring in f['outer']:
                if c is not None and len(ring) > 2:
                    dc.polygon([g.tp(p) for p in ring], fill=c)
    for lat, lng, km, k in sorted(DISTRICTS, key=lambda d: d[3] == 'cbd'):
        dc.polygon(g.circle(lat, lng, km, 48, 0.28), fill=CBD if k == 'cbd' else SHOP)
    return kind, cls, park_cls


# ---------------------------------------------------------------- painting

ROAD, ARTERIAL = (245, 243, 236), (249, 248, 243)
SHORE_LAND, BANK = (214, 211, 204), (146, 194, 224)
WATER_C, DEEP_C, WAVE_C = (174, 213, 237), (165, 207, 234), (198, 229, 245)
LAWN_C, LAWN_DOT, LAWN_RIM = (192, 222, 158), (182, 214, 148), (160, 198, 134)
TREE = [(56, 104, 70), (84, 142, 84), (126, 182, 102), (168, 210, 128)]   # dark, mid, light, highlight
UNDERWOOD = (92, 146, 92)
ROOFS_RES = [(204, 168, 150), (176, 176, 190), (196, 186, 166), (162, 178, 194), (212, 194, 170), (186, 160, 160)]
ROOFS_SHOP = [(222, 182, 172), (190, 190, 208), (228, 214, 180), (180, 202, 216), (214, 190, 204), (236, 226, 214)]
CONTAINERS = [(196, 150, 140), (150, 172, 192), (172, 188, 160), (204, 186, 150)]
BASE = {RES: (236, 231, 221), SUB: (235, 236, 226), SHOP: (232, 226, 225), CBD: (221, 222, 233),
        PORT: (226, 227, 226), RAIL: (220, 216, 212), RURAL: (232, 236, 220)}
TARGET = {RES: 7, SUB: 9, SHOP: 5, CBD: 8, PORT: 13, RAIL: 11, RURAL: 14}
FIELD_TONES = [(226, 234, 206), (234, 232, 208), (222, 230, 200), (236, 238, 222)]
MOTORWAY, MOTORWAY_EDGE = (226, 224, 232), (196, 194, 208)
AIRPORTS = ('東京国際空港', '成田国際空港')                   # Haneda, Narita
AIRFIELD, AIRFIELD_DOT, APRON = (214, 228, 196), (200, 220, 182), (218, 218, 222)
RUNWAY, RUNWAY_MARK = (150, 152, 162), (244, 244, 246)
BRIDGE_DECK, BRIDGE_RAIL =(232, 230, 226), (104, 164, 210)   # light deck, blue steel (Eitai, Kiyosu)
SUMIDA_BRIDGES = [
    (35.6625, 139.7728),   # Kachidoki
    (35.6705, 139.7812),   # Tsukuda-ohashi
    (35.6745, 139.7845),   # Chuo-ohashi
    (35.6770, 139.7860),   # Eitai
    (35.6795, 139.7876),   # Sumida-ohashi
    (35.6825, 139.7893),   # Kiyosu
    (35.6880, 139.7900),   # Shin-ohashi
    (35.6935, 139.7882),   # Ryogoku
    (35.7015, 139.7925),   # Kuramae
    (35.7070, 139.7965),   # Komagata
    (35.7105, 139.7985),   # Azuma
    (35.7155, 139.8025),   # Kototoi
    (35.7270, 139.8115),   # Shirahige
    (35.7330, 139.8075),   # Suijin
]


def _mix(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def _blocks(w, h, clsp, rnd):
    """Split the ground into city blocks (recursive, like real streets)."""
    out = []
    stack = [(0, 0, w - 1, h - 1, 0)]
    while stack:
        x0, y0, x1, y1, depth = stack.pop()
        bw, bh = x1 - x0 + 1, y1 - y0 + 1
        c = clsp[min(w - 1, (x0 + x1) // 2), min(h - 1, (y0 + y1) // 2)]
        t = TARGET[c] * (0.8 + 0.6 * ((_h(x0, y0, 3) % 100) / 100))
        if bw < t * 1.7 and bh < t * 1.7:
            out.append((x0, y0, x1, y1, c))
            continue
        gap = 2 if max(bw, bh) > 90 else 1
        if bw >= bh:
            cut = x0 + int(bw * rnd.uniform(0.36, 0.64))
            stack.append((x0, y0, cut - 1, y1, depth + 1))
            stack.append((cut + gap, y0, x1, y1, depth + 1))
        else:
            cut = y0 + int(bh * rnd.uniform(0.36, 0.64))
            stack.append((x0, y0, x1, cut - 1, depth + 1))
            stack.append((x0, cut + gap, x1, y1, depth + 1))
    return out


def _dist_to_land(kp, w, h, cap=12):
    """Chamfer distance (pixels) from each water pixel to the nearest non-water pixel, capped."""
    INF = cap
    d = [[0 if kp[x, y] != WATER else INF for x in range(w)] for y in range(h)]
    for y in range(h):
        row, prev = d[y], d[y - 1] if y else None
        for x in range(w):
            v = row[x]
            if v:
                if x:
                    v = min(v, row[x - 1] + 1)
                if prev:
                    v = min(v, prev[x] + 1)
                row[x] = v
    for y in range(h - 1, -1, -1):
        row, nxt = d[y], d[y + 1] if y < h - 1 else None
        for x in range(w - 1, -1, -1):
            v = row[x]
            if v:
                if x < w - 1:
                    v = min(v, row[x + 1] + 1)
                if nxt:
                    v = min(v, nxt[x] + 1)
                row[x] = v
    return d


def paint(kind, cls, park_cls, to_map, scale, seed=7):
    w, h = kind.size
    kp, clsp, pcp = kind.load(), cls.load(), park_cls.load()
    rnd = random.Random(seed)
    img = Image.new('RGB', (w, h), ROAD)
    px = img.load()

    def kat(x, y):
        return kp[min(max(x, 0), w - 1), min(max(y, 0), h - 1)]

    # ---- land: streets and blocks ----
    for (x0, y0, x1, y1, c) in _blocks(w, h, clsp, rnd):
        hb = _h(x0, y0, 11)
        base = BASE[c]
        var = (hb % 7) - 3
        base = tuple(v + var for v in base)
        style = c
        if c == CBD and hb % 11 == 0:
            style = 'plaza'
        if c == PORT and hb % 5 == 0:
            style = 'yard'
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if kp[x, y] != LAND:
                    continue
                col = base
                top, left, bottom, right = y == y0, x == x0, y == y1, x == x1
                hp = _h(x, y, 5) % 100
                if style == CBD:
                    if bottom or right:
                        col = _mix(base, (180, 180, 204), 0.45)
                    elif top or left:
                        col = _mix(base, (250, 250, 255), 0.55)
                    elif (x - x0) % 2 == 1 and (y - y0) % 2 == 0:
                        col = _mix(base, (244, 246, 255), 0.35)
                elif style == 'plaza':
                    col = _mix(base, (240, 240, 244), 0.5) if not (bottom or right) else _mix(base, (190, 190, 206), 0.4)
                    if (x - x0) % 4 == 2 and (y - y0) % 4 == 2:
                        col = (150, 190, 128)                      # a planted tree on the plaza
                elif style == SHOP:
                    # Shops: small 2x2 roofs packed tight, each with a shaded lower edge.
                    lx, ly = (x - x0) % 3, (y - y0) % 3
                    if bottom or right:
                        col = _mix(base, (198, 188, 194), 0.5)
                    elif lx < 2 and ly < 2:
                        roof = ROOFS_SHOP[_h((x - x0) // 3 + x0, (y - y0) // 3 + y0, 9) % len(ROOFS_SHOP)]
                        col = _mix(base, roof, 0.42 if ly == 0 else 0.55)
                elif style == RES:
                    # Town: rows of little houses (2x1 roofs) with gardens between.
                    lx, ly = (x - x0) % 3, (y - y0) % 2
                    hid = _h((x - x0) // 3 + x0 * 7, (y - y0) // 2 + y0, 9)
                    if bottom:
                        col = _mix(base, (206, 198, 188), 0.4)
                    elif ly == 0 and lx < 2 and hid % 100 < 62:
                        col = _mix(base, ROOFS_RES[hid % len(ROOFS_RES)], 0.36)
                    elif ly == 1 and lx < 2 and hid % 100 < 62:
                        col = _mix(base, (208, 202, 194), 0.3)     # the house's shaded side
                elif style == SUB:
                    lx, ly = (x - x0) % 4, (y - y0) % 3
                    hid = _h((x - x0) // 4 + x0 * 7, (y - y0) // 3 + y0, 9)
                    if ly == 0 and lx < 2 and hid % 100 < 45:
                        col = _mix(base, ROOFS_RES[hid % len(ROOFS_RES)], 0.28)
                    elif hid % 100 > 86 and lx >= 2:
                        col = _mix(base, (196, 216, 176), 0.5)     # garden trees
                elif style == PORT:
                    if bottom or right:
                        col = _mix(base, (196, 200, 206), 0.6)
                    elif top or left:
                        col = base
                    else:
                        col = (237, 238, 237)
                elif style == 'yard':
                    col = _mix(base, CONTAINERS[((y - y0) // 2 + hb) % len(CONTAINERS)], 0.4) \
                        if (y - y0) % 2 == 0 and not (left or right) else base
                elif style == RURAL:
                    # Fields: each block one crop, in rows; a farmhouse with a tree in some.
                    tone = FIELD_TONES[hb % len(FIELD_TONES)]
                    rows = (y - y0) if hb % 2 else (x - x0)
                    col = _mix(tone, base, 0.35) if rows % 2 else tone
                    if hb % 7 == 0 and x - x0 < 2 and y - y0 < 1:
                        col = ROOFS_RES[hb % len(ROOFS_RES)]
                    elif hb % 7 == 0 and x - x0 == 2 and y - y0 < 2:
                        col = TREE[2]
                elif style == RAIL:
                    col = _mix(base, (188, 182, 180), 0.5) if (y + x // 6) % 3 == 0 else base
                px[x, y] = col
    # Streets are what is left between blocks. The 2-pixel avenues (street
    # pixels with street on both axes) are a touch brighter.
    def street(x, y):
        return 0 <= x < w and 0 <= y < h and kp[x, y] == LAND and px[x, y] in (ROAD, ARTERIAL)

    wide = [(x, y) for y in range(h) for x in range(w)
            if street(x, y) and (street(x + 1, y) or street(x - 1, y)) and (street(x, y + 1) or street(x, y - 1))]
    for x, y in wide:
        px[x, y] = ARTERIAL

    # ---- water ----
    dist = _dist_to_land(kp, w, h)
    for y in range(h):
        drow = dist[y]
        for x in range(w):
            if kp[x, y] != WATER:
                continue
            dd = drow[x]
            if dd <= 1:
                px[x, y] = BANK
            elif dd >= 10:
                px[x, y] = DEEP_C
            else:
                px[x, y] = WATER_C
    for y in range(h):
        for x in range(w - 3):
            if dist[y][x] >= 6 and _h(x, y, 21) % 260 == 0:
                for i in range(3):
                    if dist[y][x + i] >= 4:
                        px[x + i, y] = WAVE_C
                if dist[y - 1][x + 1] >= 4 if y else False:
                    px[x + 1, y - 1] = _mix(WAVE_C, WATER_C, 0.5)
    # embankment: the land pixel touching water
    for y in range(h):
        for x in range(w):
            if kp[x, y] == LAND and any(kat(x + dx, y + dy) == WATER for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = SHORE_LAND

    # ---- parks: lawn, then round tree crowns ----
    for y in range(h):
        for x in range(w):
            if kp[x, y] != PARK:
                continue
            rim = any(kat(x + dx, y + dy) != PARK for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if rim:
                px[x, y] = LAWN_RIM
            elif pcp[x, y] == FOREST:
                px[x, y] = UNDERWOOD
            else:
                px[x, y] = LAWN_DOT if _h(x, y, 31) % 9 == 0 else LAWN_C
    trees = []
    for y in range(1, h - 1, 2):
        for x in range(1, w - 1, 2):
            if kp[x, y] != PARK:
                continue
            c = pcp[x, y]
            p = {FOREST: 70, GARDEN: 30, LAWN: 6}.get(c, 30)
            if _h(x, y, 41) % 100 < p:
                jx, jy = _h(x, y, 42) % 3 - 1, _h(x, y, 43) % 3 - 1
                r = 2 + (_h(x, y, 44) % 3 == 0) if c != LAWN else 2
                trees.append((y + jy, x + jx, r))
    trees.sort()
    for (ty, tx, r) in trees:
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                d2 = dx * dx + dy * dy
                if d2 > r * r + r * 0.6:
                    continue
                x, y = tx + dx, ty + dy
                if not (0 <= x < w and 0 <= y < h) or kp[x, y] != PARK:
                    continue
                lit = (-dx - dy) / (r * 1.4)               # light from the top left
                if d2 >= r * r - 0.5 and lit < 0.2:
                    col = TREE[0]
                elif lit > 0.55 and d2 <= (r - 1) ** 2 + 1:
                    col = TREE[3]
                elif lit > 0.05:
                    col = TREE[2]
                else:
                    col = TREE[1]
                px[x, y] = col
        # a soft shadow on the ground to the lower right
        sx, sy = tx + r, ty + r
        if 0 <= sx < w and 0 <= sy < h and kp[sx, sy] == PARK and px[sx, sy] in (LAWN_C, LAWN_DOT):
            px[sx, sy] = (164, 198, 136)

    # ---- airports (Haneda, Narita): grass field, aprons, runways ----
    ap = _load('airports_wide')
    if ap:
        def poly_px(ring):
            return [(to_map(p[0], p[1])[0] / scale, to_map(p[0], p[1])[1] / scale) for p in ring]

        field = Image.new('L', (w, h), 0)
        df = ImageDraw.Draw(field)
        for f in ap['features']:
            t = f['tags']
            if t.get('aeroway') == 'aerodrome' and t.get('name') in AIRPORTS:
                for ring in f['outer']:
                    if len(ring) > 2:
                        df.polygon(poly_px(ring), fill=1)
            elif t.get('aeroway') == 'apron':
                for ring in f['outer']:
                    if len(ring) > 2:
                        df.polygon(poly_px(ring), fill=2)
        for f in ap['features']:
            if f['tags'].get('aeroway') == 'runway':
                for ring in f['outer']:
                    if len(ring) > 1:
                        df.line(poly_px(ring), fill=3, width=3)
        fp_ = field.load()
        for y in range(h):
            for x in range(w):
                v = fp_[x, y]
                if not v or kp[x, y] == WATER:
                    continue
                if v == 1:
                    px[x, y] = AIRFIELD if _h(x, y, 61) % 7 else AIRFIELD_DOT
                elif v == 2:
                    px[x, y] = APRON
                else:
                    # runway: dark edges, a white dashed centre line
                    side = sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                               if 0 <= x + dx < w and 0 <= y + dy < h and fp_[x + dx, y + dy] == 3)
                    px[x, y] = RUNWAY_MARK if side == 4 and (x + y) % 4 < 2 else RUNWAY

    # ---- bridges over the Sumida, at the real bridges ----
    def wat(x, y):
        return 0 <= x < w and 0 <= y < h and kp[x, y] == WATER

    dirs = [(1, 0), (0, 1), (1, 1), (1, -1), (2, 1), (1, 2), (2, -1), (1, -2)]
    for lat, lng in SUMIDA_BRIDGES:
        mx, my = to_map(lat, lng)
        x0, y0 = int(mx / scale), int(my / scale)
        cand = [(abs(dx) + abs(dy), x0 + dx, y0 + dy) for dy in range(-6, 7) for dx in range(-6, 7)
                if wat(x0 + dx, y0 + dy)]
        if not cand:
            continue
        _, sx, sy = min(cand)
        best = None
        for dx, dy in dirs:
            n = math.hypot(dx, dy)
            ux, uy = dx / n, dy / n
            a = b = 0
            while a < 60 and wat(round(sx + ux * (a + 1)), round(sy + uy * (a + 1))):
                a += 1
            while b < 60 and wat(round(sx - ux * (b + 1)), round(sy - uy * (b + 1))):
                b += 1
            if a < 60 and b < 60 and (best is None or a + b < best[0]):
                best = (a + b, ux, uy, a, b)
        if not best:
            continue
        _, ux, uy, a, b = best
        nx, ny = -uy, ux                                   # across the deck
        for t in range(-b - 2, a + 3):
            for side in (-1, 0, 1):
                x = round(sx + ux * t + nx * side * 0.9)
                y = round(sy + uy * t + ny * side * 0.9)
                if not (0 <= x < w and 0 <= y < h):
                    continue
                over_water = -b <= t <= a
                if side == 0:
                    px[x, y] = BRIDGE_DECK
                elif over_water:
                    px[x, y] = BRIDGE_RAIL if (t + side) % 3 else BRIDGE_DECK
        # its shadow on the water, just below
        for t in range(-b, a + 1):
            x, y = round(sx + ux * t), round(sy + uy * t + 2)
            if wat(x, y) and px[x, y] in (WATER_C, DEEP_C, BANK):
                px[x, y] = _mix(px[x, y], (90, 120, 150), 0.25)

    # ---- expressways (Shuto): faint elevated bands with a little shadow ----
    mw = _load('motorways')
    if mw:
        band = Image.new('L', (w, h), 0)
        db = ImageDraw.Draw(band)
        for f in mw['features']:
            if f['tags'].get('highway') != 'motorway':
                continue
            for ring in f['outer']:
                pts = []
                for p in ring:
                    x, y = to_map(p[0], p[1])
                    pts.append((x / scale, y / scale))
                if len(pts) > 1:
                    db.line(pts, fill=1, width=2)
        bp = band.load()
        for y in range(h - 1, -1, -1):
            for x in range(w):
                if not bp[x, y]:
                    continue
                edge = any(not bp[min(max(x + dx, 0), w - 1), min(max(y + dy, 0), h - 1)]
                           for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                under = px[x, y]
                col = _mix(under, MOTORWAY_EDGE if edge else MOTORWAY, 0.75)
                px[x, y] = col
                if y + 1 < h and not bp[x, y + 1]:
                    px[x, y + 1] = _mix(px[x, y + 1], (120, 120, 140), 0.12)
    return img
