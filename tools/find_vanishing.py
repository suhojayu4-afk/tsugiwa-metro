"""Finds where the rails of the train's track meet (the vanishing point) in
each station picture, so the arriving train comes out of the right spot.
The weather and crowd versions were redrawn one by one, and some came out
with a slightly different camera, so the point differs between pictures.

Each rail of the track is followed up the picture row by row from the
bottom (a rail is a shiny line: brighter than the pixels just beside it),
a straight line is fitted to each, and the two lines are crossed.

Writes assets/art/vanishing.json: {"<picture file name>": [x, y]} for every
scene, weather and crowd picture (the app falls back to the usual point).

  python tools/find_vanishing.py [picture.png ...]
"""
import glob
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'art', 'vanishing.json')


def follow(gray, x_start, y_from, y_to):
    """x of a rail on each row from y_from up to y_to."""
    w = gray.shape[1]
    pts = []
    x = x_start
    for y in range(y_from, y_to, -1):
        row = gray[y]
        best, bx = -1e9, x
        for cx in np.arange(x - 2.5, x + 2.6, 0.5):
            i = int(round(cx))
            if i < 3 or i > w - 4:
                continue
            s = row[i] - (row[i - 2] + row[i + 2]) / 2
            if s > best:
                best, bx = s, cx
        x = bx
        pts.append((y, x, best))
    return pts


def start_x(gray, y, lo, hi):
    row = gray[y]
    xs = np.arange(lo, hi)
    s = row[xs] - (row[xs - 2] + row[xs + 2]) / 2
    return float(xs[int(np.argmax(s))])


def fit(pts):
    pts = [p for p in pts if p[2] > 4]  # only rows where the rail clearly shows
    ys = np.array([p[0] for p in pts], dtype=float)
    xs = np.array([p[1] for p in pts], dtype=float)
    a, b = np.polyfit(ys, xs, 1)       # x = a*y + b
    return a, b, len(pts)


def find(path):
    im = Image.open(path).convert('L')
    if im.height > 192:  # an animation sheet: its first frame
        im = im.crop((0, 0, 384, 192))
    g = np.asarray(im, dtype=np.float32)
    y0, y1 = 185, 118
    left = follow(g, start_x(g, y0, 138, 178), y0, y1)
    right = follow(g, start_x(g, y0, 226, 256), y0, y1)
    al, bl, nl = fit(left)
    ar, br, nr = fit(right)
    y = (br - bl) / (al - ar)
    x = al * y + bl
    return round(float(x), 1), round(float(y), 1), min(nl, nr)


def main():
    if len(sys.argv) > 1:
        for p in sys.argv[1:]:
            print(os.path.basename(p), find(p))
        return
    out = {}
    pics = [os.path.join(ROOT, 'assets', 'art', f'scene_{part}{a}.webp') for part in ('day', 'evening', 'night')
            for a in ('', '_anim')]
    for d in ('scenes', 'scenes_season', 'weather', 'crowd'):
        pics += sorted(glob.glob(os.path.join(ROOT, 'assets', 'art', d, '*.webp')))
    for p in [q for q in pics if os.path.exists(q)]:
        x, y, n = find(p)
        name = os.path.basename(p)
        if n < 30 or not (210 <= x <= 245 and 82 <= y <= 112):
            print('unsure', name, x, y, n)
            continue
        out[name] = [x, y]
    # Unsure ones (rails hidden under snow or puddles) use the usual point of
    # their kind of picture in the app.
    json.dump(out, open(OUT, 'w'), indent=0, sort_keys=True)
    ys = [v[1] for v in out.values()]
    print(len(out), 'pictures; y from', min(ys), 'to', max(ys))


if __name__ == '__main__':
    main()
