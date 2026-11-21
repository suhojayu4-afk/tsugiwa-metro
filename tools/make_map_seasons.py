"""Pictures for the seasonal decorations on the route map
(lib/features/route_map/map_seasons.dart, assets/cities/tokyo/seasons.json).

Ginkgo trees (いちょう) for the autumn avenues: the red maple pictures of the
map scenery (assets/art/map_decor/momiji_*.png) turned golden yellow, so they
match the other trees pixel for pixel.

  python tools/make_map_seasons.py   -> assets/art/map_seasons/icho_*.webp
"""
import colorsys
import os

from PIL import Image

from art_io import save_art

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DECOR = os.path.join(ROOT, 'assets', 'art', 'map_decor')
OUT = os.path.join(ROOT, 'assets', 'art', 'map_seasons')


def golden(src):
    """Leaves (reds and oranges) to ginkgo yellow; trunks (dark, low
    saturation) stay as they are."""
    im = Image.open(src).convert('RGBA')
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
            if s < 0.35 or l < 0.16 or not (h < 0.13 or h > 0.93):
                continue
            # Red 0.0 -> 0.12 (gold), orange 0.08 -> 0.15 (lemon); brighter.
            hn = 0.115 + (h if h < 0.5 else h - 1) * 0.45
            ln = min(0.82, l * 1.18 + 0.08)
            r2, g2, b2 = colorsys.hls_to_rgb(hn % 1, ln, min(1, s * 1.05))
            px[x, y] = (round(r2 * 255), round(g2 * 255), round(b2 * 255), a)
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    for v in ('a', 'b'):
        save_art(golden(os.path.join(DECOR, f'momiji_{v}.png')), os.path.join(OUT, f'icho_{v}.webp'))
    print('saved', sorted(os.listdir(OUT)))


if __name__ == '__main__':
    main()
