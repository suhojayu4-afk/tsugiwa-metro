"""Keeps only the attendant from the GPT-drawn attendant scenes
(tools/gen_staff_scene_gpt.py): each frame is compared with the station's
original picture, the pixels that changed (him and his shadow) are kept as
a transparent overlay at the app's 384x192 grid, so the app's own
background never flickers between frames.

  docs/art/gen/staff_scene/{scene}_{part}_{n}_raw.png
    -> assets/art/staff_scene/{scene}_{part}.png  (overlays stacked vertically, 384x192 each)
    -> docs/captures/staff_scene_{scene}_{part}.gif (review, with the train)

  python tools/cut_staff_scene.py [--scene tokyo] [--part day]
"""
import argparse
import glob
import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, 'docs', 'art', 'gen', 'staff_scene')
OUT = os.path.join(ROOT, 'assets', 'art', 'staff_scene')


def source(scene, part):
    if scene == 'standard':
        name = {'day': 'bg_day_raw.png', 'evening': 'bg_evening2_raw.png', 'night': 'bg_night_raw.png'}[part]
        return os.path.join(ROOT, 'docs', 'art', 'gen', name)
    return os.path.join(ROOT, 'docs', 'art', 'gen', 'stations', f'{scene}_{part}_raw.png')


def to_grid(im):
    """The app's 384x192 crop of a 3:2 picture (as tools/pixelize.py: centre band)."""
    w, h = im.size
    band = w / 2.0
    top = (h - band) / 2
    return im.crop((0, round(top), w, round(top + band))).resize((384, 192), Image.BOX)


def overlay(base, frame):
    b = np.asarray(base.convert('RGB'), dtype=np.int16)
    f = np.asarray(frame.convert('RGB').resize(base.size, Image.BOX), dtype=np.int16)
    diff = np.abs(b - f).sum(axis=2)
    mask = Image.fromarray(((diff > 70) * 255).astype(np.uint8))
    # Close small gaps in him, drop specks elsewhere.
    mask = mask.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))
    mask = mask.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
    # Only the platform (right of the track, below the roof edge): GPT also
    # retouches the sky and buildings a little, which we do not want.
    m = np.asarray(mask) > 0
    h, w = m.shape
    yy, xx = np.mgrid[0:h, 0:w]
    m &= (xx > w * 0.52) & (yy > h * 0.30)
    # Keep only the biggest blob: him (and his shadow).
    m = _largest(m)
    rgba = np.dstack([f.astype(np.uint8), (m * 255).astype(np.uint8)])
    big = Image.fromarray(rgba, 'RGBA')
    return to_grid(big)


def _largest(m):
    from collections import deque
    h, w = m.shape
    seen = np.zeros_like(m, dtype=bool)
    best = []
    for y0, x0 in zip(*np.nonzero(m)):
        if seen[y0, x0]:
            continue
        comp = []
        q = deque([(y0, x0)])
        seen[y0, x0] = True
        while q:
            y, x = q.popleft()
            comp.append((y, x))
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and m[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    q.append((ny, nx))
        if len(comp) > len(best):
            best = comp
    out = np.zeros_like(m, dtype=bool)
    for y, x in best:
        out[y, x] = True
    return out


# Where his feet should be in each frame (the app's 384x192 grid, Tokyo
# pictures: floor horizon at row 92), along the platform edge strip.
PATH = [(249, 103), (262, 121), (277, 140), (277, 140), (266, 125), (254, 109)]


def place(tile, foot, horizon=92.0):
    """Moves the figure in [tile] so its feet stand at [foot], sized by the
    platform's perspective (height = 1.33 x (feet row - horizon))."""
    box = tile.getbbox()
    if box is None:
        return tile
    fig = tile.crop(box)
    h = 1.33 * (foot[1] - horizon)
    k = h / fig.height
    fig = fig.resize((max(1, round(fig.width * k)), max(1, round(h))), Image.NEAREST)
    out = Image.new('RGBA', tile.size)
    out.paste(fig, (round(foot[0] - fig.width / 2), round(foot[1] - fig.height)), fig)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--scene', default='tokyo')
    ap.add_argument('--part', default='day')
    a = ap.parse_args()
    base = Image.open(source(a.scene, a.part))
    frames = sorted(glob.glob(os.path.join(RAW, f'{a.scene}_{a.part}_[0-9]_raw.png')))
    os.makedirs(OUT, exist_ok=True)
    tiles = []
    for p in frames:
        o = overlay(base, Image.open(p))
        # Crisp: fully opaque or empty.
        px = o.load()
        for y in range(o.height):
            for x in range(o.width):
                c = px[x, y]
                px[x, y] = (c[0], c[1], c[2], 255) if c[3] >= 140 else (0, 0, 0, 0)
        tiles.append(place(o, PATH[min(len(tiles), len(PATH) - 1)]))
    sheet = Image.new('RGBA', (384, 192 * len(tiles)))
    for i, t in enumerate(tiles):
        sheet.paste(t, (0, 192 * i))
    sheet.save(os.path.join(OUT, f'{a.scene}_{a.part}.png'))
    print('frames', len(tiles))

    # Review GIF: the app's picture, the train standing, the attendant frames
    # (each held a while, as the app would show them).
    pic = Image.open(os.path.join(ROOT, 'assets', 'art', 'scenes', f'{a.scene}_{a.part}.png')).convert('RGBA') \
        if a.scene != 'standard' else Image.open(os.path.join(ROOT, 'assets', 'art', f'scene_{a.part}.png')).convert('RGBA').crop((0, 0, 384, 192))
    train = Image.open(os.path.join(ROOT, 'assets', 'art', f'train_front_base_{a.part}.png')).convert('RGBA')
    stripe = Image.open(os.path.join(ROOT, 'assets', 'art', 'train_front_stripe.png')).convert('RGBA')
    sp = stripe.load()
    for y in range(stripe.height):
        for x in range(stripe.width):
            r, g, b, al = sp[x, y]
            if al:
                sp[x, y] = (r * 241 // 255, g * 90 // 255, b * 34 // 255, al)
    train.alpha_composite(stripe)
    out = []
    holds = [6, 6, 5, 10, 6, 6]
    for i, t in enumerate(tiles):
        im = pic.copy()
        im.alpha_composite(train, (178, 27))
        im.alpha_composite(t)
        big = im.resize((768, 384), Image.NEAREST).convert('RGB')
        out += [big] * holds[min(i, len(holds) - 1)]
    os.makedirs(os.path.join(ROOT, 'docs', 'captures'), exist_ok=True)
    gif = os.path.join(ROOT, 'docs', 'captures', f'staff_scene_{a.scene}_{a.part}.gif')
    out[0].save(gif, save_all=True, append_images=out[1:], duration=120, loop=0)
    print(gif)


if __name__ == '__main__':
    main()
