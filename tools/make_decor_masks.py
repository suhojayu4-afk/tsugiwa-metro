"""Masks of the people standing where MY platform decorations go, one per
platform picture, so the app can draw them again over the decoration (it
then stands behind them, against the wall). Replaces make_vending_masks.py.

Decorations stand at the wall between the pillars (ZONE, in the built-in
scene's rows; other pictures are the same platform drawn some rows lower,
see DecorIndex in the app). Nobody can stand behind
something that is against the wall, so everyone inside the zone is in front.

People are found by comparing the picture with the same platform when it is
empty there: the 'relaxed' crowd picture of that station and hour. The two
are not the same drawing (other weather, other light, another camera
height), so the empty one is first moved onto the picture and its colours
are translated colour by colour (pixel art: a wall colour of one becomes
one wall colour of the other). What then still differs is a person.

  python tools/make_decor_masks.py [--check DIR] [--only substring]

Writes assets/art/decor/vending_front/<picture name>.webp (384 wide, alpha =
person; animated pictures get one mask per frame, stacked like the frames)
for every platform picture the app can show (none when nobody stands in the
zone), and lists them with each picture's platform shift in
assets/art/decor/index.json.
"""
import glob
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

from art_io import save_art

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets/art/decor/vending_front')
W, H = 384, 192
# Where decorations may be (built-in scene rows, horizon at row 92).
ZONE = (286, 40, 354, 136)
# The empty ('relaxed') pictures are this many rows below the built-in scene.
REF_SHIFT = 10


def ref_path(path):
    name = os.path.splitext(os.path.basename(path))[0]
    if '/tottori/' in path.replace(os.sep, '/'):
        # Tottori: an empty version of the very same drawing
        # (tools/tottori/gen_empty_refs.py), in the picture's own rows.
        return os.path.join(ROOT, 'docs/art/gen/tottori/empty', name.replace('_anim', '') + '.webp')
    if name.startswith('scene_'):
        name = 'standard_' + name[6:]
    scene, part = name.split('_')[:2]
    if 'closed' in name:
        part = 'night'
    p = os.path.join(ROOT, 'assets/art/crowd', f'{scene}_{part}_relaxed.webp')
    if not os.path.exists(p):  # seasonal pictures are the built-in platform
        p = os.path.join(ROOT, 'assets/art/crowd', f'standard_{part}_relaxed.webp')
    return p


def grad(a):
    g = a.astype(np.float32).mean(axis=2)
    return np.abs(np.diff(g, axis=1, prepend=g[:, :1])) + np.abs(np.diff(g, axis=0, prepend=g[:1]))


def moved(a, dx, dy):
    """[a] moved right/down by (dx, dy), edges repeated."""
    h, w = a.shape[:2]
    ys = np.clip(np.arange(h) - dy, 0, h - 1)
    xs = np.clip(np.arange(w) - dx, 0, w - 1)
    return a[ys][:, xs]


def align(pic, ref, box):
    """Best (dx, dy) to move [ref] onto [pic]: their lines (pillars, window
    frames) fall on each other. (The rails' meeting point of vanishing.json
    is no guide here: it is off in the snow pictures.)"""
    x0, y0, x1, y1 = box
    gp = np.minimum(grad(pic), 60)
    gr = np.minimum(grad(ref), 60)
    best = None
    for dy in range(-15, 5):
        for dx in range(-3, 4):
            d = np.abs(gp[y0:y1, x0:x1] - moved(gr, dx, dy)[y0:y1, x0:x1])
            s = np.sort(d.ravel())[: int(d.size * 0.6)].sum()  # people excluded
            if best is None or s < best[0]:
                best = (s, dx, dy)
    return best[1], best[2]


def _key(a):
    return (a[..., 0] >> 2).astype(np.int32) << 12 | (a[..., 1] >> 2).astype(np.int32) << 6 | (a[..., 2] >> 2)


def translate(pic, ref, box):
    """[ref] in [pic]'s colours: each ref colour becomes the colour the
    picture mostly has at those places."""
    x0, y0, x1, y1 = box
    r = ref[y0:y1, x0:x1].reshape(-1, 3)
    p = pic[y0:y1, x0:x1].reshape(-1, 3).astype(np.float32)
    key = _key(r)
    # Overall light change, for colours seen too rarely.
    A = np.c_[r.astype(np.float32), np.ones(len(r))]
    coef = np.linalg.lstsq(A, p, rcond=None)[0]
    flat = np.c_[ref.reshape(-1, 3).astype(np.float32), np.ones(ref.shape[0] * ref.shape[1])]
    out = np.clip(flat @ coef, 0, 255).reshape(ref.shape).copy()
    allkey = _key(ref)
    order = np.argsort(key)
    ks, starts, counts = np.unique(key[order], return_index=True, return_counts=True)
    for k, s, c in zip(ks, starts, counts):
        if c < 12:
            continue
        out[allkey == k] = np.median(p[order[s:s + c]], axis=0)
    return out


def people(pic, ref, ref_shift=REF_SHIFT):
    """Mask (bool, H×W) of the people of [pic] inside the zone, and how many
    rows its platform is below the built-in scene's ([ref_shift]: the
    empty picture's)."""
    dx, dy = align(pic, ref, (266, 40, W, 150))
    shift = ref_shift + dy
    zx0, zy0, zx1, zy1 = ZONE[0], ZONE[1] + shift, ZONE[2], min(H, ZONE[3] + shift)
    wide = (max(0, zx0 - 30), max(0, zy0 - 10), W, min(H, zy1 + 20))
    ref = moved(ref, dx, dy)
    tr = translate(pic, ref, wide)
    p = pic.astype(np.float32)
    # Unlike every background colour within two pixels.
    best = np.full((H, W), 1e9, np.float32)
    R = 2
    for ddy in range(-R, R + 1):
        for ddx in range(-R, R + 1):
            d = np.sqrt(((p - moved(tr, ddx, ddy)) ** 2).sum(axis=2))
            best = np.minimum(best, d)
    m = best > 30
    zone = np.zeros((H, W), bool)
    zone[zy0:zy1, zx0:zx1] = True
    m &= ndimage.binary_dilation(zone, iterations=14)
    m = ndimage.binary_closing(m, iterations=2)
    m = ndimage.binary_fill_holes(m)
    m = ndimage.binary_opening(m, structure=np.ones((2, 2)))
    lab, _ = ndimage.label(m, structure=np.ones((3, 3)))
    keep = np.zeros_like(m)
    for i, sl in enumerate(ndimage.find_objects(lab), 1):
        hgt = sl[0].stop - sl[0].start
        area = (lab[sl] == i).sum()
        if hgt >= 9 and area >= 40:  # a person, not a speck
            keep |= lab == i
    keep = ndimage.binary_fill_holes(keep)
    return keep & zone, shift


def steady(masks):
    """The masks of an animated picture's frames without what only flickers:
    the people stand still (they only breathe and look at their phones),
    while window lights and signs blink and would pass for a person in
    some frames. Kept: what is found in most frames, and in each frame what
    it found right next to that."""
    if len(masks) < 3:
        return masks
    most = np.sum(masks, axis=0) * 2 > len(masks)
    near = ndimage.binary_dilation(most, iterations=1)
    return [(m & near) | (most & ndimage.binary_erosion(most, iterations=2)) for m in masks]


def pictures():
    pics = glob.glob(os.path.join(ROOT, 'assets/art/scene_*.webp'))
    for d in ('scenes', 'scenes_season', 'crowd', 'weather'):
        pics += glob.glob(os.path.join(ROOT, f'assets/art/{d}/*.webp'))
    # Tottori: the country station and the station scenes (drawn from the
    # built-in scene's original, so their platform is in its rows).
    pics += glob.glob(os.path.join(ROOT, 'assets/art/tottori/rural_*.webp'))
    pics += glob.glob(os.path.join(ROOT, 'assets/art/tottori/scenes/*.webp'))
    # An animated picture replaces its still one in the app.
    pics = [p for p in pics if not os.path.exists(p.replace('.webp', '_anim.webp'))]
    return sorted(p for p in pics if Image.open(p).size[0] == W)


def main():
    os.makedirs(OUT, exist_ok=True)
    check = sys.argv[sys.argv.index('--check') + 1] if '--check' in sys.argv else None
    only = sys.argv[sys.argv.index('--only') + 1] if '--only' in sys.argv else None
    if check:
        os.makedirs(check, exist_ok=True)
    if not only:
        for old in glob.glob(os.path.join(OUT, '*.webp')):
            os.remove(old)
    names, shifts = [], {}
    for path in pictures():
        name = os.path.basename(path).replace('_anim.webp', '.webp')
        if only and only not in name:
            continue
        if name == 'scene_underground.webp':
            # The subway platform (tools/gen_underground_scene.py): drawn
            # from the same original as the empty pictures, with nobody on it.
            shifts[name] = REF_SHIFT
            continue
        img = np.asarray(Image.open(path).convert('RGB'))
        ref = np.asarray(Image.open(ref_path(path)).convert('RGB'))
        masks = []
        for f in range(img.shape[0] // H):
            m, shift = people(img[f * H:(f + 1) * H], ref, 0 if '/tottori/' in path.replace(os.sep, '/') else REF_SHIFT)
            masks.append(m)
        shifts[name] = shift
        masks = steady(masks)
        mask = np.concatenate(masks, axis=0)
        if 'closed' in name:
            # After the last train nobody is on the platform (the dark
            # picture only differs from the empty one by its light).
            mask[:] = False
        if not only and mask.any():
            out = np.zeros((mask.shape[0], W, 4), np.uint8)
            out[..., 3] = mask * 255
            save_art(Image.fromarray(out, 'RGBA'), os.path.join(OUT, name))
            names.append(name)
        if check:
            z = (ZONE[0] - 16, max(0, ZONE[1] + shift - 4), W, min(H, ZONE[3] + shift + 14))
            b = img[:H].astype(np.float32)
            b[masks[0]] = b[masks[0]] * 0.45 + np.array([255, 0, 60]) * 0.55
            im = Image.fromarray(b.astype(np.uint8)[z[1]:z[3], z[0]:z[2]])
            im.resize((im.width * 3, im.height * 3), Image.NEAREST).save(os.path.join(check, name[:-5] + '.png'))
        print(name, len(masks), shift, int(mask.sum()))
    if not only:
        # The app reads this: which pictures have a mask, and each picture's
        # platform shift (decorations move down with it).
        index_path = os.path.join(ROOT, 'assets/art/decor/index.json')
        index = json.load(open(index_path, encoding='utf8')) if os.path.exists(index_path) else {}
        index['masks'] = sorted(names)
        index['shifts'] = dict(sorted(shifts.items()))
        with open(index_path, 'w', encoding='utf8') as f:
            json.dump(index, f, indent=1)
        print(len(names), 'masks of', len(shifts), 'pictures')


if __name__ == '__main__':
    main()
