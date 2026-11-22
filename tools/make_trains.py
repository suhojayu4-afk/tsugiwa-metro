"""The MY trains of tools/gen_trains.py for the app: the chosen GPT picture
cut out (tools/train_cutout.py --factor 8, so the body is the standard
train's width and stands on the same rails), padded to 75 wide and at least
96 tall - horns and pantographs may stand taller: the app draws the extra
rows above the usual frame - plus rain and snow overlays
(tools/make_train_weather.py) and the small side view for the MY shop
(a PixelLab candidate in docs/art/gen/trains/<name>/side/). Prints the
headlight centres for SceneArt._lamps, in the standard 75x96 frame.

  python tools/make_trains.py [name ...]  ->  assets/art/trains/<name>/
"""
import colorsys
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

import make_train_weather
from art_io import save_art

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEN = os.path.join(ROOT, 'docs', 'art', 'gen', 'trains')
W, H = 75, 96
# name: (front candidate, side candidate)
PICKS = {'oni': (2, 0), 'yako': (1, 1), 'tenbo': (1, 6)}


def pad(im, tall):
    im = im.convert('RGBA')
    if im.width > W:  # a pixel too wide: trimmed at the sides
        x = (im.width - W) // 2
        im = im.crop((x, 0, x + W, im.height))
    out = Image.new('RGBA', (W, tall), (0, 0, 0, 0))
    out.paste(im, ((W - im.width) // 2, tall - im.height))
    return out


def relit(base, tint, amount, gain):
    """[base] (lit by the sunset) in another light; lamps keep their colour."""
    im = base.convert('RGBA')
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if not a or (max(r, g, b) > 235 and b < 215):
                continue
            lum = (r * 299 + g * 587 + b * 114) / 1000
            px[x, y] = tuple(max(0, min(255, round(((1 - amount) * c + amount * lum * t / 255) * gain)))
                             for c, t in zip((r, g, b), tint)) + (a,)
    return im


# Colourful trains keep their paint by day (the cut-out tool's day light
# is made for a silver train and would grey a red one).
LIGHT = {'day': ((226, 234, 250), 0.28, 1.08), 'evening': ((255, 255, 255), 0.0, 1.0),
         'night': ((120, 132, 190), 0.5, 0.66)}


def side(name, cand, out):
    src = os.path.join(GEN, name, 'side', f'c{cand}.png')
    if not os.path.exists(src):
        print(name, 'no side view yet')
        return
    im = Image.open(src).convert('RGBA')
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y][3] < 128:
                px[x, y] = (0, 0, 0, 0)
    im = im.crop(im.getbbox())
    # The shop draws side views 61 wide and about 20 tall.
    k = min(61 / im.width, 22 / im.height, 1.0)
    if k < 1:
        im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.NEAREST)
    base = Image.new('RGBA', im.size, (0, 0, 0, 0))
    stripe = Image.new('RGBA', im.size, (0, 0, 0, 0))
    sp, bp, tp = im.load(), base.load(), stripe.load()
    n = 0
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = sp[x, y]
            if a < 128:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if 0.22 < h < 0.45 and s > 0.35 and v > 0.25:
                k = min(255, round(v * 255 / 0.8))
                tp[x, y] = (k, k, k, 255)
                n += 1
            else:
                bp[x, y] = (r, g, b, 255)
    save_art(base, os.path.join(out, 'side_base.webp'))
    save_art(stripe, os.path.join(out, 'side_stripe.webp'))
    print(name, 'side', im.size, 'stripe px', n)


def make(name):
    front, side_cand = PICKS[name]
    cut = os.path.join(GEN, name, 'cut')
    subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'train_cutout.py'),
                    os.path.join(GEN, name, f'c{front}_raw.png'), cut, '--factor', '8'], check=True,
                   stdout=subprocess.DEVNULL)
    out = os.path.join(ROOT, 'assets', 'art', 'trains', name)
    os.makedirs(out, exist_ok=True)
    stripe = Image.open(os.path.join(cut, 'train_front_stripe.webp'))
    assert stripe.width <= W + 2, (name, stripe.size)
    tall = max(H, stripe.height)
    base = Image.open(os.path.join(cut, 'train_front_base.webp'))
    for part, light in LIGHT.items():
        save_art(pad(relit(base, *light), tall), os.path.join(out, f'front_base_{part}.webp'))
    save_art(pad(stripe, tall), os.path.join(out, 'front_stripe.webp'))
    n = sum(stripe.convert('RGBA').getchannel('A').histogram()[1:])

    tmp = tempfile.mkdtemp()
    shutil.copy(os.path.join(out, 'front_base_day.webp'), os.path.join(tmp, 'train_front_base_day.webp'))
    make_train_weather.ART = tmp
    make_train_weather.main()
    shutil.copy(os.path.join(tmp, 'train_front_snow.png'), os.path.join(out, 'front_snow.png'))
    shutil.copy(os.path.join(tmp, 'train_front_rain.png'), os.path.join(out, 'front_rain.png'))

    # Headlights: the brightest warm blobs in the lower half, in the
    # standard frame's rows (the extra rows above it count as negative).
    eve = Image.open(os.path.join(out, 'front_base_evening.webp')).convert('RGBA')
    px = eve.load()
    over = tall - H
    pts = [(x, y - over) for y in range(over + H // 2, tall) for x in range(W)
           if px[x, y][3] and px[x, y][0] > 235 and px[x, y][1] > 200 and px[x, y][2] < 215]
    lamps = []
    for part in ([p for p in pts if p[0] < W / 2], [p for p in pts if p[0] >= W / 2]):
        if part:
            lamps.append((round(sum(p[0] for p in part) / len(part) + 0.5, 1),
                          round(sum(p[1] for p in part) / len(part) + 0.5, 1)))
    print(name, 'size', (W, tall), 'stripe px', n, 'lamps', lamps)
    side(name, side_cand, out)


if __name__ == '__main__':
    for name in sys.argv[1:] or list(PICKS):
        make(name)
