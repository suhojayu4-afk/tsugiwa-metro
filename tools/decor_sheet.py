"""Contact sheets of the review renders of a platform decoration
(test/tools/render_vending_check.dart): one sheet per scene, one tile per
picture the app really has (plain + each weather / crowd picture), cropped
around the decoration and enlarged.

  python tools/decor_sheet.py IN_DIR OUT_DIR [--crop x0,y0,x1,y1] [--scale 3] [--cols 6]
"""
import glob
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def arg(name, default):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def has_picture(scene, part, sky):
    if sky == 'plain':
        return True
    if sky == 'closed':
        part = 'night'
    d = 'crowd' if sky in ('relaxed', 'normal', 'crowded', 'packed') else 'weather'
    return os.path.exists(os.path.join(ROOT, 'assets/art', d, f'{scene}_{part}_{sky}.webp'))


def main():
    src, out = sys.argv[1], sys.argv[2]
    crop = tuple(int(v) for v in arg('--crop', '270,36,384,146').split(','))
    k, cols = int(arg('--scale', '3')), int(arg('--cols', '6'))
    os.makedirs(out, exist_ok=True)
    by_scene = {}
    for p in sorted(glob.glob(os.path.join(src, '*.png'))):
        scene, part, sky = os.path.basename(p)[:-4].split('_', 2)
        if has_picture(scene, part, sky):
            by_scene.setdefault(scene, []).append((part, sky, p))
    order = {'day': 0, 'evening': 1, 'night': 2}
    for scene, tiles in by_scene.items():
        tiles.sort(key=lambda t: (order[t[0]], t[1] != 'plain', t[1]))
        tw, th = (crop[2] - crop[0]) * k, (crop[3] - crop[1]) * k + 12
        rows = (len(tiles) + cols - 1) // cols
        sheet = Image.new('RGB', (tw * cols, th * rows), (20, 20, 24))
        d = ImageDraw.Draw(sheet)
        for i, (part, sky, p) in enumerate(tiles):
            im = Image.open(p).convert('RGB').crop(crop)
            im = im.resize((im.width * k, im.height * k), Image.NEAREST)
            x, y = (i % cols) * tw, (i // cols) * th
            sheet.paste(im, (x, y + 12))
            d.text((x + 2, y), f'{part} {sky}', fill=(255, 255, 255))
        sheet.save(os.path.join(out, f'{scene}.png'))
        print(scene, len(tiles))


if __name__ == '__main__':
    main()
