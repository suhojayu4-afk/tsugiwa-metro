"""Review sheets of the MY decorations (test/tools/render_decor_items.dart):
one PNG per item with every scene / hour it was rendered on, enlarged.

  python tools/decor_items_sheet.py IN_DIR OUT_DIR [--crop x0,y0,x1,y1] [--scale 3] [--cols 3]
"""
import glob
import os
import sys

from PIL import Image, ImageDraw


def arg(name, default):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def main():
    src, out = sys.argv[1], sys.argv[2]
    crop = tuple(int(v) for v in arg('--crop', '232,0,384,150').split(','))
    k, cols = int(arg('--scale', '3')), int(arg('--cols', '3'))
    os.makedirs(out, exist_ok=True)
    items = {}
    for p in sorted(glob.glob(os.path.join(src, '*__*.png'))):
        item, case = os.path.basename(p)[:-4].split('__')
        items.setdefault(item, []).append((case, p))
    order = {'day': 0, 'evening': 1, 'night': 2}
    for item, tiles in items.items():
        tiles.sort(key=lambda t: (t[0].split('_')[0], t[0].split('_')[2:], order[t[0].split('_')[1]]))
        tw, th = (crop[2] - crop[0]) * k, (crop[3] - crop[1]) * k + 12
        sheet = Image.new('RGB', (tw * cols, th * ((len(tiles) + cols - 1) // cols)), (20, 20, 24))
        d = ImageDraw.Draw(sheet)
        for i, (case, p) in enumerate(tiles):
            im = Image.open(p).convert('RGB').crop(crop)
            x, y = (i % cols) * tw, (i // cols) * th
            sheet.paste(im.resize((im.width * k, im.height * k), Image.NEAREST), (x, y + 12))
            d.text((x + 2, y), f'{item} {case}', fill=(255, 255, 255))
        sheet.save(os.path.join(out, f'{item}.png'))
    print(len(items), 'sheets')


if __name__ == '__main__':
    main()
