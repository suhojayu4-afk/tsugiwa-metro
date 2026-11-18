"""Pixel parts for the つぎの電車 widget, picked from PixelLab candidates in
docs/art/gen/widget/ (2026-11-18): night platform background, station sign,
side-view train, LED frame and small icons.

Magenta areas (the colour band of the sign and the stripe of the train) are
split into a *_band.png mask the app tints with the line colour.

  python tools/make_widget_art.py  →  assets/art/widget/*.png
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'docs', 'art', 'gen', 'widget')
OUT = os.path.join(ROOT, 'assets', 'art', 'widget')

PICK = {'train': 'train_30.png', 'sign': 'sign_0.png', 'led': 'led_2.png'}


def is_magenta(r, g, b):
    return r > 40 and b > 40 and g < min(r, b) * 0.6


def split(im):
    """→ (base with the band in neutral grey, white band mask keeping its shading)."""
    base, band = im.copy(), Image.new('RGBA', im.size)
    bp, mp = base.load(), band.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = bp[x, y]
            if a > 40 and r > 235 and b > 235 and g < 240:
                bp[x, y] = (250, 250, 250, a)  # white tinted by the magenta next to it
            elif a > 40 and is_magenta(r, g, b):
                v = min(255, round(max(r, b) / 215 * 255))
                mp[x, y] = (v, v, v, 255)
                bp[x, y] = (0, 0, 0, 0)
    return base, band


def main():
    os.makedirs(OUT, exist_ok=True)
    src = lambda n: Image.open(os.path.join(SRC, n)).convert('RGBA')

    # Backgrounds: the night platform redrawn by PixelLab edit_image for each
    # time of day × sky (bg/{day,evening,night}_{clear,cloudy,rainsoon,rain,
    # snowsoon,snow}.png, 320×112), at the widget's 192×58.
    for f in sorted(os.listdir(os.path.join(SRC, 'bg'))):
        src(os.path.join('bg', f)).crop((0, 6, 320, 103)).resize((192, 58), Image.BOX).save(
            os.path.join(OUT, f'bg_{f}'))

    # The bigger 地下鉄案内 widget (4x2): the same backgrounds at 192×96,
    # scaled to the height and cropped to the middle.
    for f in sorted(os.listdir(os.path.join(SRC, 'bg'))):
        im = src(os.path.join('bg', f)).resize((274, 96), Image.BOX)
        im.crop((41, 0, 233, 96)).save(os.path.join(OUT, f'board_{f}'))

    sign = src(PICK['sign']).crop((1, 0, 45, 28))
    ImageDraw.Draw(sign).line([(1, 27), (43, 27)], fill=(60, 62, 72, 255))  # bottom of the frame
    for name, im in zip(('sign', 'train'), (sign, src(PICK['train']).crop((3, 7, 62, 24)))):
        base, band = split(im)
        base.save(os.path.join(OUT, f'{name}_base.png'))
        band.save(os.path.join(OUT, f'{name}_band.png'))
    src(PICK['led']).crop((7, 0, 89, 20)).save(os.path.join(OUT, 'led.png'))
    # Icons: trimmed, and small ones doubled (whole pixels) to about 20 px.
    for icon in ('sun', 'suncloud', 'cloud2', 'raincloud', 'umbrella', 'snowcloud', 'snow', 'moon', 'mooncloud', 'bell'):
        im = src(f'icon_{icon}.png')
        im = im.crop(im.getbbox())
        k = max(1, 20 // max(im.size))
        im = im.resize((im.width * k, im.height * k), Image.NEAREST)
        out = Image.new('RGBA', (24, 24))
        out.paste(im, ((24 - im.width) // 2, (24 - im.height) // 2))
        out.save(os.path.join(OUT, f'icon_{icon}.png'))
    print('widget art written to', OUT)


if __name__ == '__main__':
    main()
