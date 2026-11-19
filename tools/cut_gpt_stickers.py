"""Cuts the GPT sticker sheet (docs/art/gen/stickers/stickers_raw.png: 12
stickers in a 4x3 grid on flat magenta) into one transparent PNG each,
assets/art/stickers/{name}.png, trimmed and shrunk so the longest side is
96 px (the share card draws them at about 48 logical px, saved at 3x).

  python tools/cut_gpt_stickers.py
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, 'docs', 'art', 'gen', 'stickers', 'stickers_raw.png')
OUT = os.path.join(ROOT, 'assets', 'art', 'stickers')
NAMES = [
    'sakura', 'heart', 'star', 'cat',
    'onigiri', 'fuji', 'train', 'ticket',
    'sparkle', 'hanko', 'coffee', 'rainbow',
]
SIZE = 96


def key(c):
    r, g, b = c[:3]
    return r > 150 and b > 150 and g < 110 and abs(r - b) < 90


def main():
    im = Image.open(RAW).convert('RGBA')
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if key(px[x, y]):
                px[x, y] = (0, 0, 0, 0)
    os.makedirs(OUT, exist_ok=True)
    cw, ch = w / 4, h / 3
    for i, name in enumerate(NAMES):
        cell = im.crop((round((i % 4) * cw), round((i // 4) * ch), round((i % 4 + 1) * cw), round((i // 4 + 1) * ch)))
        box = cell.getbbox()
        s = cell.crop(box)
        k = SIZE / max(s.size)
        s = s.resize((max(1, round(s.width * k)), max(1, round(s.height * k))), Image.NEAREST)
        sp = s.load()
        for y in range(s.height):
            for x in range(s.width):
                c = sp[x, y]
                sp[x, y] = (c[0], c[1], c[2], 255) if c[3] >= 128 else (0, 0, 0, 0)
        s.save(os.path.join(OUT, f'{name}.png'))
        print(name, s.size)


if __name__ == '__main__':
    main()
