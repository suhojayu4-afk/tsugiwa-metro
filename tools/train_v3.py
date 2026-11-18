"""Train front v3: clean PixelLab art (docs/art/gen/train_v3/c0.png, 75x96)
→ assets/art/train_front_base_{day,evening,night}.png + train_front_stripe.png

The band under the windshield was drawn in flat magenta so it can be cut out
exactly; the app multiplies the stripe by the line colour.

  python tools/train_v3.py
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'docs', 'art', 'gen', 'train_v3', 'c0.png')
OUT = os.path.join(ROOT, 'assets', 'art')


def is_magenta(r, g, b):
    return r > 170 and b > 170 and g < 110


def main():
    src = Image.open(SRC).convert('RGBA')
    # The art leaves 5 empty rows under the skirt; move it down so the train
    # stands on the rails at the same place as before (bottom at row 95).
    shifted = Image.new('RGBA', src.size, (0, 0, 0, 0))
    shifted.paste(src.crop((0, 0, src.width, src.height - 5)), (0, 5))
    src = shifted
    w, h = src.size
    base = Image.new('RGBA', (w, h))
    stripe = Image.new('RGBA', (w, h))
    sp, bp, s = stripe.load(), base.load(), src.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = s[x, y]
            if a < 40:
                continue
            if is_magenta(r, g, b):
                # Light at the top of the band, a touch darker at the bottom.
                v = 255 if y < 65 else 236
                sp[x, y] = (v, v, v, 255)
                bp[x, y] = (190, 192, 200, 255)
            else:
                bp[x, y] = (r, g, b, 255)

    # The art is lit like a bright day; re-light it for the other scenes.
    # Headlights and other very bright pixels keep their colour.
    for part, (tint, amount, gain) in {
        'day': ((255, 255, 255), 0.0, 1.0),
        'evening': ((255, 214, 188), 0.38, 0.98),
        'night': ((120, 132, 190), 0.7, 0.72),
    }.items():
        graded = base.copy()
        gp = graded.load()
        for y in range(h):
            for x in range(w):
                r, g, b, al = gp[x, y]
                if not al or max(r, g, b) > 235:
                    continue
                lum = (r * 299 + g * 587 + b * 114) / 1000
                gp[x, y] = tuple(
                    max(0, min(255, round(((1 - amount) * c + amount * lum * t / 255) * gain)))
                    for c, t in zip((r, g, b), tint)
                ) + (al,)
        graded.save(os.path.join(OUT, f'train_front_base_{part}.png'))
    stripe.save(os.path.join(OUT, 'train_front_stripe.png'))
    print('train v3 written:', w, 'x', h)


if __name__ == '__main__':
    main()
