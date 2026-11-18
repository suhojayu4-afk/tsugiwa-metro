"""Preview part of the route map from map.json, painted like route_map_screen.dart.

  python -X utf8 tools/render_map_preview.py OUT.png X0,Y0,X1,Y1 SCALE [--no-lines] [--dpr=2.5]
      [--no-3d] [--pins] [--plain] [--names]

--no-3d hides landmarks and decorations, --pins draws landmarks as flat
pins instead, --plain leaves out the terrain (white diagram), --names adds
station names (Japanese).

X0..Y1 are map units; SCALE is the zoom (the app's matrix scale `s`).
Lines, stations, decorations and landmarks (with shadow and tone) are drawn
with the app's sizes, so the result looks close to the 路線図 tab.
"""
import json
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = sys.argv[1]
X0, Y0, X1, Y1 = [int(v) for v in sys.argv[2].split(',')]
S = float(sys.argv[3])
draw_lines = '--no-lines' not in sys.argv
# --dpr=2.5 draws like a phone: SCALE is the app's logical zoom, pixels are physical.
DPR = next((float(a.split('=')[1]) for a in sys.argv if a.startswith('--dpr=')), 1.0)
LS, S = S, S * DPR                      # logical zoom (for the app's thresholds), drawing scale
NO3D = '--no-3d' in sys.argv or '--pins' in sys.argv or '--plain' in sys.argv
PINS, PLAIN, NAMES = '--pins' in sys.argv, '--plain' in sys.argv, '--names' in sys.argv

d = json.load(open(os.path.join(ROOT, 'assets/cities/tokyo/map.json'), encoding='utf8'))
colors = {l['id']: l['color'] for l in json.load(open(os.path.join(ROOT, 'assets/cities/tokyo/lines.json'), encoding='utf8'))}
W, H = int((X1 - X0) * S), int((Y1 - Y0) * S)


def sp(x, y):
    return ((x - X0) * S, (y - Y0) * S)


def hexc(h, a=255):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


ts = d['terrain']['scale']
ter = Image.open(os.path.join(ROOT, d['terrain']['image'])).convert('RGBA')
canvas = Image.new('RGBA', (W, H), (255, 255, 255, 255) if PLAIN else (241, 240, 233, 255))
if not PLAIN:
    canvas.alpha_composite(ter.crop((X0 // ts, Y0 // ts, -(-X1 // ts), -(-Y1 // ts))).resize((W, H), Image.NEAREST))

cache = {}


def img(p):
    if p not in cache:
        cache[p] = Image.open(os.path.join(ROOT, p)).convert('RGBA')
    return cache[p]


# decorations (1 picture pixel = 2 map units)
if LS > 0.5 and not NO3D:
    for dc in d.get('decor', []):
        if not (X0 - 60 < dc['x'] < X1 + 60 and Y0 - 60 < dc['y'] < Y1 + 60):
            continue
        im = img(dc['image'])
        w, h = max(1, int(im.width * 2 * S)), max(1, int(im.height * 2 * S))
        x, y = sp(dc['x'], dc['y'])
        canvas.alpha_composite(im.resize((w, h), Image.NEAREST), (int(x - w / 2), int(y - h * 0.75)))

# landmarks, with the app's shadow and 12 % grey tone
px = min(max(LS * 1.1, 0.5), 2.2) * DPR
labels = []
if LS > 0.42 and not NO3D:
    for lm in sorted(d['landmarks'], key=lambda l: l['y']):
        if not (X0 - 80 < lm['x'] < X1 + 80 and Y0 - 20 < lm['y'] < Y1 + 90):
            continue
        im = img(lm['image'])
        w, h = int(im.width * px), int(im.height * px)
        big = im.resize((w, h), Image.NEAREST)
        x, y = sp(lm['x'], lm['y'])
        left, top = int(x - w / 2), int(y - h + 4 * px)
        sh = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
        spx, ap = sh.load(), big.getchannel('A').load()
        for yy in range(h):
            for xx in range(w):
                if ap[xx, yy]:
                    ry = top + yy - y
                    sx, sy = int(left + xx - 0.9 * ry), int(y - 0.32 * ry)
                    if 0 <= sx < W and 0 <= sy < H:
                        spx[sx, sy] = (40, 36, 60, 46)
        canvas.alpha_composite(sh)
        tp = big.load()
        for yy in range(h):
            for xx in range(w):
                r, g, b, al = tp[xx, yy]
                if al:
                    gr = 0.299 * r + 0.587 * g + 0.114 * b
                    tp[xx, yy] = (min(255, int(r * .88 + gr * .12 + 4)), min(255, int(g * .88 + gr * .12 + 2)),
                                  int(b * .88 + gr * .12), al)
        canvas.alpha_composite(big, (left, top))
        labels.append((x, y + 6 * DPR, lm['name']['ja']))

dr = ImageDraw.Draw(canvas)
if draw_lines:
    lw = round(max(2.0, min(7.0, 5.5 * LS)) * DPR)
    for l in d['lines']:
        pts = [sp(*p) for p in l['path']]
        if l.get('closed'):
            pts.append(pts[0])
        dr.line(pts, fill=hexc(colors.get(l['id'], '#888888')), width=lw, joint='curve')
    r = max(2.2, min(8.5, 6.5 * LS)) * DPR
    seen = {}
    for l in d['lines']:
        for sid, st in l['stops'].items():
            seen.setdefault(sid, []).append(sp(st['x'], st['y']))
    for sid, pts in seen.items():
        if LS < 0.3 and len(pts) == 1:
            continue
        xs, ys = [p[0] for p in pts], [p[1] for p in pts]
        box = [min(xs) - r - 2 * (len(pts) > 1), min(ys) - r - 2 * (len(pts) > 1),
               max(xs) + r + 2 * (len(pts) > 1), max(ys) + r + 2 * (len(pts) > 1)]
        try:
            dr.rounded_rectangle(box, radius=min(r + 2, (box[2] - box[0]) / 2 - 0.5, (box[3] - box[1]) / 2 - 0.5),
                                 fill=(255, 255, 255, 255), outline=(40, 40, 48, 255),
                                 width=max(1, round(r / 3)))
        except ValueError:   # tiny at this zoom
            dr.ellipse(box, fill=(255, 255, 255, 255), outline=(40, 40, 48, 255), width=1)
try:
    from PIL import ImageFont
    small = ImageFont.truetype(os.path.join(ROOT, 'assets/fonts/DotGothic16-Regular.ttf'), round(11 * DPR))
    font = ImageFont.truetype(os.path.join(ROOT, 'assets/fonts/DotGothic16-Regular.ttf'), round(12 * DPR))
except Exception:
    font = None
if PINS and LS > 0.42:
    # Flat pins: a round badge with a dot, the name under it (no 3D picture).
    for lm in d['landmarks']:
        if not (X0 < lm['x'] < X1 and Y0 < lm['y'] < Y1):
            continue
        x, y = sp(lm['x'], lm['y'] - 18)
        rr = 9 * DPR
        dr.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(232, 96, 76, 255), outline=(255, 255, 255, 255),
                   width=round(2 * DPR))
        dr.ellipse([x - rr / 3, y - rr / 3, x + rr / 3, y + rr / 3], fill=(255, 255, 255, 255))
        labels.append((x, y + rr + 3 * DPR, lm['name']['ja']))
if NAMES and draw_lines:
    names = {s_['id']: s_['name']['ja'] for s_ in json.load(open(os.path.join(ROOT, 'assets/cities/tokyo/stations.json'),
                                                                   encoding='utf8'))}
    done = set()
    for l in d['lines']:
        for sid, st in l['stops'].items():
            if sid in done:
                continue
            done.add(sid)
            x, y = sp(st['x'], st['y'])
            off = r + 3 * DPR
            pos, anc = {'l': ((x - off, y), 'rm'), 'r': ((x + off, y), 'lm'), 't': ((x, y - off), 'mb')}.get(
                st.get('label'), ((x, y + off), 'mt'))
            dr.text(pos, names.get(sid, ''), fill=(40, 40, 48, 255), font=small, anchor=anc,
                    stroke_width=round(2 * DPR), stroke_fill=(255, 255, 255, 255))
for x, y, t in labels:
    dr.text((x, y), t, fill=(96, 102, 111, 255), font=font, anchor='mt',
            stroke_width=round(2 * DPR), stroke_fill=(250, 250, 246, 255))
canvas.convert('RGB').save(out)
print('saved', out, canvas.size)
