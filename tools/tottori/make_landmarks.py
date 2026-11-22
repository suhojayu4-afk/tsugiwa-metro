"""Tottori landmarks for the route map from the chosen PixelLab candidates
(docs/art/gen/tottori/lm_<name>/c<N>.png): the side of the little tile cut
away so they sit flat on the map (tools/landmark_flatten.py), and Mt. Daisen
re-coloured into the map's own colours like Mt. Fuji (tools/make_fuji.py).

  python tools/tottori/make_landmarks.py  ->  assets/art/tottori/landmarks/
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import make_fuji  # noqa: E402
from landmark_flatten import flatten  # noqa: E402

GEN = os.path.join(ROOT, 'docs', 'art', 'gen', 'tottori')
OUT = os.path.join(ROOT, 'assets', 'art', 'tottori', 'landmarks')
# name: (candidate, side thickness in px)
PICKS = {'sakyu': (2, 3), 'jinpukaku': (5, 3), 'hakuto': (0, 4), 'uradome': (6, 4), 'kurayoshi': (2, 3),
         'nageiredo': (2, 3), 'sakaiminato': (2, 4),
         # 2026-11-23: more of the prefecture (same style image as the first eight)
         'yonago_castle': (5, 4), 'kaike': (6, 4), 'misasa': (4, 4), 'wakasa_sl': (0, 4), 'koi_yamagata': (0, 4),
         'chizu': (0, 4), 'koyamaike': (0, 5), 'togo': (5, 4), 'mukibanda': (0, 4), 'eshima': (5, 4),
         'hanakairo': (9, 4), 'nagashibina': (7, 4), 'hokuei_wind': (0, 4), 'hayabusa': (1, 4)}




def trim_tail(im):
    """Clears stray pixels under the tile (below the first empty row in the lower half)."""
    im = im.convert('RGBA')
    px = im.load()
    w, h = im.size
    for y in range(h // 2, h):
        if all(px[x, y][3] == 0 for x in range(w)):
            for yy in range(y, h):
                for x in range(w):
                    px[x, yy] = (0, 0, 0, 0)
            break
    return im


os.makedirs(OUT, exist_ok=True)
for name, (c, t) in PICKS.items():
    im = Image.open(os.path.join(GEN, f'lm_{name}', f'c{c}.png'))
    flatten(trim_tail(im), t).save(os.path.join(OUT, name + '.png'))
    print(name, 'c%d' % c)
make_fuji.SRC = os.path.join(GEN, 'lm_daisen_big', 'c1.png')
make_fuji.OUT = os.path.join(OUT, 'daisen_big.png')
make_fuji.main()
