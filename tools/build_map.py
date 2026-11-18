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
OUTER_SCALE = 16             # world units per pixel of the pale surroundings
OUTER_MARGIN = 6400          # world units of surroundings on each side

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


# What every terrain pixel is (land / water / park), from the real shapes in
# OpenStreetMap (tools/fetch_osm.py) where we have them, the hand-drawn ones
# above further out.
from terrain_paint import build_kinds, paint  # noqa: E402

w, h = W // TERRAIN_SCALE, H // TERRAIN_SCALE
kind_img, land_cls, park_cls = build_kinds(to_map, TERRAIN_SCALE, w, h, CENTER,
                                           kind_map(TERRAIN_SCALE, 0, 0, w, h, detail=True))
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
    x, y = int(p[0] / TERRAIN_SCALE), int(p[1] / TERRAIN_SCALE)
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
]

data = {
    'size': [W, H],
    'terrain': {'image': 'assets/art/map_tokyo_terrain.png', 'scale': TERRAIN_SCALE,
                'outer': {'image': 'assets/art/map_tokyo_outer.png', 'origin': [-6400, -6400], 'scale': 16}},
    'lines': out_lines,
    'landmarks': landmarks,
}
json.dump(data, open(os.path.join(CITY, 'map.json'), 'w', encoding='utf8'), ensure_ascii=False, indent=1)


# Inside: the real ground (city blocks, parks with round trees, water with a
# bank, faint expressways) painted by terrain_paint.py; then small PixelLab
# decorations (trees, houses, office towers, boats) are scattered where they
# do not crowd the lines.
DECOR = os.path.join(ROOT, 'docs', 'art', 'gen', 'map_decor')
t = paint(kind_img, land_cls, park_cls, to_map, TERRAIN_SCALE)
px = t.load()

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
               'green_a', 'green_b', 'green_c')
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
        wx, wy = px_ * TERRAIN_SCALE, py_ * TERRAIN_SCALE
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
                       'x': round(x * TERRAIN_SCALE), 'y': round(y * TERRAIN_SCALE)})


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
        x0, y0 = to_map(lat, lng)
        x0, y0 = x0 / TERRAIN_SCALE, y0 / TERRAIN_SCALE
        cands = sorted(((x0 + dx, y0 + dy) for dx in range(-reach_px, reach_px + 1, 3)
                        for dy in range(-reach_px, reach_px + 1, 3)), key=lambda q: math.dist(q, (x0, y0)))
        for x, y in cands:
            if free_spot(x, y, r // 2, need):
                put(name, x, y)
                break


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
towns = [q for q in stop_pts if 260 < math.dist(q, (cx, cy)) <= 600]
rnd.shuffle(towns)
for i, (qx, qy) in enumerate(towns[:18]):
    name = ('mansion_a', 'mansion_b', 'mansion_c')[i % 3]
    for _ in range(30):
        ang, dist = rnd.random() * 2 * math.pi, rnd.uniform(46, 80)
        x, y = (qx + math.cos(ang) * dist) / TERRAIN_SCALE, (qy + math.sin(ang) * dist) / TERRAIN_SCALE
        if free_spot(x, y, 8, {0}):
            put(name, x, y)
            break
# Houses: little towns around the stations away from the centre.
suburbs = [q for q in stop_pts if math.dist(q, (cx, cy)) > 520]
rnd.shuffle(suburbs)
for i, (qx, qy) in enumerate(suburbs[:44]):
    name = ('houses_a', 'houses_b', 'houses_c')[i % 3]
    for _ in range(30):
        ang, dist = rnd.random() * 2 * math.pi, rnd.uniform(50, 90)
        x, y = (qx + math.cos(ang) * dist) / TERRAIN_SCALE, (qy + math.sin(ang) * dist) / TERRAIN_SCALE
        if free_spot(x, y, 8, {0}):
            put(name, x, y)
            break


# Bridges over the Sumida are drawn into the ground at their real size (terrain_paint.py).
scatter('sailboat', 6, {1})
scatter('ferry', 3, {1})

# Soften the last few pixels towards the pale surroundings.
FADE = 60
pale_land, pale_water, pale_park = (241, 240, 233), (200, 224, 238), (222, 234, 210)
for y in range(h):
    for x in range(w):
        dist = min(x, y, w - 1 - x, h - 1 - y)
        if dist >= FADE:
            continue
        a = dist / FADE
        pale = (pale_water if k[x, y] == 1 else pale_park if k[x, y] == 2 else pale_land)
        px[x, y] = tuple(round(p + (q - p) * a) for p, q in zip(pale, px[x, y]))
t.save(os.path.join(ROOT, 'assets', 'art', 'map_tokyo_terrain.png'))

# Around: big, pale pixels.
ow = (W + 2 * OUTER_MARGIN) // OUTER_SCALE
oh = (H + 2 * OUTER_MARGIN) // OUTER_SCALE
ok = kind_map(OUTER_SCALE, -OUTER_MARGIN, -OUTER_MARGIN, ow, oh, detail=False).load()
o = Image.new('RGB', (ow, oh))
op = o.load()
for y in range(oh):
    for x in range(ow):
        v = ok[x, y]
        c = pale_water if v == 1 else pale_park if v == 2 else pale_land
        # A loose, hand-made feel: a few slightly darker pixels here and there.
        if ((x * 7 + y * 13) % 23 == 0) or ((x * 5 + y * 3) % 31 == 0):
            c = tuple(v2 - 5 for v2 in c)
        op[x, y] = c
o.save(os.path.join(ROOT, 'assets', 'art', 'map_tokyo_outer.png'))
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
json.dump(data, open(os.path.join(CITY, 'map.json'), 'w', encoding='utf8'), ensure_ascii=False, indent=1)
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
    glints.append([round(x * TERRAIN_SCALE), round(y * TERRAIN_SCALE)])
data['glints'] = glints

# ---- compass rose (bottom left, on the ground) and Mt. Fuji far away ----
from PIL import ImageFont  # noqa: E402

compass = Image.open(os.path.join(ROOT, 'docs', 'art', 'gen', 'landmarks_raw', 'compass.png')).convert('RGBA')
soft = Image.blend(compass, Image.new('RGBA', compass.size, (240, 236, 222, 255)), 0.28)
soft.putalpha(compass.getchannel('A'))
t2 = Image.open(os.path.join(ROOT, 'assets', 'art', 'map_tokyo_terrain.png')).convert('RGBA')
cxp, cyp = 70, t2.height - 92
t2.alpha_composite(soft, (cxp, cyp))
dn = ImageDraw.Draw(t2)
font = ImageFont.truetype(os.path.join(ROOT, 'assets', 'fonts', 'DotGothic16-Regular.ttf'), 14)
dn.text((cxp + 24, cyp - 4), 'N', font=font, fill=(60, 64, 76, 255), anchor='mb')
t2.convert('RGB').save(os.path.join(ROOT, 'assets', 'art', 'map_tokyo_terrain.png'))

fuji = Image.open(os.path.join(ROOT, 'docs', 'art', 'gen', 'landmarks_raw', 'fuji.png')).convert('RGBA')
# One picture pixel = one pale pixel: big enough to read, smaller than the city.
outer = Image.open(os.path.join(ROOT, 'assets', 'art', 'map_tokyo_outer.png')).convert('RGBA')
fx, fy = to_map(35.3606, 138.7274)
# Far away to the south-west, clear of the map itself.
ox = (fx + OUTER_MARGIN) / OUTER_SCALE - fuji.width / 2 - 40
oy = (fy + OUTER_MARGIN) / OUTER_SCALE - fuji.height + 70
haze = Image.blend(fuji, Image.new('RGBA', fuji.size, (241, 240, 233, 255)), 0.5)
haze.putalpha(fuji.getchannel('A'))
outer.alpha_composite(haze, (int(ox), int(oy)))
outer.convert('RGB').save(os.path.join(ROOT, 'assets', 'art', 'map_tokyo_outer.png'))

json.dump(data, open(os.path.join(CITY, 'map.json'), 'w', encoding='utf8'), ensure_ascii=False, indent=1)
print(len(glints), 'glints; Fuji at outer px', int(ox), int(oy))
