"""Cuts a GPT-drawn walk-cycle sheet (6 frames in a row on flat magenta,
docs/art/gen/people_gpt/*_raw.png) into the strip the app uses
(assets/art/people/{id}_{toward|away}.webp, see tools/make_passengers.py):
magenta keyed out, frames found by the empty columns between them, every
frame in one shared box with the feet on the bottom row, then shrunk to the
pixel size of the station pictures' people (the sheet is drawn with big
pixels, so it is shrunk by sampling the middle of each big pixel). Frame 0
is the one with the feet closest together (someone standing and waiting).

  python tools/cut_gpt_walk.py <raw.png> <out.webp> [--height 72]
"""
import argparse

from PIL import Image
from art_io import save_art  # noqa: E402  (lossless WebP)


def is_key(c):
    r, g, b = c[:3]
    return r > 150 and b > 150 and g < 110 and abs(r - b) < 90


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('raw')
    ap.add_argument('out')
    ap.add_argument('--height', type=int, default=72)
    ap.add_argument('--frames', type=int, default=6,
                    help='7 = a standing frame first, then the 6 walking frames (kept in that order)')
    a = ap.parse_args()
    im = Image.open(a.raw).convert('RGBA')
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if is_key(px[x, y]):
                px[x, y] = (0, 0, 0, 0)
            else:
                r, g, b, al = px[x, y]
                # Pinkish fringe left by the key: pull it toward the body colour.
                if r > g + 40 and b > g + 40:
                    px[x, y] = (min(r, (g + b) // 2), g, min(b, (r + g) // 2), al)
    # Pink fringe on the outline: magenta-tinted pixels next to the cut-out
    # are dropped, twice, so no pink rim is left.
    for _ in range(2):
        drop = []
        for y in range(1, h - 1):
            for x in range(1, w - 1):
                r, g, b, al = px[x, y]
                if al and r > g + 25 and b > g + 25 and any(
                        px[x + dx, y + dy][3] == 0 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    drop.append((x, y))
        for x, y in drop:
            px[x, y] = (0, 0, 0, 0)
    # Frames: runs of columns that have something in them.
    cols = [any(px[x, y][3] for y in range(0, h, 2)) for x in range(w)]
    runs, start = [], None
    for x, on in enumerate(cols + [False]):
        if on and start is None:
            start = x
        elif not on and start is not None:
            if x - start > 20:
                runs.append((start, x))
            start = None
    assert len(runs) == a.frames, f'found {len(runs)} frames'
    frames = [im.crop((l, 0, r, h)) for l, r in runs]
    # Start the loop on the frame closest to standing still (feet closest
    # together), so the app can use frame 0 for someone waiting.
    def stride(f):
        b = f.getbbox()
        legs = f.crop((0, b[3] - (b[3] - b[1]) // 4, f.width, b[3])).getbbox()
        return legs[2] - legs[0]
    if a.frames == 6:
        first = min(range(len(frames)), key=lambda i: stride(frames[i]))
        frames = frames[first:] + frames[:first]
    boxes = [f.getbbox() for f in frames]
    top = min(b[1] for b in boxes)
    bottom = max(b[3] for b in boxes)
    fw = max(b[2] - b[0] for b in boxes)
    k = a.height / (bottom - top)
    out_w = round(fw * k) + 2
    strip = Image.new('RGBA', (out_w * len(frames), a.height))
    for i, (f, b) in enumerate(zip(frames, boxes)):
        # Centre each figure on its own middle (they walk on the spot).
        cx = (b[0] + b[2]) / 2
        part = f.crop((round(cx - fw / 2), top, round(cx + fw / 2), bottom))
        small = part.resize((round(fw * k), a.height), Image.NEAREST)
        # Fully opaque or empty, like pixel art.
        sp = small.load()
        for y in range(small.height):
            for x in range(small.width):
                c = sp[x, y]
                sp[x, y] = (c[0], c[1], c[2], 255) if c[3] >= 128 else (0, 0, 0, 0)
        strip.paste(small, (i * out_w + 1, 0))
    save_art(strip, a.out)
    print(a.out, strip.size)


if __name__ == '__main__':
    main()
