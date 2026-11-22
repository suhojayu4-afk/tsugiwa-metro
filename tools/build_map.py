"""Build the schematic Tokyo route map: station positions, line paths,
landmarks (assets/cities/tokyo/map.json) and the flat pixel terrain
(assets/art/map_tokyo_terrain.png).

Stations are placed from their real coordinates, with the centre spread out
(a gentle "fish-eye") so the crowded middle of Tokyo stays readable. Lines
are drawn with straight and 45° segments only; where two lines run over the
same stretch, the later one is drawn alongside. The map is flat; only
landmarks are 3D art.

  python tools/build_map.py
"""
import json
import math
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CITY = os.path.join(ROOT, 'assets', 'cities', 'tokyo')
TERRAIN_SCALE = 2            # world units per terrain pixel
CENTER = (35.686, 139.760)   # around Otemachi / the Imperial Palace
UNITS = 150                  # map units per "spread" km
POWER = 0.75                 # < 1 spreads the centre, squeezes the edges
FAR = 30.0                   # km; further out (Narita) is squeezed more
MARGIN = 110

lines = json.load(open(os.path.join(CITY, 'lines.json'), encoding='utf8'))
stations = {s['id']: s for s in json.load(open(os.path.join(CITY, 'stations.json'), encoding='utf8'))}


SOFT = 0.15                  # km; keeps the spread finite right at the centre
# Beyond FAR keep the same squeeze as just inside it (no jump): squeezing the
# far east-west much harder than north-south stretched Narita into tall streaks.
FAR_RATE = POWER * (FAR + SOFT) ** (POWER - 1)


def _spread(t):
    """Map units for [t] km from the centre along one axis: wide in the centre,
    squeezed further out, and much harder beyond ~20 km (towards Narita)."""
    a = abs(t)
    if a <= FAR:
        s = (a + SOFT) ** POWER - SOFT ** POWER
    else:
        s = (FAR + SOFT) ** POWER - SOFT ** POWER + (a - FAR) * FAR_RATE
    return math.copysign(s * UNITS, t)


def project(lat, lng):
    # East-west and north-south are spread separately (not in rings round the
    # centre): straight roads, rivers and coasts stay straight-ish, so the
    # ground looks flat like the lines instead of bulging like a lens.
    dx = (lng - CENTER[1]) * 90.9
    dy = (CENTER[0] - lat) * 111.0
    return _spread(dx), _spread(dy)


raw = {sid: project(s['geo']['lat'], s['geo']['lng']) for sid, s in stations.items()
       if any(sid in l['stations'] for l in lines)}
# The map also has to hold the far landmarks (Mt. Takao west of the last
# station, Narita Airport), not only the stations.
_extent = list(raw.values()) + [project(35.6251, 139.2437), project(35.7720, 140.3929)]
min_x = min(p[0] for p in _extent) - MARGIN
# Extra room in the north too: Narita is the top-right corner of the lines.
NORTH_PAD = 120
min_y = min(p[1] for p in _extent) - MARGIN - NORTH_PAD
# Extra room on the east so Narita Airport (and its name) sits clear of the faded edge.
EAST_PAD = 180
W = int(max(p[0] for p in _extent) - min_x + MARGIN + EAST_PAD)
H = int(max(p[1] for p in _extent) - min_y + MARGIN)
W, H = W + (-W) % TERRAIN_SCALE, H + (-H) % TERRAIN_SCALE


def to_map(lat, lng):
    x, y = project(lat, lng)
    return x - min_x, y - min_y


# The detailed pixel terrain covers the Tokyo area only (Yokohama - Omiya -
# Narita - Takao); the rest of Kanto is painted coarser (outer picture).
CORE_AREA = (35.30, 139.20, 36.02, 140.42)
_core = [to_map(stations[sid]['geo']['lat'], stations[sid]['geo']['lng']) for sid in raw
         if CORE_AREA[0] <= stations[sid]['geo']['lat'] <= CORE_AREA[2]
         and CORE_AREA[1] <= stations[sid]['geo']['lng'] <= CORE_AREA[3]]
_core += [to_map(35.6251, 139.2437), to_map(35.7720, 140.3929)]
CX0 = int(min(p[0] for p in _core) - MARGIN) // TERRAIN_SCALE * TERRAIN_SCALE
CY0 = int(min(p[1] for p in _core) - MARGIN - NORTH_PAD) // TERRAIN_SCALE * TERRAIN_SCALE
CW = int(max(p[0] for p in _core) + MARGIN + EAST_PAD - CX0)
CH = int(max(p[1] for p in _core) + MARGIN - CY0)
CW, CH = CW + (-CW) % TERRAIN_SCALE, CH + (-CH) % TERRAIN_SCALE


def to_core(lat, lng):
    """Map units inside the detailed terrain picture."""
    x, y = to_map(lat, lng)
    return x - CX0, y - CY0


# Stations, express trains along the local tracks, lines side by side (map_layout.py).
from map_layout import layout, place, relax, ride_paths, schematize  # noqa: E402

_geo = {sid: (s_['geo']['lat'], s_['geo']['lng']) for sid, s_ in stations.items()}
rides = ride_paths(lines, _geo, {l['id']: l.get('group', 'other') for l in lines})
_closed = {l['id']: l['loop'] for l in lines}
# Main lines first (the Yamanote ring, then the longest), express trains last.
_order = sorted((l['id'] for l in lines),
                key=lambda lid: (lid != 'tokyo.yamanote', len(rides[lid]) != len(next(
                    l for l in lines if l['id'] == lid)['stations']), -len(rides[lid])))
# Lines through each station: the marker is that much wider (lines side by side).
_through = {}
for _seq in rides.values():
    for _sid in set(_seq):
        _through[_sid] = _through.get(_sid, 0) + 1
_half = {sid: (n - 1) / 2 * 6 for sid, n in _through.items()}
# The drawn map (assets/cities/tokyo/map.json) keeps its layout: laying the
# lines out again moves a few stations a little from run to run, and the
# seasonal spots, the landmarks and what people remember sit on the lines as
# drawn. Only the ground is painted again. MAP_NEW_LAYOUT=1 lays everything
# out afresh (after new stations or lines).
_old_path = os.path.join(CITY, 'map.json')
KEEP = os.environ.get('MAP_NEW_LAYOUT') != '1' and os.path.exists(_old_path)
if KEEP:
    _old = json.load(open(_old_path, encoding='utf8'))
    KEEP = (_old.get('size') == [W, H] and {l['id'] for l in _old['lines']} == {l['id'] for l in lines}
            and all(s in o['stops'] for l in lines for o in _old['lines'] if o['id'] == l['id'] for s in l['stations']))
    if not KEEP:
        print('the lines or the map size changed: laying the map out afresh')
cx, cy = to_map(*CENTER)
if KEEP:
    out_lines = _old['lines']
    _sum = {}
    for l in out_lines:
        for sid, st in l['stops'].items():
            a_ = _sum.setdefault(sid, [0.0, 0.0, 0])
            a_[0], a_[1], a_[2] = a_[0] + st['x'], a_[1] + st['y'], a_[2] + 1
    # A station's spot: the middle of its stops on each line.
    pos = {sid: (a_[0] / a_[2], a_[1] / a_[2]) for sid, a_ in _sum.items()}
else:
    # Real spots first pushed apart so no two station markers overlap.
    _raw = place({sid: (x - min_x, y - min_y) for sid, (x, y) in raw.items()}, _half)
    _c = to_map(*CENTER)
    # Stations may move further from their real spot in the suburbs (fewer, longer straight runs).
    pos, shape = schematize(rides, _raw, _order, _closed,
                            eps=lambda sid: 30 + 30 * min(1.0, math.dist(_raw[sid], _c) / 2500), half=_half)
    relax(pos, shape, _half)
    cx, cy = to_map(*CENTER)
    rank = {l['id']: i for i, l in enumerate(lines)}
    _laid = layout(lines, pos, rank, rides, shape)
    out_lines = []
    for l, line in zip(_laid, lines):
        sids, closed = line['stations'], line['loop']
        stops = {}
        for i, s_ in enumerate(sids):
            x, y = l['stops'][s_]
            prev = pos[sids[i - 1]] if (i > 0 or closed) else pos[s_]
            nxt = pos[sids[(i + 1) % len(sids)]] if (i + 1 < len(sids) or closed) else pos[s_]
            dx, dy = nxt[0] - prev[0], nxt[1] - prev[1]
            if abs(dy) > abs(dx):
                side = 'r' if x >= cx else 'l'
            else:
                side = 'b' if y >= cy else 't'
            stops[s_] = {'x': x, 'y': y, 'label': side}
        out_lines.append({'id': l['id'], 'closed': closed, 'path': l['path'], 'stops': stops})


def _seg_dist(p, a, b):
    ax, ay = a
    bx, by = b
    l2 = (bx - ax) ** 2 + (by - ay) ** 2
    t = 0 if l2 == 0 else max(0, min(1, ((p[0] - ax) * (bx - ax) + (p[1] - ay) * (by - ay)) / l2))
    return math.dist(p, (ax + t * (bx - ax), ay + t * (by - ay)))


segments = []
for l in out_lines:
    pts = [tuple(p) for p in l['path']] + ([tuple(l['path'][0])] if l['closed'] else [])
    segments += list(zip(pts, pts[1:]))
stop_pts = list(pos.values())

# Buckets of segments / stations, so "how close is the nearest line" stays quick with 1,000+ stations.
CELL = 64
_seg_grid, _stop_grid = {}, {}
for sg in segments:
    (ax, ay), (bx, by) = sg
    for gx in range(int(min(ax, bx) // CELL) - 1, int(max(ax, bx) // CELL) + 2):
        for gy in range(int(min(ay, by) // CELL) - 1, int(max(ay, by) // CELL) + 2):
            _seg_grid.setdefault((gx, gy), []).append(sg)
for q in stop_pts:
    _stop_grid.setdefault((int(q[0] // CELL), int(q[1] // CELL)), []).append(q)


def _near(grid, p, r):
    gx, gy = int(p[0] // CELL), int(p[1] // CELL)
    k = int(r // CELL) + 1
    for x in range(gx - k, gx + k + 1):
        for y in range(gy - k, gy + k + 1):
            yield from grid.get((x, y), ())


def near_stop(p, r=200):
    """Distance to the nearest station (capped at r)."""
    return min((math.dist(p, q) for q in _near(_stop_grid, p, r)), default=r)


def near_line(p, r=200):
    """Distance to the nearest line (capped at r)."""
    return min((_seg_dist(p, a, b) for a, b in _near(_seg_grid, p, r)), default=r)


# LINES_ONLY=1: just the lines (quick look with render_map_preview.py --plain).
if os.environ.get('LINES_ONLY'):
    json.dump({'size': [W, H], 'terrain': {'image': 'assets/art/map_tokyo_terrain.png', 'scale': TERRAIN_SCALE},
               'lines': out_lines, 'landmarks': []},
              open(os.path.join(CITY, 'map.json'), 'w', encoding='utf8'), ensure_ascii=False, indent=1)
    print('lines only:', W, 'x', H, 'units,', len(out_lines), 'lines,', len(pos), 'stations')
    raise SystemExit

# ---- pixel terrain (real shapes, same projection) ----
# Inside the map: a clean pixel picture (shorelines, trees, town texture).
# Around it: the same land and sea in big, pale pixels, so the map does not
# end at a hard rectangle.
OUTER_SCALE = 6              # world units per pixel of the rest of Kanto (and round the map)
OUTER_MARGIN = 3000          # world units of surroundings on each side

LAND, WATER, PARK = 'land', 'water', 'park'

# Tokyo Bay with the Kanagawa and Chiba coasts, far enough for the surroundings.
BAY = [(35.668, 139.772), (35.660, 139.765), (35.648, 139.757), (35.635, 139.752), (35.620, 139.748),
       (35.600, 139.745), (35.585, 139.742), (35.560, 139.748), (35.540, 139.750), (35.500, 139.700),
       (35.450, 139.650), (35.300, 139.650), (34.900, 139.700), (34.900, 139.880), (35.300, 139.900),
       (35.400, 139.950), (35.560, 140.100), (35.600, 140.100), (35.660, 140.030), (35.690, 139.975),
       (35.668, 139.945), (35.652, 139.915), (35.642, 139.890), (35.637, 139.865), (35.633, 139.840),
       (35.627, 139.815), (35.628, 139.790), (35.645, 139.785), (35.655, 139.779)]
ODAIBA = [(35.634, 139.766), (35.637, 139.800), (35.628, 139.806), (35.617, 139.796), (35.617, 139.772)]
HANEDA = [(35.566, 139.752), (35.566, 139.772), (35.560, 139.800), (35.530, 139.805), (35.522, 139.770),
          (35.530, 139.752)]
RIVERS = [  # (points, width in km)
    ([(35.665, 139.200), (35.665, 139.320), (35.655, 139.400), (35.650, 139.460), (35.640, 139.520),
      (35.625, 139.580), (35.610, 139.630), (35.590, 139.670), (35.570, 139.700), (35.550, 139.730),
      (35.545, 139.750)], 0.22),                                                                     # Tama
    ([(35.790, 139.770), (35.760, 139.795), (35.745, 139.805), (35.725, 139.802), (35.705, 139.797),
      (35.690, 139.792), (35.672, 139.786), (35.655, 139.778), (35.640, 139.772)], 0.16),            # Sumida
    ([(35.900, 139.600), (35.820, 139.700), (35.800, 139.740), (35.785, 139.770), (35.765, 139.820),
      (35.735, 139.840), (35.700, 139.850), (35.665, 139.860), (35.640, 139.862)], 0.30),            # Arakawa
    ([(35.900, 139.870), (35.760, 139.885), (35.720, 139.885), (35.690, 139.890), (35.665, 139.885)], 0.18),  # Edogawa
]
PARKS = [  # (lat, lng, rx km, ry km)
    (35.7155, 139.7735, 0.45, 0.40),   # Ueno Park
    (35.6735, 139.6975, 0.70, 0.55),   # Yoyogi / Meiji Jingu
    (35.6852, 139.7101, 0.40, 0.25),   # Shinjuku Gyoen
    (35.7040, 139.7500, 0.18, 0.15),   # Koishikawa Korakuen
    (35.6600, 139.7480, 0.20, 0.15),   # Shiba Park
]
PALACE = (35.6852, 139.7528)


def ellipse_pts(lat, lng, rx_km, ry_km, n=28):
    return [(lat + math.sin(i / n * 2 * math.pi) * ry_km / 111.0,
             lng + math.cos(i / n * 2 * math.pi) * rx_km / 90.9) for i in range(n)]


def kind_map(scale, ox, oy, w, h, detail, thin=True):
    """Paint land / water / park ids into an image, pixel = [scale] world units,
    top-left at world (ox, oy)."""
    img = Image.new('L', (w, h), 0)                 # 0 land, 1 water, 2 park
    d = ImageDraw.Draw(img)

    def tp(lat, lng):
        x, y = to_map(lat, lng)
        return (x - ox) / scale, (y - oy) / scale

    def km_px(km):
        # Width on screen for a feature [km] wide near the centre.
        return max(1, round(km * UNITS / scale))

    d.polygon([tp(*p) for p in BAY], fill=1)
    d.polygon([tp(*p) for p in HANEDA], fill=0)
    d.polygon([tp(*p) for p in ODAIBA], fill=0)
    for pts, width in RIVERS if thin else []:
        pp = [tp(*p) for p in pts]
        wpx = km_px(width)
        d.line(pp, fill=1, width=wpx)
        for p in pp:
            d.ellipse((p[0] - wpx / 2, p[1] - wpx / 2, p[0] + wpx / 2, p[1] + wpx / 2), fill=1)
    if thin:
        d.polygon([tp(*p) for p in ellipse_pts(*PALACE, 0.75, 0.75)], fill=1)   # moat
    d.polygon([tp(*p) for p in ellipse_pts(*PALACE, 0.62, 0.62)], fill=2)       # Imperial Palace
    if detail:
        for lat, lng, rx, ry in PARKS:
            d.polygon([tp(*p) for p in ellipse_pts(lat, lng, rx, ry)], fill=2)
    return img


COARSE_SCALE = 12            # map units per pixel of the rough sea map (sea_seeds)
_coarse_sea = None


def sea_seeds(scale, ox, oy, pw, ph):
    """Pixels of a picture ([pw] x [ph] of [scale] map units at map point
    (ox, oy)) that lie in open sea, well off the coast: a grid of them, from
    a rough sea map of all Kanto. A picture of only a part of Kanto floods
    its sea from these (the usual seeds may lie outside it)."""
    global _coarse_sea
    if _coarse_sea is None:
        cw_, ch_ = (W + 2 * OUTER_MARGIN) // COARSE_SCALE, (H + 2 * OUTER_MARGIN) // COARSE_SCALE
        sea = np.asarray(outer_kinds(cw_, ch_, COARSE_SCALE, -OUTER_MARGIN, -OUTER_MARGIN, lakes=False)) == 1
        _coarse_sea = ndimage.binary_erosion(sea, iterations=5)
    out = []
    step = max(6, round(150 / scale))
    for y in range(step // 2, ph, step):
        for x in range(step // 2, pw, step):
            cx_ = int((ox + x * scale + OUTER_MARGIN) / COARSE_SCALE)
            cy_ = int((oy + y * scale + OUTER_MARGIN) / COARSE_SCALE)
            if 0 <= cy_ < _coarse_sea.shape[0] and 0 <= cx_ < _coarse_sea.shape[1] and _coarse_sea[cy_, cx_]:
                out.append((x, y))
    return out


def flood_seeds(img, seeds, stroke, scale):
    """Flood [img] with 1 from each of [seeds] still 0 and not near a coast
    stroke (a seed on a small island must not drown it)."""
    if not seeds:
        return
    off = ndimage.distance_transform_edt(np.asarray(img) != stroke) * scale
    for x, y in seeds:
        if off[y, x] >= 45 and img.getpixel((x, y)) == 0:
            ImageDraw.floodfill(img, (x, y), 1)


def outer_kinds(ow, oh, scale=None, ox=None, oy=None, lakes=True):
    """Land / sea / lake of the pale surroundings, from the real Kanto coast
    (OpenStreetMap coastline_kanto + lakes_kanto): Sagami Bay, the Miura and
    Boso peninsulas, the Pacific, Kasumigaura. Falls back to the old
    hand-drawn bay when those files are missing."""
    path = os.path.join(ROOT, 'tools', 'data', 'osm')
    try:
        coast = json.load(open(os.path.join(path, 'coastline_kanto.json'), encoding='utf8'))
        lakes_on, lakes = lakes, json.load(open(os.path.join(path, 'lakes_kanto.json'), encoding='utf8'))
    except FileNotFoundError:
        return kind_map(OUTER_SCALE, -OUTER_MARGIN, -OUTER_MARGIN, ow, oh, detail=False)
    scale = scale or OUTER_SCALE
    ox = -OUTER_MARGIN if ox is None else ox
    oy = -OUTER_MARGIN if oy is None else oy

    def tp(lat, lng):
        x, y = to_map(lat, lng)
        return (x - ox) / scale, (y - oy) / scale

    s_, w_, n_, e_ = coast['bbox']
    edge = ([(s_ + (n_ - s_) * i / 200, w_) for i in range(201)] + [(n_, w_ + (e_ - w_) * i / 200) for i in range(201)]
            + [(n_ - (n_ - s_) * i / 200, e_) for i in range(201)] + [(s_, e_ - (e_ - w_) * i / 200) for i in range(201)])
    img = Image.new('L', (ow, oh), 0)
    d = ImageDraw.Draw(img)
    # Beyond the downloaded box: open sea to the south and east, land elsewhere.
    sx, _ = tp(35.0, e_)
    _, sy = tp(s_, 139.0)
    if sx < ow:
        d.rectangle([max(0, sx), 0, ow, oh], fill=1)
    if sy < oh:
        d.rectangle([0, max(0, sy), ow, oh], fill=1)
    # Beyond the box's corners, roughly the real coast: Suruga Bay to the
    # south-west, the Ibaraki / Fukushima coast to the north-east.
    # (The coast leaves the box at the mouth of the Oi, 34.777 N, and runs on to Cape Omaezaki.)
    d.polygon([tp(34.777, w_), tp(34.70, 138.262), tp(34.63, 138.235), tp(34.595, 138.225), tp(34.61, 138.17),
               tp(34.64, 138.05), tp(34.66, 137.85), tp(34.66, 137.70), tp(34.70, 136.80),
               tp(33.50, 136.80), tp(33.50, w_)], fill=1)
    d.polygon([tp(n_, 140.86), tp(37.40, 140.98), tp(37.40, e_ + 1), tp(n_, e_ + 1)], fill=1)
    d.polygon([tp(*q) for q in edge], fill=0)
    d.line([tp(*q) for q in edge] + [tp(*edge[0])], fill=3, width=1)
    for f in coast['features']:
        for ring in f['outer']:
            d.line([tp(*q) for q in ring], fill=3, width=1)
    # Flood the sea from open water: the Pacific, Sagami Bay, Tokyo Bay, off Kashima.
    for seed in ((34.70, 139.90), (35.15, 139.40), (35.50, 139.85), (36.10, 140.95), (34.85, 138.55),
                 (34.95, 138.62), (34.60, 138.40)):
        x, y = tp(*seed)
        if 0 <= x < ow and 0 <= y < oh and img.getpixel((int(x), int(y))) == 0:
            ImageDraw.floodfill(img, (int(x), int(y)), 1)
    if scale < COARSE_SCALE:
        flood_seeds(img, sea_seeds(scale, ox, oy, ow, oh), 3, scale)
    # The coastline strokes themselves: sea if next to sea, else land.
    px_ = img.load()
    for y in range(oh):
        for x in range(ow):
            if px_[x, y] == 3:
                near = [px_[x + dx, y + dy] for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                        if 0 <= x + dx < ow and 0 <= y + dy < oh]
                px_[x, y] = 1 if near.count(1) > near.count(0) else 0
    for f in lakes['features'] if lakes_on else ():
        for ring in f['outer']:
            if len(ring) > 2:
                d.polygon([tp(*q) for q in ring], fill=1)
    return img


# Full-size pictures (tools and previews only; the app loads tiles).
FULL_DIR = os.path.join(ROOT, 'docs', 'art', 'gen', 'map_full')
os.makedirs(FULL_DIR, exist_ok=True)
FULL_TERRAIN = os.path.join(FULL_DIR, 'terrain.png')
FULL_OUTER = os.path.join(FULL_DIR, 'outer.png')

# ---- the rest of Kanto: same brush as Tokyo, coarser pixels ----
# Real coast and lakes (outer_kinds), big rivers, forests and parks, towns
# round the stations and real cities by population (OSM place=city/town),
# mountains round the real peaks. paint_kanto() paints it at any scale: the
# whole-Kanto picture (OUTER_SCALE, with the margin round the map) and the
# finer tiles the app loads when zoomed in outside Tokyo (KANTO_TILE_SCALE).
from terrain_paint import BANK, ROOFS_RES, TREE, WATER_C, DEEP_C, _h  # noqa: E402
from terrain_paint import FOREST as T_FOREST, PARK as T_PARK, RURAL as T_RURAL, SUB as T_SUB  # noqa: E402
from terrain_paint import RES as T_RES, SHOP as T_SHOP  # noqa: E402
from terrain_paint import paint as t_paint  # noqa: E402
from PIL import ImageFilter  # noqa: E402
import random as _random  # noqa: E402

sys.path.insert(0, os.path.join(ROOT, 'tools'))
from landmark_flatten import flatten as flatten_  # noqa: E402

ow = (W + 2 * OUTER_MARGIN) // OUTER_SCALE
oh = (H + 2 * OUTER_MARGIN) // OUTER_SCALE
KANTO_TILE_SCALE = 3          # map units per pixel of the zoom-in tiles outside Tokyo
KANTO_TILE = 512              # tile size in pixels


def _osm(name):
    f = os.path.join(ROOT, 'tools', 'data', 'osm', name + '.json')
    return json.load(open(f, encoding='utf8'))['features'] if os.path.exists(f) else []


KDIR = os.path.join(ROOT, 'docs', 'art', 'gen', 'map_decor', 'kanto')
_sprites = {}


def _sprite(kind, i, grow=1):
    key = (kind, i, grow)
    if key not in _sprites:
        im = Image.open(os.path.join(KDIR, kind + '_pro', f'c{i}.png')).convert('RGBA')
        if grow != 1:
            im = im.resize((im.width * grow, im.height * grow), Image.NEAREST)
        _sprites[key] = im
    return _sprites[key]


PEAKY = [6, 14, 19, 29, 33, 43, 44, 51, 53, 62]   # forested mountains
ROCKY = [1, 8, 16, 21, 28, 37, 44, 55]             # high rocky ridges
LIGHTS = [12, 21, 40]


def _ele(f):
    try:
        return float(str(f['tags'].get('ele', '0')).replace('m', '').split(';')[0])
    except ValueError:
        return 0.0


def _pop(f):
    try:
        return int(str(f['tags'].get('population', '0')).replace(',', '').split(';')[0])
    except ValueError:
        return 0


_pk = {f['id']: f for f in _osm('peaks_kanto') + _osm('peaks_far')}
peaks = sorted(((_ele(f), f['outer'][0][0]) for f in _pk.values() if _ele(f) >= 250), reverse=True)
places = sorted(((_pop(f), f['outer'][0][0]) for f in _osm('places_far') if _pop(f) >= 8000))
import numpy as np  # noqa: E402
from scipy import ndimage  # noqa: E402


def unproject(x, y):
    """(lat, lng) of map point (x, y): the fish-eye of project() undone."""
    def back(u):
        a = abs(u) / UNITS
        edge = (FAR + SOFT) ** POWER - SOFT ** POWER
        t_ = (a + SOFT ** POWER) ** (1 / POWER) - SOFT if a <= edge else FAR + (a - edge) / FAR_RATE
        return math.copysign(t_, u)
    return CENTER[0] - back(y + min_y) / 111.0, CENTER[1] + back(x + min_x) / 90.9


# Where OpenStreetMap's small woods are in the data (tools/fetch_osm.py, the
# "wide" box): outside it only the big forests are known, so the fields get
# little groves of their own (see kanto_nature).
WOODS_BOX = (35.40, 139.10, 35.95, 140.50)
GROVE_CELL = 190             # map units


def kanto_nature(scale, ox, oy, pw, ph, cities=True):
    """What the ground of Kanto is, for a picture of [pw] x [ph] pixels of
    [scale] map units with its top-left at map point (ox, oy): sea, lakes and
    rivers ('kind': 1 water), forests and groves ('green'), towns ('urban':
    1 + land class) and the mountain ground round the peaks ('mp', with
    'mblur' for the relief). The Tokyo picture and the Kanto ones all use
    it, so they agree where they meet."""
    K = 8 / scale                 # sizes below were tuned at 8 units per pixel

    def otp(lat, lng):
        x, y = to_map(lat, lng)
        return (x - ox) / scale, (y - oy) / scale

    okind = outer_kinds(pw, ph, scale, ox, oy)
    odraw = ImageDraw.Draw(okind)
    for f in _osm('water_wide') + _osm('lakes_kanto'):
        for ring in f['outer']:
            if len(ring) > 2:
                odraw.polygon([otp(*q) for q in ring], fill=1)
    for f in _osm('rivers_kanto'):
        big = f['tags'].get('name') in ('利根川', '荒川', '多摩川', '相模川', '鬼怒川', '江戸川', '富士川', '那珂川')
        for ring in f['outer']:
            if len(ring) > 1:
                odraw.line([otp(*q) for q in ring], fill=1, width=max(1, round((2 if big else 1) * K / 1.33)))
    green = Image.new('L', (pw, ph), 0)
    gdraw = ImageDraw.Draw(green)
    for f in _osm('forest_kanto') + _osm('parks_wide'):
        for ring in f['outer']:
            if len(ring) > 2:
                gdraw.polygon([otp(*q) for q in ring], fill=1)
        for ring in f['inner']:
            if len(ring) > 2:
                gdraw.polygon([otp(*q) for q in ring], fill=0)

    def blob(x, y, r, seed):
        return [(x + math.cos(a) * r * (1 + 0.16 * math.sin(3 * a + seed) + 0.09 * math.sin(5 * a + seed * 1.7)),
                 y + math.sin(a) * r * (1 + 0.16 * math.sin(3 * a + seed) + 0.09 * math.sin(5 * a + seed * 1.7)))
                for a in [i / 28 * 2 * math.pi for i in range(28)]]

    # Groves between the fields (satoyama woods), where the data has only the
    # big forests: a few small woods in some cells, more of them in some
    # parts of the plain than in others. Placed in map units, so every
    # picture has the same ones.
    for gy in range(int(oy // GROVE_CELL) - 1, int((oy + ph * scale) // GROVE_CELL) + 2):
        for gx in range(int(ox // GROVE_CELL) - 1, int((ox + pw * scale) // GROVE_CELL) + 2):
            hc = _h(gx, gy, 71)
            dens = (_h(gx // 5, gy // 5, 72) % 100 + _h((gx + 2) // 3, (gy + 1) // 3, 73) % 100) / 200
            if hc % 100 >= 12 + 62 * dens:
                continue
            lat, lng = unproject((gx + 0.5) * GROVE_CELL, (gy + 0.5) * GROVE_CELL)
            if WOODS_BOX[0] <= lat <= WOODS_BOX[2] and WOODS_BOX[1] <= lng <= WOODS_BOX[3]:
                continue
            for i in range(1 + (hc >> 8) % 3):
                hh = _h(gx * 3 + i, gy * 5 - i, 74)
                mx = (gx + (hh % 1000) / 1000) * GROVE_CELL
                my = (gy + ((hh >> 10) % 1000) / 1000) * GROVE_CELL
                rx = 12 + (hh >> 20) % 26
                squash = 0.55 + ((hh >> 4) % 50) / 100
                cy_ = (my - oy) / scale
                pts = blob((mx - ox) / scale, cy_, rx / scale, hh % 628 / 100)
                gdraw.polygon([(x, cy_ + (y - cy_) * squash) for x, y in pts], fill=1)

    # Towns: a little one round every station (busier = bigger), and the
    # real cities by population: shops in the middle, then houses, then suburbs.
    urban = Image.new('L', (pw, ph), 0)
    udraw = ImageDraw.Draw(urban)
    for sid, (qx, qy) in pos.items():
        r = (34 + 10 * min(_through.get(sid, 1), 5)) / scale
        udraw.ellipse([(qx - ox) / scale - r, (qy - oy) / scale - r, (qx - ox) / scale + r, (qy - oy) / scale + r],
                      fill=1 + T_SUB)
    for ring_k, cls_ in ((1.0, T_SUB), (0.62, T_RES), (0.3, T_SHOP)) if cities else ():
        for popn, (lat, lng) in places:
            x, y = otp(lat, lng)
            R = math.sqrt(popn) * 0.33 / scale            # map units: about 170 for 270,000 people
            if R * ring_k < 1.5:
                continue
            udraw.polygon(blob(x, y, R * ring_k, lat * 37 + lng * 11), fill=1 + cls_)

    # Mountain ground: one soft area round the peaks (circles blurred together).
    mmask = Image.new('L', (pw, ph), 0)
    mdraw = ImageDraw.Draw(mmask)
    for ele, (lat, lng) in peaks:
        x, y = otp(lat, lng)
        r = (3 + min(ele, 2500) / 2500 * 10) * K
        if not (34.55 <= lat <= 36.90 and 138.30 <= lng <= 141.10):
            r *= 1.8          # no forest outlines out there: a wider green round each peak
        if -r <= x < pw + r and -r <= y < ph + r:
            mdraw.ellipse([x - r, y - r, x + r, y + r], fill=255)
    mblur = mmask.filter(ImageFilter.GaussianBlur(5 * K))
    return {'kind': okind, 'green': green, 'urban': urban, 'mblur': mblur, 'mp': np.asarray(mblur) > 110, 'K': K}


SUNLIT = (250, 250, 205)      # the sunny side of a slope: a warm light, not white


def relief(img, nat, forest):
    """Relief, softly over the trees of the mountain ground: light from the north-west."""
    K = nat['K']
    rp = np.asarray(nat['mblur'].filter(ImageFilter.GaussianBlur(3 * K)), dtype=np.int16)
    dd = max(1, round(2 * K))
    pad = np.pad(rp, dd, mode='edge')
    ph, pw = rp.shape
    d = pad[0:ph, 0:pw] - pad[2 * dd:2 * dd + ph, 2 * dd:2 * dd + pw]
    arr = np.asarray(img, dtype=np.float32).copy()
    on = nat['mp'] & forest
    lit, shade = on & (d < -18), on & (d > 18)
    arr[lit] += (np.array(SUNLIT, dtype=np.float32) - arr[lit]) * 0.13
    arr[shade] *= 0.86
    img.paste(Image.fromarray(np.rint(arr).astype(np.uint8), 'RGB'))


# The mountains everybody knows, drawn first (then the highest peaks, well
# apart): (lat, lng, rocky). The drawn spot moves a little when a line, a
# station or a landmark is in the way.
FAMOUS_PEAKS = [
    (36.2253, 140.1067, False),   # 筑波山
    (36.5603, 139.1933, False),   # 赤城山
    (36.4772, 138.8500, False),   # 榛名山
    (36.2990, 138.7480, True),    # 妙義山
    (36.4064, 138.5231, True),    # 浅間山
    (36.7650, 139.4906, False),   # 男体山
    (36.7986, 139.3758, True),    # 日光白根山
    (37.1247, 139.9631, True),    # 那須岳
    (36.8370, 138.9300, True),    # 谷川岳
    (36.8053, 139.1325, False),   # 武尊山
    (36.9000, 139.7767, False),   # 高原山
    (36.9303, 140.2717, False),   # 八溝山
    (36.0233, 138.8414, True),    # 両神山
    (35.9517, 139.0981, False),   # 武甲山
    (35.8556, 138.9439, False),   # 雲取山
    (35.7653, 139.1308, False),   # 大岳山
    (35.6525, 139.1664, False),   # 陣馬山
    (35.4744, 139.1628, False),   # 丹沢山
    (35.4408, 139.2311, False),   # 大山
    (35.2897, 139.0047, False),   # 金時山
    (35.2242, 139.0250, False),   # 箱根駒ヶ岳
    (35.2050, 138.8100, False),   # 愛鷹山
    (34.8628, 139.0019, False),   # 天城山
    (34.9031, 139.0944, False),   # 大室山
    (35.1578, 139.8358, False),   # 鋸山
    (35.1617, 140.1483, False),   # 清澄山
    (34.7244, 139.3944, True),    # 伊豆大島 三原山
    (35.9711, 138.3703, True),    # 八ヶ岳 赤岳
    (35.8714, 138.6256, True),    # 金峰山
    (35.9089, 138.7294, False),   # 甲武信ヶ岳
    (35.7483, 138.8456, False),   # 大菩薩嶺
    (35.5467, 138.8089, False),   # 三ツ峠山
    (36.5417, 138.4131, False),   # 四阿山
    (36.2053, 138.6375, False),   # 荒船山
]
_symbols = None


def symbols():
    """Mountain and lighthouse pictures on the ground: (map x, map y, kind,
    sprite number, part of its height above the spot), the same in every picture."""
    global _symbols
    if _symbols is not None:
        return _symbols
    srnd = _random.Random(19)
    # (A symbol is about 190 map units across: clear of the landmarks and the scenery.)
    lms = [(l_['x'], l_['y'], 420 if 'fuji' in l_['image'] else 200) for l_ in data['landmarks']]
    lms += [(d_['x'], d_['y'], 170) for d_ in decor_list]
    placed_m = []

    def free(q, apart):
        # Not in the detailed Tokyo picture: zoomed in that far a symbol's pixels are too big.
        if CX0 - 100 < q[0] < CX0 + CW + 100 and CY0 - 100 < q[1] < CY0 + CH + 100:
            return False
        return (near_line(q, 80) > 46 and near_stop(q, 110) > 70
                and all(math.dist(q, (lx, ly)) > lr for lx, ly, lr in lms)
                and all(math.dist(q, p_[:2]) > apart for p_ in placed_m))

    def spot(lat, lng, apart):
        x, y = to_map(lat, lng)
        for r in range(0, 261, 20):
            for a in range(0, 360, 30 if r else 360):
                q = (x + r * math.cos(math.radians(a)), y - r * math.sin(math.radians(a)))
                if free(q, apart):
                    return q
        return None

    for lat, lng, rocky in FAMOUS_PEAKS:
        q = spot(lat, lng, 230)
        if q:
            placed_m.append((q[0], q[1], 'ridge' if rocky else 'mountain',
                             srnd.choice(ROCKY if rocky else PEAKY), 0.62))
    n_famous = len(placed_m)
    for ele, (lat, lng) in peaks:
        if ele < 1200 or len(placed_m) >= n_famous + 34:
            continue
        x, y = to_map(lat, lng)
        if not (-OUTER_MARGIN < x < W + OUTER_MARGIN and -OUTER_MARGIN < y < H + OUTER_MARGIN):
            continue
        q = spot(lat, lng, 520)
        if q and math.dist(q, (x, y)) < 90:
            rocky = ele >= 2300
            placed_m.append((q[0], q[1], 'ridge' if rocky else 'mountain',
                             srnd.choice(ROCKY if rocky else PEAKY), 0.62))
    for i, (lat, lng) in enumerate([(35.7073, 140.8689), (34.9017, 139.8883), (35.2563, 139.7450),
                                    (35.1336, 139.6114), (36.3092, 140.5806)]):   # famous capes' lighthouses
        x, y = to_map(lat, lng)
        placed_m.append((x, y, 'lighthouse', LIGHTS[i % len(LIGHTS)], 0.7))
    print(f'  {n_famous} famous mountains, {len(placed_m) - n_famous - 5} high peaks, 5 lighthouses')
    _symbols = placed_m
    return _symbols


_toned_cache = {}
# The raw sprites are much darker than the ground: their light and shade are
# kept, in the map's own greens (terrain_paint.TREE) and a light rock grey.
HILL_GREENS = [(40, 84, 60), (56, 104, 70), (74, 128, 78), (98, 156, 90), (126, 182, 102), (160, 206, 124)]
HILL_ROCKS = [(98, 100, 112), (134, 134, 142), (172, 170, 168), (208, 204, 196), (234, 232, 224)]


def _ramp(v, cols):
    cols = np.array(cols, dtype=np.float32)
    t_ = np.clip(v, 0, 1) * (len(cols) - 1)
    i = np.clip(np.floor(t_).astype(int), 0, len(cols) - 2)
    f = (t_ - i)[..., None]
    return cols[i] * (1 - f) + cols[i + 1] * f


def _toned(kind, i, grow):
    """A mountain sprite in the map's soft colours."""
    key = (kind, i, grow)
    if key not in _toned_cache:
        a = np.asarray(_sprite(kind, i, grow), dtype=np.float32).copy()
        r, g, b = a[..., 0], a[..., 1], a[..., 2]
        lum = (0.3 * r + 0.59 * g + 0.11 * b) / 255
        solid = a[..., 3] > 0
        lo, hi_ = np.percentile(lum[solid], 2), np.percentile(lum[solid], 98)
        v = (lum - lo) / max(hi_ - lo, 1e-3)
        leafy = (g > r * 1.08) & (g > b * 1.08)
        a[..., :3] = np.where(leafy[..., None], _ramp(np.clip(v, 0, 1) ** 1.3, HILL_GREENS), _ramp(v, HILL_ROCKS))
        _toned_cache[key] = Image.fromarray(np.rint(a).astype(np.uint8), 'RGBA')
    return _toned_cache[key]


def paste_symbols(o, scale, ox, oy):
    """The mountain and lighthouse pictures of symbols() on picture [o]: one
    sprite pixel is OUTER_SCALE map units whatever the picture's scale."""
    grow = max(1, round(OUTER_SCALE / scale))
    for mx, my, kind, i, up in sorted(symbols(), key=lambda s_: s_[1]):
        im = _sprite(kind, i, grow) if kind == 'lighthouse' else _toned(kind, i, grow)
        x, y = (mx - ox) / scale, (my - oy) / scale
        if -im.width < x < o.width + im.width and -im.height < y < o.height + im.height:
            o.paste(im, (int(x - im.width / 2), int(y - im.height * up)), im)


def paint_kanto(scale, ox, oy, pw, ph):
    """All of Kanto painted at [scale] map units per pixel, picture top-left
    at map point (ox, oy), [pw] x [ph] pixels."""
    nat = kanto_nature(scale, ox, oy, pw, ph)
    water = np.asarray(nat['kind']) == 1
    up = np.asarray(nat['urban'])
    # Towns and cities win over forest (they sit in valleys).
    forest = ~water & (up == 0) & ((np.asarray(nat['green']) > 0) | nat['mp'])
    kind = np.where(water, 1, np.where(forest, T_PARK, 0)).astype(np.uint8)
    cls = np.where(up > 0, up - 1, T_RURAL).astype(np.uint8)
    pcls = np.where(forest, T_FOREST, 0).astype(np.uint8)
    o = t_paint(Image.fromarray(kind, 'L'), Image.fromarray(cls, 'L'), Image.fromarray(pcls, 'L'),
                lambda la, ln: (to_map(la, ln)[0] - ox, to_map(la, ln)[1] - oy), scale, origin=(ox, oy))
    relief(o, nat, forest)
    paste_symbols(o, scale, ox, oy)
    print(f'  Kanto at {scale} units/px: {pw}x{ph}, {len(places)} towns by population')
    return o


# ---- the detailed Tokyo picture ----
RURAL_FROM_KM = 18            # nearer the centre than this, everything is town
NATURE_PAD = 64               # pixels painted round a picture so blurs agree at its edge


def _km_from_centre(ox, oy, w_, h_, scale):
    """Distance (km) from the centre of every pixel, the fish-eye undone."""
    def back(u):
        a = np.abs(u) / UNITS
        edge = (FAR + SOFT) ** POWER - SOFT ** POWER
        return np.where(a <= edge, (a + SOFT ** POWER) ** (1 / POWER) - SOFT, FAR + (a - edge) / FAR_RATE)
    kx = back(ox + np.arange(w_) * scale + min_x)
    ky = back(oy + np.arange(h_) * scale + min_y)
    return np.hypot(kx[None, :], ky[:, None])


def core_ground(ox, oy, w_, h_):
    """What every pixel of the detailed picture is (land / water / park, the
    land and park classes), for the window of [w_] x [h_] pixels at map point
    (ox, oy): the real shapes from OpenStreetMap where we have them
    (terrain_paint.build_kinds), and the ground of all Kanto (kanto_nature)
    round them - its coast, lakes, mountain forests and fields - so the
    picture runs into the Kanto one without a seam."""
    P = NATURE_PAD
    nat = kanto_nature(TERRAIN_SCALE, ox - P * TERRAIN_SCALE, oy - P * TERRAIN_SCALE, w_ + 2 * P, h_ + 2 * P,
                       cities=False)
    box = (P, P, P + w_, P + h_)
    nat = {k_: (v.crop(box) if isinstance(v, Image.Image) else v[P:P + h_, P:P + w_] if isinstance(v, np.ndarray)
                else v) for k_, v in nat.items()}

    def to_win(lat, lng):
        x, y = to_map(lat, lng)
        return x - ox, y - oy

    kind_i, cls_i, pcls_i = build_kinds(to_win, TERRAIN_SCALE, w_, h_, CENTER, nat['kind'].copy(),
                                        seeds=sea_seeds(TERRAIN_SCALE, ox, oy, w_, h_))
    kind, cls, pcls = np.array(kind_i), np.array(cls_i), np.array(pcls_i)
    # Inside the area with OpenStreetMap's own woods and parks only the
    # mountain ground is added; outside it, the Kanto forests and groves too.
    b = WOODS_BOX
    edge = ([(b[0] + (b[2] - b[0]) * i / 60, b[1]) for i in range(61)]
            + [(b[2], b[1] + (b[3] - b[1]) * i / 60) for i in range(61)]
            + [(b[2] - (b[2] - b[0]) * i / 60, b[3]) for i in range(61)]
            + [(b[0], b[3] - (b[3] - b[1]) * i / 60) for i in range(61)])
    woods = Image.new('L', (w_, h_), 0)
    ImageDraw.Draw(woods).polygon([(x / TERRAIN_SCALE, y / TERRAIN_SCALE) for x, y in (to_win(*q) for q in edge)],
                                  fill=1)
    known = np.asarray(woods) > 0
    km = _km_from_centre(ox, oy, w_, h_, TERRAIN_SCALE)
    far = np.ones((h_, w_), dtype=bool)
    for qx, qy in pos.values():
        x, y = int((qx - ox) / TERRAIN_SCALE), int((qy - oy) / TERRAIN_SCALE)
        if 0 <= x < w_ and 0 <= y < h_:
            far[y, x] = False
    # Map units to the nearest station (of this window: fine for the whole picture).
    to_stop = ndimage.distance_transform_edt(far) * TERRAIN_SCALE if not far.all() else np.full((h_, w_), 1e6)
    town = np.asarray(nat['urban']) > 0
    open_land = (kind == 0) & (cls == T_SUB) & ~town & (km > RURAL_FROM_KM - 4)
    forest = open_land & (nat['mp'] | ((np.asarray(nat['green']) > 0) & ~known))
    # Fields where no station is near: everything is town up to RURAL_FROM_KM,
    # then the towns shrink to the stations' own (as in the Kanto picture).
    reach = np.interp(km, [RURAL_FROM_KM, RURAL_FROM_KM + 16], [420, 105])
    rural = open_land & ~forest & (km > RURAL_FROM_KM) & (to_stop > reach)
    kind[forest], pcls[forest] = T_PARK, T_FOREST
    cls[rural] = T_RURAL
    nat['forest'] = (kind == T_PARK) & (pcls == T_FOREST)
    return Image.fromarray(kind, 'L'), Image.fromarray(cls, 'L'), Image.fromarray(pcls, 'L'), nat


def core_picture(ox, oy, ground):
    """The detailed picture painted from core_ground()."""
    kind_i, cls_i, pcls_i, nat = ground
    t_ = paint(kind_i, cls_i, pcls_i, lambda la, ln: (to_map(la, ln)[0] - ox, to_map(la, ln)[1] - oy),
               TERRAIN_SCALE, origin=(ox, oy))
    relief(t_, nat, nat['forest'])
    paste_symbols(t_, TERRAIN_SCALE, ox, oy)
    return t_


FADE = 70                     # pixels of the Tokyo picture that run into the Kanto one


def fade_core(part, under, ax, ay, ux, uy):
    """[part] (the Tokyo picture, or a window of it with its top-left at map
    point (ax, ay)) with its last FADE pixels towards the edge of the whole
    Tokyo picture blended into [under] (Kanto at KANTO_TILE_SCALE, top-left
    at map point (ux, uy))."""
    pw_, ph_ = part.size
    gx = (ax - CX0) / TERRAIN_SCALE + np.arange(pw_)        # pixel in the whole Tokyo picture
    gy = (ay - CY0) / TERRAIN_SCALE + np.arange(ph_)
    dx = np.minimum(gx, CW / TERRAIN_SCALE - 1 - gx)
    dy = np.minimum(gy, CH / TERRAIN_SCALE - 1 - gy)
    a = np.clip(np.minimum(dx[None, :], dy[:, None]) / FADE, 0, 1)[..., None]
    u = np.asarray(under.convert('RGB'), dtype=np.float32)
    sx = np.clip(((ax + np.arange(pw_) * TERRAIN_SCALE - ux) / KANTO_TILE_SCALE).astype(int), 0, u.shape[1] - 1)
    sy = np.clip(((ay + np.arange(ph_) * TERRAIN_SCALE - uy) / KANTO_TILE_SCALE).astype(int), 0, u.shape[0] - 1)
    low = u[sy][:, sx]
    top = np.asarray(part.convert('RGB'), dtype=np.float32)
    return Image.fromarray(np.rint(low + (top - low) * a).astype(np.uint8), 'RGB')



# What every terrain pixel is (land / water / park), from the real shapes in
# OpenStreetMap (tools/fetch_osm.py) where we have them, the ground of all
# Kanto further out (core_ground).
from terrain_paint import build_kinds, paint  # noqa: E402

w, h = CW // TERRAIN_SCALE, CH // TERRAIN_SCALE
PREVIEW = os.environ.get('MAP_PREVIEW')
if PREVIEW:
    # Only a look at some places (see below the decorations): no full picture.
    core_all = None
    kind_img = Image.new('L', (w, h), 0)
else:
    core_all = core_ground(CX0, CY0, w, h)
    kind_img = core_all[0]
k = base = kind_img.load()


placed_lms = []


def clearance(p, gap=34):
    d1 = near_stop(p)
    d2 = near_line(p)
    d3 = min((math.dist(p, q) - 50 for q in placed_lms), default=1e9)   # keep landmarks apart
    return min(d1 - gap, d2, d3)   # leave room for the station's name


def _in_poly(pt, poly):
    x, y = pt
    inside = False
    for (x1, y1), (x2, y2) in zip(poly, poly[1:] + poly[:1]):
        if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
            inside = not inside
    return inside


def on_water(p):
    x, y = int((p[0] - CX0) / TERRAIN_SCALE), int((p[1] - CY0) / TERRAIN_SCALE)
    return 0 <= x < w and 0 <= y < h and k[x, y] == 1


def lm(file, lat, lng, name, water=False, reach=110, gap=34, pin=None):
    """Landmark near its real place, moved to the emptiest spot within
    [reach] so it never covers a station or a line. Landmarks that belong
    right next to a station (Tokyo Station, Kaminarimon) use a short reach
    and a small [gap]."""
    if pin:
        # Pinned beside a station: (station id, dx, dy) in map units.
        sx, sy = pos[pin[0]]
        best = (sx + pin[1], sy + pin[2])
        placed_lms.append(best)
        return {'image': f'assets/art/landmarks/{file}', 'x': round(best[0]), 'y': round(best[1]), 'name': name}
    x0, y0 = to_map(lat, lng)
    best, score = (x0, y0), -1e9
    for dx in range(-reach, reach + 1, 6):
        for dy in range(-reach, reach + 1, 6):
            p = (x0 + dx, y0 + dy)
            if not water and on_water(p):
                continue
            c = min(clearance(p, gap), 48)
            sc = c * 3 - math.hypot(dx, dy) * 0.25
            if sc > score:
                best, score = p, sc
    placed_lms.append(best)
    return {'image': f'assets/art/landmarks/{file}', 'x': round(best[0]), 'y': round(best[1]), 'name': name}


landmarks = [
    # Next to their station first (short reach), then the rest.
    # The red-brick building faces the Imperial Palace (Marunouchi side).
    lm('station.png', 35.6812, 139.7660, {'ja': '東京駅', 'ko': '도쿄역', 'en': 'Tokyo Station'},
       reach=42, gap=10),
    lm('kaminarimon.png', 35.7111, 139.7963, {'ja': '雷門', 'ko': '가미나리몬', 'en': 'Kaminarimon'}, reach=60, gap=16),
    lm('dome.png', 35.7056, 139.7519, {'ja': '東京ドーム', 'ko': '도쿄돔', 'en': 'Tokyo Dome'}, reach=60, gap=16),
    lm('nijubashi.png', 35.6800, 139.7505, {'ja': '皇居・二重橋', 'ko': '고쿄 니주바시', 'en': 'Imperial Palace'}),
    lm('tower.png', 35.6586, 139.7454, {'ja': '東京タワー', 'ko': '도쿄타워', 'en': 'Tokyo Tower'}),
    lm('skytree.png', 35.7101, 139.8107, {'ja': 'スカイツリー', 'ko': '스카이트리', 'en': 'Skytree'}, reach=70, gap=20),
    lm('kokugikan.png', 35.6969, 139.7932, {'ja': '両国国技館', 'ko': '료고쿠 국기관', 'en': 'Ryogoku Kokugikan'}, reach=70, gap=20),
    lm('akihabara.png', 35.6984, 139.7731, {'ja': '秋葉原電気街', 'ko': '아키하바라 전자상가', 'en': 'Akihabara'}, reach=70, gap=20),
    lm('tocho.png', 35.6896, 139.6917, {'ja': '東京都庁', 'ko': '도쿄도청', 'en': 'Tokyo Metropolitan Gov.'}, reach=80, gap=20),
    lm('sunshine.png', 35.7289, 139.7186, {'ja': 'サンシャイン60', 'ko': '선샤인 60', 'en': 'Sunshine 60'}, reach=80, gap=20),
    lm('shibuya.png', 35.6595, 139.7005, {'ja': '渋谷スクランブル交差点', 'ko': '시부야 스크램블 교차로', 'en': 'Shibuya Crossing'}, reach=80, gap=20),
    lm('meiji.png', 35.6764, 139.6993, {'ja': '明治神宮', 'ko': '메이지 신궁', 'en': 'Meiji Jingu'}, reach=80, gap=20),
    lm('ferris.png', 35.6255, 139.7756, {'ja': 'お台場', 'ko': '오다이바', 'en': 'Odaiba'}, reach=70, gap=20),
    lm('bigsight.png', 35.6298, 139.7942, {'ja': '東京ビッグサイト', 'ko': '도쿄 빅사이트', 'en': 'Tokyo Big Sight'}, reach=70, gap=20),
    lm('rainbow.png', 35.6365, 139.7631, {'ja': 'レインボーブリッジ', 'ko': '레인보우 브리지', 'en': 'Rainbow Bridge'}, water=True),
    lm('airport.png', 35.5494, 139.7798, {'ja': '羽田空港', 'ko': '하네다 공항', 'en': 'Haneda Airport'}),
    lm('narita.png', 35.7720, 140.3929, {'ja': '成田空港', 'ko': '나리타 공항', 'en': 'Narita Airport'}),
    lm('takao.png', 35.6251, 139.2437, {'ja': '高尾山', 'ko': '다카오산', 'en': 'Mt. Takao'}),
    # Batch C (2026-11-18): placed after the others so those keep their spots.
    lm('ueno.png', 35.7148, 139.7730, {'ja': '上野公園', 'ko': '우에노 공원', 'en': 'Ueno Park'}, reach=70, gap=20),
    # Inside Senso-ji, just north of Kaminarimon: a short reach keeps it there.
    lm('pagoda.png', 35.7148, 139.7966, {'ja': '浅草寺 五重塔', 'ko': '센소지 오층탑', 'en': 'Senso-ji Pagoda'},
       reach=30, gap=12),
    lm('wako.png', 35.6717, 139.7650, {'ja': '銀座 和光', 'ko': '긴자 와코', 'en': 'Ginza Wako'}, reach=60, gap=16),
    lm('roppongi.png', 35.6604, 139.7292, {'ja': '六本木ヒルズ', 'ko': '롯폰기힐스', 'en': 'Roppongi Hills'},
       reach=70, gap=20),
    lm('toyosu.png', 35.6450, 139.7845, {'ja': '豊洲市場', 'ko': '도요스 시장', 'en': 'Toyosu Market'}, reach=60, gap=20),
    lm('gatebridge.png', 35.6135, 139.8370, {'ja': '東京ゲートブリッジ', 'ko': '도쿄 게이트브리지', 'en': 'Tokyo Gate Bridge'},
       water=True, reach=70),
    # All of Kanto (2026-11-19): only the very famous sights.
    lm('fuji.png', 35.3606, 138.7274, {'ja': '富士山', 'ko': '후지산', 'en': 'Mt. Fuji'}),
    lm('daibutsu.png', 35.3168, 139.5358, {'ja': '鎌倉大仏', 'ko': '가마쿠라 대불', 'en': 'Great Buddha of Kamakura'},
       reach=70, gap=20),
    lm('enoshima.png', 35.2994, 139.4803, {'ja': '江の島', 'ko': '에노시마', 'en': 'Enoshima'}, water=True, reach=70),
    lm('hakone.png', 35.2045, 139.0258, {'ja': '箱根 平和の鳥居', 'ko': '하코네 평화의 도리이', 'en': 'Hakone Torii'}),
    lm('minatomirai.png', 35.4550, 139.6315, {'ja': 'みなとみらい', 'ko': '미나토미라이', 'en': 'Minato Mirai'},
       reach=70, gap=20),
    lm('chinatown.png', 35.4425, 139.6460, {'ja': '横浜中華街', 'ko': '요코하마 중화가', 'en': 'Yokohama Chinatown'},
       reach=70, gap=20),
    lm('kawagoe.png', 35.9205, 139.4853, {'ja': '川越 時の鐘', 'ko': '가와고에 시간의 종', 'en': 'Kawagoe Bell Tower'},
       reach=70, gap=20),
    lm('naritasan.png', 35.7860, 140.3180, {'ja': '成田山新勝寺', 'ko': '나리타산 신쇼지', 'en': 'Naritasan Shinshoji'},
       reach=70, gap=20),
    lm('chureito.png', 35.5013, 138.8017, {'ja': '新倉山浅間公園', 'ko': '아라쿠라야마 센겐 공원', 'en': 'Chureito Pagoda'}),
    # An original theme park (no real park's design): the Maihama resort area.
    lm('themepark.png', 35.6329, 139.8804, {'ja': '舞浜リゾート', 'ko': '마이하마 리조트', 'en': 'Maihama Resort'},
       reach=70, gap=20),
    # Round the north and east (2026-11-19).
    lm('nikko.png', 36.7580, 139.5990, {'ja': '日光東照宮', 'ko': '닛코 도쇼구', 'en': 'Nikko Toshogu'}, reach=70, gap=20),
    lm('hitachi.png', 36.4020, 140.5920, {'ja': '国営ひたち海浜公園', 'ko': '히타치 해변공원', 'en': 'Hitachi Seaside Park'},
       reach=70, gap=20),
    lm('ashikaga.png', 36.3150, 139.5200, {'ja': 'あしかがフラワーパーク', 'ko': '아시카가 플라워파크',
                                          'en': 'Ashikaga Flower Park'}, reach=70, gap=20),
    lm('tomioka.png', 36.2550, 138.8880, {'ja': '富岡製糸場', 'ko': '도미오카 제사장', 'en': 'Tomioka Silk Mill'},
       reach=70, gap=20),
    lm('oarai.png', 36.3460, 140.5970, {'ja': '大洗磯前神社 神磯の鳥居', 'ko': '오아라이 가미이소 도리이',
                                       'en': 'Oarai Torii'}, water=True, reach=70),
    lm('kusatsu.png', 36.6227, 138.5966, {'ja': '草津温泉 湯畑', 'ko': '구사쓰 온천 유바타케', 'en': 'Kusatsu Onsen'},
       reach=70, gap=20),
    lm('karuizawa.png', 36.3540, 138.6290, {'ja': '軽井沢', 'ko': '가루이자와', 'en': 'Karuizawa'}, reach=70, gap=20),
    lm('hachimangu.png', 35.3259, 139.5563, {'ja': '鶴岡八幡宮', 'ko': '쓰루가오카 하치만구', 'en': 'Tsurugaoka Hachimangu'},
       reach=70, gap=20),
    lm('atami.png', 35.0960, 139.0770, {'ja': '熱海', 'ko': '아타미', 'en': 'Atami'}, reach=70, gap=20),
]

data = {
    'size': [W, H],
    'terrain': {'image': 'assets/art/map_tokyo_terrain.png', 'scale': TERRAIN_SCALE, 'origin': [CX0, CY0],
                'outer': {'image': 'assets/art/map_tokyo_outer.png', 'origin': [-OUTER_MARGIN, -OUTER_MARGIN],
                          'scale': OUTER_SCALE}},
    'lines': out_lines,
    'landmarks': landmarks,
}
if KEEP:
    # Landmarks stay where they stand (a new one takes the spot found above).
    _by_name = {l_['name']['ja']: l_ for l_ in _old['landmarks']}
    landmarks = data['landmarks'] = [_by_name.get(l_['name']['ja'], l_) for l_ in landmarks]
    placed_lms[:] = [(l_['x'], l_['y']) for l_ in landmarks]


DECOR = os.path.join(ROOT, 'docs', 'art', 'gen', 'map_decor')

# ---- decorations ----
# Small PixelLab pictures, each standing where that kind of place really is
# in Tokyo (docs/art/gen/map_decor; candidates in map_decor/v2). Several
# variants per kind so neighbours do not look copied.
import random  # noqa: E402

rnd = random.Random(7)
DECOR_NAMES = ('towers', 'sailboat', 'ferry',
               'houses_a', 'houses_b', 'houses_c', 'mansion_a', 'mansion_b', 'mansion_c',
               'shops_a', 'shops_b', 'shops_c', 'shrine_a', 'shrine_b', 'temple_a', 'temple_b',
               'sakura_a', 'sakura_b', 'sakura_c', 'momiji_a', 'momiji_b', 'momiji_c',
               'green_a', 'green_b', 'green_c',
               'onsen_a', 'onsen_b', 'whale_a', 'whale_b', 'surfer_a', 'surfer_b', 'steam_a', 'steam_b',
               'ropeway_a', 'ropeway_b', 'cablecar_a', 'cablecar_b')
decor = {n: Image.open(os.path.join(DECOR, n + '.png')).convert('RGBA') for n in DECOR_NAMES}
placed = []
decor_list = []


def free_spot(x, y, r, need, line_gap=None, size=None):
    """Terrain-pixel spot (where the picture stands) is free for a decoration
    [size] pixels wide (default 4 r) on [need] ground. A decoration pixel is
    one terrain pixel, and the app draws the picture from 3/4 of its height
    above the spot, so its visual centre is a little higher."""
    size = size or r * 4
    if not (r <= x < w - r and r <= y < h - r):
        return False
    if any(base[min(max(int(x + dx), 0), w - 1), min(max(int(y + dy), 0), h - 1)] not in need
           for dx in (-r, 0, r) for dy in (-r, 0, r)):
        return False
    gap = line_gap if line_gap is not None else max(22, size * TERRAIN_SCALE * 0.42)
    vy = y - size * 0.25
    for px_, py_ in ((x, y), (x, vy)):
        wx, wy = px_ * TERRAIN_SCALE + CX0, py_ * TERRAIN_SCALE + CY0
        if near_stop((wx, wy), 60) < 46:
            return False
        if near_line((wx, wy), gap + 10) < gap:
            return False
        if any(math.dist((wx, wy), q) < 60 + size for q in placed_lms):
            return False
    return all(math.dist((x, vy), (qx, qy)) > (size + qs) / 2 * 0.85 for qx, qy, qs in placed)


def put(name, x, y):
    size = decor[name].width
    placed.append((x, y - size * 0.25, size))
    # Drawn by the app (only when zoomed in), standing on this spot.
    decor_list.append({'image': f'assets/art/map_decor/{name}.png',
                       'x': round(x * TERRAIN_SCALE + CX0), 'y': round(y * TERRAIN_SCALE + CY0)})


def scatter(name, count, need, tries=4000):
    r = decor[name].width // 2
    n = 0
    for _ in range(tries):
        if n >= count:
            break
        x, y = rnd.uniform(0, w), rnd.uniform(0, h)
        if free_spot(x, y, r // 2, need):
            put(name, x, y)
            n += 1


def scatter_near(names, spots, reach_px, need):
    """One decoration near each real (lat, lng) spot, in the nearest free place.
    [names] are variants used in turn."""
    if isinstance(names, str):
        names = [names]
    for i, (lat, lng) in enumerate(spots):
        name = names[i % len(names)]
        r = decor[name].width // 2
        x0, y0 = to_core(lat, lng)
        x0, y0 = x0 / TERRAIN_SCALE, y0 / TERRAIN_SCALE
        cands = sorted(((x0 + dx, y0 + dy) for dx in range(-reach_px, reach_px + 1, 3)
                        for dy in range(-reach_px, reach_px + 1, 3)), key=lambda q: math.dist(q, (x0, y0)))
        for x, y in cands:
            if free_spot(x, y, r // 2, need):
                put(name, x, y)
                break


if not KEEP:
    ccx, ccy = cx / TERRAIN_SCALE, cy / TERRAIN_SCALE
    ANY_GROUND = {0, 2}
    # Office towers where Tokyo's business districts really are.
    scatter_near('towers', [(35.6905, 139.6950), (35.6640, 139.7610), (35.6605, 139.7300), (35.7300, 139.7110),
                            (35.6260, 139.7430), (35.6540, 139.7930), (35.6860, 139.7660), (35.6950, 139.8150)],
                 60, {0})
    # Cherry blossoms: the famous hanami spots.
    scatter_near(['sakura_a', 'sakura_b', 'sakura_c'],
                 [(35.7140, 139.7720), (35.6905, 139.7445), (35.7140, 139.8030), (35.6440, 139.6990),
                  (35.6850, 139.7110), (35.6720, 139.6940), (35.7000, 139.5740), (35.7520, 139.7380),
                  (35.6660, 139.7230), (35.7330, 139.7470), (35.6100, 139.7330)], 30, ANY_GROUND)
    # Shrines and temples.
    scatter_near(['shrine_a', 'shrine_b'],
                 [(35.6942, 139.7437), (35.7020, 139.7680), (35.7202, 139.7605), (35.6747, 139.7395),
                  (35.6717, 139.7997), (35.6935, 139.7050), (35.7078, 139.7680), (35.7030, 139.8200),
                  (35.6560, 139.7540), (35.6195, 139.7425), (35.7520, 139.7390)], 30, ANY_GROUND)
    scatter_near(['temple_a', 'temple_b'],
                 [(35.6575, 139.7484), (35.6380, 139.7395), (35.7180, 139.7270), (35.7230, 139.7710),
                  (35.7590, 139.8780), (35.5800, 139.7040), (35.6665, 139.7720), (35.6490, 139.6470),
                  (35.6700, 139.5480)], 30, ANY_GROUND)
    # Shopping streets (shotengai).
    scatter_near(['shops_a', 'shops_b', 'shops_c'],
                 [(35.6717, 139.7650), (35.7100, 139.7745), (35.6930, 139.7020), (35.6600, 139.6985),
                  (35.6710, 139.7040), (35.7035, 139.5795), (35.6615, 139.6675), (35.7055, 139.6495),
                  (35.6155, 139.7155), (35.7350, 139.7330), (35.7090, 139.6660), (35.6965, 139.8145),
                  (35.7495, 139.8045), (35.7775, 139.7215), (35.6430, 139.6700), (35.6075, 139.6690),
                  (35.6860, 139.7820), (35.7275, 139.7650), (35.7015, 139.7385), (35.7300, 139.7180)], 30, {0})
    # Tower apartments on the bay, then flats in the towns around the centre.
    scatter_near(['mansion_a', 'mansion_b', 'mansion_c'],
                 [(35.6545, 139.7955), (35.6585, 139.7770), (35.6640, 139.7840), (35.6460, 139.8050),
                  (35.5765, 139.6595), (35.6280, 139.7460)], 30, {0})
    _in_core = [q for q in stop_pts if CX0 < q[0] < CX0 + CW and CY0 < q[1] < CY0 + CH]
    towns = [q for q in _in_core if 260 < math.dist(q, (cx, cy)) <= 600]
    rnd.shuffle(towns)
    for i, (qx, qy) in enumerate(towns[:18]):
        name = ('mansion_a', 'mansion_b', 'mansion_c')[i % 3]
        for _ in range(30):
            ang, dist = rnd.random() * 2 * math.pi, rnd.uniform(46, 80)
            x, y = (qx - CX0 + math.cos(ang) * dist) / TERRAIN_SCALE, (qy - CY0 + math.sin(ang) * dist) / TERRAIN_SCALE
            if free_spot(x, y, 8, {0}):
                put(name, x, y)
                break
    # Houses: little towns around the stations away from the centre.
    suburbs = [q for q in _in_core if math.dist(q, (cx, cy)) > 520]
    rnd.shuffle(suburbs)
    for i, (qx, qy) in enumerate(suburbs[:44]):
        name = ('houses_a', 'houses_b', 'houses_c')[i % 3]
        for _ in range(30):
            ang, dist = rnd.random() * 2 * math.pi, rnd.uniform(50, 90)
            x, y = (qx - CX0 + math.cos(ang) * dist) / TERRAIN_SCALE, (qy - CY0 + math.sin(ang) * dist) / TERRAIN_SCALE
            if free_spot(x, y, 8, {0}):
                put(name, x, y)
                break


    # Little cute points round Kanto, where they really are: hot springs (with a
    # snow monkey), whales off the coast, surfers on the surf beaches, steam
    # trains where SLs still run. Free spots near the place; anywhere on the map.
    CUTE = [
        ('onsen', (35.2330, 139.1060)), ('onsen', (35.0960, 139.0720)), ('onsen', (34.9700, 139.1000)),
        ('onsen', (36.8000, 139.7100)), ('onsen', (36.6200, 138.5960)),
        ('whale', (35.1000, 140.3500)), ('whale', (35.6800, 140.9800)), ('whale', (34.8000, 139.5000)),
        ('surfer', (35.3080, 139.4700)), ('surfer', (35.3700, 140.4200)), ('surfer', (34.6650, 138.9750)),
        ('steam', (36.1050, 139.1100)), ('steam', (36.4400, 140.0100)), ('steam', (36.7800, 139.7250)),
        # Mountain cable cars and ropeways: not drawn as lines, just their pictures.
        ('ropeway', (35.2436, 139.0198), 'a'),     # Hakone Ropeway over Owakudani (steam)
        ('ropeway', (36.2245, 140.1110), 'b'),     # Mt. Tsukuba
        ('cablecar', (35.6320, 139.2620), 'a'),    # Mt. Takao
        ('cablecar', (35.7880, 139.1660), 'b'),    # Mt. Mitake
        ('cablecar', (35.4400, 139.2400), 'a'),    # Oyama
        ('cablecar', (35.2510, 139.0430), 'b'),    # Hakone Tozan cable car (Gora - Sounzan)
    ]
    for i_, (kind_, (lat_, lng_), *var_) in enumerate(CUTE):
        name_ = f"{kind_}_{var_[0] if var_ else 'ab'[i_ % 2]}"
        x_, y_ = to_map(lat_, lng_)
        best_ = None
        for r_ in range(0, 90, 6):
            for a_ in range(0, 360, 30):
                q_ = (x_ + r_ * math.cos(math.radians(a_)), y_ + r_ * math.sin(math.radians(a_)))
                if near_stop(q_, 60) > 40 and near_line(q_, 40) > 26:
                    best_ = q_
                    break
            if best_:
                break
        best_ = best_ or (x_, y_)
        decor_list.append({'image': f'assets/art/map_decor/{name_}.png', 'x': round(best_[0]), 'y': round(best_[1])})

    # Bridges over the Sumida are drawn into the ground at their real size (terrain_paint.py).
    scatter('sailboat', 6, {1})
    scatter('ferry', 3, {1})
else:
    # The scenery stays where it stands.
    decor_list = _old.get('decor', [])


# ---- a quick look at a few places (no file of the app is touched) ----
#   MAP_PREVIEW="hakone:35.23,139.05,1800;takao:35.63,139.26" python tools/build_map.py
# paints name: lat, lng[, size in map units] the way the tiles will look
# (Kanto at KANTO_TILE_SCALE with the Tokyo picture in its place, lines and
# stations sketched over it) into docs/captures/map_polish/dev_<name>.png.
if PREVIEW:
    _colors = {l['id']: l['color'] for l in lines}
    os.makedirs(os.path.join(ROOT, 'docs', 'captures', 'map_polish'), exist_ok=True)
    for item in PREVIEW.split(';'):
        name, _, rest = item.partition(':')
        v = [float(x) for x in rest.split(',')]
        size = v[2] if len(v) > 2 else 1800
        mx, my = to_map(v[0], v[1])
        x0, y0 = int(mx - size / 2) // 6 * 6, int(my - size / 2) // 6 * 6
        pw_ = int(size / KANTO_TILE_SCALE)
        im = paint_kanto(KANTO_TILE_SCALE, x0, y0, pw_, pw_).convert('RGB')
        # The part of the Tokyo picture in this window.
        a0, b0 = max(x0, CX0), max(y0, CY0)
        a1, b1 = min(x0 + size, CX0 + CW), min(y0 + size, CY0 + CH)
        if a1 - a0 > 8 and b1 - b0 > 8:
            cw_, ch_ = int((a1 - a0) / TERRAIN_SCALE), int((b1 - b0) / TERRAIN_SCALE)
            part = fade_core(core_picture(a0, b0, core_ground(a0, b0, cw_, ch_)), im, a0, b0, x0, y0)
            part = part.resize((round(cw_ * TERRAIN_SCALE / KANTO_TILE_SCALE),
                                round(ch_ * TERRAIN_SCALE / KANTO_TILE_SCALE)), Image.BOX)
            im.paste(part, (round((a0 - x0) / KANTO_TILE_SCALE), round((b0 - y0) / KANTO_TILE_SCALE)))
        if not os.environ.get('MAP_PREVIEW_BARE'):
            dr = ImageDraw.Draw(im)
            for l in out_lines:
                pts = [((p[0] - x0) / KANTO_TILE_SCALE, (p[1] - y0) / KANTO_TILE_SCALE) for p in l['path']]
                dr.line(pts + ([pts[0]] if l['closed'] else []), fill=_colors[l['id']], width=2)
            for qx, qy in pos.values():
                x, y = (qx - x0) / KANTO_TILE_SCALE, (qy - y0) / KANTO_TILE_SCALE
                dr.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(255, 255, 255), outline=(48, 52, 60))
        im.save(os.path.join(ROOT, 'docs', 'captures', 'map_polish', f'dev_{name}.png'))
        print('preview', name, im.size)
    raise SystemExit

# Inside: the real ground (city blocks, parks with round trees, water with a
# bank, faint expressways) painted by terrain_paint.py.
t = core_picture(CX0, CY0, core_all)

o = paint_kanto(OUTER_SCALE, -OUTER_MARGIN, -OUTER_MARGIN, ow, oh)

# Zoom-in tiles outside Tokyo: the same picture, twice as fine, cut in
# KANTO_TILE squares, with the Tokyo picture shrunk into its place.
tw, th = -(-W // KANTO_TILE_SCALE), -(-H // KANTO_TILE_SCALE)
hi = paint_kanto(KANTO_TILE_SCALE, 0, 0, tw, th)

# Soften the last pixels of the detailed centre into the countryside under it.
t = fade_core(t, hi, CX0, CY0, 0, 0)
t.save(FULL_TERRAIN)
o.save(FULL_OUTER)

print('map.json + terrain written:', W, 'x', H, 'units,', len(out_lines), 'lines,', len(pos), 'stations')

# Decorations go into map.json (the app draws them over the terrain when zoomed in).
os.makedirs(os.path.join(ROOT, 'assets', 'art', 'map_decor'), exist_ok=True)
for name, img in decor.items():
    img.save(os.path.join(ROOT, 'assets', 'art', 'map_decor', name + '.png'))
# Hanami spots change with the season: cherry blossom in spring, red maple
# in autumn, fresh green the rest of the year (the app picks by date).
for d_ in decor_list:
    base_name = os.path.basename(d_['image'])
    if base_name.startswith('sakura_'):
        v = base_name[len('sakura_'):]
        d_['image'] = f'assets/art/map_decor/green_{v}'
        d_['seasons'] = {'spring': f'assets/art/map_decor/sakura_{v}', 'autumn': f'assets/art/map_decor/momiji_{v}'}
data['decor'] = decor_list
# Ward and neighbourhood of every station (tools/fetch_station_areas.py), for the station card.
_areas = os.path.join(ROOT, 'tools', 'data', 'osm', 'station_areas.json')
if os.path.exists(_areas):
    data['areas'] = {k: v for k, v in json.load(open(_areas, encoding='utf8'))['areas'].items() if k in pos}
print(len(decor_list), 'decorations')

# ---- sea glints (twinkle in the app) ----
glints = []
grnd = random.Random(11)
for _ in range(20000):
    if len(glints) >= 160:
        break
    x, y = grnd.uniform(0, w), grnd.uniform(0, h)
    xi, yi = int(x), int(y)
    if base[xi, yi] != 1:
        continue
    # Away from the shore so they sit on open water.
    if any(base[min(max(xi + dx, 0), w - 1), min(max(yi + dy, 0), h - 1)] != 1
           for dx in (-12, 0, 12) for dy in (-12, 0, 12)):
        continue
    glints.append([round(x * TERRAIN_SCALE + CX0), round(y * TERRAIN_SCALE + CY0)])
if KEEP and _old.get('glints'):
    glints = _old['glints']            # they twinkle where they did
data['glints'] = glints
print(len(glints), 'glints')



# ---- what the app loads: an overview and tiles (2026-11-19, map too big) ----
# Far out: one small picture of all Kanto (OVERVIEW_SCALE). Zoomed in: tiles,
# only the ones on screen - Kanto at KANTO_TILE_SCALE (with the Tokyo
# detail shrunk into it), and the detailed Tokyo picture itself.
OVERVIEW_SCALE = 12
CORE_FROM, KANTO_FROM = 0.4, 0.15          # zoom from which each tile set is used
TILE_DIR = os.path.join(ROOT, 'assets', 'art', 'map_tiles')
os.makedirs(TILE_DIR, exist_ok=True)
for f_ in os.listdir(TILE_DIR):
    if f_.endswith('.png'):
        os.remove(os.path.join(TILE_DIR, f_))


def save_png(img, path):
    """Pixel art: an exact 256-colour palette when it fits, else the nearest one (no dithering)."""
    img = img.convert('RGB')
    if img.getcolors(256) is not None:
        q = img.convert('P', palette=Image.Palette.ADAPTIVE, colors=256)
    else:
        q = img.quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    q.save(path, optimize=True)


core_full = Image.open(FULL_TERRAIN).convert('RGB')
outer_full = Image.open(FULL_OUTER).convert('RGB')
# Overview: the outer picture halved, with the Tokyo picture shrunk into its place.
ov = outer_full.reduce(OVERVIEW_SCALE // OUTER_SCALE)
cr = core_full.reduce(OVERVIEW_SCALE // TERRAIN_SCALE)
ov.paste(cr, (round((CX0 + OUTER_MARGIN) / OVERVIEW_SCALE), round((CY0 + OUTER_MARGIN) / OVERVIEW_SCALE)))
save_png(ov, os.path.join(ROOT, 'assets', 'art', 'map_overview.png'))
# Kanto tiles, with Tokyo's detail in them for the middle zooms.
hi_rgb = hi.convert('RGB')
shrunk = core_full.resize((round(core_full.width * TERRAIN_SCALE / KANTO_TILE_SCALE),
                           round(core_full.height * TERRAIN_SCALE / KANTO_TILE_SCALE)), Image.BOX)
hi_rgb.paste(shrunk, (round(CX0 / KANTO_TILE_SCALE), round(CY0 / KANTO_TILE_SCALE)))


def cut(img, prefix, inside=None):
    names = []
    for ty in range(-(-img.height // KANTO_TILE)):
        for tx in range(-(-img.width // KANTO_TILE)):
            part = img.crop((tx * KANTO_TILE, ty * KANTO_TILE,
                             min(img.width, (tx + 1) * KANTO_TILE), min(img.height, (ty + 1) * KANTO_TILE)))
            save_png(part, os.path.join(TILE_DIR, f'{prefix}{tx}_{ty}.png'))
            names.append(f'{tx}_{ty}')
    return names


kanto_tiles = cut(hi_rgb, 'kanto_')
core_tiles = cut(core_full, 'core_')
data['terrain'] = {
    'image': 'assets/art/map_overview.png', 'origin': [-OUTER_MARGIN, -OUTER_MARGIN], 'scale': OVERVIEW_SCALE,
    'sets': [
        {'dir': 'assets/art/map_tiles', 'prefix': 'kanto_', 'origin': [0, 0], 'scale': KANTO_TILE_SCALE,
         'size': KANTO_TILE, 'from': KANTO_FROM, 'have': kanto_tiles},
        {'dir': 'assets/art/map_tiles', 'prefix': 'core_', 'origin': [CX0, CY0], 'scale': TERRAIN_SCALE,
         'size': KANTO_TILE, 'from': CORE_FROM, 'have': core_tiles},
    ],
    # Full pictures for the preview tools (not in the app).
    'full': {'core': {'image': 'docs/art/gen/map_full/terrain.png', 'origin': [CX0, CY0], 'scale': TERRAIN_SCALE},
             'outer': {'image': 'docs/art/gen/map_full/outer.png', 'origin': [-OUTER_MARGIN, -OUTER_MARGIN],
                       'scale': OUTER_SCALE}},
}
# The Rainbow Bridge spans the water from Shibaura to Daiba, drawn at the
# map's scale (tools/make_rainbow_bridge.py prints this spot).
for lm_ in data['landmarks']:
    if lm_['image'].endswith('/rainbow.png'):
        lm_.update({'image': 'assets/art/landmarks/rainbow_bridge.png', 'x': 7636, 'y': 7454, 'ground': True})

# Mt. Fuji: a big snow-capped cone at the map's scale (6 units a pixel),
# centred on the real summit and shown at every zoom.
for lm_ in data['landmarks']:
    if lm_['image'].endswith('/fuji.png'):
        lm_.update({'image': 'assets/art/landmarks/fuji_big.png', 'x': 2616, 'y': 9237, 'unit': 6})

# Moving pictures (PixelLab animations, 8 frames side by side in assets/art/anim).
ANIM_DECOR = ['onsen_a', 'onsen_b', 'whale_a', 'whale_b', 'surfer_a', 'surfer_b', 'steam_a', 'steam_b', 'ropeway_a', 'ropeway_b', 'cablecar_a', 'cablecar_b']
ANIM_LANDMARKS = ['ferris', 'minatomirai', 'themepark', 'hitachi', 'kusatsu', 'enoshima']
for x_ in data['decor']:
    n_ = x_['image'].rsplit('/', 1)[1][:-4]
    if n_ in ANIM_DECOR:
        x_['image'], x_['frames'] = f'assets/art/anim/{n_}.png', 8
for lm_ in data['landmarks']:
    n_ = lm_['image'].rsplit('/', 1)[1][:-4]
    if n_ in ANIM_LANDMARKS:
        lm_['image'], lm_['frames'] = f'assets/art/anim/{n_}.png', 8
json.dump(data, open(os.path.join(CITY, 'map.json'), 'w', encoding='utf8'), ensure_ascii=False, separators=(',', ':'))
sz = sum(os.path.getsize(os.path.join(TILE_DIR, f_)) for f_ in os.listdir(TILE_DIR))
print(f'overview {ov.size}, {len(kanto_tiles)} Kanto tiles + {len(core_tiles)} Tokyo tiles = {sz / 1e6:.1f} MB')
