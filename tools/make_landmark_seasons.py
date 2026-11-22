"""Landmark pictures whose trees are cherry blossom by nature (Ueno Park,
the Chureito pagoda), for the rest of the year: the pink crowns turned
summer green and autumn red, in the colours of the map's own trees
(assets/art/map_decor/green_*.png, momiji_*.png), pixel for pixel otherwise.
The route map swaps them in by the season (route_map_screen.dart).

  python tools/make_landmark_seasons.py
    -> assets/art/map_seasons/<name>_green.webp, <name>_koyo.webp
"""
import colorsys
import os

from PIL import Image

from art_io import save_art

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, 'assets', 'art')
OUT = os.path.join(ART, 'map_seasons')

NAMES = ['ueno', 'chureito']


def hls(c):
    return colorsys.rgb_to_hls(c[0] / 255, c[1] / 255, c[2] / 255)


def is_pink(c):
    """Blossom pinks (light to deep), not the vermilion of a pagoda."""
    h, l, s = hls(c)
    return c[3] > 0 and 0.84 <= h <= 0.985 and s >= 0.25 and l >= 0.22


def palette(files, keep):
    """The leaf pixels of the map's trees, dark to light (each colour as
    often as it is used, so a recoloured crown is shaded the same way)."""
    cols = []
    for f in files:
        im = Image.open(os.path.join(ART, 'map_decor', f)).convert('RGBA')
        for c in im.get_flattened_data() if hasattr(im, 'get_flattened_data') else im.getdata():
            if c[3] == 255 and keep(*hls(c)):
                cols.append(c[:3])
    return sorted(cols, key=lambda c: hls(c)[1])


GREEN = palette(['green_a.png', 'green_b.png', 'green_c.png'], lambda h, l, s: 0.2 < h < 0.45 and s > 0.3 and l > 0.2)
KOYO = palette(
    ['momiji_a.png', 'momiji_b.png', 'momiji_c.png'],
    lambda h, l, s: (h < 0.13 or h > 0.93) and s >= 0.35 and l > 0.25,
)


def recolour(name, pal):
    im = Image.open(os.path.join(ART, 'landmarks', name + '.png')).convert('RGBA')
    px = im.load()
    count = {}
    for y in range(im.height):
        for x in range(im.width):
            if is_pink(px[x, y]):
                count[px[x, y]] = count.get(px[x, y], 0) + 1
    if not count:
        return im
    # By lightness rank: the darkest pinks to the darkest leaf colour, and so on.
    total, seen, to = sum(count.values()), 0, {}
    for c in sorted(count, key=lambda c: hls(c)[1]):
        t = (seen + count[c] / 2) / total
        seen += count[c]
        to[c] = pal[min(len(pal) - 1, int(t * len(pal)))] + (c[3],)
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y] in to:
                px[x, y] = to[px[x, y]]
    return im


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for name in NAMES:
        for tag, pal in (('green', GREEN), ('koyo', KOYO)):
            out = os.path.join(OUT, f'{name}_{tag}.webp')
            save_art(recolour(name, pal), out)
            print(out)
