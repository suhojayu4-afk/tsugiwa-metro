"""Make PixelLab landmarks sit flat on the map.

The generated landmarks stand on a little floating block (a top face plus a
thick dirt/stone side). On a flat map that side makes them look like
floating islands. This removes the bottom `t` pixels of every column (the
side faces), leaving the top face as a flat plaza drawn on the ground.

  python tools/landmark_flatten.py SRC_DIR DST_DIR
"""
import os
import sys

from PIL import Image

# Side-face thickness per landmark, measured by eye at 64x64.
THICKNESS = {'tower': 2, 'station': 1, 'kaminarimon': 2, 'skytree': 1, 'tocho': 2, 'ueno': 4,
             'rainbow': 4, 'meiji': 2, 'airport': 2,
             'shibuya': 3, 'dome': 2, 'nijubashi': 4, 'takao': 3, 'narita': 2,
             'kokugikan': 2, 'akihabara': 2, 'sunshine': 2,
             'ferris': 3,
             'bigsight': 3,  # v2 (2026-11-18): bigsight_v2.png, 4 inverted pyramids; 1px outline + 2px side
             'pagoda': 3, 'roppongi': 4, 'wako': 4, 'toyosu': 4,
             # all of Kanto (2026-11-19)
             'fuji': 4, 'daibutsu': 3, 'enoshima': 4, 'hakone': 4, 'minatomirai': 4, 'chinatown': 4,
             'kawagoe': 3, 'naritasan': 3, 'chureito': 8, 'themepark': 3,
             'nikko': 3, 'hitachi': 4, 'ashikaga': 4, 'tomioka': 3, 'oarai': 4,
             'kusatsu': 3, 'karuizawa': 4, 'hachimangu': 3, 'atami': 4}
# gatebridge.png has no base (stands on the sea): copied as it is.


def flatten(im: Image.Image, t: int) -> Image.Image:
    im = im.convert('RGBA')
    px = im.load()
    w, h = im.size
    for x in range(w):
        removed = 0
        for y in range(h - 1, -1, -1):
            if px[x, y][3] == 0:
                if removed:
                    break
                continue
            px[x, y] = (0, 0, 0, 0)
            removed += 1
            if removed >= t:
                break
    return im


def main() -> None:
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    for name, t in THICKNESS.items():
        im = Image.open(os.path.join(src, name + '.png'))
        flatten(im, t).save(os.path.join(dst, name + '.png'))
        print(name, 'side removed:', t, 'px')


if __name__ == '__main__':
    main()
