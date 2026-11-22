"""People masks for the Tottori platform pictures only (tools/make_decor_masks.py
does all pictures and re-measures Tokyo's too): adds their masks to
assets/art/decor/vending_front/ and their entries to assets/art/decor/index.json,
leaving Tokyo's as they are.

  python tools/tottori/make_decor_masks_tottori.py
"""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import make_decor_masks as m  # noqa: E402
from art_io import save_art  # noqa: E402

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
        mk, shift = m.people(img[f * m.H:(f + 1) * m.H], ref, 0)
        masks.append(mk)
    mask = np.concatenate(m.steady(masks), axis=0)
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
