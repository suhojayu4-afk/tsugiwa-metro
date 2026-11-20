"""Fills the see-through holes inside the front train art
(assets/art/train_front_base_*.webp): between the headlights, the lower
front panel and the right side. Every hole pixel inside the train's outline
(per row, between its leftmost and rightmost solid pixel) takes the most
common solid colour around it, so the fill stays in the art's own palette
(no blur). The stripe band (train_front_stripe.webp) is left as it is.

  python tools/fill_train_holes.py

After this, the lower front panel (rows 61-80) was redrawn with PixelLab
inpaint (day picture), toned to the body greys, and carried over to the
evening and night pictures by their colour mapping (2026-11-19).
"""
import collections
import os

from PIL import Image
from art_io import save_art  # noqa: E402  (lossless WebP)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, 'assets', 'art')


def fill(path, stripe):
    im = Image.open(path).convert('RGBA')
    px, sp = im.load(), stripe.load()
    w, h = im.size
    holes = set()
    for y in range(h):
        solid = [x for x in range(w) if px[x, y][3] > 128 or sp[x, y][3] > 128]
        if not solid:
            continue
        for x in range(min(solid), max(solid) + 1):
            if px[x, y][3] <= 128 and sp[x, y][3] <= 128:
                holes.add((x, y))
    # Grow inwards from the edges of each hole, a ring at a time.
    while holes:
        done = {}
        for x, y in holes:
            near = collections.Counter(
                px[x + dx, y + dy][:3]
                for dx in (-2, -1, 0, 1, 2) for dy in (-2, -1, 0, 1, 2)
                if 0 <= x + dx < w and 0 <= y + dy < h and (x + dx, y + dy) not in holes
                and px[x + dx, y + dy][3] > 128
            )
            if near:
                done[(x, y)] = near.most_common(1)[0][0]
        if not done:
            break
        for (x, y), c in done.items():
            px[x, y] = (*c, 255)
        holes -= done.keys()
    save_art(im, path)
    return len(done)


stripe = Image.open(os.path.join(ART, 'train_front_stripe.webp')).convert('RGBA')
for part in ('day', 'evening', 'night'):
    p = os.path.join(ART, f'train_front_base_{part}.webp')
    fill(p, stripe)
    print('filled', os.path.basename(p))
