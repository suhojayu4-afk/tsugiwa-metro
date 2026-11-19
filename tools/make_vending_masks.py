"""Masks of the people standing IN FRONT of the vending machine, one per
platform picture, so the app can draw them again over the machine (it then
stands behind them, against the wall).

A person is in front when their body reaches below the machine's foot line
(they stand closer to us). People are found as the pixels that differ from
the empty platform: the floor below the foot line is plain tiles, so
anything there that is not floor is a leg or a bag; from there the person is
grown upwards through pixels unlike the wall behind the machine.

  python tools/make_vending_masks.py [--check OUT.png]

Writes assets/art/decor/vending_front/<picture name>.png (384x192, alpha =
person) for every platform picture the app can show.
"""
import glob
import os
import sys

from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VEND = Image.open(os.path.join(ROOT, 'assets/art/decor/vending.png')).convert('RGBA')
BOX = VEND.getbbox()                 # (314, 62, 335, 120)
X0, Y0, X1, FOOT = BOX[0] - 2, BOX[1] - 2, BOX[2] + 2, BOX[3]
OUT = os.path.join(ROOT, 'assets/art/decor/vending_front')


def lum(c):
    return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]


def dist(a, b):
    return sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5


def _ref_for(path):
    """The emptiest picture of the same platform and hour (crowd 'relaxed')."""
    name = os.path.basename(path)[:-4]
    if name.startswith('scene_'):
        name = 'standard_' + name[6:]
    parts = name.split('_')
    ref = os.path.join(ROOT, 'assets/art/crowd', f'{parts[0]}_{parts[1]}_relaxed.png')
    return Image.open(ref).convert('RGB') if os.path.exists(ref) else None


def mask_for(img, path):
    img = img.convert('RGB')
    px = img.load()
    w, h = img.size
    ref = _ref_for(path)
    rp = ref.load() if ref else None
    snowy = any(k in os.path.basename(path) for k in ('snow', 'winter'))

    def unlike_ref(x, y):
        """Unlike the empty platform here (best match within one pixel)."""
        c = px[x, y]
        best = 1e9
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if 0 <= x + dx < w and 0 <= y + dy < h:
                    best = min(best, dist(c, rp[x + dx, y + dy]))
        return best

    # Fallback without a reference: the wall beside the machine.
    wall = [px[x, y] for y in range(Y0, FOOT) for x in (X0 - 3, X1 + 3)]
    floor = [px[x, y] for y in range(FOOT + 5, min(h, FOOT + 16)) for x in range(X0 - 30, X1 + 30)]
    floor.sort(key=lum)
    floor_c = floor[len(floor) // 2]

    def person(x, y, strict):
        c = px[x, y]
        if rp is not None and not snowy:
            return unlike_ref(x, y) > (60 if strict else 44)
        return min(dist(c, q) for q in wall[::2]) > 34 and dist(c, floor_c) > (52 if strict else 30)

    m = Image.new('L', (w, h), 0)
    mp = m.load()
    frontier = []
    for y in range(FOOT + 4, min(h, FOOT + 14)):
        for x in range(X0, X1):
            if person(x, y, True):
                mp[x, y] = 255
                frontier.append((x, y))
    seen = set(frontier)
    while frontier:
        x, y = frontier.pop()
        for dx, dy in ((0, -1), (1, 0), (-1, 0), (1, -1), (-1, -1), (0, 1)):
            q = (x + dx, y + dy)
            if q in seen or not (X0 - 6 <= q[0] < X1 + 6 and Y0 - 4 <= q[1] < h):
                continue
            seen.add(q)
            if person(q[0], q[1], False):
                mp[q] = 255
                frontier.append(q)
    # Only people: drop bits that do not reach well above the foot line.
    bbox = m.crop((X0 - 6, Y0 - 4, X1 + 6, FOOT)).getbbox()
    if bbox is None or bbox[3] - bbox[1] < 8:
        return Image.new('L', (w, h), 0)
    return m.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))


def pictures():
    pics = glob.glob(os.path.join(ROOT, 'assets/art/scene_*.png'))
    pics = [p for p in pics if not p.endswith('_anim.png')]
    for d in ('scenes', 'crowd', 'weather'):
        pics += glob.glob(os.path.join(ROOT, f'assets/art/{d}/*.png'))
    return sorted(p for p in pics if Image.open(p).size == (384, 192))


def main():
    os.makedirs(OUT, exist_ok=True)
    check = sys.argv[sys.argv.index('--check') + 1] if '--check' in sys.argv else None
    rows = []
    for p in pictures():
        img = Image.open(p)
        m = mask_for(img, p)
        name = os.path.basename(p)
        target = os.path.join(OUT, name)
        if m.getbbox() is None:
            # Nobody in front: no file (the app then draws the machine as it is).
            if os.path.exists(target):
                os.remove(target)
        else:
            out = Image.new('RGBA', img.size, (0, 0, 0, 0))
            out.putalpha(m.point(lambda v: 255 if v > 127 else 0))
            out.save(target, optimize=True)
        if check and (hash(name) % 11 == 0 or 'relaxed' in name and 'tokyo' in name) and len(rows) < 24:
            a = img.convert('RGBA')
            b = a.copy()
            b.alpha_composite(VEND)
            front = Image.composite(a, b, m)
            rows.append((a.crop((290, 40, 384, 150)), b.crop((290, 40, 384, 150)), front.crop((290, 40, 384, 150))))
    print(len(pictures()), 'masks')
    if check:
        cw, ch = 94, 110
        sheet = Image.new('RGB', (cw * 3 * 4 + 40, ch * 6), (0, 0, 0))
        for i, (a, b, c) in enumerate(rows):
            x, y = (i % 4) * (cw * 3 + 10), (i // 4) * ch
            for k, im in enumerate((a, b, c)):
                sheet.paste(im.convert('RGB'), (x + k * cw, y))
        sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(check)


if __name__ == '__main__':
    main()
