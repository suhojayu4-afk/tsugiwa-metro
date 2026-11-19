"""Mt. Fuji for the route map, in the map's own colours: the PixelLab
painting (docs/art/gen/landmarks_raw/fuji_big/c1.png) re-coloured so it
belongs to the flat terrain round it - light blue-grey slopes, white snow,
and a foot that turns into the same forest greens and fades into them.

  python tools/make_fuji.py   →  assets/art/landmarks/fuji_big.png
"""
import colorsys
import math
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'docs/art/gen/landmarks_raw/fuji_big/c1.png')
OUT = os.path.join(ROOT, 'assets/art/landmarks/fuji_big.png')

# The terrain's forest greens round Fuji (light → dark).
FOREST = [(168, 210, 128), (126, 182, 102), (108, 157, 88), (84, 142, 84), (56, 104, 70)]
# Slopes: soft lilac grey like the map's distant hills, lit from the top left.
SLOPE_LIGHT, SLOPE_DARK = (196, 204, 222), (122, 132, 166)
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def lum(c):
    return (0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]) / 255


def mix(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def main():
    src = Image.open(SRC).convert('RGBA')
    src = src.crop(src.getbbox())
    w, h = src.size
    sp = src.load()
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    op = out.load()
    cx = w / 2
    for y in range(h):
        for x in range(w):
            r, g, b, a = sp[x, y]
            if a < 128:
                continue
            l = lum((r, g, b))
            _, s, _ = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            # Snow: bright, nearly grey pixels stay white (a little warm).
            if l > 0.72 and s < 0.25:
                c = mix((236, 240, 248), (255, 255, 255), min(1, (l - 0.72) / 0.2))
            else:
                # Slope shade from the painting's light, in the map's lilac grey.
                t = max(0.0, min(1.0, (l - 0.12) / 0.5))
                c = mix(SLOPE_DARK, SLOPE_LIGHT, t)
            # Lower down the mountain turns into forest.
            v = y / h
            green = max(0.0, min(1.0, (v - 0.48) / 0.32))
            if green > 0:
                t = max(0.0, min(1.0, (l - 0.1) / 0.45))
                f = FOREST[min(len(FOREST) - 1, int((1 - t) * len(FOREST)))]
                c = mix(c, f, green)
            # The foot fades into the ground (dithered, no hard edge): an oval
            # base, transparent towards its rim.
            d = (x - cx) / (w / 2)
            bottom = h * 0.5 + h * 0.5 * math.sqrt(max(0.0, 1 - d * d))
            fade = max(0.0, min(1.0, (bottom - y) / (h * 0.22)))
            side = max(0.0, min(1.0, (1 - abs(d)) / 0.12))
            keep = min(fade, side)
            if keep < 1 and keep * 16 <= BAYER[y % 4][x % 4]:
                continue
            op[x, y] = c + (255,)
    out = out.crop(out.getbbox())
    out.save(OUT)
    print('fuji', out.size)


if __name__ == '__main__':
    main()
