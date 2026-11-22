"""Stands the MY decorations (tools/gen_decor_gpt.py) on the platform:

  docs/art/gen/decor/cut/{id}.png
  -> assets/art/decor/{id}.webp       (384x192 overlay, built-in scene rows)
     assets/art/decor/{id}_lit.webp   (its lamps and lit windows only, drawn
                                       at full brightness at dusk and night)
  and the list of lit overlays in assets/art/decor/index.json ("lights").

Platform things stand at the wall between the two nearest pillars (columns
305-350; the wall's foot runs from row 117 to row 124, the far pillar's
base is on row 123). In most pictures somebody waits around column 332, so
small things stand to the left of that, in front of the far pillar, and
slim tall ones to the right (tools/make_decor_masks.py knows who stands
where). The
platform's perspective gives the sizes: a person whose feet are on row y is
1.33 x (y - 92) pixels tall, so one metre is 0.8 x (y - 92) pixels. The
app moves the overlay down in pictures drawn lower (DecorIndex.shifts) and
draws the people of the picture over it (tools/make_decor_masks.py).

Roof things hang along the roof's edge beam between the pillars, smaller
towards the far end (the same line as the drawn fairy lights).

  python tools/place_decor.py [--only id ...] [--preview OUT.png]
"""
import argparse
import json
import math
import os

from PIL import Image, ImageFilter

from art_io import save_art

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))).replace('\\', '/')
CUT = f'{ROOT}/docs/art/gen/decor/cut'
OUT = f'{ROOT}/assets/art/decor'
W, H = 384, 192
HORIZON = 92
# The near pillar starts at this column: things reaching it go behind it.
PILLAR_X = 350


def metre(foot):
    """Pixels per metre for something standing on row [foot]."""
    return 1.33 * (foot - HORIZON) / 1.65


# id: height in metres, cx / foot = where its lowest point stands (column of
# the sprite's middle, row of its bottom), shear = rows the base drops per
# column to the right (the wall's foot does: 0.2), colors = palette size,
# lit = which pixels are lamps (None, 'all', or (min brightness, warm only)),
# lit_box = only inside this part of the sprite (fractions: left, top, right, bottom).
PLATFORM = {
    'vending': dict(m=1.85, cx=322, foot=124, shear=0.12, lit=(150, False), lit_box=(0.04, 0.1, 0.8, 0.7)),
    'bench': dict(m=0.86, cx=327, foot=126, shear=0.2),
    'clock': dict(m=2.75, cx=341, foot=125),
    'phone': dict(m=1.65, cx=319, foot=125, shear=0.1),
    'umbrella': dict(m=0.95, cx=315, foot=126),
    'bins': dict(m=0.95, cx=321, foot=127, shear=0.2),
    'soba': dict(m=1.95, cx=327, foot=127, shear=0.14, colors=56, lit=(190, True)),
    'kiosk': dict(m=1.95, cx=327, foot=127, shear=0.14, colors=56, lit=(200, True)),
    'planter': dict(m=0.8, cx=327, foot=127, shear=0.2),
    'board': dict(m=1.5, cx=326, foot=125, shear=0.12),
    'catbed': dict(m=0.62, cx=314, foot=128),
    'kadomatsu': dict(m=1.3, cx=317, foot=127, shear=0.15),
    'tanabata': dict(m=2.7, cx=325, foot=125),
    'xmastree': dict(m=2.0, cx=319, foot=127, lit=(225, True)),
    'pumpkin': dict(m=0.85, cx=315, foot=127, lit=(215, True)),
    'koinobori': dict(m=2.7, cx=327, foot=125),
}

# Roof: sprite, height in pixels at the nearest pillar, how many hang per
# span (None = as many as fit), lit.
ROOF = {
    'lanterns': dict(src='r_lantern', h=17, gap=1.25, lit='all'),
    'furin': dict(src='r_furin', h=23, gap=1.6),
    'tsurushi': dict(src='r_tsurushi', h=26, gap=2.2),
    'fuji': dict(src='r_fuji', h=30, gap=0.62, jitter=0.3),
}
PILLARS = [384, 358, 311, 290, 278, 268, 261]


def line_y(x):
    return 93 - 0.404 * (x - 228)


def shrink(im, height, colors=40):
    """[im] at [height] rows: each art pixel the average of its block, hard
    edges, few colours (pixel art, as tools/pixelize.py)."""
    k = height / im.height
    w = max(1, round(im.width * k))
    # Premultiplied, so the transparent surround does not darken the edge.
    pre = im.copy()
    pre.putalpha(255)
    black = Image.new('RGBA', im.size, (0, 0, 0, 255))
    pre = Image.composite(pre, black, im.getchannel('A'))
    rgb = pre.convert('RGB').resize((w, height), Image.Resampling.BOX)
    a = im.getchannel('A').resize((w, height), Image.Resampling.BOX)
    out = Image.new('RGBA', (w, height))
    op, rp, ap = out.load(), rgb.load(), a.load()
    for y in range(height):
        for x in range(w):
            al = ap[x, y]
            if al >= 128:
                r, g, b = rp[x, y]
                op[x, y] = (min(255, r * 255 // al), min(255, g * 255 // al), min(255, b * 255 // al), 255)
    q = out.convert('RGB').quantize(colors=colors, method=Image.Quantize.MEDIANCUT,
                                    dither=Image.Dither.NONE).convert('RGBA')
    q.putalpha(out.getchannel('A'))
    return q


def clear_glass(im):
    """Clear glass or acrylic drawn on the magenta page keeps its pink:
    those pixels become a pale blue-grey of the same brightness."""
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a and r > g + 18 and b > g + 18:
                v = (r + g + b) // 3
                px[x, y] = (max(0, v - 6), min(255, v + 4), min(255, v + 22), a)
    return out


def sheared(im, slope):
    """Columns pushed down by slope x (column - left): the base then follows
    the wall's foot, which comes down towards us."""
    if not slope:
        return im
    extra = math.ceil(abs(slope) * im.width)
    out = Image.new('RGBA', (im.width, im.height + extra))
    for x in range(im.width):
        dy = round(slope * x) if slope > 0 else extra + round(slope * x)
        out.paste(im.crop((x, 0, x + 1, im.height)), (x, dy))
    return out


def lights_of(im, rule, part=None):
    """The lamp pixels of [im] as their own picture, or None."""
    if rule is None:
        return None
    if rule == 'all':
        return im.copy()
    vmin, warm = rule
    out = Image.new('RGBA', im.size)
    px, op = im.load(), out.load()
    n = 0
    bx = im.getbbox()
    if part:
        w, h = bx[2] - bx[0], bx[3] - bx[1]
        bx = (bx[0] + round(part[0] * w), bx[1] + round(part[1] * h), bx[0] + round(part[2] * w), bx[1] + round(part[3] * h))
    for y in range(bx[1], bx[3]):
        for x in range(bx[0], bx[2]):
            r, g, b, a = px[x, y]
            if a and max(r, g, b) >= vmin and (not warm or (r >= b + 18 and g >= b)):
                op[x, y] = (r, g, b, 255)
                n += 1
    return out if n else None


def contact_shadow(layer):
    """A soft shadow on the floor under the thing, so it stands instead of
    floating: two rows under each column's lowest pixel."""
    a = layer.getchannel('A')
    px = a.load()
    sh = Image.new('L', layer.size, 0)
    sp = sh.load()
    box = layer.getbbox()
    for x in range(box[0], box[2]):
        for y in range(box[3] - 1, box[1], -1):
            if px[x, y]:
                # Only where it reaches the ground (the lowest third).
                if y > box[3] - (box[3] - box[1]) * 0.3:
                    for d, v in ((1, 90), (2, 50)):
                        if y + d < H:
                            sp[x, y + d] = v
                break
    sh = sh.filter(ImageFilter.BoxBlur(0.6))
    shadow = Image.new('RGBA', layer.size, (24, 18, 40, 0))
    shadow.putalpha(sh)
    out = Image.new('RGBA', layer.size)
    out.alpha_composite(shadow)
    out.alpha_composite(layer)
    # Hard alpha steps keep it pixel art.
    op = out.load()
    for y in range(H):
        for x in range(box[0] - 2, min(W, box[2] + 2)):
            r, g, b, al = op[x, y]
            if 0 < al < 255:
                op[x, y] = (r, g, b, 96 if al >= 60 else 48 if al >= 24 else 0)
    return out


def place_platform(name, c):
    src = Image.open(f'{CUT}/{name}.png').convert('RGBA')
    if c.get('clear'):
        src = clear_glass(src)
    height = max(4, round(c['m'] * metre(c['foot'])))
    sprite = sheared(shrink(src, height, c.get('colors', 40)), c.get('shear', 0))
    box = sprite.getbbox()
    sprite = sprite.crop(box)
    x0 = round(c['cx'] - sprite.width / 2)
    y0 = c['foot'] - sprite.height
    layer = Image.new('RGBA', (W, H))
    layer.alpha_composite(sprite, (x0, y0))
    layer.paste((0, 0, 0, 0), (PILLAR_X, 0, W, H))
    lit = lights_of(layer, c.get('lit'), c.get('lit_box'))
    return contact_shadow(layer), lit, (x0, y0, x0 + sprite.width, c['foot'])


def place_roof(name, c):
    src = Image.open(f'{CUT}/{c["src"]}.png').convert('RGBA')
    layer = Image.new('RGBA', (W, H))
    n = 0
    # Far spans first, so the nearer ones are drawn over them.
    for k in range(len(PILLARS) - 2, -1, -1):
        x1, x2 = PILLARS[k], PILLARS[k + 1]
        span = x1 - x2
        depth = min(1.0, max(0.22, ((x1 + x2) / 2 - 236) / 120))
        h = max(3, round(c['h'] * depth))
        sprite = shrink(src, h, 24)
        step = max(sprite.width * c['gap'], 3)
        count = max(1, int(span / step))
        for i in range(count):
            x = x2 + (i + 0.5) * span / count
            if x > W + sprite.width:
                continue
            n += 1
            drop = c.get('jitter', 0) * h * ((n * 7) % 5) / 5
            layer.alpha_composite(sprite, (round(x - sprite.width / 2), round(line_y(x) + drop)))
    return layer, lights_of(layer, c.get('lit')), layer.getbbox()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--only', nargs='*')
    ap.add_argument('--preview')
    a = ap.parse_args()
    index_path = f'{OUT}/index.json'
    index = json.load(open(index_path, encoding='utf8')) if os.path.exists(index_path) else {}
    lights = set(index.get('lights', []))
    layers = []
    for name, c in list(PLATFORM.items()) + list(ROOF.items()):
        if a.only and name not in a.only:
            continue
        src = f'{CUT}/{c.get("src", name)}.png'
        if not os.path.exists(src):
            print('no art:', name)
            continue
        layer, lit, box = place_platform(name, c) if name in PLATFORM else place_roof(name, c)
        save_art(layer, f'{OUT}/{name}.webp')
        asset = f'assets/art/decor/{name}.webp'
        lit_path = f'{OUT}/{name}_lit.webp'
        if lit is not None:
            save_art(lit, lit_path)
            lights.add(asset)
        else:
            lights.discard(asset)
            if os.path.exists(lit_path):
                os.remove(lit_path)
        layers.append((name, layer))
        print(name, box, 'lit' if lit is not None else '')
    index['lights'] = sorted(lights)
    with open(index_path, 'w', encoding='utf8') as f:
        json.dump(index, f, indent=1)
    if a.preview:
        bg = Image.open(f'{ROOT}/assets/art/scenes/tokyo_day.webp').convert('RGBA')
        crop = (236, 0, 384, 150)
        cols = 6
        tw, th = (crop[2] - crop[0]) * 3, (crop[3] - crop[1]) * 3
        sheet = Image.new('RGB', (tw * cols, th * ((len(layers) + cols - 1) // cols)))
        for i, (name, layer) in enumerate(layers):
            im = bg.copy()
            im.alpha_composite(layer)
            im = im.crop(crop)
            sheet.paste(im.resize((tw, th), Image.NEAREST).convert('RGB'), ((i % cols) * tw, (i // cols) * th))
        sheet.save(a.preview)


if __name__ == '__main__':
    main()
