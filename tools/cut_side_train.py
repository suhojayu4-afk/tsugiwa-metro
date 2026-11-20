"""Turns the GPT pictures of tools/gen_side_train_gpt.py
(docs/art/gen/side_train/*_raw.png) into the pixel art the side-view train
uses (assets/art/side_*.webp, art grid 384x112, see side_train_view.dart):

- snapped to a real pixel grid (box filter per art pixel, then a limited
  shared palette, no dithering), like tools/pixelize.py;
- magenta keyed out (only the non-magenta part of each block is averaged, a
  block is kept when at least half of it is drawn, pink fringe pulled back);
- strips that scroll sideways are made to loop: the two most alike columns
  near the ends are found, the picture is cut there and a short cross-fade
  closes the last small step;
- the train: the leading and middle cars cut apart, the pure green line-colour
  bands turned into a white stripe mask (side_car_*_stripe.webp) the app tints.

  python tools/cut_side_train.py [names ...]
Writes docs/art/gen/side_train/{name}_preview.png (4x) for review.
"""
import os
import sys

import numpy as np
from PIL import Image
from art_io import save_art  # noqa: E402  (lossless WebP)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))).replace('\\', '/')
RAW = f'{ROOT}/docs/art/gen/side_train'
OUT = f'{ROOT}/assets/art'


def load(name):
    return np.asarray(Image.open(f'{RAW}/{name}_raw.png').convert('RGB')).astype(np.float32)


def key_mask(a):
    """True where the picture is drawn (not the magenta background)."""
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    magenta = (r > 150) & (b > 150) & (g < 110) & (np.abs(r - b) < 90)
    return ~magenta


def shrink(a, mask, out_w, out_h):
    """Box filter to out_w x out_h, averaging only drawn pixels."""
    h, w = a.shape[:2]
    ys = np.linspace(0, h, out_h + 1).round().astype(int)
    xs = np.linspace(0, w, out_w + 1).round().astype(int)
    rgb = np.zeros((out_h, out_w, 3), np.float32)
    al = np.zeros((out_h, out_w), np.float32)
    m = mask.astype(np.float32)
    for j in range(out_h):
        for i in range(out_w):
            mm = m[ys[j]:ys[j + 1], xs[i]:xs[i + 1]]
            cov = mm.mean()
            al[j, i] = cov
            if cov > 0:
                blk = a[ys[j]:ys[j + 1], xs[i]:xs[i + 1]]
                rgb[j, i] = (blk * mm[..., None]).sum((0, 1)) / mm.sum()
    return rgb, al >= 0.5


def despill(rgb, alpha):
    """Pink edge pixels next to the cut-out: pull the magenta tint out."""
    out = rgb.copy()
    h, w = alpha.shape
    edge = np.zeros_like(alpha)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        sh = np.roll(np.roll(~alpha, dy, 0), dx, 1)
        edge |= sh
    edge &= alpha
    r, g, b = out[..., 0], out[..., 1], out[..., 2]
    pink = edge & (r > g + 30) & (b > g + 30)
    lo = np.minimum(r, b)
    out[..., 0] = np.where(pink, (g + lo) / 2 + (r - lo) * 0.3, r)
    out[..., 2] = np.where(pink, (g + lo) / 2 + (b - lo) * 0.3, b)
    return out


def palette(rgb, alpha, colors):
    """One shared palette, no dithering; transparent pixels stay transparent."""
    h, w = alpha.shape
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8))
    q = np.asarray(img.quantize(colors=colors, method=Image.Quantize.MEDIANCUT,
                                dither=Image.Dither.NONE).convert('RGB'))
    out = np.zeros((h, w, 4), np.uint8)
    out[..., :3] = q
    out[..., 3] = np.where(alpha, 255, 0)
    out[~alpha, :3] = 0
    return out


def loop(rgba, search=0.18, block=10, fade=3, cut=None):
    """Cuts a strip so its right edge runs on into its left edge: the cut is
    where a block of columns near the left end best matches a block near the
    right end (so pillars and lamps keep their spacing across the seam)."""
    a = rgba.astype(np.float32)
    a[..., :3] *= a[..., 3:4] / 255
    h, w = a.shape[:2]
    s = int(w * search)
    best = (0.0, *cut) if cut else None
    for x1 in range(0, 0 if cut else s):
        b1 = a[:, x1:x1 + block]
        for x2 in range(w - s - block, w - block):
            d = np.abs(b1 - a[:, x2:x2 + block]).mean()
            if best is None or d < best[0]:
                best = (d, x1, x2)
    _, x1, x2 = best
    src = rgba.astype(np.float32)
    strip = src[:, x1:x2].copy()
    # Close the remaining small step: the first columns blend from what
    # follows the right edge (x2..) into the strip itself.
    for i in range(fade):
        t = (i + 1) / (fade + 1)
        strip[:, i] = src[:, x2 + i] * (1 - t) + strip[:, i] * t
    strip[..., 3] = np.where(strip[..., 3] >= 128, 255, 0)
    print(f'  loop: cut {x1}..{x2} of {w} -> {x2 - x1} wide, block diff {best[0]:.1f}')
    return strip.astype(np.uint8)


def save(rgba, name):
    im = Image.fromarray(rgba, 'RGBA')
    save_art(im, f'{OUT}/side_{name}.webp')
    im.resize((im.width * 4, im.height * 4), Image.NEAREST).save(f'{RAW}/{name}_preview.png')
    print(f'side_{name}.webp {im.size}')


def crop(a, rows, cols, k):
    """Raw rows y0..y1; with cols x0..x1 (one period of the picture, e.g.
    two pillar spacings) a few more columns are kept for the cross-fade."""
    y0, y1 = rows
    a = a[y0:y1]
    if cols:
        x0, x1 = cols
        a = a[:, x0:min(a.shape[1], x1 + 4 * k)]
    return a


def wrap(q, cols, k, tile):
    if cols:
        n = round((cols[1] - cols[0]) / k)
        return loop(q, cut=(0, n))
    return tiled(q, tile)


def full(name, k, rows, colors=64, tile='loop', cols=None):
    """A full picture (no magenta): raw rows y0..y1, shrunk k times."""
    a = crop(load(name), rows, cols, k)
    h, w = a.shape[:2]
    rgb, al = shrink(a, np.ones((h, w), bool), round(w / k), round(h / k))
    save(wrap(palette(rgb, al, colors), cols, k, tile), name)


def tiled(q, tile):
    if tile == 'loop':
        return loop(q)
    if tile == 'mirror':
        return np.concatenate([q, no_sun(q[:, ::-1].copy())], 1)
    return q


def no_sun(q):
    """The mirrored copy of a sky loses its sun (one sun on screen at most):
    the sun's box is filled with the sky just right of it."""
    r, g, b = (q[..., i].astype(int) for i in range(3))
    sun = (r > 230) & (g > 170) & (b < 130)
    sun[int(q.shape[0] * 0.5):] = False
    # Only the solid disc: pixels with many sun-coloured neighbours.
    pad = np.pad(sun.astype(int), 3)
    near = sum(pad[dy:dy + sun.shape[0], dx:dx + sun.shape[1]] for dy in range(7) for dx in range(7))
    sun &= near >= 24
    ys, xs = np.nonzero(sun)
    if len(xs) < 6:
        return q
    y0, y1, x0, x1 = ys.min() - 2, ys.max() + 3, xs.min() - 2, xs.max() + 3
    bw = x1 - x0
    # Only the sun's own pixels (and a 1-pixel rim) change; buildings stay.
    loose = (r > 225) & (g > 150) & (b < 140)
    box = np.zeros_like(loose)
    box[y0:y1, x0:x1] = True
    m = loose & box
    m = box & (m | np.roll(m, 1, 0) | np.roll(m, -1, 0) | np.roll(m, 1, 1) | np.roll(m, -1, 1))
    my, mx = np.nonzero(m)
    q[my, mx] = q[my, mx + bw]
    print(f'  removed the sun from the mirrored copy at {x0},{y0} ({bw}x{y1 - y0})')
    return q


def keyed(name, k, rows, colors=64, tile='loop', cols=None):
    """On magenta: tile = 'loop' (cut to loop), 'mirror' (the strip and its
    mirror image side by side, which always loops) or None (a sprite,
    cropped to what is drawn)."""
    a = crop(load(name), rows, cols, k)
    h, w = a.shape[:2]
    rgb, al = shrink(a, key_mask(a), round(w / k), round(h / k))
    q = palette(despill(rgb, al), al, colors)
    if tile:
        q = wrap(q, cols, k, tile)
    else:
        ys, xs = np.nonzero(q[..., 3])
        q = q[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    save(q, name)


def unpink(rgb):
    """GPT's magenta background tints the silver pink: cool the greys."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    grey = (np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b)) < 70
    out = rgb.copy()
    out[..., 0] = np.where(grey, g + (r - g) * 0.35, r)
    out[..., 2] = np.where(grey, g + (b - g) * 0.75, b)
    return out


def close(m, n=2):
    """Fills small holes (clouds reflected in the glass): grow, then shrink."""
    def grow(x):
        return x | np.roll(x, 1, 0) | np.roll(x, -1, 0) | np.roll(x, 1, 1) | np.roll(x, -1, 1)
    out = m
    for _ in range(n):
        out = grow(out)
    for _ in range(n):
        out = ~grow(~out)
    return out


def enclosed(a, drawn):
    """Window glass: what the silver body cannot reach without crossing a
    dark window frame. The body is grown from plain light-grey pixels (and
    the green bands) through everything that is not dark."""
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    lum = a.sum(2) / 3
    open_ = (lum >= 75) & (b < r + 30) & drawn
    body = open_ & (((lum > 150) & (np.abs(r - b) < 25)) | ((g > r + 50) & (g > b + 50)))
    while True:
        grown = body | np.roll(body, 1, 0) | np.roll(body, -1, 0) | np.roll(body, 1, 1) | np.roll(body, -1, 1)
        grown &= open_
        if (grown == body).all():
            break
        body = grown
    return drawn & ~body


def train(src='train3d_b', car_len=368):
    """Both cars at one scale (from the middle car), so they line up. Drawn
    at twice the art grid's resolution (the app shows them at half size)."""
    a = load(src)
    m = key_mask(a)
    rows = m.mean(1) > 0.003  # thin pantograph rows count too
    # The two cars: the two longest runs of rows with something in them.
    runs, start = [], None
    for y, on in enumerate(list(rows) + [False]):
        if on and start is None:
            start = y
        elif not on and start is not None:
            runs.append((start, y))
            start = None
    runs = sorted(sorted(runs, key=lambda r: r[1] - r[0])[-2:])

    def span(t, b):
        cols = np.nonzero(m[t:b].mean(0) > 0.02)[0]
        return cols.min(), cols.max() + 1

    ml, mr = span(*runs[1])
    k = (mr - ml) / car_len
    for (t, b), car in zip(runs, ('lead', 'mid')):
        l, r = span(t, b)
        sub, mk = a[t:b, l:r], m[t:b, l:r]
        rgb, al = shrink(sub, mk, round((r - l) / k), round((b - t) / k))
        rgb = despill(rgb, al)
        R, G, B = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        # Line-colour bands: pure green in the picture.
        band = al & (G > R + 50) & (G > B + 50)
        # Window glass: dark blue-grey, only between the top band (under the
        # roof) and the band below the windows.
        rows = np.nonzero(band.mean(1) > 0.3)[0]
        yy = np.arange(al.shape[0])[:, None]
        lum = (R + G + B) / 3
        # Windows: what the black window frames enclose, found at full size,
        # then shrunk like the picture.
        raw_glass = enclosed(sub, mk)
        _, glass = shrink(np.zeros_like(sub), raw_glass, al.shape[1], al.shape[0])
        glass &= al & (yy > rows.min() + 1) & (yy < rows.max() - 2) & ~band

        # Clouds reflected in the glass: holes with glass close on all sides.
        def near(axis, sign):
            return np.any([np.roll(glass, sign * d, axis) for d in range(1, 5)], 0)

        glass |= near(1, 1) & near(1, -1) & near(0, 1) & near(0, -1) & al & ~band
        # Thin lines (door seams, frame tops) are not windows: open by 1 px.
        glass = ~close(~glass, 1)
        glass &= sum(np.roll(np.roll(glass, dy, 0), dx, 1) for dy in (-1, 0, 1) for dx in (-1, 0, 1)) >= 5
        # Drop lone specks (bogie bolts and the like).
        n = sum(np.roll(np.roll(glass, dy, 0), dx, 1) for dy in (-1, 0, 1) for dx in (-1, 0, 1))
        glass &= n >= 4
        q = palette(unpink(rgb), al, 96)
        base = q.copy()
        stripe = np.zeros_like(q)
        v = np.clip(G / max(1, np.percentile(G[band], 90)) * 255, 140, 255)
        stripe[band, :3] = v[band, None].astype(np.uint8)
        stripe[band, 3] = 255
        # Under the band the base is a neutral grey of the same lightness.
        base[band, :3] = (v[band, None] * 0.75).astype(np.uint8)
        # Glass mask for lit windows: bright glass, darker where passengers sit.
        gl = np.zeros_like(q)
        gv = np.where(lum < 45, 175, 255)
        gl[glass, :3] = gv[glass, None].astype(np.uint8)
        gl[glass, 3] = 255
        save(base, f'car_{car}')
        save(stripe, f'car_{car}_stripe')
        save(gl, f'car_{car}_glass')


JOBS = {
    # Far: shrunk 6x, the bottom 90 rows (skyline and the sky above it).
    # Mirrored, so the sun / moon never shows twice on screen.
    'far_day': lambda: full('far_day', 6, (1024 - 540, 1024), tile='mirror'),
    'far_evening': lambda: full('far_evening', 6, (1024 - 540, 1024), tile='mirror'),
    'far_night': lambda: full('far_night', 6, (1024 - 540, 1024), tile='mirror'),
    'mid_day': lambda: keyed('mid_day', 7, (500, 1024), tile='mirror'),
    'mid_evening': lambda: keyed('mid_evening', 7, (500, 1024), tile='mirror'),
    'mid_night': lambda: keyed('mid_night', 7, (500, 1024), tile='mirror'),
    # Wall from the pipe down: 96 rows.
    # One period each, from the raw pillar / ring positions.
    'tunnel': lambda: full('tunnel', 6, (170, 170 + 576), cols=(60, 60 + 1026)),
    'platform': lambda: keyed('platform', 8, (160, 160 + 776), cols=(100, 100 + 1144)),
    'platform_ug': lambda: full('platform_ug', 8, (100, 100 + 768), cols=(40, 40 + 1384)),
    'mast': lambda: keyed('mast', 12, (0, 1024), tile=None),
    'train3d_b': train,
}

if __name__ == '__main__':
    for n in sys.argv[1:] or JOBS:
        if os.path.exists(f'{RAW}/{n}_raw.png'):
            print(n)
            JOBS[n]()
        else:
            print(f'{n}: no raw picture yet')
