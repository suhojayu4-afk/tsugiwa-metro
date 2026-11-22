"""The country diesel railcar's pictures for the app, from the chosen GPT
cut (docs/art/gen/tottori/diesel/cut1, tools/train_cutout.py --factor 8):
padded to the standard train's 75x96 frame (standing on the same rails),
plus the rain and snow overlays made the same way as the standard train's
(tools/make_train_weather.py). Prints the headlight centres for
SceneArt._lamps.

  python tools/tottori/make_diesel.py  ->  assets/art/tottori/diesel/
"""
import os
import shutil
import sys
import tempfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import make_train_weather  # noqa: E402
from art_io import save_art  # noqa: E402

CUT = os.path.join(ROOT, 'docs', 'art', 'gen', 'tottori', 'diesel', 'cut1')
OUT = os.path.join(ROOT, 'assets', 'art', 'tottori', 'diesel')
W, H = 75, 96


def pad(im):
    im = im.convert('RGBA')
    out = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    out.paste(im, ((W - im.width) // 2, H - im.height))
    return out


os.makedirs(OUT, exist_ok=True)
for part in ('day', 'evening', 'night'):
    save_art(pad(Image.open(os.path.join(CUT, f'train_front_base_{part}.webp'))),
             os.path.join(OUT, f'front_base_{part}.webp'))
save_art(pad(Image.open(os.path.join(CUT, 'train_front_stripe.webp'))), os.path.join(OUT, 'front_stripe.webp'))

tmp = tempfile.mkdtemp()
shutil.copy(os.path.join(OUT, 'front_base_day.webp'), os.path.join(tmp, 'train_front_base_day.webp'))
make_train_weather.ART = tmp
make_train_weather.main()
shutil.copy(os.path.join(tmp, 'train_front_snow.png'), os.path.join(OUT, 'front_snow.png'))
shutil.copy(os.path.join(tmp, 'train_front_rain.png'), os.path.join(OUT, 'front_rain.png'))

# Headlights: the brightest warm blobs below the stripe.
day = Image.open(os.path.join(OUT, 'front_base_evening.webp')).convert('RGBA')
px = day.load()
pts = [(x, y) for y in range(H // 2, H) for x in range(W)
       if px[x, y][3] and px[x, y][0] > 235 and px[x, y][1] > 200 and px[x, y][2] < 190]
for side in (pts and [p for p in pts if p[0] < W / 2], pts and [p for p in pts if p[0] >= W / 2]):
    if side:
        print('lamp', round(sum(p[0] for p in side) / len(side) + 0.5, 1), round(sum(p[1] for p in side) / len(side) + 0.5, 1))

# Side view for the MY shop (PixelLab candidate c0): the pure green band
# becomes a grey stripe mask the app tints with the line colour.
import colorsys  # noqa: E402

side = Image.open(os.path.join(ROOT, 'docs', 'art', 'gen', 'tottori', 'diesel', 'side', 'c0.png')).convert('RGBA')
side = side.crop(side.getbbox())
base = Image.new('RGBA', side.size, (0, 0, 0, 0))
stripe = Image.new('RGBA', side.size, (0, 0, 0, 0))
sp, bp, tp = side.load(), base.load(), stripe.load()
for y in range(side.height):
    for x in range(side.width):
        r, g, b, a = sp[x, y]
        if a < 128:
            continue
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        if 0.22 < h < 0.45 and s > 0.35 and v > 0.25:
            k = min(255, round(v * 255 / 0.8))
            tp[x, y] = (k, k, k, 255)
        else:
            bp[x, y] = (r, g, b, 255)
save_art(base, os.path.join(OUT, 'side_base.webp'))
save_art(stripe, os.path.join(OUT, 'side_stripe.webp'))
print('side', side.size)
