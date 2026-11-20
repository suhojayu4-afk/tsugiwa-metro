"""Weather overlays for the front train (75x96, drawn over train_front_base_*):

  assets/art/train_front_snow.png  snow on the roof, the cab edges, the ledge
                                   under the windshield and the skirt
  assets/art/train_front_rain.png  raindrops and short runs on the windshield

Made from the train's own outline, so they fit it exactly.
  python tools/make_train_weather.py
"""
import os
import random

from PIL import Image
from art_io import save_art  # noqa: E402  (lossless WebP)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, 'assets', 'art')

SNOW = (244, 247, 252, 255)
SNOW_SHADE = (206, 214, 232, 255)


def main():
    base = Image.open(os.path.join(ART, 'train_front_base_day.webp')).convert('RGBA')
    w, h = base.size
    alpha = base.split()[3].load()
    solid = lambda x, y: 0 <= x < w and 0 <= y < h and alpha[x, y] > 40
    rnd = random.Random(7)

    # ---- snow ----
    snow = Image.new('RGBA', (w, h))
    s = snow.load()
    for x in range(w):
        top = next((y for y in range(h) if solid(x, y)), None)
        if top is None or top > 20:
            continue
        depth = 2 + (rnd.random() < 0.45) + (rnd.random() < 0.15)
        for d in range(depth):
            if solid(x, top + d):
                s[x, top + d] = SNOW if d < depth - 1 else SNOW_SHADE
    # Upper corners of the cab: snow sticks a little lower down the sides.
    for y in range(8, 24):
        for x in range(w):
            if solid(x, y) and not solid(x - 1, y) and rnd.random() < 0.7:
                s[x, y] = SNOW_SHADE
            if solid(x, y) and not solid(x + 1, y) and rnd.random() < 0.7:
                s[x, y] = SNOW_SHADE
    # A soft pile along the bottom of the windshield, deeper in the corners
    # (the wipers push it there): smooth bumps, 1-4 px.
    bumps = [rnd.random() for _ in range(80)]
    for x in range(4, 70):
        n = (bumps[x] + bumps[x + 1] + bumps[x + 2]) / 3
        d = 1 + round(n * 1.6) + (2 if x < 12 or x > 62 else 0)
        for k in range(d):
            y = 55 - k
            if solid(x, y):
                s[x, y] = SNOW_SHADE if k == 0 else SNOW
    # Patches on the top of the skirt.
    x = 6
    while x < 68:
        run = rnd.randrange(3, 9)
        if rnd.random() < 0.6:
            for k in range(run):
                if solid(x + k, 77):
                    s[x + k, 77] = SNOW
                    if 0 < k < run - 1 and solid(x + k, 76):
                        s[x + k, 76] = SNOW
        x += run + rnd.randrange(1, 4)
    # Flakes stuck on the windshield and the body.
    for _ in range(26):
        x, y = rnd.randrange(6, 68), rnd.randrange(16, 92)
        if solid(x, y):
            s[x, y] = (236, 241, 250, 210)
    # PNG on purpose: WebP decodes the half-transparent edges a shade differently.
    save_art(snow, os.path.join(ART, 'train_front_snow.png'))

    # ---- rain ----
    rain = Image.new('RGBA', (w, h))
    r = rain.load()
    for _ in range(40):
        x, y = rnd.randrange(7, 67), rnd.randrange(16, 53)
        if not solid(x, y):
            continue
        r[x, y] = (226, 234, 246, 200)  # the drop's highlight
        if solid(x, y + 1):
            r[x, y + 1] = (150, 164, 186, 150)  # its shadow side
        if rnd.random() < 0.15:  # a drop running down
            for k in range(2, 2 + rnd.randrange(1, 4)):
                if solid(x, y + k):
                    r[x, y + k] = (190, 202, 222, 110)
    # Water on the band and the lights.
    for _ in range(18):
        x, y = rnd.randrange(4, 70), rnd.randrange(57, 76)
        if solid(x, y):
            r[x, y] = (226, 234, 246, 150)
    save_art(rain, os.path.join(ART, 'train_front_rain.png'))
    print('train weather overlays written')


if __name__ == '__main__':
    main()
