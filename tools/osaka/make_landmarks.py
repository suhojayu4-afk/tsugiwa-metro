"""The city's landmarks for the route map from the chosen PixelLab candidates
(docs/art/gen/<city>/lm_<name>/c<N>.png, picks in landmarks.py): the side of
the little tile cut away so they sit flat on the map (tools/landmark_flatten.py),
like tools/tottori/make_landmarks.py.

  python -X utf8 tools/<city>/make_landmarks.py  ->  assets/art/<city>/landmarks/
  python -X utf8 tools/<city>/make_landmarks.py sheet   (also a side-by-side check sheet in docs/art/gen/<city>/)
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
sys.path.insert(1, os.path.join(ROOT, 'tools'))
import conf  # noqa: E402
from landmark_flatten import flatten  # noqa: E402
from landmarks import PICKS  # noqa: E402

GEN = os.path.join(ROOT, 'docs', 'art', 'gen', conf.CITY)
OUT = os.path.join(ROOT, 'assets', 'art', conf.CITY, 'landmarks')


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
done = []
for name, (c, t) in PICKS.items():
    src = Image.open(os.path.join(GEN, f'lm_{name}', f'c{c}.png'))
    flat = flatten(trim_tail(src), t)
    flat.save(os.path.join(OUT, name + '.png'))
    done.append((src.convert('RGBA'), flat))
    print(name, 'c%d' % c)
if 'sheet' in sys.argv[1:]:
    k = 3
    sheet = Image.new('RGBA', (len(done) * 64 * k, 2 * 64 * k), (200, 214, 180, 255))
    for i, (a, b) in enumerate(done):
        sheet.alpha_composite(a.resize((64 * k, 64 * k), Image.NEAREST), (i * 64 * k, 0))
        sheet.alpha_composite(b.resize((64 * k, 64 * k), Image.NEAREST), (i * 64 * k, 64 * k))
    sheet.save(os.path.join(GEN, 'landmarks_flat.png'))
