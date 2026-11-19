"""The Rainbow Bridge as one picture that spans the water from Shibaura to
Daiba (1 picture pixel = 2 map units, drawn with the ground so its ends stay
on the shores at every zoom). Writes assets/art/landmarks/rainbow_bridge.png
and prints where it goes in map.json (bottom-centre position).

  python tools/make_rainbow_bridge.py
"""
import json
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Map units (tools/build_map.py to_map) of the two anchorages and the towers.
A, B = (7552, 7390), (7718, 7450)
TW, TE = (7612, 7413), (7675, 7429)
U = 2                                  # map units per picture pixel
TOWER = 15                             # tower height in pixels above the deck
PAD = 3

WHITE, LIGHT, MID, SHADE, DARK = (250, 250, 246), (226, 228, 232), (184, 188, 198), (140, 146, 160), (92, 98, 116)
DECK_T, DECK_U = (210, 212, 218), (112, 118, 134)


def main() -> None:
    x0 = min(A[0], B[0]) / U - PAD
    y0 = min(A[1], B[1]) / U - TOWER - PAD - 2
    w = int(abs(B[0] - A[0]) / U + 2 * PAD) + 1
    h = int(abs(B[1] - A[1]) / U + TOWER + 2 * PAD + 5)
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = img.load()

    def pt(p):
        return (p[0] / U - x0, p[1] / U - y0)

    def put(x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < w and 0 <= y < h:
            px[x, y] = c + (255,)

    a, b, tw, te = pt(A), pt(B), pt(TW), pt(TE)

    def deck_y(x):
        return a[1] + (b[1] - a[1]) * (x - a[0]) / (b[0] - a[0])

    # Deck: light road on top, darker girder underneath, pillars down to the water at the ends.
    for xi in range(int(a[0]), int(b[0]) + 1):
        y = deck_y(xi)
        put(xi, y - 1, LIGHT)
        put(xi, y, DECK_T)
        put(xi, y + 1, DECK_U)
        put(xi, y + 2, DARK if xi % 2 else DECK_U)
    for x in (a[0] + 2, b[0] - 2):
        for dy in range(2, 5):
            put(x, deck_y(x) + dy, SHADE)

    # Main cables: anchorage → tower top → sag → tower top → anchorage.
    def tower_top(t):
        return (t[0], deck_y(t[0]) - TOWER)

    t1, t2 = tower_top(tw), tower_top(te)

    def cable_y(x):
        if x <= t1[0]:
            f = (x - a[0]) / (t1[0] - a[0])
            return deck_y(a[0]) - 1 + (t1[1] - deck_y(a[0]) + 1) * f * f
        if x >= t2[0]:
            f = (b[0] - x) / (b[0] - t2[0])
            return deck_y(b[0]) - 1 + (t2[1] - deck_y(b[0]) + 1) * f * f
        f = (x - t1[0]) / (t2[0] - t1[0])
        top = t1[1] + (t2[1] - t1[1]) * f
        low = deck_y(x) - 2.5
        return top + (low - top) * (1 - (2 * f - 1) ** 2)

    # Hangers (thin, every other pixel), then the cable over them.
    for xi in range(int(a[0]) + 2, int(b[0]) - 1, 2):
        cy, dy = cable_y(xi), deck_y(xi) - 2
        for y in range(int(round(cy)) + 1, int(round(dy)) + 1):
            if px[xi, y][3] == 0:
                put(xi, y, MID)
    for xi in range(int(a[0]), int(b[0]) + 1):
        put(xi, cable_y(xi), WHITE)

    # Towers: two white legs with cross beams, shaded on the right (light from the top left).
    for t, top in ((tw, t1), (te, t2)):
        base = deck_y(t[0]) + 2
        for y in range(int(round(top[1])), int(round(base)) + 1):
            put(t[0] - 1, y, WHITE)
            put(t[0], y, LIGHT)
            put(t[0] + 1, y, SHADE)
        for k in (2, 7, 12):
            put(t[0] - 2, top[1] + k, LIGHT)
            put(t[0] + 2, top[1] + k, SHADE)
        put(t[0], top[1] - 1, WHITE)
        # Footing in the water.
        for dx in (-2, -1, 0, 1, 2):
            put(t[0] + dx, base + 1, DARK)

    out = os.path.join(ROOT, 'assets', 'art', 'landmarks', 'rainbow_bridge.png')
    img.save(out)
    # The app draws a landmark with its bottom centre at (x, y) + 4 picture px down.
    cx = x0 * U + w * U / 2
    by = (y0 + h) * U - 4 * U
    print(json.dumps({'image': 'assets/art/landmarks/rainbow_bridge.png', 'x': round(cx), 'y': round(by),
                      'size': [w, h]}))


if __name__ == '__main__':
    main()
