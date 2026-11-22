"""People masks for the Tottori platform pictures only (tools/make_decor_masks.py
does all pictures and re-measures Tokyo's too): adds their masks to
assets/art/decor/vending_front/ and their entries to assets/art/decor/index.json,
leaving Tokyo's as they are.

Unlike Tokyo's, these pictures have an empty version of the very same drawing
(gen_empty_refs.py), so a person is simply what differs from it. The whole
person is kept, not only the part inside Tokyo's wall zone: here people stand
wider and lower, and a mask cut at the zone left them in pieces in front of a
stall.

  python tools/tottori/make_decor_masks_tottori.py
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import make_decor_masks as m  # noqa: E402
from art_io import save_art  # noqa: E402



def people(pic, ref):
    """Mask (bool, H×W) of the people of [pic] on the near platform."""
    p = pic.astype(np.float32)
    best = np.full((m.H, m.W), 1e9, np.float32)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            best = np.minimum(best, np.sqrt(((p - m.moved(ref, dx, dy).astype(np.float32)) ** 2).sum(axis=2)))
    k = best > 34
    k[:, :280] = False  # the far end: no decoration reaches it
    k[:60] = False  # the roof
    k = ndimage.binary_closing(k, iterations=3)
    k = ndimage.binary_fill_holes(k)
    # Shadows on the floor are flat slivers, a person is tall.
    k = ndimage.binary_opening(k, structure=np.ones((7, 1)))
    k = ndimage.binary_opening(k, structure=np.ones((2, 2)))
    lab, _ = ndimage.label(k, structure=np.ones((3, 3)))
    keep = np.zeros_like(k)
    for i, sl in enumerate(ndimage.find_objects(lab), 1):
        # Tall, and standing on the floor (a window that changed is not).
        if sl[0].stop - sl[0].start >= 20 and sl[0].stop >= 112 and (lab[sl] == i).sum() >= 90:
            keep |= lab == i
    return ndimage.binary_fill_holes(ndimage.binary_closing(keep, iterations=2))


# The pillar that stands where the decorations go: nearer than the wall they
# stand against (its foot is on row 137, theirs on 129), so it is in front
# of them too. Columns (first, one past the last); the same in every hour.
PILLAR = {'tottori': (310, 315)}
PILLAR_WOOD = (308, 316)
PILLAR_ROWS = (60, 138)


def pillar(name):
    x0, x1 = PILLAR.get(name.split('_')[0], PILLAR_WOOD)
    k = np.zeros((m.H, m.W), bool)
    k[PILLAR_ROWS[0]:PILLAR_ROWS[1], x0:x1] = True
    return k


index_path = os.path.join(ROOT, 'assets/art/decor/index.json')
index = json.load(open(index_path, encoding='utf8'))
names, shifts = set(index['masks']), dict(index['shifts'])
for path in m.pictures():
    if '/tottori/' not in path.replace(os.sep, '/'):
        continue
    name = os.path.basename(path).replace('_anim.webp', '.webp')
    img = np.asarray(Image.open(path).convert('RGB'))
    ref = np.asarray(Image.open(m.ref_path(path)).convert('RGB'))
    masks = []
    for f in range(img.shape[0] // m.H):
        masks.append(people(img[f * m.H:(f + 1) * m.H], ref))
    shift = 0  # drawn from the built-in scene's original: the same rows
    post = pillar(name)
    mask = np.concatenate([k | post for k in m.steady(masks)], axis=0)
    shifts[name] = shift
    out_path = os.path.join(m.OUT, name)
    if mask.any():
        out = np.zeros((mask.shape[0], m.W, 4), np.uint8)
        out[..., 3] = mask * 255
        save_art(Image.fromarray(out, 'RGBA'), out_path)
        names.add(name)
    else:
        names.discard(name)
        if os.path.exists(out_path):
            os.remove(out_path)
    print(name, len(masks), shift, int(mask.sum()))
index['masks'] = sorted(names)
index['shifts'] = dict(sorted(shifts.items()))
with open(index_path, 'w', encoding='utf8') as f:
    json.dump(index, f, indent=1)
