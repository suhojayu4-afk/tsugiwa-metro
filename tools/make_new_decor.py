"""MY decorations that are not platform furniture (which looked pasted on
among the people): train head marks, things in the sky and two more roof
strings. From PixelLab candidates in docs/art/gen/newdecor/<name>/cN.png.

  python tools/make_new_decor.py
  -> assets/art/marks/<id>.png   head marks, 15x15 (drawn on the train's face)
     assets/art/sky/<id>.png     sky things at their drawn size
     assets/art/decor/bunting.webp, teru.webp   roof overlays (384x192)
"""
import os

from PIL import Image, ImageDraw

from art_io import save_art

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEN = os.path.join(ROOT, 'docs/art/gen/newdecor')
# id: (candidate folder, candidate)
MARKS = {'sakura': ('hm_sakura', 4), 'dune': ('hm_dune', 7), 'moon': ('hm_dune', 0), 'pear': ('hm_dune', 10)}
SKY = {'balloon': ('balloon', 0, 26), 'balloon_far': ('balloon', 13, 13)}
# The roof's edge beam between the pillars, far end to near end (the line
# the lanterns hang on, tools/place_decor.py).
BEAM = ((262, 84), (383, 36))
FLAGS = [(230, 60, 60), (250, 200, 60), (70, 150, 230), (90, 190, 90), (240, 240, 240)]


def cut(name, i):
    im = Image.open(os.path.join(GEN, name, f'c{i}.png')).convert('RGBA')
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
    return im.crop(im.getbbox())


def sized(im, h):
    return im.resize((max(1, round(im.width * h / im.height)), max(1, round(h))), Image.NEAREST)


def along(t):
    (x0, y0), (x1, y1) = BEAM
    return x0 + (x1 - x0) * t, y0 + (y1 - y0) * t


def roof(kind):
    im = Image.new('RGBA', (384, 192))
    d = ImageDraw.Draw(im)
    d.line([BEAM[0], BEAM[1]], fill=(90, 80, 80, 255))
    teru = cut('teru', 0)
    n = 13 if kind == 'bunting' else 7
    for i in range(n):
        t = (i + 0.5) / n
        x, y = along(t)
        if kind == 'bunting':
            s = 3 + 7 * t
            d.polygon([(x - s / 2, y), (x + s / 2, y - s * 0.4), (x + s * 0.1, y + s)], fill=FLAGS[i % 5] + (255,))
        else:
            doll = sized(teru, 6 + 11 * t)
            im.alpha_composite(doll, (round(x - doll.width / 2), round(y)))
    return im


def main():
    for d in ('assets/art/marks', 'assets/art/sky'):
        os.makedirs(os.path.join(ROOT, d), exist_ok=True)
    for id_, (name, i) in MARKS.items():
        sized(cut(name, i), 15).save(os.path.join(ROOT, 'assets/art/marks', f'{id_}.png'))
    for id_, (name, i, h) in SKY.items():
        sized(cut(name, i), h).save(os.path.join(ROOT, 'assets/art/sky', f'{id_}.png'))
    for kind in ('bunting', 'teru'):
        save_art(roof(kind), os.path.join(ROOT, 'assets/art/decor', f'{kind}.webp'))
    print('ok')


if __name__ == '__main__':
    main()
