"""Iso sketch of Tokyo Big Sight (4 inverted pyramids on pillars over a glass hall)."""
import sys
from PIL import Image, ImageDraw

W = H = 64
CX, CY = 32, 45  # screen pos of world origin centre


def P(x, y, z):
    # world centred at (15,15); 2:1 iso
    x -= 14; y -= 14
    return (CX + (x - y), CY + (x + y) / 2 - z)


def poly(d, pts, col):
    d.polygon([P(*p) for p in pts], fill=col)


def build(scale=1):
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # plaza (thin slab, 3px side so flatten can cut it)
    a, b, t = 0, 28, 3
    poly(d, [(b, a, 0), (b, b, 0), (b, b, -t), (b, a, -t)], (150, 150, 150, 255))   # right side
    poly(d, [(a, b, 0), (b, b, 0), (b, b, -t), (a, b, -t)], (120, 120, 125, 255))   # left side
    poly(d, [(a, a, 0), (b, a, 0), (b, b, 0), (a, b, 0)], (196, 196, 192, 255))
    # glass hall
    h0, h1, hz = 6, 22, 4
    poly(d, [(h1, h0, 0), (h1, h1, 0), (h1, h1, hz), (h1, h0, hz)], (120, 170, 205, 255))
    poly(d, [(h0, h1, 0), (h1, h1, 0), (h1, h1, hz), (h0, h1, hz)], (90, 135, 175, 255))
    poly(d, [(h0, h0, hz), (h1, h0, hz), (h1, h1, hz), (h0, h1, hz)], (215, 218, 222, 255))
    # glass mullions
    for k in range(h0 + 3, h1, 3):
        d.line([P(h1, k, 0), P(h1, k, hz)], fill=(80, 110, 140, 255))
        d.line([P(k, h1, 0), P(k, h1, hz)], fill=(60, 90, 120, 255))
    # pyramids: 2x2, tops 12x12, top z 34, apex z 21
    s, zt, za, g = 10, 32, 13, 4
    o = 2
    cells = sorted([(o + i * (s + g), o + j * (s + g)) for i in range(2) for j in range(2)], key=lambda c: c[0] + c[1])
    # pillars under apexes
    for x0, y0 in cells:
        cx, cy = x0 + s / 2, y0 + s / 2
        p1, p2 = P(cx, cy, hz), P(cx, cy, za)
        d.rectangle([p1[0] - 1, p2[1], p1[0] + 1, p1[1]], fill=(110, 112, 118, 255))
        d.line([(p1[0] + 1, p2[1]), (p1[0] + 1, p1[1])], fill=(80, 82, 90, 255))
    for x0, y0 in cells:
        x1, y1 = x0 + s, y0 + s
        cx, cy = x0 + s / 2, y0 + s / 2
        ap = (cx, cy, za)
        poly(d, [(x1, y0, zt), (x1, y1, zt), ap], (150, 154, 162, 255))   # +x face (lit right)
        poly(d, [(x0, y1, zt), (x1, y1, zt), ap], (105, 108, 118, 255))   # +y face (shaded left)
        poly(d, [(x0, y0, zt), (x1, y0, zt), (x1, y1, zt), (x0, y1, zt)], (225, 228, 232, 255))
        # roof edge highlight / outline
        d.line([P(x0, y1, zt), P(x1, y1, zt), P(x1, y0, zt)], fill=(245, 247, 250, 255))
        # ribs on faces
        d.line([P(x1, y1, zt), P(*ap)], fill=(80, 82, 92, 255))
    # seams between the four roofs
    # selective outline: darken opaque pixels touching transparency
    px = im.load(); edge = []
    for y in range(H):
        for x in range(W):
            if px[x, y][3] and any(not (0 <= x+dx < W and 0 <= y+dy < H) or px[x+dx, y+dy][3] == 0 for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))):
                edge.append((x, y))
    for x, y in edge:
        r, g_, b_, a_ = px[x, y]
        px[x, y] = (int(r*.45), int(g_*.45), int(b_*.5), 255)
    return im


if __name__ == '__main__':
    im = build()
    im.save(sys.argv[1])
    im.resize((384, 384), Image.NEAREST).save(sys.argv[1].replace('.png', '_x6.png'))
